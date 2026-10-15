// The PDF backend on poppler-glib (the system library, `poppler-glib` on Fedora) through FFI,
// with cairo for the bitmaps. Each document lives in its own worker isolate: rendering a page
// can take tens of milliseconds and must not stop the interface, and poppler documents are not
// meant to be used from two threads at once. The isolate owns the document; the app sends it
// requests (render a page, read the text of a page) and gets bitmaps back as transferable
// buffers.

import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui show Offset, Rect, Size;

import 'package:ffi/ffi.dart';

import 'backend.dart';

/// The real backend. [available] says whether the libraries load at all.
class PopplerBackend implements PdfBackend {
  const PopplerBackend();

  static bool? _available;

  /// Whether poppler-glib and cairo are installed.
  static bool get available => _available ??= () {
    try {
      _Poppler.load();
      return true;
    } on ArgumentError {
      return false;
    }
  }();

  @override
  Future<PdfDocumentHandle> open(String path, {String? password}) async {
    if (!available) {
      throw const PdfOpenException(
        PdfOpenFailure.unavailable,
        'libpoppler-glib.so.8 or libcairo.so.2 not found',
      );
    }
    final replies = ReceivePort();
    final first = Completer<Object?>();
    final pending = <int, Completer<Object?>>{};
    replies.listen((message) {
      if (!first.isCompleted) {
        first.complete(message);
        return;
      }
      if (message is List && message.isNotEmpty && message.first is int) {
        pending
            .remove(message.first)
            ?.complete(message.length > 1 ? message[1] : null);
      }
    });
    final isolate = await Isolate.spawn(
      _worker,
      _Start(replies.sendPort, path, password),
      debugName: 'poppler',
    );
    final hello = await first.future;
    if (hello is! _Opened) {
      replies.close();
      isolate.kill();
      final (kind, text) = hello is (int, String) ? hello : (1, 'no reply');
      throw PdfOpenException(PdfOpenFailure.values[kind], text);
    }
    return _PopplerDocument(isolate, replies, hello, pending);
  }
}

class _Start {
  const _Start(this.reply, this.path, this.password);
  final SendPort reply;
  final String path;
  final String? password;
}

class _Opened {
  _Opened(this.requests, this.sizes, this.info, this.outline, this.pageMode);
  final SendPort requests;
  final PdfPageMode pageMode;

  /// Width, height of each page.
  final List<double> sizes;
  final PdfInfo info;
  final List<PdfOutlineItem> outline;
}

class _PopplerDocument implements PdfDocumentHandle {
  _PopplerDocument(this._isolate, this._replies, this._opened, this._pending)
    : pageSizes = [
        for (var i = 0; i + 1 < _opened.sizes.length; i += 2)
          ui.Size(_opened.sizes[i], _opened.sizes[i + 1]),
      ];

  final Isolate _isolate;
  final ReceivePort _replies;
  final _Opened _opened;
  final Map<int, Completer<Object?>> _pending;
  int _next = 0;
  bool _closed = false;

  @override
  final List<ui.Size> pageSizes;

  @override
  int get pageCount => pageSizes.length;

  @override
  PdfInfo get info => _opened.info;

  @override
  List<PdfOutlineItem> get outline => _opened.outline;

  Future<Object?> _ask(List<Object?> request) {
    if (_closed) return Future.error(StateError('closed'));
    final id = _next++;
    final done = Completer<Object?>();
    _pending[id] = done;
    _opened.requests.send([id, ...request]);
    return done.future;
  }

  @override
  Future<PdfPageBitmap> render(int page, double scale) async {
    final reply = await _ask(['render', page, scale]);
    if (reply is! List || reply.length != 3) {
      throw StateError('page $page did not render');
    }
    final data = (reply[2] as TransferableTypedData)
        .materialize()
        .asUint8List();
    return PdfPageBitmap(reply[0] as int, reply[1] as int, data);
  }

  @override
  Future<PdfTextLayout> text(int page) async {
    final reply = await _ask(['text', page]);
    if (reply is! List || reply.length != 2) return PdfTextLayout('', const []);
    final boxes = reply[1] as Float64List;
    return PdfTextLayout(reply[0] as String, [
      for (var i = 0; i + 3 < boxes.length; i += 4)
        ui.Rect.fromLTRB(boxes[i], boxes[i + 1], boxes[i + 2], boxes[i + 3]),
    ]);
  }

  @override
  PdfPageMode get pageMode => _opened.pageMode;

  /// Asks the worker for an annotation change; its failure becomes an exception.
  Future<Object?> _change(List<Object?> request) async {
    final reply = await _ask(request);
    if (reply is _Failure) {
      if (request.first == 'save') throw PdfSaveException(reply.message);
      throw StateError(reply.message);
    }
    return reply;
  }

  @override
  Future<List<PdfAnnotation>> annotations(int page) async =>
      (await _change(['annotations', page]) as List?)?.cast<PdfAnnotation>() ??
      const [];

  @override
  Future<PdfAnnotation> addMarkup(
    int page,
    PdfMarkupKind kind,
    List<ui.Rect> quads,
    int argb, {
    String author = '',
    String contents = '',
  }) async =>
      await _change([
            'addMarkup',
            page,
            kind.index,
            Float64List.fromList([
              for (final r in quads) ...[r.left, r.top, r.right, r.bottom],
            ]),
            argb,
            author,
            contents,
          ])
          as PdfAnnotation;

  @override
  Future<PdfAnnotation> addNote(
    int page,
    ui.Offset at,
    int argb, {
    String author = '',
    String contents = '',
  }) async =>
      await _change(['addNote', page, at.dx, at.dy, argb, author, contents])
          as PdfAnnotation;

  @override
  Future<void> updateAnnotation(
    int page,
    int id, {
    int? argb,
    String? contents,
  }) => _change(['update', page, id, argb, contents]);

  @override
  Future<void> removeAnnotation(int page, int id) =>
      _change(['remove', page, id]);

  @override
  Future<void> saveTo(String path) => _change(['save', path]);

