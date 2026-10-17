// A multi-page TIFF opens as one item per page.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:preview/src/model/document.dart';

import 'support/fake_pdf.dart';

void main() {
  test('a multi-page TIFF opens as one read-only item per page', () async {
    final dir = Directory.systemTemp.createTempSync('tiff');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/scan.tiff';
    File(path).writeAsBytesSync(twoPageTiff());
    final items = await DocumentLoader(pdf: FakePdfBackend({})).images(path);
    expect(items.length, 2);
    expect([for (final i in items) i.page], [0, 1]);
    expect(items.every((i) => i.pageCount == 2 && !i.writable), isTrue);
    expect(items[1].content.size.width, 5);
  });
}

/// A little-endian TIFF of two uncompressed 8-bit grey pages: 4 x 3 and 5 x 2.
Uint8List twoPageTiff() {
  final out = BytesBuilder();
  void u16(int v) => out.add([v & 255, v >> 8]);
  void u32(int v) =>
      out.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, v >> 24]);
  void entry(int tag, int value) {
    u16(tag);
    u16(4);
    u32(1);
    u32(value);
  }

  out.add([0x49, 0x49, 42, 0]);
  u32(8);
  const sizes = [(4, 3), (5, 2)];
  // Each page: an IFD of 8 entries (2 + 8 * 12 + 4 = 102 bytes) then its pixels.
  var offset = 8;
  for (final (i, (w, h)) in sizes.indexed) {
    final data = offset + 102;
    final next = i == sizes.length - 1 ? 0 : data + w * h;
    u16(8);
    entry(256, w);
    entry(257, h);
    entry(258, 8);
    entry(262, 1);
    entry(273, data);
    entry(277, 1);
    entry(278, h);
    entry(279, w * h);
    u32(next);
    out.add(List.filled(w * h, 128));
    offset = next;
  }
  return out.toBytes();
}
