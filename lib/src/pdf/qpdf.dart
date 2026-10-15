// Writing PDFs: the pages of one or several documents in a new order, turned, removed or
// added blank, with bookmarks, keywords and encryption, through the qpdf C API (the system
// library `libqpdf.so.30`, `qpdf-libs` on Fedora) loaded with FFI. poppler-glib reads and draws
// documents but cannot rearrange their pages; qpdf rewrites a document object by object and
// keeps what it does not touch (outline, names, form fields, metadata).
//
// Every write runs in a short-lived isolate: qpdf blocks while it reads and writes.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui show Size;

import 'package:ffi/ffi.dart';

/// One page of a document to write.
sealed class PageSpec {
  const PageSpec({this.bookmarked = false});

  /// The page carries a bookmark (stored in the page, so it travels with it).
  final bool bookmarked;
}

/// Page `index` (0-based) of the PDF at `path`, turned by `quarterTurns` more clockwise
/// quarter turns than its own /Rotate.
class SourcePage extends PageSpec {
  const SourcePage(
    this.path,
    this.index, {
    this.password,
    this.quarterTurns = 0,
    super.bookmarked,
  });

  final String path;
  final int index;

  /// The password that opens `path`, when it has one.
  final String? password;
  final int quarterTurns;
}

/// A new empty page of `size` points.
class BlankPage extends PageSpec {
  const BlankPage(this.size, {super.bookmarked});
  final ui.Size size;
}

/// Who may open the document and what may be done with it. Encryption is AES-256 (PDF 2.0,
/// revision 6).
class PdfSecurity {
  const PdfSecurity({
    this.userPassword,
    this.ownerPassword,
    this.printing = true,
    this.copying = true,
    this.assembling = true,
    this.annotating = true,
    this.formFilling = true,
  });

  /// The password to open the document; null: it opens without one.
  final String? userPassword;

  /// The password that lifts the restrictions; null when not known (reading) or not set.
  final String? ownerPassword;
  final bool printing;

  /// Copying text and images.
  final bool copying;

  /// Inserting, deleting and rotating pages.
  final bool assembling;

  /// Adding annotations and signatures.
  final bool annotating;
  final bool formFilling;

  /// No password and every permission: writing with it removes the encryption.
  bool get isOpen =>
      (userPassword ?? '').isEmpty &&
      (ownerPassword ?? '').isEmpty &&
      printing &&
      copying &&
      assembling &&
      annotating &&
      formFilling;

  @override
  bool operator ==(Object other) =>
      other is PdfSecurity &&
      other.userPassword == userPassword &&
      other.ownerPassword == ownerPassword &&
      other.printing == printing &&
      other.copying == copying &&
      other.assembling == assembling &&
      other.annotating == annotating &&
      other.formFilling == formFilling;

  @override
  int get hashCode => Object.hash(
    userPassword,
    ownerPassword,
    printing,
    copying,
    assembling,
    annotating,
    formFilling,
  );

  @override
  String toString() =>
      'PdfSecurity(user: ${userPassword != null}, owner: ${ownerPassword != null}, '
      'print $printing, copy $copying, assemble $assembling, annotate $annotating, '
      'forms $formFilling)';
}

/// What Preview keeps in a PDF besides its pages.
class PdfExtras {
  const PdfExtras({this.bookmarks = const [], this.security});

  /// The bookmarked pages, 0-based, in order.
  final List<int> bookmarks;

  /// The encryption, null when the file is not encrypted.
  final PdfSecurity? security;
}

/// Why a write or a read failed.
enum PdfWriteFailure {
  /// qpdf is not installed.
  unavailable,

  /// A source needs a password (or the one given is wrong).
  password,

  /// A source could not be read, or a page index is out of range.
  source,

  /// The result could not be written.
  output,
}

class PdfWriteException implements Exception {
  const PdfWriteException(this.failure, [this.message = '']);
  final PdfWriteFailure failure;
  final String message;

  @override
  String toString() => 'PdfWriteException(${failure.name}: $message)';
}