  @override
  Future<void> close() async {
    if (_closed) return;
    try {
      await _ask(['close']).timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // The worker is stuck in a page: it goes anyway.
    }
    _closed = true;
    for (final p in _pending.values) {
      p.completeError(StateError('closed'));
    }
    _pending.clear();
    _replies.close();
    _isolate.kill();
  }
}

// ---------------------------------------------------------------------------------------------
// The worker isolate.

Future<void> _worker(_Start start) async {
  final lib = _Poppler.load();
  final requests = ReceivePort();
  final doc = lib.openDocument(start.path, start.password);
  if (doc.$1 == nullptr) {
    start.reply.send((doc.$2, doc.$3));
    requests.close();
    return;
  }
  final document = doc.$1;
  final count = lib.pageCount(document);
  final sizes = <double>[];
  for (var i = 0; i < count; i++) {
    final (w, h) = lib.pageSize(document, i);
    sizes
      ..add(w)
      ..add(h);
  }
  start.reply.send(
    _Opened(
      requests.sendPort,
      sizes,
      lib.info(
        document,
        encrypted:
            (start.password?.isNotEmpty ?? false) ||
            lib.edit.restricted(document),
      ),
      lib.outline(document),
      lib.edit.pageMode(document),
    ),
  );
  await for (final message in requests) {
    if (message is! List || message.length < 2) continue;
    final id = message[0] as int;
    switch (message[1]) {
      case 'render':
        final page = message[2] as int;
        final scale = message[3] as double;
        final bitmap = lib.render(document, page, scale);
        start.reply.send([
          id,
          bitmap == null
              ? null
              : [
                  bitmap.width,
                  bitmap.height,
                  TransferableTypedData.fromList([bitmap.bgra]),
                ],
        ]);
      case 'text':
        final (text, boxes) = lib.text(document, message[2] as int);
        start.reply.send([
          id,
          [text, boxes],
        ]);
      case 'annotations' ||
          'addMarkup' ||
          'addNote' ||
          'update' ||
          'remove' ||
          'save':
        Object? result;
        try {
          result = _edit(lib.edit, document, message);
        } on PdfSaveException catch (e) {
          result = _Failure(e.message);
        } on Object catch (e) {
          result = _Failure('$e');
        }
        start.reply.send([id, result]);
      case 'close':
        lib.edit.release();
        lib.unref(document.cast());
        start.reply.send([id]);
        requests.close();
    }
  }
}

/// An annotation request in the worker: its result (or throws).
Object? _edit(_Edit edit, _Doc doc, List<Object?> m) {
  final page = m.length > 2 ? m[2] : null;
  switch (m[1]) {
    case 'annotations':
      return edit.annotations(doc, page! as int);
    case 'addMarkup':
      final boxes = m[4]! as Float64List;
      return edit.addMarkup(
        doc,
        page! as int,
        PdfMarkupKind.values[m[3]! as int],
        [
          for (var i = 0; i + 3 < boxes.length; i += 4)
            ui.Rect.fromLTRB(
              boxes[i],
              boxes[i + 1],
              boxes[i + 2],
              boxes[i + 3],
            ),
        ],
        m[5]! as int,
        m[6]! as String,
        m[7]! as String,
      );
    case 'addNote':
      return edit.addNote(
        doc,
        page! as int,
        m[3]! as double,
        m[4]! as double,
        m[5]! as int,
        m[6]! as String,
        m[7]! as String,
      );
    case 'update':
      edit.update(
        doc,
        page! as int,
        m[3]! as int,
        m[4] as int?,
        m[5] as String?,
      );
      return null;
    case 'remove':
      edit.remove(doc, page! as int, m[3]! as int);
      return null;
    case 'save':
      edit.save(doc, page! as String);
      return null;
  }
  return null;
}

// ---------------------------------------------------------------------------------------------
// The bindings.

typedef _Doc = Pointer<Void>;
typedef _Page = Pointer<Void>;

final class _GError extends Struct {
  @Uint32()
  external int domain;
  @Int32()
  external int code;
  external Pointer<Utf8> message;
}

final class _Rectangle extends Struct {
  @Double()
  external double x1;
  @Double()
  external double y1;
  @Double()
  external double x2;
  @Double()
  external double y2;
}

/// `PopplerActionGotoDest` (the other action kinds share `type` and `title`).
final class _ActionGotoDest extends Struct {
  @Int32()
  external int type;
  external Pointer<Utf8> title;
  external Pointer<_Dest> dest;
}

final class _Dest extends Struct {
  @Int32()
  external int type;
  @Int32()
  external int pageNum;
  @Double()
  external double left;
  @Double()
  external double bottom;
  @Double()
  external double right;
  @Double()
  external double top;
  @Double()
  external double zoom;
  external Pointer<Utf8> namedDest;
}

const int _actionGotoDest = 2;
const int _destNamed = 9;
const int _errorEncrypted = 1;
const int _cairoFormatArgb32 = 0;

DynamicLibrary _openFirst(List<String> names) {
  ArgumentError? last;
  for (final name in names) {
    try {
      return DynamicLibrary.open(name);
    } on ArgumentError catch (e) {
      last = e;
    }
  }
  throw last ?? ArgumentError('no library');
}

