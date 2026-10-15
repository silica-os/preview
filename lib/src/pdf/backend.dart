// The PDF library behind an interface: the app asks for page sizes, page bitmaps, the text
// layout and the outline, and never touches the library directly. The real backend is
// poppler-glib through FFI (`poppler.dart`); tests use a fake.

import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

/// Why a document did not open.
enum PdfOpenFailure {
  /// It needs a password (or the one given is wrong).
  encrypted,

  /// It is not a PDF, or it is damaged beyond reading.
  invalid,

  /// The PDF library is not installed.
  unavailable,
}

class PdfOpenException implements Exception {
  const PdfOpenException(this.failure, [this.message = '']);
  final PdfOpenFailure failure;
  final String message;

  @override
  String toString() => 'PdfOpenException(${failure.name}: $message)';
}

/// The document's metadata (empty strings when missing).
class PdfInfo {
  const PdfInfo({
    this.title = '',
    this.author = '',
    this.subject = '',
    this.creator = '',
    this.producer = '',
    this.version = '',
    this.keywords = '',
    this.encrypted = false,
  });
  final String title;
  final String author;
  final String subject;
  final String creator;
  final String producer;

  /// "PDF-1.7".
  final String version;

  /// The Info dictionary's /Keywords, as one string.
  final String keywords;

  /// Whether the file is encrypted (it may still open without a password).
  final bool encrypted;
}

/// How the document asks to be shown when opened (the catalog's /PageMode).
enum PdfPageMode {
  /// Nothing asked, or /UseNone.
  none,

  /// /UseOutlines: the table of contents.
  outlines,

  /// /UseThumbs: the page thumbnails.
  thumbnails,

  /// /FullScreen.
  fullScreen,

  /// Optional content or attachments panels.
  other,
}

/// The annotation kinds Preview reads and writes.
enum PdfMarkupKind { highlight, underline, strikeOut, note }

/// An annotation of a page. Geometry in page points from the top-left corner, in the same
/// space as the rectangles of [PdfTextLayout] (the page's own /Rotate applied, as in
/// [PdfDocumentHandle.pageSizes]).
class PdfAnnotation {
  const PdfAnnotation({
    required this.id,
    required this.page,
    required this.kind,
    required this.bounds,
    this.quads = const [],
    this.argb = 0xFFFFFF00,
    this.contents = '',
    this.author = '',
    this.modified,
  });

  /// Stable while the document stays open.
  final int id;
  final int page;
  final PdfMarkupKind kind;

  /// The marked areas of a highlight, underline or strike-out (empty for a note).
  final List<Rect> quads;

  /// The annotation's rectangle (a note: its icon).
  final Rect bounds;

  /// The colour; alpha is the annotation's opacity.
  final int argb;

  /// The text of the annotation (a note's text, a comment on a highlight).
  final String contents;

  /// The author (the annotation's /T label).
  final String author;

  /// Last modified, when the file says.
  final DateTime? modified;
}

/// An entry of the table of contents; [page] is 0-based, null when it points nowhere in the
/// document (a link to another file, a broken destination).
class PdfOutlineItem {
  const PdfOutlineItem(this.title, this.page, [this.children = const []]);
  final String title;
  final int? page;
  final List<PdfOutlineItem> children;
}

/// The text of a page and, for each of its characters (code points, not UTF-16 units), the
/// box it occupies in page points from the top-left corner.
class PdfTextLayout {
  PdfTextLayout(this.text, this.rects) : chars = _split(text);

  final String text;
  final List<Rect> rects;

  /// [text] as one string per character, aligned with [rects].
  final List<String> chars;

  static List<String> _split(String text) => [
    for (final r in text.runes) String.fromCharCode(r),
  ];

  /// The number of characters that have a box.
  int get length => chars.length < rects.length ? chars.length : rects.length;

  /// The characters `start` (inclusive) to `end` (exclusive).
  String slice(int start, int end) => chars
      .sublist(start.clamp(0, chars.length), end.clamp(0, chars.length))
      .join();
}

/// A rendered page: premultiplied BGRA, 4 bytes per pixel, rows without padding.
class PdfPageBitmap {
  const PdfPageBitmap(this.width, this.height, this.bgra);
  final int width;
  final int height;
  final Uint8List bgra;
}

/// An open document.
abstract class PdfDocumentHandle {
  int get pageCount;

  /// The size of each page in points (its own rotation applied).
  List<Size> get pageSizes;
  PdfInfo get info;
  List<PdfOutlineItem> get outline;

  /// How the document asks to be shown.
  PdfPageMode get pageMode;

  /// Page `page` (0-based) at `scale` pixels per point, on white.
  Future<PdfPageBitmap> render(int page, double scale);

  /// The text and its layout of page `page`.
  Future<PdfTextLayout> text(int page);

  /// The highlights, underlines, strike-outs and notes of `page` (other kinds are left out).
  Future<List<PdfAnnotation>> annotations(int page);

  /// Adds a highlight, underline or strike-out over `quads` (page points, top-left origin, the
  /// page's own rotation applied, as the text layout).
  Future<PdfAnnotation> addMarkup(
    int page,
    PdfMarkupKind kind,
    List<Rect> quads,
    int argb, {
    String author = '',
    String contents = '',
  });

  /// Adds a note: a 22 pt icon with its top-left corner at `at`.
  Future<PdfAnnotation> addNote(
    int page,
    Offset at,
    int argb, {
    String author = '',
    String contents = '',
  });

  /// Changes the colour or the text of annotation `id` of `page`.
  Future<void> updateAnnotation(
    int page,
    int id, {
    int? argb,
    String? contents,
  });

  /// Removes annotation `id` of `page`.
  Future<void> removeAnnotation(int page, int id);

  /// Writes the document, with the annotation changes, to `path` (which may be the file it was
  /// opened from: it is replaced atomically). Throws [PdfSaveException].
  Future<void> saveTo(String path);

  Future<void> close();
}

/// Writing the document failed.
class PdfSaveException implements Exception {
  const PdfSaveException(this.message);
  final String message;

  @override
  String toString() => 'PdfSaveException($message)';
}

/// Opens documents.
abstract class PdfBackend {
  /// Throws [PdfOpenException].
  Future<PdfDocumentHandle> open(String path, {String? password});
}
