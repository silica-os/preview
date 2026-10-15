// The PDF library behind an interface: the app asks for page sizes, page bitmaps, the text
// layout and the outline, and never touches the library directly. The real backend is
// poppler-glib through FFI (`poppler.dart`); tests use a fake.

import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

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
  });
  final String title;
  final String author;
  final String subject;
  final String creator;
  final String producer;

  /// "PDF-1.7".
  final String version;
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

  /// Page `page` (0-based) at `scale` pixels per point, on white.
  Future<PdfPageBitmap> render(int page, double scale);

  /// The text and its layout of page `page`.
  Future<PdfTextLayout> text(int page);

  Future<void> close();
}

/// Opens documents.
abstract class PdfBackend {
  /// Throws [PdfOpenException].
  Future<PdfDocumentHandle> open(String path, {String? password});
}