class _Poppler {
  _Poppler._(
    DynamicLibrary p,
    DynamicLibrary c,
    DynamicLibrary g,
    DynamicLibrary o,
  ) : _newFromFile = p
          .lookupFunction<
            _Doc Function(
              Pointer<Utf8>,
              Pointer<Utf8>,
              Pointer<Pointer<_GError>>,
            ),
            _Doc Function(
              Pointer<Utf8>,
              Pointer<Utf8>,
              Pointer<Pointer<_GError>>,
            )
          >('poppler_document_new_from_file'),
      _nPages = p.lookupFunction<Int32 Function(_Doc), int Function(_Doc)>(
        'poppler_document_get_n_pages',
      ),
      _getPage = p
          .lookupFunction<
            _Page Function(_Doc, Int32),
            _Page Function(_Doc, int)
          >('poppler_document_get_page'),
      _pageSize = p
          .lookupFunction<
            Void Function(_Page, Pointer<Double>, Pointer<Double>),
            void Function(_Page, Pointer<Double>, Pointer<Double>)
          >('poppler_page_get_size'),
      _renderPage = p
          .lookupFunction<
            Void Function(_Page, Pointer<Void>),
            void Function(_Page, Pointer<Void>)
          >('poppler_page_render'),
      _getText = p
          .lookupFunction<
            Pointer<Utf8> Function(_Page),
            Pointer<Utf8> Function(_Page)
          >('poppler_page_get_text'),
      _textLayout = p
          .lookupFunction<
            Int32 Function(
              _Page,
              Pointer<Pointer<_Rectangle>>,
              Pointer<Uint32>,
            ),
            int Function(_Page, Pointer<Pointer<_Rectangle>>, Pointer<Uint32>)
          >('poppler_page_get_text_layout'),
      _docString = {
        for (final name in const [
          'title',
          'author',
          'subject',
          'creator',
          'producer',
          'keywords',
          'pdf_version_string',
        ])
          name: p
              .lookupFunction<
                Pointer<Utf8> Function(_Doc),
                Pointer<Utf8> Function(_Doc)
              >('poppler_document_get_$name'),
      },
      _indexNew = p
          .lookupFunction<
            Pointer<Void> Function(_Doc),
            Pointer<Void> Function(_Doc)
          >('poppler_index_iter_new'),
      _indexChild = p
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >('poppler_index_iter_get_child'),
      _indexNext = p
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('poppler_index_iter_next'),
      _indexAction = p
          .lookupFunction<
            Pointer<_ActionGotoDest> Function(Pointer<Void>),
            Pointer<_ActionGotoDest> Function(Pointer<Void>)
          >('poppler_index_iter_get_action'),
      _indexFree = p
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('poppler_index_iter_free'),
      _actionFree = p
          .lookupFunction<
            Void Function(Pointer<_ActionGotoDest>),
            void Function(Pointer<_ActionGotoDest>)
          >('poppler_action_free'),
      _findDest = p
          .lookupFunction<
            Pointer<_Dest> Function(_Doc, Pointer<Utf8>),
            Pointer<_Dest> Function(_Doc, Pointer<Utf8>)
          >('poppler_document_find_dest'),
      _destFree = p
          .lookupFunction<
            Void Function(Pointer<_Dest>),
            void Function(Pointer<_Dest>)
          >('poppler_dest_free'),
      _surfaceCreate = c
          .lookupFunction<
            Pointer<Void> Function(Int32, Int32, Int32),
            Pointer<Void> Function(int, int, int)
          >('cairo_image_surface_create'),
      _cairoCreate = c
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >('cairo_create'),
      _cairoScale = c
          .lookupFunction<
            Void Function(Pointer<Void>, Double, Double),
            void Function(Pointer<Void>, double, double)
          >('cairo_scale'),
      _cairoRgb = c
          .lookupFunction<
            Void Function(Pointer<Void>, Double, Double, Double),
            void Function(Pointer<Void>, double, double, double)
          >('cairo_set_source_rgb'),
      _cairoPaint = c
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('cairo_paint'),
      _cairoDestroy = c
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('cairo_destroy'),
      _surfaceFlush = c
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('cairo_surface_flush'),
      _surfaceData = c
          .lookupFunction<
            Pointer<Uint8> Function(Pointer<Void>),
            Pointer<Uint8> Function(Pointer<Void>)
          >('cairo_image_surface_get_data'),
      _surfaceStride = c
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('cairo_image_surface_get_stride'),
      _surfaceDestroy = c
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('cairo_surface_destroy'),
      _gFree = g
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('g_free'),
      _errorFree = g
          .lookupFunction<
            Void Function(Pointer<_GError>),
            void Function(Pointer<_GError>)
          >('g_error_free'),
      edit = _Edit(p, g, o),
      unref = o
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('g_object_unref');

  static _Poppler load() => _Poppler._(
    _openFirst(const ['libpoppler-glib.so.8', 'libpoppler-glib.so']),
    _openFirst(const ['libcairo.so.2', 'libcairo.so']),
    _openFirst(const ['libglib-2.0.so.0', 'libglib-2.0.so']),
    _openFirst(const ['libgobject-2.0.so.0', 'libgobject-2.0.so']),
  );

