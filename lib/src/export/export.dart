// File › Export… for images: PNG, JPEG (with a quality) or PDF, with the image's rotation and
// flips applied. Encoding runs in a background isolate (pure Dart `image` package and the PDF
// writer).

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../model/document.dart';
import 'pdf_writer.dart';

enum ExportFormat { png, jpeg, pdf }

extension ExportFormatNames on ExportFormat {
  String get label => switch (this) {
    ExportFormat.png => 'PNG',
    ExportFormat.jpeg => 'JPEG',
    ExportFormat.pdf => 'PDF',
  };

  String get extension => switch (this) {
    ExportFormat.png => 'png',
    ExportFormat.jpeg => 'jpg',
    ExportFormat.pdf => 'pdf',
  };
}

/// The export settings: the format and, for JPEG, the quality (0–1).
class ExportOptions {
  const ExportOptions(this.format, {this.quality = 0.85});
  final ExportFormat format;
  final double quality;

  /// The name of the exported file next to the original's stem.
  String fileName(String path) => '${stemName(path)}.${format.extension}';
}

/// The image as it is shown: rotated and flipped, at its full size.
Future<ui.Image> renderShown(ImageItem item) async {
  final source = await item.content.rasterize(1);
  if (!item.transformed) return source;
  final w = source.width.toDouble();
  final h = source.height.toDouble();
  final turned = item.quarterTurns.isOdd;
  final outW = turned ? h : w;
  final outH = turned ? w : h;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..translate(outW / 2, outH / 2)
    ..rotate(item.quarterTurns * math.pi / 2)
    ..scale(item.flipHorizontal ? -1 : 1, item.flipVertical ? -1 : 1)
    ..translate(-w / 2, -h / 2)
    ..drawImage(source, ui.Offset.zero, ui.Paint());
  final out = await recorder.endRecording().toImage(outW.round(), outH.round());
  source.dispose();
  return out;
}

/// The encoded file.
Future<Uint8List> encodeShown(ImageItem item, ExportOptions options) async {
  final image = await renderShown(item);
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final width = image.width;
  final height = image.height;
  image.dispose();
  if (data == null) throw StateError('no pixels');
  final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  final format = options.format;
  final quality = (options.quality * 100).round().clamp(1, 100);
  return Isolate.run(() => encodePixels(rgba, width, height, format, quality));
}

/// Encodes straight RGBA pixels.
Uint8List encodePixels(
  Uint8List rgba,
  int width,
  int height,
  ExportFormat format,
  int quality,
) {
  if (format == ExportFormat.pdf) return imagePdf(rgba, width, height);
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return switch (format) {
    ExportFormat.png => img.encodePng(image),
    // JPEG has no alpha: transparent pixels go on white.
    _ => img.encodeJpg(
      img.compositeImage(
        img.Image(width: width, height: height)
          ..clear(img.ColorRgb8(255, 255, 255)),
        image,
      ),
      quality: quality,
    ),
  };
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
  final bytes = await encodeShown(item, options);
  await File(path).writeAsBytes(bytes, flush: true);
}
