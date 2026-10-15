// Writing images: File › Export… (PREVIEW-02 › Files: JPEG, PDF, PNG and TIFF of the
// reference's formats; HEIC, JPEG 2000 and OpenEXR have no encoder in Silica, #14) and saving an
// edited image back in its own format (PNG, JPEG, TIFF, BMP, a single-frame GIF, WebP). The
// image is written as it is shown: rotated, flipped, resized, with its markup. Encoding runs in
// a background isolate (the pure Dart `image` package and the PDF writer).

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../images/decode.dart';
import '../images/formats.dart';
import '../model/document.dart';
import 'pdf_writer.dart';

/// The formats of the export sheet, in its order.
enum ExportFormat { jpeg, pdf, png, tiff }

extension ExportFormatNames on ExportFormat {
  String get label => switch (this) {
    ExportFormat.png => 'PNG',
    ExportFormat.jpeg => 'JPEG',
    ExportFormat.pdf => 'PDF',
    ExportFormat.tiff => 'TIFF',
  };

  String get extension => switch (this) {
    ExportFormat.png => 'png',
    ExportFormat.jpeg => 'jpg',
    ExportFormat.pdf => 'pdf',
    ExportFormat.tiff => 'tiff',
  };

  Encoding get encoding => switch (this) {
    ExportFormat.png => Encoding.png,
    ExportFormat.jpeg => Encoding.jpeg,
    ExportFormat.pdf => Encoding.pdf,
    ExportFormat.tiff => Encoding.tiff,
  };
}

/// What [encodePixels] writes.
enum Encoding { png, jpeg, tiff, bmp, gif, webp, pdf }

/// The encoding that writes an image back in its own format, null when Preview cannot.
Encoding? ownEncoding(FileFormat format) => switch (format) {
  FileFormat.png => Encoding.png,
  FileFormat.jpeg => Encoding.jpeg,
  FileFormat.tiff => Encoding.tiff,
  FileFormat.bmp => Encoding.bmp,
  FileFormat.gif => Encoding.gif,
  FileFormat.webp => Encoding.webp,
  _ => null,
};

/// The export settings: the format, the quality (JPEG, 0–1, 0.85 by default) and whether the
/// alpha channel is kept (PNG; off puts the image on white).
class ExportOptions {
  const ExportOptions(this.format, {this.quality = 0.85, this.alpha = true});
  final ExportFormat format;
  final double quality;
  final bool alpha;

  /// The name of the exported file next to the original's stem.
  String fileName(String path) => '${stemName(path)}.${format.extension}';
}

/// Whether any pixel of `content` is not fully opaque (the export sheet's alpha check box). A
/// large image is read reduced to 1024 pixels on its longer side: a transparent pixel still
/// lowers the alpha of the reduced one it falls in.
Future<bool> detectTransparency(ImageContent content) async {
  if (content is! RasterContent) return true;
  final source = content.image;
  final side = math.max(source.width, source.height);
  final k = side > 1024 ? 1024 / side : 1.0;
  final w = math.max(1, (source.width * k).round());
  final h = math.max(1, (source.height * k).round());
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    source,
    ui.Offset.zero & ui.Size(source.width.toDouble(), source.height.toDouble()),
    ui.Offset.zero & ui.Size(w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.low,
  );
  final picture = recorder.endRecording();
  final small = await picture.toImage(w, h);
  picture.dispose();
  final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
  small.dispose();
  if (data == null) return false;
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] != 255) return true;
  }
  return false;
}