  final _Doc Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Pointer<_GError>>)
  _newFromFile;
  final int Function(_Doc) _nPages;
  final _Page Function(_Doc, int) _getPage;
  final void Function(_Page, Pointer<Double>, Pointer<Double>) _pageSize;
  final void Function(_Page, Pointer<Void>) _renderPage;
  final Pointer<Utf8> Function(_Page) _getText;
  final int Function(_Page, Pointer<Pointer<_Rectangle>>, Pointer<Uint32>)
  _textLayout;
  final Map<String, Pointer<Utf8> Function(_Doc)> _docString;
  final Pointer<Void> Function(_Doc) _indexNew;
  final Pointer<Void> Function(Pointer<Void>) _indexChild;
  final int Function(Pointer<Void>) _indexNext;
  final Pointer<_ActionGotoDest> Function(Pointer<Void>) _indexAction;
  final void Function(Pointer<Void>) _indexFree;
  final void Function(Pointer<_ActionGotoDest>) _actionFree;
  final Pointer<_Dest> Function(_Doc, Pointer<Utf8>) _findDest;
  final void Function(Pointer<_Dest>) _destFree;
  final Pointer<Void> Function(int, int, int) _surfaceCreate;
  final Pointer<Void> Function(Pointer<Void>) _cairoCreate;
  final void Function(Pointer<Void>, double, double) _cairoScale;
  final void Function(Pointer<Void>, double, double, double) _cairoRgb;
  final void Function(Pointer<Void>) _cairoPaint;
  final void Function(Pointer<Void>) _cairoDestroy;
  final void Function(Pointer<Void>) _surfaceFlush;
  final Pointer<Uint8> Function(Pointer<Void>) _surfaceData;
  final int Function(Pointer<Void>) _surfaceStride;
  final void Function(Pointer<Void>) _surfaceDestroy;
  final void Function(Pointer<Void>) _gFree;
  final void Function(Pointer<_GError>) _errorFree;
  final void Function(Pointer<Void>) unref;
  final _Edit edit;

  /// The document, or null with the failure kind (index of [PdfOpenFailure]) and the message.
  (_Doc, int, String) openDocument(String path, String? password) {
    final uri = Uri.file(File(path).absolute.path).toString().toNativeUtf8();
    final pass = password == null ? nullptr : password.toNativeUtf8();
    final error = calloc<Pointer<_GError>>();
    try {
      final doc = _newFromFile(uri, pass.cast(), error);
      if (doc != nullptr) return (doc, 0, '');
      var kind = PdfOpenFailure.invalid.index;
      var text = 'not a PDF';
      if (error.value != nullptr) {
        if (error.value.ref.code == _errorEncrypted) {
          kind = PdfOpenFailure.encrypted.index;
        }
        text = error.value.ref.message.toDartString();
        _errorFree(error.value);
      }
      return (nullptr, kind, text);
    } finally {
      calloc.free(uri);
      if (pass != nullptr) calloc.free(pass);
      calloc.free(error);
    }
  }

  int pageCount(_Doc doc) => _nPages(doc);

  (double, double) pageSize(_Doc doc, int index) {
    final page = _getPage(doc, index);
    if (page == nullptr) return (612, 792);
    final w = calloc<Double>();
    final h = calloc<Double>();
    try {
      _pageSize(page, w, h);
      return (w.value, h.value);
    } finally {
      calloc
        ..free(w)
        ..free(h);
      unref(page);
    }
  }

  String _take(Pointer<Utf8> text) {
    if (text == nullptr) return '';
    final out = text.toDartString();
    _gFree(text.cast());
    return out;
  }

  PdfInfo info(_Doc doc, {bool encrypted = false}) => PdfInfo(
    title: _take(_docString['title']!(doc)),
    author: _take(_docString['author']!(doc)),
    subject: _take(_docString['subject']!(doc)),
    creator: _take(_docString['creator']!(doc)),
    producer: _take(_docString['producer']!(doc)),
    version: _take(_docString['pdf_version_string']!(doc)),
    keywords: _take(_docString['keywords']!(doc)),
    encrypted: encrypted,
  );

  List<PdfOutlineItem> outline(_Doc doc) {
    final iter = _indexNew(doc);
    if (iter == nullptr) return const [];
    try {
      return _level(doc, iter, 0);
    } finally {
      _indexFree(iter);
    }
  }

  List<PdfOutlineItem> _level(_Doc doc, Pointer<Void> iter, int depth) {
    final items = <PdfOutlineItem>[];
    do {
      final action = _indexAction(iter);
      var title = '';
      int? page;
      if (action != nullptr) {
        if (action.ref.title != nullptr)
          title = action.ref.title.toDartString();
        if (action.ref.type == _actionGotoDest)
          page = _destPage(doc, action.ref.dest);
        _actionFree(action);
      }
      var children = const <PdfOutlineItem>[];
      // A bound on the depth: a looping outline must not hang the worker.
      if (depth < 32) {
        final child = _indexChild(iter);
        if (child != nullptr) {
          children = _level(doc, child, depth + 1);
          _indexFree(child);
        }
      }
      items.add(PdfOutlineItem(title, page, children));
    } while (_indexNext(iter) != 0 && items.length < 100000);
    return items;
  }

  int? _destPage(_Doc doc, Pointer<_Dest> dest) {
    if (dest == nullptr) return null;
    if (dest.ref.type != _destNamed) {
      return dest.ref.pageNum > 0 ? dest.ref.pageNum - 1 : null;
    }
    if (dest.ref.namedDest == nullptr) return null;
    final found = _findDest(doc, dest.ref.namedDest);
    if (found == nullptr) return null;
    final page = found.ref.pageNum;
    _destFree(found);
    return page > 0 ? page - 1 : null;
  }

  PdfPageBitmap? render(_Doc doc, int index, double scale) {
    final page = _getPage(doc, index);
    if (page == nullptr) return null;
    final w = calloc<Double>();
    final h = calloc<Double>();
    try {
      _pageSize(page, w, h);
      final width = (w.value * scale).ceil().clamp(1, 16384);
      final height = (h.value * scale).ceil().clamp(1, 16384);
      final surface = _surfaceCreate(_cairoFormatArgb32, width, height);
      final cr = _cairoCreate(surface);
      _cairoRgb(cr, 1, 1, 1);
      _cairoPaint(cr);
      _cairoScale(cr, scale, scale);
      _renderPage(page, cr);
      _cairoDestroy(cr);
      _surfaceFlush(surface);
      final stride = _surfaceStride(surface);
      final data = _surfaceData(surface);
      final out = Uint8List(width * height * 4);
      if (data != nullptr) {
        final source = data.asTypedList(stride * height);
        for (var y = 0; y < height; y++) {
          out.setRange(y * width * 4, (y + 1) * width * 4, source, y * stride);
        }
      }
      _surfaceDestroy(surface);
      return PdfPageBitmap(width, height, out);
    } finally {
      calloc
        ..free(w)
        ..free(h);
      unref(page);
    }
  }

  (String, Float64List) text(_Doc doc, int index) {
    final page = _getPage(doc, index);
    if (page == nullptr) return ('', Float64List(0));
    final rects = calloc<Pointer<_Rectangle>>();
    final count = calloc<Uint32>();
    try {
      final text = _take(_getText(page));
      if (_textLayout(page, rects, count) == 0 || rects.value == nullptr) {
        return (text, Float64List(0));
      }
      final n = count.value;
      final boxes = Float64List(n * 4);
      for (var i = 0; i < n; i++) {
        final r = (rects.value + i).ref;
        boxes[i * 4] = r.x1;
        boxes[i * 4 + 1] = r.y1;
        boxes[i * 4 + 2] = r.x2;
        boxes[i * 4 + 3] = r.y2;
      }
      _gFree(rects.value.cast());
      return (text, boxes);
    } finally {
      calloc
        ..free(rects)
        ..free(count);
      unref(page);
    }
  }
}

