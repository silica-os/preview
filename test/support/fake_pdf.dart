// A fake PDF backend: documents described in memory, text laid out on a fixed grid (each
// character 6 × 12 pt, lines 14 pt apart from (20, 20)), bitmaps of plain white.

import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' show Offset, Rect, Size;

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
    this.pageMode = PdfPageMode.none,
    this.annotations = const [],
  });
  final List<FakePage> pages;
  final List<PdfOutlineItem> outline;
  final String? password;
  final PdfInfo info;
  final PdfPageMode pageMode;

  /// The annotations the file starts with.
  final List<PdfAnnotation> annotations;
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

  /// The annotations now, every page together.
  late final List<PdfAnnotation> annots = [...pdf.annotations];
  late int _nextId = pdf.annotations.fold(0, (m, a) => a.id > m ? a.id : m) + 1;

  /// The paths [saveTo] wrote, in order.
  final List<String> saves = [];

  /// Set to make [saveTo] fail.
  bool failSave = false;

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
  PdfPageMode get pageMode => pdf.pageMode;

  @override
  Future<List<PdfAnnotation>> annotations(int page) async => [
    for (final a in annots)
      if (a.page == page) a,
  ];

  PdfAnnotation _keep(PdfAnnotation a) {
    annots.add(a);
    return a;
  }

  @override
  Future<PdfAnnotation> addMarkup(
    int page,
    PdfMarkupKind kind,
    List<Rect> quads,
    int argb, {
    String author = '',
    String contents = '',
  }) async => _keep(
    PdfAnnotation(
      id: _nextId++,
      page: page,
      kind: kind,
      quads: quads,
      bounds: quads.reduce((a, b) => a.expandToInclude(b)),
      argb: argb,
      author: author,
      contents: contents,
      modified: DateTime(2026, 10, 15),
    ),
  );

  @override
  Future<PdfAnnotation> addNote(
    int page,
    Offset at,
    int argb, {
    String author = '',
    String contents = '',
  }) async => _keep(
    PdfAnnotation(
      id: _nextId++,
      page: page,
      kind: PdfMarkupKind.note,
      bounds: at & const Size(22, 22),
      argb: argb,
      author: author,
      contents: contents,
      modified: DateTime(2026, 10, 15),
    ),
  );

  int _index(int page, int id) {
    final i = annots.indexWhere((a) => a.page == page && a.id == id);
    if (i < 0) throw StateError('no annotation $id on page $page');
    return i;
  }

  @override
  Future<void> updateAnnotation(
    int page,
    int id, {
    int? argb,
    String? contents,
  }) async {
    final i = _index(page, id);
    final a = annots[i];
    annots[i] = PdfAnnotation(
      id: a.id,
      page: a.page,
      kind: a.kind,
      quads: a.quads,
      bounds: a.bounds,
      argb: argb ?? a.argb,
      contents: contents ?? a.contents,
      author: a.author,
      modified: a.modified,
    );
  }

  @override
  Future<void> removeAnnotation(int page, int id) async =>
      annots.removeAt(_index(page, id));

  /// Records the path and writes a placeholder file there.
  @override
  Future<void> saveTo(String path) async {
    if (failSave) throw const PdfSaveException('fake failure');
    saves.add(path);
    File(path).writeAsStringSync('%PDF-1.4 fake\n');
  }

  @override
  Future<void> close() async => closed = true;
}