/// Writes and reads PDFs at the object level (tests use a fake).
abstract class PdfWriter {
  /// Writes `pages` in order to `out`, atomically (a temporary file next to it, renamed).
  /// `security`: null keeps the encryption of the first source as it is; [PdfSecurity.isOpen]
  /// removes it; otherwise the document is encrypted with it. `keywords`, when not null,
  /// becomes the Info dictionary's /Keywords. Throws [PdfWriteException].
  Future<void> write(
    List<PageSpec> pages,
    String out, {
    PdfSecurity? security,
    String? keywords,
  });

  /// The bookmarks and the encryption of the PDF at `path`. Throws [PdfWriteException].
  Future<PdfExtras> read(String path, {String? password});
}

/// The writer on qpdf.
class QpdfWriter implements PdfWriter {
  const QpdfWriter();

  static bool? _available;

  /// Whether libqpdf loads.
  static bool get available => _available ??= () {
    try {
      _Qpdf.load();
      return true;
    } on ArgumentError {
      return false;
    }
  }();

  void _check() {
    if (!available) {
      throw const PdfWriteException(
        PdfWriteFailure.unavailable,
        'libqpdf.so.30 not found',
      );
    }
  }

  @override
  Future<void> write(
    List<PageSpec> pages,
    String out, {
    PdfSecurity? security,
    String? keywords,
  }) async {
    _check();
    final error = await Isolate.run(
      () => _writeNow(pages, out, security, keywords),
      debugName: 'qpdf write',
    );
    if (error != null) throw error;
  }

  @override
  Future<PdfExtras> read(String path, {String? password}) async {
    _check();
    final (extras, error) = await Isolate.run(
      () => _readNow(path, password),
      debugName: 'qpdf read',
    );
    if (error != null) throw error;
    return extras!;
  }
}

// ---------------------------------------------------------------------------------------------
// The work, inside the isolate.

const String _bookmarkKey = '/SilicaBookmark';

(PdfExtras?, PdfWriteException?) _readNow(String path, String? password) {
  final q = _Qpdf.load();
  final doc = q.open(path, password);
  try {
    if (doc.error case final e?) return (null, e);
    final h = doc.handle;
    final bookmarks = <int>[];
    final count = q.numPages(h);
    for (var i = 0; i < count; i++) {
      final page = q.pageN(h, i);
      if (q.hasKey(h, page, _bookmarkKey) &&
          q.boolValue(h, q.key(h, page, _bookmarkKey))) {
        bookmarks.add(i);
      }
    }
    PdfSecurity? security;
    if (q.isEncrypted(h) != 0) {
      final user = q.userPassword(h);
      security = PdfSecurity(
        userPassword: user.isEmpty ? null : user,
        printing: q.allowPrintLow(h) != 0,
        copying: q.allowExtract(h) != 0,
        assembling: q.allowAssembly(h) != 0,
        annotating: q.allowAnnotation(h) != 0,
        formFilling: q.allowForm(h) != 0,
      );
    }
    return (PdfExtras(bookmarks: bookmarks, security: security), null);
  } finally {
    q.close(doc.handle);
  }
}