// ---------------------------------------------------------------------------------------------
// Annotations, the page mode and saving.

final class _Quad extends Struct {
  @Double()
  external double x1;
  @Double()
  external double y1;
  @Double()
  external double x2;
  @Double()
  external double y2;
  @Double()
  external double x3;
  @Double()
  external double y3;
  @Double()
  external double x4;
  @Double()
  external double y4;
}

final class _Color extends Struct {
  @Uint16()
  external int red;
  @Uint16()
  external int green;
  @Uint16()
  external int blue;
}

final class _GArray extends Struct {
  external Pointer<Uint8> data;
  @Uint32()
  external int len;
}

final class _GList extends Struct {
  external Pointer<Void> data;
  external Pointer<_GList> next;
  external Pointer<_GList> prev;
}

final class _AnnotMapping extends Struct {
  external _Rectangle area;
  external Pointer<Void> annot;
}

/// PopplerAnnotType values.
const int _annotText = 1;
const int _annotHighlight = 9;
const int _annotUnderline = 10;
const int _annotStrikeOut = 12;

/// The full permission set of poppler (`POPPLER_PERMISSIONS_FULL`).
const int _permissionsFull = 0xff;

/// The side of a note's icon, in points.
const double noteIconSide = 22;

/// A failure inside the worker, sent back to the caller.
class _Failure {
  const _Failure(this.message);
  final String message;
}

/// One annotation the worker holds a reference to.
class _Held {
  _Held(this.id, this.annot);
  final int id;
  final Pointer<Void> annot;
}

