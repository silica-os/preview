// A fake PDF backend: documents described in memory, text laid out on a fixed grid (each
// character 6 × 12 pt, lines 14 pt apart from (20, 20)), bitmaps of plain white.

import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:preview/src/pdf/backend.dart';

class FakePage {
  const FakePage({this.size = const Size(300, 400), this.lines = const []});
  final Size size;
  final List<String> lines;
}

class FakePdf {
  FakePdf(
    this.pages, {
    this.outline = const [],
    this.password,
    this.info = const PdfInfo(),
  });
  final List<FakePage> pages;
  final List<PdfOutlineItem> outline;
  final String? password;
  final PdfInfo info;
}

/// The layout of `lines` on the fake grid.
PdfTextLayout fakeLayout(List<String> lines) {
  final text = StringBuffer();
  final rects = <Rect>[];
  for (final (row, line) in lines.indexed) {
    final top = 20.0 + row * 14;
    for (final (col, _) in line.runes.indexed) {
      rects.add(Rect.fromLTWH(20.0 + col * 6, top, 6, 12));
    }
    text.write(line);
    if (row < lines.length - 1) {
      text.write('\n');
      rects.add(Rect.fromLTWH(20.0 + line.length * 6, top, 0, 12));
    }
  }
  return PdfTextLayout(text.toString(), rects);
}

class FakePdfBackend implements PdfBackend {
  FakePdfBackend(this.files);
  final Map<String, FakePdf> files;
  final List<FakeDocument> opened = [];

  @override
  Future<PdfDocumentHandle> open(String path, {String? password}) async {
    final pdf = files[path];
    if (pdf == null)
      throw const PdfOpenException(PdfOpenFailure.invalid, 'no such');
    if (pdf.password != null && pdf.password != password) {
      throw const PdfOpenException(PdfOpenFailure.encrypted, 'password');
    }
    final doc = FakeDocument(pdf);
    opened.add(doc);
    return doc;
  }
}

class FakeDocument implements PdfDocumentHandle {
  FakeDocument(this.pdf);
  final FakePdf pdf;
  final List<(int, double)> renders = [];
  final List<int> texts = [];
  bool closed = false;

  @override
  int get pageCount => pdf.pages.length;

  @override
  List<Size> get pageSizes => [for (final p in pdf.pages) p.size];

  @override
  PdfInfo get info => pdf.info;

  @override
  List<PdfOutlineItem> get outline => pdf.outline;

  @override
  Future<PdfPageBitmap> render(int page, double scale) async {
    renders.add((page, scale));
    final size = pdf.pages[page].size;
    final w = (size.width * scale).ceil();
    final h = (size.height * scale).ceil();
    return PdfPageBitmap(
      w,
      h,
      Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255),
    );
  }

  @override
  Future<PdfTextLayout> text(int page) async {
    texts.add(page);
    return fakeLayout(pdf.pages[page].lines);
  }

  @override
  Future<void> close() async => closed = true;
}