PdfWriteException? _writeNow(
  List<PageSpec> pages,
  String out,
  PdfSecurity? security,
  String? keywords,
) {
  final q = _Qpdf.load();
  final base = pages.whereType<SourcePage>().firstOrNull;
  // Every open document: the base first (the result is written from it), then each other
  // source, read once per (path, password). A page used again comes from another reading of
  // its file (a page object can be in a document once).
  final handles = <_Doc>[];
  try {
    final _Doc main;
    if (base == null) {
      main = q.empty();
    } else {
      main = q.open(base.path, base.password);
    }
    handles.add(main);
    if (main.error case final e?) return e;
    final m = main.handle;
    q.pushInherited(m);
    final sources = <(String, String?), _Doc>{
      if (base != null) (base.path, base.password): main,
    };
    // Further readings of a file, for pages used more than once.
    final again = <(String, String?), List<_Doc>>{};
    final uses = <(String, String?, int), int>{};
    // The objects to add, in order: (from, page object).
    final picks = <(Pointer<Void>, int)>[];
    for (final spec in pages) {
      switch (spec) {
        case SourcePage(:final path, :final password, :final index):
          var doc = sources[(path, password)];
          if (doc == null) {
            doc = q.open(path, password);
            handles.add(doc);
            if (doc.error case final e?) return e;
            q.pushInherited(doc.handle);
            sources[(path, password)] = doc;
          }
          final use = uses[(path, password, index)] ?? 0;
          uses[(path, password, index)] = use + 1;
          if (use > 0) {
            final more = again.putIfAbsent((path, password), () => []);
            while (more.length < use) {
              final extra = q.open(path, password);
              handles.add(extra);
              if (extra.error case final e?) return e;
              q.pushInherited(extra.handle);
              more.add(extra);
            }
            doc = more[use - 1];
          }
          final count = q.numPages(doc.handle);
          if (index < 0 || index >= count) {
            return PdfWriteException(
              PdfWriteFailure.source,
              '$path has no page ${index + 1}',
            );
          }
          picks.add((doc.handle, q.pageN(doc.handle, index)));
        case BlankPage(:final size):
          final page = q.makeIndirect(
            m,
            q.parse(
              m,
              '<< /Type /Page /MediaBox [0 0 ${_num(size.width)} '
              '${_num(size.height)}] /Resources << >> >>',
            ),
          );
          picks.add((m, page));
      }
    }
    // Out with every page of the base, in with the chosen ones.
    final before = [for (var i = 0; i < q.numPages(m); i++) q.pageN(m, i)];
    for (final page in before) {
      if (q.removePage(m, page) != 0)
        return q.failure(m, PdfWriteFailure.source);
    }
    for (final (from, page) in picks) {
      if (q.addPage(m, from, page, 0) != 0) {
        return q.failure(m, PdfWriteFailure.source);
      }
    }
    for (final (i, spec) in pages.indexed) {
      final page = q.pageN(m, i);
      if (spec case SourcePage(
        :final quarterTurns,
      ) when quarterTurns % 4 != 0) {
        final own = q.hasKey(m, page, '/Rotate')
            ? q.intValue(m, q.key(m, page, '/Rotate'))
            : 0;
        final turned = ((own + quarterTurns * 90) % 360 + 360) % 360;
        q.replaceKey(m, page, '/Rotate', q.newInteger(m, turned));
      }
      if (spec.bookmarked) {
        q.replaceKey(m, page, _bookmarkKey, q.newBool(m, 1));
      } else if (q.hasKey(m, page, _bookmarkKey)) {
        q.removeKey(m, page, _bookmarkKey);
      }
    }
    if (keywords != null) q.setInfo(m, '/Keywords', keywords);
    if (q.hasError(m) != 0) return q.failure(m, PdfWriteFailure.source);

    final target = File(out).absolute;
    final temp = File(
      '${target.parent.path}/.${target.uri.pathSegments.last}.$pid.qpdf.tmp',
    );
    if (q.initWrite(m, temp.path) != 0) {
      return q.failure(m, PdfWriteFailure.output);
    }
    if (security != null) {
      if (security.isOpen) {
        q.preserveEncryption(m, 0);
      } else {
        q.encrypt(m, security);
      }
    }
    if (q.write(m) > 1 || q.hasError(m) != 0) {
      if (temp.existsSync()) temp.deleteSync();
      return q.failure(m, PdfWriteFailure.output);
    }
    try {
      temp.renameSync(target.path);
    } on FileSystemException catch (e) {
      if (temp.existsSync()) temp.deleteSync();
      return PdfWriteException(PdfWriteFailure.output, e.message);
    }
    return null;
  } finally {
    for (final doc in handles.reversed) {
      q.close(doc.handle);
    }
  }
}

String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

// ---------------------------------------------------------------------------------------------
// The bindings (qpdf-c.h).

