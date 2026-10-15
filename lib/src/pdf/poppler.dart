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
import 'dart:ui' as ui show Rect, Size;

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
  _Opened(this.requests, this.sizes, this.info, this.outline);
  final SendPort requests;

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
      lib.info(document),
      lib.outline(document),
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
      case 'close':
        lib.unref(document.cast());
        start.reply.send([id]);
        requests.close();
    }
  }
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

  PdfInfo info(_Doc doc) => PdfInfo(
    title: _take(_docString['title']!(doc)),
    author: _take(_docString['author']!(doc)),
    subject: _take(_docString['subject']!(doc)),
    creator: _take(_docString['creator']!(doc)),
    producer: _take(_docString['producer']!(doc)),
    version: _take(_docString['pdf_version_string']!(doc)),
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
