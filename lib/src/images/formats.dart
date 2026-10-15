// The file formats Preview recognises, from the first bytes of the file (the extension only
// decides between plain text formats), and what their headers say about colour.

import 'dart:convert';
import 'dart:typed_data';

enum FileFormat { png, jpeg, gif, webp, bmp, tiff, svg, pdf, heic, unknown }

extension FileFormatNames on FileFormat {
  /// The extension of exported files and the kind shown by Get Info.
  String get label => switch (this) {
    FileFormat.png => 'PNG',
    FileFormat.jpeg => 'JPEG',
    FileFormat.gif => 'GIF',
    FileFormat.webp => 'WebP',
    FileFormat.bmp => 'BMP',
    FileFormat.tiff => 'TIFF',
    FileFormat.svg => 'SVG',
    FileFormat.pdf => 'PDF',
    FileFormat.heic => 'HEIC',
    FileFormat.unknown => '',
  };

  bool get isImage => switch (this) {
    FileFormat.pdf || FileFormat.heic || FileFormat.unknown => false,
    _ => true,
  };
}

bool _starts(Uint8List b, List<int> magic, [int at = 0]) {
  if (b.length < at + magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (b[at + i] != magic[i]) return false;
  }
  return true;
}

/// The format of a file starting with `head` (at least the first 64 bytes when the file has
/// them) and named `path`.
FileFormat sniffFormat(Uint8List head, String path) {
  if (_starts(head, const [0x89, 0x50, 0x4E, 0x47])) return FileFormat.png;
  if (_starts(head, const [0xFF, 0xD8, 0xFF])) return FileFormat.jpeg;
  if (_starts(head, ascii.encode('GIF8'))) return FileFormat.gif;
  if (_starts(head, ascii.encode('RIFF')) &&
      _starts(head, ascii.encode('WEBP'), 8)) {
    return FileFormat.webp;
  }
  if (_starts(head, ascii.encode('BM'))) return FileFormat.bmp;
  if (_starts(head, const [0x49, 0x49, 0x2A, 0x00]) ||
      _starts(head, const [0x4D, 0x4D, 0x00, 0x2A])) {
    return FileFormat.tiff;
  }
  if (_starts(head, ascii.encode('%PDF'))) return FileFormat.pdf;
  if (_starts(head, ascii.encode('ftyp'), 4) && head.length >= 12) {
    final brand = ascii.decode(head.sublist(8, 12), allowInvalid: true);
    if (const {
      'heic',
      'heix',
      'hevc',
      'heim',
      'heis',
      'mif1',
      'msf1',
    }.contains(brand)) {
      return FileFormat.heic;
    }
  }
  final lower = path.toLowerCase();
  if (lower.endsWith('.svg') || lower.endsWith('.svgz')) return FileFormat.svg;
  // An SVG without the extension: XML whose first element is <svg.
  final text = latin1.decode(head.length > 1024 ? head.sublist(0, 1024) : head);
  if (RegExp(
    r'^\s*(<\?xml[^>]*>\s*)?(<!--[\s\S]*?-->\s*)*(<!DOCTYPE[^>]*>\s*)?<svg[\s>]',
  ).hasMatch(text)) {
    return FileFormat.svg;
  }
  return FileFormat.unknown;
}

/// How an image stores colour: the model, whether it has alpha, the bits per sample.
class ColourInfo {
  const ColourInfo(this.model, {this.alpha = false, this.depth});

  final ColourModel model;
  final bool alpha;

  /// Bits per channel, when the header says.
  final int? depth;

  @override
  bool operator ==(Object other) =>
      other is ColourInfo &&
      other.model == model &&
      other.alpha == alpha &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(model, alpha, depth);

  @override
  String toString() =>
      'ColourInfo(${model.name}, alpha: $alpha, depth: $depth)';
}

enum ColourModel { rgb, gray, cmyk, indexed, vector, unknown }

/// The colour model from the header of an image file.
ColourInfo colourInfo(Uint8List bytes, FileFormat format) {
  switch (format) {
    case FileFormat.png:
      if (bytes.length < 26) return const ColourInfo(ColourModel.unknown);
      final depth = bytes[24];
      return switch (bytes[25]) {
        0 => ColourInfo(ColourModel.gray, depth: depth),
        2 => ColourInfo(ColourModel.rgb, depth: depth),
        3 => ColourInfo(ColourModel.indexed, depth: depth),
        4 => ColourInfo(ColourModel.gray, alpha: true, depth: depth),
        6 => ColourInfo(ColourModel.rgb, alpha: true, depth: depth),
        _ => const ColourInfo(ColourModel.unknown),
      };
    case FileFormat.jpeg:
      return _jpegColour(bytes);
    case FileFormat.gif:
      return const ColourInfo(ColourModel.indexed, depth: 8);
    case FileFormat.webp:
      final alpha =
          (bytes.length > 20 &&
              _starts(bytes, ascii.encode('VP8X'), 12) &&
              bytes[20] & 0x10 != 0) ||
          _starts(bytes, ascii.encode('VP8L'), 12);
      return ColourInfo(ColourModel.rgb, alpha: alpha, depth: 8);
    case FileFormat.bmp:
      if (bytes.length < 30) return const ColourInfo(ColourModel.unknown);
      final bits = bytes[28] | bytes[29] << 8;
      if (bits <= 8) return ColourInfo(ColourModel.indexed, depth: bits);
      return ColourInfo(ColourModel.rgb, alpha: bits == 32, depth: 8);
    case FileFormat.svg:
      return const ColourInfo(ColourModel.vector);
    case FileFormat.tiff:
    case FileFormat.pdf:
    case FileFormat.heic:
    case FileFormat.unknown:
      return const ColourInfo(ColourModel.unknown);
  }
}

/// JPEG: the number of components in the start-of-frame marker.
ColourInfo _jpegColour(Uint8List b) {
  var i = 2;
  while (i + 9 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = b[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0xD8 ||
        (marker >= 0xD0 && marker <= 0xD7) ||
        marker == 0x01) {
      i += 2;
      continue;
    }
    final length = b[i + 2] << 8 | b[i + 3];
    final isFrame =
        marker >= 0xC0 &&
        marker <= 0xCF &&
        marker != 0xC4 &&
        marker != 0xC8 &&
        marker != 0xCC;
    if (isFrame) {
      final depth = b[i + 4];
      return switch (b[i + 9]) {
        1 => ColourInfo(ColourModel.gray, depth: depth),
        3 => ColourInfo(ColourModel.rgb, depth: depth),
        4 => ColourInfo(ColourModel.cmyk, depth: depth),
        _ => const ColourInfo(ColourModel.unknown),
      };
    }
    if (marker == 0xDA) break;
    i += 2 + length;
  }
  return const ColourInfo(ColourModel.unknown);
}