/// The image as it is shown: resized, rotated, flipped, with its markup, at its full size.
Future<ui.Image> renderShown(ImageItem item) async {
  final source = await item.content.rasterize(1);
  final out = item.pixelSize;
  final markup = item.markup;
  if (!item.transformed &&
      markup.isEmpty &&
      out.width.round() == source.width &&
      out.height.round() == source.height) {
    return source;
  }
  final w = out.width;
  final h = out.height;
  final turned = item.quarterTurns.isOdd;
  final outW = turned ? h : w;
  final outH = turned ? w : h;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..translate(outW / 2, outH / 2)
    ..rotate(item.quarterTurns * math.pi / 2)
    ..scale(item.flipHorizontal ? -1 : 1, item.flipVertical ? -1 : 1)
    ..translate(-w / 2, -h / 2)
    ..drawImageRect(
      source,
      ui.Offset.zero &
          ui.Size(source.width.toDouble(), source.height.toDouble()),
      ui.Offset.zero & out,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  // The markup is drawn in the image's own (unturned) pixels, scaled with it.
  final own = item.content.size;
  canvas.scale(w / own.width, h / own.height);
  for (final shape in markup) {
    shape.paint(canvas);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(outW.round(), outH.round());
  picture.dispose();
  source.dispose();
  return image;
}

/// The encoded file.
Future<Uint8List> encodeShown(
  ImageItem item,
  Encoding encoding, {
  double quality = 0.85,
  bool alpha = true,
  Uint8List? exifFrom,
}) async {
  final image = await renderShown(item);
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final width = image.width;
  final height = image.height;
  image.dispose();
  if (data == null) throw StateError('no pixels');
  final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final q = (quality * 100).round().clamp(1, 100);
  return Isolate.run(
    () => encodePixels(
      rgba,
      width,
      height,
      encoding,
      q,
      alpha: alpha,
      exifFrom: exifFrom,
    ),
  );
}

/// Encodes straight RGBA pixels. `exifFrom`: a JPEG whose EXIF block is kept (orientation
/// reset: the pixels are already turned).
Uint8List encodePixels(
  Uint8List rgba,
  int width,
  int height,
  Encoding encoding,
  int quality, {
  bool alpha = true,
  Uint8List? exifFrom,
}) {
  if (encoding == Encoding.pdf) return imagePdf(rgba, width, height);
  var image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  img.Image onWhite() => img.compositeImage(
    img.Image(width: width, height: height)
      ..clear(img.ColorRgb8(255, 255, 255)),
    image,
  );
  if (!alpha) image = onWhite();
  switch (encoding) {
    case Encoding.png:
      return img.encodePng(image);
    case Encoding.tiff:
      return img.encodeTiff(image);
    case Encoding.bmp:
      return img.encodeBmp(image);
    case Encoding.gif:
      return img.encodeGif(image);
    case Encoding.webp:
      return img.encodeWebP(image);
    case Encoding.jpeg:
      // JPEG has no alpha: transparent pixels go on white.
      final jpeg = img.encodeJpg(onWhite(), quality: quality);
      if (exifFrom == null) return jpeg;
      final exif = img.decodeJpgExif(exifFrom);
      if (exif == null || exif.isEmpty) return jpeg;
      exif.imageIfd.orientation = null;
      return img.injectJpgExif(jpeg, exif) ?? jpeg;
    case Encoding.pdf:
      return imagePdf(rgba, width, height);
  }
}

/// Writes `item` with `options` to `path`.
typedef Exporter =
    Future<void> Function(ImageItem item, ExportOptions options, String path);

/// Exports `item` to `path`.
Future<void> exportImage(
  ImageItem item,
  ExportOptions options,
  String path,
) async {
  final bytes = await encodeShown(
    item,
    options.format.encoding,
    quality: options.quality,
    alpha: options.alpha,
  );
  await writeAtomically(path, bytes);
}

/// Writes `bytes` to a temporary file next to `path`, then puts it in its place.
Future<void> writeAtomically(String path, List<int> bytes) async {
  final temp = File('$path.preview-${DateTime.now().microsecondsSinceEpoch}');
  try {
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(path);
  } on Object {
    if (temp.existsSync()) await temp.delete();
    rethrow;
  }
}

/// Saves an edited image over its file, in its own format (JPEG keeps its EXIF block).
Future<void> saveImage(ImageItem item) async {
  final encoding = ownEncoding(item.format);
  if (encoding == null) throw StateError('${item.format.label} is not written');
  final original = item.format == FileFormat.jpeg
      ? await File(item.path).readAsBytes()
      : null;
  final bytes = await encodeShown(
    item,
    encoding,
    quality: 0.9,
    exifFrom: original,
  );
  await writeAtomically(item.path, bytes);
}
