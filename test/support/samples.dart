// Sample files for the tests, written into temporary directories: text PDFs with an outline,
// and images encoded with the `image` package.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:preview/src/export/pdf_writer.dart';

/// A PDF with one page per entry of `pages` (each a list of text lines), 300 × 400 pt, and an
/// outline entry "Chapter n" for each page; `rotate` is every page's /Rotate.
Uint8List textPdf(List<List<String>> pages, {int rotate = 0}) {
  final n = pages.length;
  int page(int i) => 5 + 3 * i;
  int content(int i) => 6 + 3 * i;
  int outline(int i) => 7 + 3 * i;
  final objects = <List<int>>[
    ascii.encode(
      '<< /Type /Catalog /Pages 2 0 R /Outlines 3 0 R /PageMode /UseOutlines >>',
    ),
    ascii.encode(
      '<< /Type /Pages /Kids [${[for (var i = 0; i < n; i++) '${page(i)} 0 R'].join(' ')}] '
      '/Count $n >>',
    ),
    ascii.encode(
      '<< /Type /Outlines /First ${outline(0)} 0 R /Last ${outline(n - 1)} 0 R /Count $n >>',
    ),
    ascii.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'),
  ];
  for (var i = 0; i < n; i++) {
    final text = StringBuffer('BT /F1 14 Tf 40 360 Td 18 TL\n');
    for (final line in pages[i]) {
      final escaped = line
          .replaceAll(r'\', r'\\')
          .replaceAll('(', r'\(')
          .replaceAll(')', r'\)');
      text.write('($escaped) Tj T*\n');
    }
    text.write('ET');
    final stream = ascii.encode(text.toString());
    objects
      ..add(
        ascii.encode(
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 400] /Rotate $rotate '
          '/Resources << /Font << /F1 4 0 R >> >> /Contents ${content(i)} 0 R >>',
        ),
      )
      ..add([
        ...ascii.encode('<< /Length ${stream.length} >>\nstream\n'),
        ...stream,
        ...ascii.encode('\nendstream'),
      ])
      ..add(
        ascii.encode(
          '<< /Title (Chapter ${i + 1}) /Parent 3 0 R /Dest [${page(i)} 0 R /Fit]'
          '${i > 0 ? ' /Prev ${outline(i - 1)} 0 R' : ''}'
          '${i < n - 1 ? ' /Next ${outline(i + 1)} 0 R' : ''} >>',
        ),
      );
  }
  return writePdf(objects);
}

/// A `width` × `height` image, red on the left half and blue on the right.
img.Image halves(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        x < width / 2 ? 255 : 0,
        0,
        x < width / 2 ? 0 : 255,
        255,
      );
    }
  }
  return image;
}

/// A temporary directory removed after the test.
Directory tempDir(void Function(void Function()) addTearDown) {
  final dir = Directory.systemTemp.createTempSync('preview-test-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Writes `bytes` to `name` in `dir`; its path.
String write(Directory dir, String name, List<int> bytes) {
  final file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
  return file.path;
}

/// The directory at `path` (made by [tempDir]).
Directory tempDirOf(String path) => Directory(path);
