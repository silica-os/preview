// Decoding images. PNG, JPEG, GIF (animated too), WebP and BMP go through the engine's codecs;
// TIFF through the pure-Dart `image` package in a background isolate; SVG through flutter_svg
// (drawn as vectors, sharp at every zoom). HEIC is recognised but not decoded (no decoder is
// available on Silica OS without the HEVC plugin: silica-os/preview issues).

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

import 'formats.dart';

/// Why an image did not open.
enum ImageFailure { unsupported, damaged }

class ImageLoadException implements Exception {
  const ImageLoadException(this.failure, [this.message = '']);
  final ImageFailure failure;
  final String message;

  @override
  String toString() => 'ImageLoadException(${failure.name}: $message)';
}

/// A decoded image.
sealed class ImageContent {
  /// The size in pixels (vector images: their own size in points).
  Size get size;

  /// Draws the image at full size at `scale` pixels per pixel, for exporting.
  Future<ui.Image> rasterize(double scale);

  void dispose();
}

/// Pixels; [animation] is the codec of an animated image (its first frame is [image]).
class RasterContent extends ImageContent {
  RasterContent(
    this.image, {
    this.animation,
    this.frames = 1,
    ColourInfo? colour,
  }) : colour = colour;

  final ui.Image image;
  final ui.Codec? animation;
  final int frames;

  /// The colour model when only decoding could tell it (TIFF).
  final ColourInfo? colour;

  @override
  Size get size => Size(image.width.toDouble(), image.height.toDouble());

  @override
  Future<ui.Image> rasterize(double scale) async => image.clone();

  @override
  void dispose() {
    image.dispose();
    animation?.dispose();
  }
}

/// A vector picture.
class VectorContent extends ImageContent {
  VectorContent(this.picture);

  final PictureInfo picture;

  @override
  Size get size => picture.size.isEmpty ? const Size(100, 100) : picture.size;

  @override
  Future<ui.Image> rasterize(double scale) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(scale);
    canvas.drawPicture(picture.picture);
    final width = (size.width * scale).ceil().clamp(1, 16384);
    final height = (size.height * scale).ceil().clamp(1, 16384);
    return recorder.endRecording().toImage(width, height);
  }

  @override
  void dispose() => picture.picture.dispose();
}

/// Decodes `bytes` of `format`. Throws [ImageLoadException].
Future<ImageContent> decodeImage(Uint8List bytes, FileFormat format) async {
  switch (format) {
    case FileFormat.png ||
        FileFormat.jpeg ||
        FileFormat.gif ||
        FileFormat.webp ||
        FileFormat.bmp:
      return _engine(bytes);
    case FileFormat.tiff:
      return _tiff(bytes);
    case FileFormat.svg:
      return _svg(bytes);
    case FileFormat.heic || FileFormat.pdf || FileFormat.unknown:
      throw ImageLoadException(ImageFailure.unsupported, format.label);
  }
}

Future<ImageContent> _engine(Uint8List bytes) async {
  ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
  } on Exception catch (e) {
    throw ImageLoadException(ImageFailure.damaged, '$e');
  }
  try {
    final frame = await codec.getNextFrame();
    if (codec.frameCount > 1) {
      return RasterContent(
        frame.image,
        animation: codec,
        frames: codec.frameCount,
      );
    }
    codec.dispose();
    return RasterContent(frame.image);
  } on Exception catch (e) {
    codec.dispose();
    throw ImageLoadException(ImageFailure.damaged, '$e');
  }
}

/// TIFF: decoded to RGBA in a background isolate (big scans take a while).
Future<ImageContent> _tiff(Uint8List bytes) async {
  final decoded = await Isolate.run(() {
    final tiff = img.decodeTiff(bytes);
    if (tiff == null) return null;
    final channels = tiff.numChannels;
    final depth = tiff.bitsPerChannel;
    final rgba = tiff
        .convert(format: img.Format.uint8, numChannels: 4, alpha: 255)
        .getBytes(order: img.ChannelOrder.rgba);
    return (tiff.width, tiff.height, rgba, channels, depth);
  });
  if (decoded == null) {
    throw const ImageLoadException(ImageFailure.damaged, 'TIFF');
  }
  final (width, height, rgba, channels, depth) = decoded;
  final colour = switch (channels) {
    1 => ColourInfo(ColourModel.gray, depth: depth),
    2 => ColourInfo(ColourModel.gray, alpha: true, depth: depth),
    3 => ColourInfo(ColourModel.rgb, depth: depth),
    _ => ColourInfo(ColourModel.rgb, alpha: true, depth: depth),
  };
  return RasterContent(await rgbaImage(rgba, width, height), colour: colour);
}

/// An image from RGBA pixels.
Future<ui.Image> rgbaImage(
  Uint8List rgba,
  int width,
  int height, {
  ui.PixelFormat format = ui.PixelFormat.rgba8888,
}) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, format, done.complete);
  return done.future;
}

Future<ImageContent> _svg(Uint8List bytes) async {
  var data = bytes;
  // .svgz: gzip-compressed.
  if (data.length > 2 && data[0] == 0x1F && data[1] == 0x8B) {
    try {
      data = Uint8List.fromList(gzip.decode(data));
    } on FormatException catch (e) {
      throw ImageLoadException(ImageFailure.damaged, '$e');
    }
  }
  Object? failure;
  try {
    final picture = await vg.loadPicture(
      SvgBytesLoader(data),
      null,
      onError: (error, _) => failure = error,
    );
    if (failure != null) {
      picture.picture.dispose();
      throw ImageLoadException(ImageFailure.damaged, '$failure');
    }
    return VectorContent(picture);
  } on ImageLoadException {
    rethrow;
  } on Object catch (e) {
    throw ImageLoadException(ImageFailure.damaged, '$e');
  }
}