/// An open qpdf handle and, when reading failed, why.
class _Doc {
  _Doc(this.handle, [this.error]);
  final Pointer<Void> handle;
  final PdfWriteException? error;
}

typedef _H = Pointer<Void>;

/// `qpdf_error_code_e`: `qpdf_e_password`.
const int _errorPassword = 4;

/// `qpdf_r3_print_e`.
const int _printFull = 0;
const int _printNone = 2;

class _Qpdf {
  _Qpdf._(DynamicLibrary l)
    : _init = l.lookupFunction<_H Function(), _H Function()>('qpdf_init'),
      _cleanup = l
          .lookupFunction<
            Void Function(Pointer<_H>),
            void Function(Pointer<_H>)
          >('qpdf_cleanup'),
      _silence = l.lookupFunction<Void Function(_H), void Function(_H)>(
        'qpdf_silence_errors',
      ),
      _suppressWarnings = l
          .lookupFunction<Void Function(_H, Int32), void Function(_H, int)>(
            'qpdf_set_suppress_warnings',
          ),
      hasError = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_has_error',
      ),
      _getError = l.lookupFunction<_H Function(_H), _H Function(_H)>(
        'qpdf_get_error',
      ),
      _errorText = l
          .lookupFunction<
            Pointer<Utf8> Function(_H, _H),
            Pointer<Utf8> Function(_H, _H)
          >('qpdf_get_error_full_text'),
      _errorCode = l
          .lookupFunction<Int32 Function(_H, _H), int Function(_H, _H)>(
            'qpdf_get_error_code',
          ),
      _read = l
          .lookupFunction<
            Int32 Function(_H, Pointer<Utf8>, Pointer<Utf8>),
            int Function(_H, Pointer<Utf8>, Pointer<Utf8>)
          >('qpdf_read'),
      _emptyPdf = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_empty_pdf',
      ),
      isEncrypted = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_is_encrypted',
      ),
      allowPrintLow = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_allow_print_low_res',
      ),
      allowExtract = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_allow_extract_all',
      ),
      allowAssembly = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_allow_modify_assembly',
      ),
      allowAnnotation = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_allow_modify_annotation',
      ),
      allowForm = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_allow_modify_form',
      ),
      _userPassword = l
          .lookupFunction<
            Pointer<Utf8> Function(_H),
            Pointer<Utf8> Function(_H)
          >('qpdf_get_user_password'),
      _setInfoKey = l
          .lookupFunction<
            Void Function(_H, Pointer<Utf8>, Pointer<Utf8>),
            void Function(_H, Pointer<Utf8>, Pointer<Utf8>)
          >('qpdf_set_info_key'),
      numPages = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_get_num_pages',
      ),
      pageN = l
          .lookupFunction<Uint32 Function(_H, Size), int Function(_H, int)>(
            'qpdf_get_page_n',
          ),
      pushInherited = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_push_inherited_attributes_to_page',
      ),
      addPage = l
          .lookupFunction<
            Int32 Function(_H, _H, Uint32, Int32),
            int Function(_H, _H, int, int)
          >('qpdf_add_page'),
      removePage = l
          .lookupFunction<Int32 Function(_H, Uint32), int Function(_H, int)>(
            'qpdf_remove_page',
          ),
      _hasKey = l
          .lookupFunction<
            Int32 Function(_H, Uint32, Pointer<Utf8>),
            int Function(_H, int, Pointer<Utf8>)
          >('qpdf_oh_has_key'),
      _getKey = l
          .lookupFunction<
            Uint32 Function(_H, Uint32, Pointer<Utf8>),
            int Function(_H, int, Pointer<Utf8>)
          >('qpdf_oh_get_key'),
      _replaceKey = l
          .lookupFunction<
            Void Function(_H, Uint32, Pointer<Utf8>, Uint32),
            void Function(_H, int, Pointer<Utf8>, int)
          >('qpdf_oh_replace_key'),
      _removeKey = l
          .lookupFunction<
            Void Function(_H, Uint32, Pointer<Utf8>),
            void Function(_H, int, Pointer<Utf8>)
          >('qpdf_oh_remove_key'),
      intValue = l
          .lookupFunction<Int32 Function(_H, Uint32), int Function(_H, int)>(
            'qpdf_oh_get_int_value_as_int',
          ),
      _isBool = l
          .lookupFunction<Int32 Function(_H, Uint32), int Function(_H, int)>(
            'qpdf_oh_is_bool',
          ),
      _boolValue = l
          .lookupFunction<Int32 Function(_H, Uint32), int Function(_H, int)>(
            'qpdf_oh_get_bool_value',
          ),
      newInteger = l
          .lookupFunction<Uint32 Function(_H, Int64), int Function(_H, int)>(
            'qpdf_oh_new_integer',
          ),
      newBool = l
          .lookupFunction<Uint32 Function(_H, Int32), int Function(_H, int)>(
            'qpdf_oh_new_bool',
          ),
      _parse = l
          .lookupFunction<
            Uint32 Function(_H, Pointer<Utf8>),
            int Function(_H, Pointer<Utf8>)
          >('qpdf_oh_parse'),
      makeIndirect = l
          .lookupFunction<Uint32 Function(_H, Uint32), int Function(_H, int)>(
            'qpdf_make_indirect_object',
          ),
      _initWrite = l
          .lookupFunction<
            Int32 Function(_H, Pointer<Utf8>),
            int Function(_H, Pointer<Utf8>)
          >('qpdf_init_write'),
      preserveEncryption = l
          .lookupFunction<Void Function(_H, Int32), void Function(_H, int)>(
            'qpdf_set_preserve_encryption',
          ),
      _r6 = l
          .lookupFunction<
            Void Function(
              _H,
              Pointer<Utf8>,
              Pointer<Utf8>,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
              Int32,
            ),
            void Function(
              _H,
              Pointer<Utf8>,
              Pointer<Utf8>,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
              int,
            )
          >('qpdf_set_r6_encryption_parameters2'),
      write = l.lookupFunction<Int32 Function(_H), int Function(_H)>(
        'qpdf_write',
      );

  static _Qpdf load() {
    ArgumentError? last;
    for (final name in const ['libqpdf.so.30', 'libqpdf.so.29', 'libqpdf.so']) {
      try {
        return _Qpdf._(DynamicLibrary.open(name));
      } on ArgumentError catch (e) {
        last = e;
      }
    }
    throw last ?? ArgumentError('no libqpdf');
  }

  final _H Function() _init;
  final void Function(Pointer<_H>) _cleanup;
  final void Function(_H) _silence;
  final void Function(_H, int) _suppressWarnings;
  final int Function(_H) hasError;
  final _H Function(_H) _getError;
  final Pointer<Utf8> Function(_H, _H) _errorText;
  final int Function(_H, _H) _errorCode;
  final int Function(_H, Pointer<Utf8>, Pointer<Utf8>) _read;
  final int Function(_H) _emptyPdf;
  final int Function(_H) isEncrypted;
  final int Function(_H) allowPrintLow;
  final int Function(_H) allowExtract;
  final int Function(_H) allowAssembly;
  final int Function(_H) allowAnnotation;
  final int Function(_H) allowForm;
  final Pointer<Utf8> Function(_H) _userPassword;
  final void Function(_H, Pointer<Utf8>, Pointer<Utf8>) _setInfoKey;
  final int Function(_H) numPages;
  final int Function(_H, int) pageN;
  final int Function(_H) pushInherited;
  final int Function(_H, _H, int, int) addPage;
  final int Function(_H, int) removePage;
  final int Function(_H, int, Pointer<Utf8>) _hasKey;
  final int Function(_H, int, Pointer<Utf8>) _getKey;
  final void Function(_H, int, Pointer<Utf8>, int) _replaceKey;
  final void Function(_H, int, Pointer<Utf8>) _removeKey;
  final int Function(_H, int) intValue;
  final int Function(_H, int) _isBool;
  final int Function(_H, int) _boolValue;
  final int Function(_H, int) newInteger;
  final int Function(_H, int) newBool;
  final int Function(_H, Pointer<Utf8>) _parse;
  final int Function(_H, int) makeIndirect;
  final int Function(_H, Pointer<Utf8>) _initWrite;
  final void Function(_H, int) preserveEncryption;
  final void Function(
    _H,
    Pointer<Utf8>,
    Pointer<Utf8>,
    int,
    int,
    int,
    int,
    int,
    int,
    int,
    int,
  )
  _r6;
  final int Function(_H) write;

  _H _new() {
    final h = _init();
    _silence(h);
    _suppressWarnings(h, 1);
    return h;
  }

  /// Reads `path`; on failure the handle is still returned (to be closed) with the error.
  _Doc open(String path, String? password) {
    final h = _new();
    final file = path.toNativeUtf8();
    final pass = (password ?? '').toNativeUtf8();
    try {
      final code = _read(h, file, pass);
      if (code > 1 || hasError(h) != 0) {
        return _Doc(h, failure(h, PdfWriteFailure.source));
      }
      return _Doc(h);
    } finally {
      calloc
        ..free(file)
        ..free(pass);
    }
  }

  _Doc empty() {
    final h = _new();
    if (_emptyPdf(h) > 1) return _Doc(h, failure(h, PdfWriteFailure.source));
    return _Doc(h);
  }

  void close(_H h) {
    final cell = calloc<_H>()..value = h;
    _cleanup(cell);
    calloc.free(cell);
  }

  /// The pending error of `h` as an exception (a wrong password has its own kind).
  PdfWriteException failure(_H h, PdfWriteFailure kind) {
    if (hasError(h) == 0) return PdfWriteException(kind, 'qpdf failed');
    final error = _getError(h);
    final text = _errorText(h, error);
    final message = text == nullptr ? 'qpdf failed' : text.toDartString();
    final code = _errorCode(h, error);
    return PdfWriteException(
      code == _errorPassword ? PdfWriteFailure.password : kind,
      message,
    );
  }

  String userPassword(_H h) {
    final p = _userPassword(h);
    return p == nullptr ? '' : p.toDartString();
  }

  T _withText<T>(String text, T Function(Pointer<Utf8>) body) {
    final native = text.toNativeUtf8();
    try {
      return body(native);
    } finally {
      calloc.free(native);
    }
  }

  bool hasKey(_H h, int oh, String key) =>
      _withText(key, (k) => _hasKey(h, oh, k)) != 0;
  int key(_H h, int oh, String key) => _withText(key, (k) => _getKey(h, oh, k));
  void replaceKey(_H h, int oh, String key, int value) =>
      _withText(key, (k) => _replaceKey(h, oh, k, value));
  void removeKey(_H h, int oh, String key) =>
      _withText(key, (k) => _removeKey(h, oh, k));
  bool boolValue(_H h, int oh) => _isBool(h, oh) != 0 && _boolValue(h, oh) != 0;
  int parse(_H h, String text) => _withText(text, (t) => _parse(h, t));
  int initWrite(_H h, String path) => _withText(path, (p) => _initWrite(h, p));

  void setInfo(_H h, String key, String value) =>
      _withText(key, (k) => _withText(value, (v) => _setInfoKey(h, k, v)));

  void encrypt(_H h, PdfSecurity s) {
    final user = s.userPassword ?? '';
    final owner = (s.ownerPassword ?? '').isEmpty ? user : s.ownerPassword!;
    _withText(
      user,
      (u) => _withText(
        owner,
        (o) => _r6(
          h,
          u,
          o,
          1, // accessibility: always allowed (PDF 2.0)
          s.copying ? 1 : 0,
          s.assembling ? 1 : 0,
          s.annotating ? 1 : 0,
          s.formFilling ? 1 : 0,
          // Other changes follow annotating: Preview has no separate switch.
          s.annotating ? 1 : 0,
          s.printing ? _printFull : _printNone,
          1, // encrypt the metadata too
        ),
      ),
    );
  }
}
