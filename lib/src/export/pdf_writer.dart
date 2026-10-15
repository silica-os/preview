// A one-page PDF holding one image, in pure Dart: the image's colour as a Flate-compressed RGB
// stream, its alpha (when not opaque) as a soft mask, one image pixel per point.

import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// A PDF of `width` × `height` RGBA pixels (unpremultiplied, rows without padding).
Uint8List imagePdf(Uint8List rgba, int width, int height) {
  final rgb = Uint8List(width * height * 3);
  final alpha = Uint8List(width * height);
  var opaque = true;
  for (var i = 0, j = 0, k = 0; i + 3 < rgba.length; i += 4, j += 3, k++) {
    rgb[j] = rgba[i];
    rgb[j + 1] = rgba[i + 1];
    rgb[j + 2] = rgba[i + 2];
    alpha[k] = rgba[i + 3];
    if (rgba[i + 3] != 255) opaque = false;
  }
  final zlib = ZLibCodec(level: 6);
  final content = ascii.encode('q $width 0 0 $height 0 0 cm /Im0 Do Q');
  final objects = <List<int>>[
    ascii.encode('<< /Type /Catalog /Pages 2 0 R >>'),
    ascii.encode('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
    ascii.encode(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $width $height] '
      '/Resources << /XObject << /Im0 4 0 R >> >> /Contents 5 0 R >>',
    ),
    _stream(
      '/Type /XObject /Subtype /Image /Width $width /Height $height '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /FlateDecode'
      '${opaque ? '' : ' /SMask 6 0 R'}',
      zlib.encode(rgb),
    ),
    _stream('', content),
    if (!opaque)
      _stream(
        '/Type /XObject /Subtype /Image /Width $width /Height $height '
        '/ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode',
        zlib.encode(alpha),
      ),
  ];
  return writePdf(objects);
}

List<int> _stream(String dict, List<int> data) => [
  ...ascii.encode('<< $dict /Length ${data.length} >>\nstream\n'),
  ...data,
  ...ascii.encode('\nendstream'),
];

/// A PDF from its objects (object 1 is the catalog), with the cross-reference table.
Uint8List writePdf(List<List<int>> objects) {
  final out = BytesBuilder(copy: false)
    ..add(ascii.encode('%PDF-1.4\n'))
    ..add(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out
      ..add(ascii.encode('${i + 1} 0 obj\n'))
      ..add(objects[i])
      ..add(ascii.encode('\nendobj\n'));
  }
  final xref = out.length;
  final table = StringBuffer(
    'xref\n0 ${objects.length + 1}\n0000000000 65535 f \n',
  );
  for (final o in offsets) {
    table.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  table.write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n',
  );
  out.add(ascii.encode(table.toString()));
  return out.takeBytes();
}
