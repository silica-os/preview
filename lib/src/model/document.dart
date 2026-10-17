// What a window shows: a set of images (one or several files opened together) or one PDF.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:exif/exif.dart';

import '../export/export.dart' show detectTransparency;
import '../images/decode.dart';
import '../images/formats.dart';
import '../pdf/backend.dart';
import '../pdf/qpdf.dart';
import 'markup.dart';

/// The last path component.
String baseName(String path) {
  final trimmed = path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
  final i = trimmed.lastIndexOf('/');
  return i < 0 ? trimmed : trimmed.substring(i + 1);
}

/// The name without its extension.
String stemName(String path) {
  final name = baseName(path);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// One EXIF field: its key (`Image Make`, `EXIF FNumber`…) and the value as text.
typedef ExifField = (String key, String value);

/// One image of a window, with its own rotation and flips.
class ImageItem {
  ImageItem({
    required this.path,
    required this.format,
    required this.content,
    required this.fileSize,
    required this.colour,
    this.exif = const [],
    this.transparent = false,
    this.page = 0,
    this.pageCount = 1,
  });

  /// The page of a multi-page file this item shows (0-based), and how many the file has.
  final int page;
  final int pageCount;

  /// Whether some pixels are not opaque (the export offers to keep the transparency).
  final bool transparent;

  /// The file; it changes when the file is renamed.
  String path;
  final FileFormat format;
  final ImageContent content;
  final int fileSize;
  final ColourInfo colour;
  final List<ExifField> exif;

  /// Quarter turns clockwise (0–3), and the flips (applied before the rotation).
  int quarterTurns = 0;
  bool flipHorizontal = false;
  bool flipVertical = false;

  /// The size chosen with Adjust Size, null: the file's.
  Size? resized;

  /// Shapes and text drawn over the image, in its own pixels.
  final List<MarkupShape> markup = [];

  String get name => baseName(path);

  /// The image's size in pixels, after Adjust Size.
  Size get size => resized ?? content.size;

  /// The size it is written at.
  Size get pixelSize => size;

  /// The size on screen with its rotation.
  Size get turnedSize =>
      quarterTurns.isOdd ? Size(size.height, size.width) : size;

  bool get transformed => quarterTurns != 0 || flipHorizontal || flipVertical;

  /// Anything to write: a turn, a flip, a new size, markup.
  bool get changed => transformed || resized != null || markup.isNotEmpty;

  /// Whether Preview can write the image back in its own format (edits are saved to the
  /// file); other formats are only viewed rotated or flipped, and exported.
  bool get writable => switch (format) {
    FileFormat.png ||
    FileFormat.jpeg ||
    FileFormat.bmp ||
    FileFormat.tiff ||
    FileFormat.gif ||
    FileFormat.webp =>
      pageCount == 1 &&
          content is RasterContent &&
          (content as RasterContent).frames == 1,
    _ => false,
  };

  void dispose() => content.dispose();
}

/// A page of a window's PDF: a page of the open file ([source]) or a blank page inserted by the
/// user, with the quarter turns added in Preview and whether it is bookmarked. Pages can be
/// moved, removed and inserted; the file is written when the document is saved.
class PdfPage {
  PdfPage.source(int this.source, this.size, {this.bookmarked = false});
  PdfPage.blank(this.size) : source = null, bookmarked = false;

  /// The page of the file (0-based), null for a blank page.
  final int? source;

  /// Its own size in points, with the file's rotation.
  final Size size;

  /// Quarter turns clockwise added by the user (0–3).
  int quarterTurns = 0;
  bool bookmarked;

  bool get isBlank => source == null;

  /// The size on screen.
  Size get turnedSize =>
      quarterTurns.isOdd ? Size(size.height, size.width) : size;

  PdfPage copy() {
    final out = source == null
        ? PdfPage.blank(size)
        : PdfPage.source(source!, size, bookmarked: bookmarked);
    return out
      ..quarterTurns = quarterTurns
      ..bookmarked = bookmarked;
  }
}

/// A PDF of a window.
class PdfItem {
  PdfItem({
    required this.path,
    required this.handle,
    required this.fileSize,
    this.password,
  }) : pages = [
         for (final (i, size) in handle.pageSizes.indexed)
           PdfPage.source(i, size),
       ];

  /// The file; it changes when the file is renamed.
  String path;
  final PdfDocumentHandle handle;
  final int fileSize;

  /// The password it was opened with (to write it again).
  final String? password;

  /// Its encryption and permissions as read (null: not encrypted), and as chosen with Edit
  /// Permissions (written on save).
  PdfSecurity? security;
  PdfSecurity? newSecurity;

  /// The pages as shown, in order.
  final List<PdfPage> pages;

  String get name => baseName(path);
  int get pageCount => pages.length;

  /// The size of page `i` on screen, with its rotation.
  Size pageSize(int i) => pages[i].turnedSize;

  /// The size of page `i` before Preview's rotation.
  Size ownSize(int i) => pages[i].size;

  /// The quarter turns of page `i`.
  int turnsOf(int i) => pages[i].quarterTurns;

  /// Whether the pages are those of the file, in order, unturned and unmarked.
  bool get pagesUnchanged {
    if (pages.length != handle.pageCount) return false;
    for (final (i, p) in pages.indexed) {
      if (p.source != i || p.quarterTurns != 0) return false;
    }
    return true;
  }
}

sealed class Document {
  String get title;
  int get count;
  void dispose();
}

class ImageDocument extends Document {
  ImageDocument(List<ImageItem> images)
    : images = [...images],
      opened = List.unmodifiable(images);
  final List<ImageItem> images;

  /// The images in the order they were opened.
  final List<ImageItem> opened;

  @override
  String get title => images.first.name;

  @override
  int get count => images.length;

  @override
  void dispose() {
    for (final i in opened) {
      i.dispose();
    }
  }
}

class PdfDocument extends Document {
  PdfDocument(this.pdf);
  final PdfItem pdf;

  @override
  String get title => pdf.name;

  @override
  int get count => pdf.pageCount;

  @override
  void dispose() => pdf.handle.close();
}

/// Why a file did not open.
enum OpenFailure { missing, unsupported, damaged, encrypted, noPdfLibrary }

class OpenException implements Exception {
  const OpenException(this.path, this.failure, [this.detail = '']);
  final String path;
  final OpenFailure failure;
  final String detail;

  @override
  String toString() => 'OpenException($path: ${failure.name} $detail)';
}

/// Reads files into documents. The PDF backend is given (a fake in tests).
class DocumentLoader {
  const DocumentLoader({required this.pdf, this.writer});
  final PdfBackend pdf;

  /// Rewrites PDFs (pages, bookmarks, keywords, encryption); null: PDFs are only annotated.
  final PdfWriter? writer;

  /// The format of the file at `path`. Throws [OpenException].
  Future<(FileFormat, int)> probe(String path) async {
    final file = File(path);
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final head = await raf.read(1024);
      final length = await raf.length();
      return (sniffFormat(head, path), length);
    } on FileSystemException catch (e) {
      throw OpenException(path, OpenFailure.missing, e.message);
    } finally {
      await raf?.close();
    }
  }

  /// One image. Throws [OpenException].
  Future<ImageItem> image(String path) async => (await images(path)).first;

  /// The images of a file: one, or a page each for a multi-page TIFF. Throws [OpenException].
  Future<List<ImageItem>> images(String path) async {
    final (format, _) = await probe(path);
    if (!format.isImage) {
      throw OpenException(path, OpenFailure.unsupported, format.label);
    }
    final Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } on FileSystemException catch (e) {
      throw OpenException(path, OpenFailure.missing, e.message);
    }
    final List<ImageContent> contents;
    try {
      contents = await decodePages(bytes, format);
    } on ImageLoadException catch (e) {
      throw OpenException(
        path,
        e.failure == ImageFailure.unsupported
            ? OpenFailure.unsupported
            : OpenFailure.damaged,
        e.message,
      );
    }
    final fromHeader = colourInfo(bytes, format);
    final exif = await readExif(bytes, format);
    return [
      for (final (i, content) in contents.indexed)
        await _item(
          path,
          format,
          content,
          bytes.length,
          fromHeader,
          exif,
          i,
          contents.length,
        ),
    ];
  }

  Future<ImageItem> _item(
    String path,
    FileFormat format,
    ImageContent content,
    int fileSize,
    ColourInfo fromHeader,
    List<ExifField> exif,
    int page,
    int pageCount,
  ) async {
    final colour = content is RasterContent && content.colour != null
        ? content.colour!
        : fromHeader;
    return ImageItem(
      path: path,
      format: format,
      content: content,
      fileSize: fileSize,
      colour: colour,
      exif: exif,
      transparent: colour.alpha && await detectTransparency(content),
      page: page,
      pageCount: pageCount,
    );
  }

  /// A PDF. Throws [OpenException] (encrypted: ask for the password and call again).
  Future<PdfItem> pdfFile(String path, {String? password}) async {
    final (_, size) = await probe(path);
    try {
      final handle = await pdf.open(path, password: password);
      final item = PdfItem(
        path: path,
        handle: handle,
        fileSize: size,
        password: password,
      );
      // Bookmarks and the permissions are read with the writer.
      final writer = this.writer;
      if (writer != null) {
        try {
          final extras = await writer.read(path, password: password);
          for (final i in extras.bookmarks) {
            if (i >= 0 && i < item.pages.length)
              item.pages[i].bookmarked = true;
          }
          item.security = extras.security;
        } on PdfWriteException {
          // Without qpdf or with an unreadable structure: no bookmarks, nothing else lost.
        }
      }
      return item;
    } on PdfOpenException catch (e) {
      throw OpenException(path, switch (e.failure) {
        PdfOpenFailure.encrypted => OpenFailure.encrypted,
        PdfOpenFailure.invalid => OpenFailure.damaged,
        PdfOpenFailure.unavailable => OpenFailure.noPdfLibrary,
      }, e.message);
    }
  }
}

/// The EXIF keys Get Info shows, in this order.
const List<String> exifKeys = [
  'Image Make',
  'Image Model',
  'EXIF LensModel',
  'EXIF DateTimeOriginal',
  'EXIF ExposureTime',
  'EXIF FNumber',
  'EXIF ISOSpeedRatings',
  'EXIF FocalLength',
  'EXIF Flash',
  'Image Software',
];

/// The EXIF fields of [exifKeys] the image has (pure Dart, `exif` package).
Future<List<ExifField>> readExif(Uint8List bytes, FileFormat format) async {
  if (format != FileFormat.jpeg &&
      format != FileFormat.tiff &&
      format != FileFormat.png &&
      format != FileFormat.webp) {
    return const [];
  }
  try {
    final tags = await readExifFromBytes(bytes);
    return [
      for (final key in exifKeys)
        if (tags[key] case final tag? when tag.printable.trim().isNotEmpty)
          (key, tag.printable.trim()),
    ];
  } on Object {
    // A broken EXIF block only means no EXIF section.
    return const [];
  }
}
