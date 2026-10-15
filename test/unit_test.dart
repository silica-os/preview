// Pure logic: arguments, formats, text search and selection geometry, file sizes.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:preview/src/args.dart';
import 'package:preview/src/images/formats.dart';
import 'package:preview/src/model/viewer.dart';
import 'package:preview/src/pdf/text.dart';
import 'package:preview/src/ui/inspector.dart';

import 'support/fake_pdf.dart';

void main() {
  test('files from the command line', () {
    expect(
      filesFromArgs([
        '--flag',
        'a.png',
        'file:///tmp/b%20c.pdf',
        'a.png',
        '--',
        '--odd-name.png',
      ]),
      ['a.png', '/tmp/b c.pdf', '--odd-name.png'],
    );
    expect(filesFromArgs(const []), isEmpty);
  });

  group('formats', () {
    Uint8List bytes(List<int> b) => Uint8List.fromList(b);
    test('magic numbers decide, the extension only for text', () {
      expect(
        sniffFormat(img.encodePng(img.Image(width: 1, height: 1)), 'x.jpg'),
        FileFormat.png,
      );
      expect(
        sniffFormat(bytes([0xFF, 0xD8, 0xFF, 0xE0]), 'x'),
        FileFormat.jpeg,
      );
      expect(sniffFormat(bytes(ascii.encode('GIF89a')), 'x'), FileFormat.gif);
      expect(
        sniffFormat(bytes(ascii.encode('RIFF\x00\x00\x00\x00WEBPVP8 ')), 'x'),
        FileFormat.webp,
      );
      expect(sniffFormat(bytes(ascii.encode('BM')), 'x'), FileFormat.bmp);
      expect(sniffFormat(bytes([0x49, 0x49, 0x2A, 0]), 'x'), FileFormat.tiff);
      expect(sniffFormat(bytes(ascii.encode('%PDF-1.7')), 'x'), FileFormat.pdf);
      expect(
        sniffFormat(bytes([0, 0, 0, 24, ...ascii.encode('ftypheic')]), 'x'),
        FileFormat.heic,
      );
      expect(
        sniffFormat(
          bytes(ascii.encode('<?xml version="1.0"?>\n<svg width="1">')),
          'x',
        ),
        FileFormat.svg,
      );
      expect(
        sniffFormat(bytes(ascii.encode('hello')), 'x.svg'),
        FileFormat.svg,
      );
      expect(
        sniffFormat(bytes(ascii.encode('hello')), 'x.txt'),
        FileFormat.unknown,
      );
    });

    test('colour models from the headers', () {
      final rgba = img.encodePng(
        img.Image(width: 2, height: 2, numChannels: 4),
      );
      expect(
        colourInfo(rgba, FileFormat.png),
        const ColourInfo(ColourModel.rgb, alpha: true, depth: 8),
      );
      final gray = img.encodeJpg(
        img.Image(width: 2, height: 2, numChannels: 1),
      );
      final rgb = img.encodeJpg(img.Image(width: 2, height: 2));
      expect(colourInfo(rgb, FileFormat.jpeg).model, ColourModel.rgb);
      expect(
        colourInfo(gray, FileFormat.jpeg).model,
        isIn([ColourModel.gray, ColourModel.rgb]),
      );
      expect(
        colourInfo(Uint8List(0), FileFormat.svg).model,
        ColourModel.vector,
      );
    });
  });

  group('text', () {
    final layout = fakeLayout(['Hello World', 'second LINE', 'città antica']);

    test('find ignores case and accents, spaces match line breaks', () {
      expect(findInLayout(0, layout, 'world'), [const TextMatch(0, 6, 11)]);
      expect(findInLayout(0, layout, 'CITTA'), hasLength(1));
      expect(findInLayout(0, layout, 'world second'), [
        const TextMatch(0, 6, 18),
      ]);
      expect(findInLayout(0, layout, 'o'), hasLength(3));
      expect(findInLayout(0, layout, '  '), isEmpty);
    });

    test('a range spanning lines gives one box per line', () {
      final rects = rangeRects(layout, 6, 18);
      expect(rects, hasLength(2));
      expect(rects.first, const Rect.fromLTRB(56, 20, 86, 32));
      expect(rects.last.top, 34);
    });

    test('the character at a point, or the nearest on the nearest line', () {
      expect(charAt(layout, const Offset(21, 25)), (0, false));
      expect(charAt(layout, const Offset(25, 25)), (0, true));
      // Right of the first line: its last character.
      expect(charAt(layout, const Offset(250, 22))?.$1, 10);
      expect(charAt(fakeLayout(const []), Offset.zero), isNull);
    });

    test('rotated rectangles and points round-trip', () {
      const page = Size(300, 400);
      const r = Rect.fromLTRB(10, 20, 30, 60);
      for (var turns = 0; turns < 4; turns++) {
        final turned = turnRect(r, page, turns);
        final turnedPage = turns.isOdd ? const Size(400, 300) : page;
        expect(turnedPage.contains(turned.center), isTrue);
        expect(unturnPoint(turned.center, page, turns), r.center);
      }
    });
  });

  test('file sizes in decimal units', () {
    expect(formatBytes(999, 'en'), '999 B');
    expect(formatBytes(1500, 'en'), '1.5 KB');
    expect(formatBytes(2400000, 'it'), '2,4 MB');
  });
}
