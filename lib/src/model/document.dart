// What a window shows: a set of images (one or several files opened together) or one PDF.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:exif/exif.dart';

import '../images/decode.dart';
import '../images/formats.dart';
import '../pdf/backend.dart';

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
  });

  final String path;
  final FileFormat format;
  final ImageContent content;
  final int fileSize;
  final ColourInfo colour;
  final List<ExifField> exif;

  /// Quarter turns clockwise (0–3), and the flips (applied before the rotation).
  int quarterTurns = 0;
  bool flipHorizontal = false;
  bool flipVertical = false;

  String get name => baseName(path);

  /// The image's own size.
  Size get size => content.size;

  /// The size on screen with its rotation.
  Size get turnedSize =>
      quarterTurns.isOdd ? Size(size.height, size.width) : size;

  bool get transformed => quarterTurns != 0 || flipHorizontal || flipVertical;

  void dispose() => content.dispose();
}

/// A PDF of a window; the rotation applies to every page.
class PdfItem {
  PdfItem({required this.path, required this.handle, required this.fileSize});

  final String path;
  final PdfDocumentHandle handle;
  final int fileSize;
  int quarterTurns = 0;

  String get name => baseName(path);
  int get pageCount => handle.pageCount;

  /// The size of page `i` on screen, with the rotation.
  Size pageSize(int i) {
    final s = handle.pageSizes[i];
    return quarterTurns.isOdd ? Size(s.height, s.width) : s;
  }
}

sealed class Document {
  String get title;
  int get count;
  void dispose();
}

class ImageDocument extends Document {
  ImageDocument(this.images);
  final List<ImageItem> images;

  @override
  String get title => images.first.name;

  @override
  int get count => images.length;

  @override
  void dispose() {
    for (final i in images) {
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
  const DocumentLoader({required this.pdf});
  final PdfBackend pdf;

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
  Future<ImageItem> image(String path) async {
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
    final ImageContent content;
    try {
      content = await decodeImage(bytes, format);
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
    final colour = content is RasterContent && content.colour != null
        ? content.colour!
        : fromHeader;
    return ImageItem(
      path: path,
      format: format,
      content: content,
      fileSize: bytes.length,
      colour: colour,
      exif: await readExif(bytes, format),
    );
  }

  /// A PDF. Throws [OpenException] (encrypted: ask for the password and call again).
  Future<PdfItem> pdfFile(String path, {String? password}) async {
    final (_, size) = await probe(path);
    try {
      final handle = await pdf.open(path, password: password);
      return PdfItem(path: path, handle: handle, fileSize: size);
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