class _Edit {
  _Edit(DynamicLibrary p, DynamicLibrary g, DynamicLibrary o)
    : _pageMode = p.lookupFunction<Int32 Function(_Doc), int Function(_Doc)>(
        'poppler_document_get_page_mode',
      ),
      _permissions = p.lookupFunction<Int32 Function(_Doc), int Function(_Doc)>(
        'poppler_document_get_permissions',
      ),
      _getPage = p
          .lookupFunction<
            _Page Function(_Doc, Int32),
            _Page Function(_Doc, int)
          >('poppler_document_get_page'),
      _pageSize = p
          .lookupFunction<
            Void Function(_Page, Pointer<Double>, Pointer<Double>),
            void Function(_Page, Pointer<Double>, Pointer<Double>)
          >('poppler_page_get_size'),
      _mapping = p
          .lookupFunction<
            Pointer<_GList> Function(_Page),
            Pointer<_GList> Function(_Page)
          >('poppler_page_get_annot_mapping'),
      _freeMapping = p
          .lookupFunction<
            Void Function(Pointer<_GList>),
            void Function(Pointer<_GList>)
          >('poppler_page_free_annot_mapping'),
      _annotType = p
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('poppler_annot_get_annot_type'),
      _getRect = p
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<_Rectangle>),
            void Function(Pointer<Void>, Pointer<_Rectangle>)
          >('poppler_annot_get_rectangle'),
      _getColor = p
          .lookupFunction<
            Pointer<_Color> Function(Pointer<Void>),
            Pointer<_Color> Function(Pointer<Void>)
          >('poppler_annot_get_color'),
      _setColor = p
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<_Color>),
            void Function(Pointer<Void>, Pointer<_Color>)
          >('poppler_annot_set_color'),
      _getContents = p
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>),
            Pointer<Utf8> Function(Pointer<Void>)
          >('poppler_annot_get_contents'),
      _setContents = p
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<Utf8>),
            void Function(Pointer<Void>, Pointer<Utf8>)
          >('poppler_annot_set_contents'),
      _getModified = p
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>),
            Pointer<Utf8> Function(Pointer<Void>)
          >('poppler_annot_get_modified'),
      _getLabel = p
          .lookupFunction<
            Pointer<Utf8> Function(Pointer<Void>),
            Pointer<Utf8> Function(Pointer<Void>)
          >('poppler_annot_markup_get_label'),
      _setLabel = p
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<Utf8>),
            void Function(Pointer<Void>, Pointer<Utf8>)
          >('poppler_annot_markup_set_label'),
      _getOpacity = p
          .lookupFunction<
            Double Function(Pointer<Void>),
            double Function(Pointer<Void>)
          >('poppler_annot_markup_get_opacity'),
      _setOpacity = p
          .lookupFunction<
            Void Function(Pointer<Void>, Double),
            void Function(Pointer<Void>, double)
          >('poppler_annot_markup_set_opacity'),
      _getQuads = p
          .lookupFunction<
            Pointer<_GArray> Function(Pointer<Void>),
            Pointer<_GArray> Function(Pointer<Void>)
          >('poppler_annot_text_markup_get_quadrilaterals'),
      _newMarkup = {
        for (final (kind, name) in const [
          (PdfMarkupKind.highlight, 'highlight'),
          (PdfMarkupKind.underline, 'underline'),
          (PdfMarkupKind.strikeOut, 'strikeout'),
        ])
          kind: p
              .lookupFunction<
                Pointer<Void> Function(
                  _Doc,
                  Pointer<_Rectangle>,
                  Pointer<_GArray>,
                ),
                Pointer<Void> Function(
                  _Doc,
                  Pointer<_Rectangle>,
                  Pointer<_GArray>,
                )
              >('poppler_annot_text_markup_new_$name'),
      },
      _newText = p
          .lookupFunction<
            Pointer<Void> Function(_Doc, Pointer<_Rectangle>),
            Pointer<Void> Function(_Doc, Pointer<_Rectangle>)
          >('poppler_annot_text_new'),
      _setIcon = p
          .lookupFunction<
            Void Function(Pointer<Void>, Pointer<Utf8>),
            void Function(Pointer<Void>, Pointer<Utf8>)
          >('poppler_annot_text_set_icon'),
      _addAnnot = p
          .lookupFunction<
            Void Function(_Page, Pointer<Void>),
            void Function(_Page, Pointer<Void>)
          >('poppler_page_add_annot'),
      _removeAnnot = p
          .lookupFunction<
            Void Function(_Page, Pointer<Void>),
            void Function(_Page, Pointer<Void>)
          >('poppler_page_remove_annot'),
      _save = p
          .lookupFunction<
            Int32 Function(_Doc, Pointer<Utf8>, Pointer<Pointer<_GError>>),
            int Function(_Doc, Pointer<Utf8>, Pointer<Pointer<_GError>>)
          >('poppler_document_save'),
      _dateParse = p
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Int64>),
            int Function(Pointer<Utf8>, Pointer<Int64>)
          >('poppler_date_parse'),
      _arrayNew = g
          .lookupFunction<
            Pointer<_GArray> Function(Int32, Int32, Uint32, Uint32),
            Pointer<_GArray> Function(int, int, int, int)
          >('g_array_sized_new'),
      _arrayAppend = g
          .lookupFunction<
            Pointer<_GArray> Function(Pointer<_GArray>, Pointer<Void>, Uint32),
            Pointer<_GArray> Function(Pointer<_GArray>, Pointer<Void>, int)
          >('g_array_append_vals'),
      _arrayFree = g
          .lookupFunction<
            Pointer<Void> Function(Pointer<_GArray>, Int32),
            Pointer<Void> Function(Pointer<_GArray>, int)
          >('g_array_free'),
      _gFree = g
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('g_free'),
      _errorFree = g
          .lookupFunction<
            Void Function(Pointer<_GError>),
            void Function(Pointer<_GError>)
          >('g_error_free'),
      _ref = o
          .lookupFunction<
            Pointer<Void> Function(Pointer<Void>),
            Pointer<Void> Function(Pointer<Void>)
          >('g_object_ref'),
      _unref = o
          .lookupFunction<
            Void Function(Pointer<Void>),
            void Function(Pointer<Void>)
          >('g_object_unref');

  final int Function(_Doc) _pageMode;
  final int Function(_Doc) _permissions;
  final _Page Function(_Doc, int) _getPage;
  final void Function(_Page, Pointer<Double>, Pointer<Double>) _pageSize;
  final Pointer<_GList> Function(_Page) _mapping;
  final void Function(Pointer<_GList>) _freeMapping;
  final int Function(Pointer<Void>) _annotType;
  final void Function(Pointer<Void>, Pointer<_Rectangle>) _getRect;
  final Pointer<_Color> Function(Pointer<Void>) _getColor;
  final void Function(Pointer<Void>, Pointer<_Color>) _setColor;
  final Pointer<Utf8> Function(Pointer<Void>) _getContents;
  final void Function(Pointer<Void>, Pointer<Utf8>) _setContents;
  final Pointer<Utf8> Function(Pointer<Void>) _getModified;
  final Pointer<Utf8> Function(Pointer<Void>) _getLabel;
  final void Function(Pointer<Void>, Pointer<Utf8>) _setLabel;
  final double Function(Pointer<Void>) _getOpacity;
  final void Function(Pointer<Void>, double) _setOpacity;
  final Pointer<_GArray> Function(Pointer<Void>) _getQuads;
  final Map<
    PdfMarkupKind,
    Pointer<Void> Function(_Doc, Pointer<_Rectangle>, Pointer<_GArray>)
  >
  _newMarkup;
  final Pointer<Void> Function(_Doc, Pointer<_Rectangle>) _newText;
  final void Function(Pointer<Void>, Pointer<Utf8>) _setIcon;
  final void Function(_Page, Pointer<Void>) _addAnnot;
  final void Function(_Page, Pointer<Void>) _removeAnnot;
  final int Function(_Doc, Pointer<Utf8>, Pointer<Pointer<_GError>>) _save;
  final int Function(Pointer<Utf8>, Pointer<Int64>) _dateParse;
  final Pointer<_GArray> Function(int, int, int, int) _arrayNew;
  final Pointer<_GArray> Function(Pointer<_GArray>, Pointer<Void>, int)
  _arrayAppend;
  final Pointer<Void> Function(Pointer<_GArray>, int) _arrayFree;
  final void Function(Pointer<Void>) _gFree;
  final void Function(Pointer<_GError>) _errorFree;
  final Pointer<Void> Function(Pointer<Void>) _ref;
  final void Function(Pointer<Void>) _unref;

  /// The annotations of each page read so far, referenced so their ids stay valid.
  final Map<int, List<_Held>> _held = {};

  /// Each page's own quarter turns, learnt from its first annotation (poppler takes new
  /// annotations in shown space but gives them back in unrotated PDF space).
  final Map<int, int> _turns = {};
  int _nextId = 1;

  PdfPageMode pageMode(_Doc doc) => switch (_pageMode(doc)) {
    2 => PdfPageMode.outlines,
    3 => PdfPageMode.thumbnails,
    4 => PdfPageMode.fullScreen,
    5 || 6 => PdfPageMode.other,
    _ => PdfPageMode.none,
  };

  /// Whether the document restricts any permission (so it is encrypted).
  bool restricted(_Doc doc) =>
      _permissions(doc) & _permissionsFull != _permissionsFull;

  String _take(Pointer<Utf8> text) {
    if (text == nullptr) return '';
    final out = text.toDartString();
    _gFree(text.cast());
    return out;
  }

  /// Runs `body` with page `index`, released after.
  T _withPage<T>(
    _Doc doc,
    int index,
    T Function(_Page page, double width, double height) body,
  ) {
    final page = _getPage(doc, index);
    if (page == nullptr) throw StateError('no page $index');
    final w = calloc<Double>();
    final h = calloc<Double>();
    try {
      _pageSize(page, w, h);
      return body(page, w.value, h.value);
    } finally {
      calloc
        ..free(w)
        ..free(h);
      _unref(page);
    }
  }

  List<_Held> _annotsOf(_Doc doc, int index) =>
      _held[index] ??= _withPage(doc, index, (page, width, height) {
        final held = <_Held>[];
        final list = _mapping(page);
        for (var node = list; node != nullptr; node = node.ref.next) {
          final mapping = node.ref.data.cast<_AnnotMapping>();
          if (mapping == nullptr || mapping.ref.annot == nullptr) continue;
          final annot = mapping.ref.annot;
          if (_kindOf(_annotType(annot)) == null) continue;
          if (!_turns.containsKey(index)) {
            final area = mapping.ref.area;
            _learnTurns(
              index,
              annot,
              _flip(area.x1, area.y1, area.x2, area.y2, height),
              width,
              height,
            );
          }
          held.add(_Held(_nextId++, _ref(annot)));
        }
        if (list != nullptr) _freeMapping(list);
        return held;
      });

  static PdfMarkupKind? _kindOf(int type) => switch (type) {
    _annotText => PdfMarkupKind.note,
    _annotHighlight => PdfMarkupKind.highlight,
    _annotUnderline => PdfMarkupKind.underline,
    _annotStrikeOut => PdfMarkupKind.strikeOut,
    _ => null,
  };

  List<PdfAnnotation> annotations(_Doc doc, int index) {
    final held = _annotsOf(doc, index);
    final size = _withPage(doc, index, (_, w, h) => ui.Size(w, h));
    return [for (final h in held) _describe(h, index, size)];
  }

  /// The rectangle of `annot` as poppler stores it: PDF space, unrotated.
  ui.Rect _raw(Pointer<Void> annot) {
    final rect = calloc<_Rectangle>();
    _getRect(annot, rect);
    final r = rect.ref;
    final out = ui.Rect.fromLTRB(
      r.x1 < r.x2 ? r.x1 : r.x2,
      r.y1 < r.y2 ? r.y1 : r.y2,
      r.x1 > r.x2 ? r.x1 : r.x2,
      r.y1 > r.y2 ? r.y1 : r.y2,
    );
    calloc.free(rect);
    return out;
  }

  /// A rectangle in unrotated PDF space (bottom-left origin) as shown: the page's quarter
  /// turns applied, from the top-left corner. `size` is the shown page size.
  static ui.Rect _shown(ui.Rect raw, int turns, ui.Size size) {
    // The unrotated page.
    final w = turns.isOdd ? size.height : size.width;
    final h = turns.isOdd ? size.width : size.height;
    ui.Offset map(double x, double y) => switch (turns) {
      1 => ui.Offset(y, x),
      2 => ui.Offset(w - x, y),
      3 => ui.Offset(h - y, w - x),
      _ => ui.Offset(x, h - y),
    };
    return ui.Rect.fromPoints(
      map(raw.left, raw.top),
      map(raw.right, raw.bottom),
    );
  }

  /// The page's own rotation, from one annotation whose shown rectangle is known.
  void _learnTurns(
    int index,
    Pointer<Void> annot,
    ui.Rect shown,
    double width,
    double height,
  ) {
    final raw = _raw(annot);
    var best = 0;
    var bestDistance = double.infinity;
    for (var turns = 0; turns < 4; turns++) {
      final r = _shown(raw, turns, ui.Size(width, height));
      final d =
          (r.left - shown.left).abs() +
          (r.top - shown.top).abs() +
          (r.right - shown.right).abs() +
          (r.bottom - shown.bottom).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = turns;
      }
    }
    _turns[index] = best;
  }

  PdfAnnotation _describe(_Held held, int page, ui.Size size) {
    final annot = held.annot;
    final kind = _kindOf(_annotType(annot))!;
    final turns = _turns[page] ?? 0;
    final bounds = _shown(_raw(annot), turns, size);
    final quads = <ui.Rect>[];
    if (kind != PdfMarkupKind.note) {
      final array = _getQuads(annot);
      if (array != nullptr) {
        final items = array.ref.data.cast<_Quad>();
        for (var i = 0; i < array.ref.len; i++) {
          final q = (items + i).ref;
          final xs = [q.x1, q.x2, q.x3, q.x4];
          final ys = [q.y1, q.y2, q.y3, q.y4];
          quads.add(
            _shown(
              ui.Rect.fromLTRB(
                xs.reduce((a, b) => a < b ? a : b),
                ys.reduce((a, b) => a < b ? a : b),
                xs.reduce((a, b) => a > b ? a : b),
                ys.reduce((a, b) => a > b ? a : b),
              ),
              turns,
              size,
            ),
          );
        }
        _arrayFree(array, 1);
      }
    }
    var argb = 0xFF000000;
    final color = _getColor(annot);
    if (color != nullptr) {
      argb =
          0xFF000000 |
          (color.ref.red >> 8) << 16 |
          (color.ref.green >> 8) << 8 |
          color.ref.blue >> 8;
      _gFree(color.cast());
    }
    final alpha = (_getOpacity(annot).clamp(0.0, 1.0) * 255).round();
    argb = (argb & 0x00FFFFFF) | alpha << 24;
    final modified = _getModified(annot);
    DateTime? when;
    if (modified != nullptr) {
      final time = calloc<Int64>();
      if (_dateParse(modified, time) != 0) {
        when = DateTime.fromMillisecondsSinceEpoch(time.value * 1000);
      }
      calloc.free(time);
      _gFree(modified.cast());
    }
    return PdfAnnotation(
      id: held.id,
      page: page,
      kind: kind,
      quads: quads,
      bounds: bounds,
      argb: argb,
      contents: _take(_getContents(annot)),
      author: _take(_getLabel(annot)),
      modified: when,
    );
  }

  /// A PDF rectangle (bottom-left origin) as a rectangle from the top-left corner.
  static ui.Rect _flip(double x1, double y1, double x2, double y2, double h) =>
      ui.Rect.fromLTRB(
        x1 < x2 ? x1 : x2,
        h - (y1 > y2 ? y1 : y2),
        x1 > x2 ? x1 : x2,
        h - (y1 < y2 ? y1 : y2),
      );

  void _style(Pointer<Void> annot, int argb, String author, String contents) {
    final color = calloc<_Color>();
    color.ref
      ..red = (argb >> 16 & 0xff) * 257
      ..green = (argb >> 8 & 0xff) * 257
      ..blue = (argb & 0xff) * 257;
    _setColor(annot, color);
    calloc.free(color);
    _setOpacity(annot, (argb >> 24 & 0xff) / 255);
    final label = author.toNativeUtf8();
    _setLabel(annot, label);
    calloc.free(label);
    final text = contents.toNativeUtf8();
    _setContents(annot, text);
    calloc.free(text);
  }

  PdfAnnotation _add(_Doc doc, int index, Pointer<Void> annot, ui.Rect shown) {
    final held = _annotsOf(doc, index);
    return _withPage(doc, index, (page, width, height) {
      _addAnnot(page, annot);
      if (!_turns.containsKey(index)) {
        _learnTurns(index, annot, shown, width, height);
      }
      final entry = _Held(_nextId++, annot);
      held.add(entry);
      return _describe(entry, index, ui.Size(width, height));
    });
  }

  PdfAnnotation addMarkup(
    _Doc doc,
    int index,
    PdfMarkupKind kind,
    List<ui.Rect> quads,
    int argb,
    String author,
    String contents,
  ) {
    if (kind == PdfMarkupKind.note || quads.isEmpty) {
      throw ArgumentError('a markup needs a kind and quads');
    }
    final height = _withPage(doc, index, (_, _, h) => h);
    final array = _arrayNew(0, 1, sizeOf<_Quad>(), quads.length);
    final quad = calloc<_Quad>();
    final rect = calloc<_Rectangle>();
    var left = double.infinity, top = double.infinity;
    var right = -double.infinity, bottom = -double.infinity;
    for (final r in quads) {
      // Upper left, upper right, lower left, lower right, in PDF space.
      quad.ref
        ..x1 = r.left
        ..y1 = height - r.top
        ..x2 = r.right
        ..y2 = height - r.top
        ..x3 = r.left
        ..y3 = height - r.bottom
        ..x4 = r.right
        ..y4 = height - r.bottom;
      _arrayAppend(array, quad.cast(), 1);
      if (r.left < left) left = r.left;
      if (r.top < top) top = r.top;
      if (r.right > right) right = r.right;
      if (r.bottom > bottom) bottom = r.bottom;
    }
    rect.ref
      ..x1 = left
      ..y1 = height - bottom
      ..x2 = right
      ..y2 = height - top;
    final annot = _newMarkup[kind]!(doc, rect, array);
    calloc
      ..free(quad)
      ..free(rect);
    _arrayFree(array, 1);
    if (annot == nullptr) throw StateError('poppler made no annotation');
    _style(annot, argb, author, contents);
    return _add(doc, index, annot, ui.Rect.fromLTRB(left, top, right, bottom));
  }

  PdfAnnotation addNote(
    _Doc doc,
    int index,
    double x,
    double y,
    int argb,
    String author,
    String contents,
  ) {
    final height = _withPage(doc, index, (_, _, h) => h);
    final rect = calloc<_Rectangle>();
    rect.ref
      ..x1 = x
      ..y1 = height - y - noteIconSide
      ..x2 = x + noteIconSide
      ..y2 = height - y;
    final annot = _newText(doc, rect);
    calloc.free(rect);
    if (annot == nullptr) throw StateError('poppler made no note');
    final icon = 'Note'.toNativeUtf8();
    _setIcon(annot, icon);
    calloc.free(icon);
    _style(annot, argb, author, contents);
    return _add(
      doc,
      index,
      annot,
      ui.Rect.fromLTWH(x, y, noteIconSide, noteIconSide),
    );
  }

  _Held _find(_Doc doc, int index, int id) => _annotsOf(
    doc,
    index,
  ).firstWhere((h) => h.id == id, orElse: () => throw StateError('no $id'));

  void update(_Doc doc, int index, int id, int? argb, String? contents) {
    final held = _find(doc, index, id);
    if (argb != null) {
      final color = calloc<_Color>();
      color.ref
        ..red = (argb >> 16 & 0xff) * 257
        ..green = (argb >> 8 & 0xff) * 257
        ..blue = (argb & 0xff) * 257;
      _setColor(held.annot, color);
      calloc.free(color);
      _setOpacity(held.annot, (argb >> 24 & 0xff) / 255);
    }
    if (contents != null) {
      final text = contents.toNativeUtf8();
      _setContents(held.annot, text);
      calloc.free(text);
    }
  }

  void remove(_Doc doc, int index, int id) {
    final held = _find(doc, index, id);
    _withPage(doc, index, (page, _, _) => _removeAnnot(page, held.annot));
    _held[index]!.remove(held);
    _unref(held.annot);
  }

  /// Saves to `path` through a temporary file next to it, renamed over it.
  void save(_Doc doc, String path) {
    final target = File(path).absolute;
    final temp = File(
      '${target.parent.path}/.${target.uri.pathSegments.last}.$pid.tmp',
    );
    final uri = Uri.file(temp.path).toString().toNativeUtf8();
    final error = calloc<Pointer<_GError>>();
    try {
      if (_save(doc, uri, error) == 0) {
        var message = 'not saved';
        if (error.value != nullptr) {
          message = error.value.ref.message.toDartString();
          _errorFree(error.value);
        }
        if (temp.existsSync()) temp.deleteSync();
        throw PdfSaveException(message);
      }
      temp.renameSync(target.path);
    } on FileSystemException catch (e) {
      if (temp.existsSync()) temp.deleteSync();
      throw PdfSaveException(e.message);
    } finally {
      calloc
        ..free(uri)
        ..free(error);
    }
  }

  /// Lets go of every annotation held (before the document goes).
  void release() {
    for (final list in _held.values) {
      for (final h in list) {
        _unref(h.annot);
      }
    }
    _held.clear();
  }
}
