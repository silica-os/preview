// The window's state with the fake PDF backend: opening, pages, layouts, zoom, rotation,
// search, selection and passwords; and the page cache.

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:preview/src/model/document.dart';
import 'package:preview/src/model/viewer.dart';
import 'package:preview/src/pdf/backend.dart';
import 'package:preview/src/pdf/pages.dart';
import 'package:preview/src/style.dart';

import 'support/fake_pdf.dart';
import 'support/samples.dart';

void main() {
  late FakePdfBackend backend;
  late FakePdfWriter writer;
  late ViewerController c;
  late String dirPath;

  String pdfFile(String name, FakePdf pdf) {
    final path = '$dirPath/$name';
    write(tempDirOf(dirPath), name, '%PDF-1.4\n'.codeUnits);
    backend.files[path] = pdf;
    return path;
  }

  setUp(() {
    final dir = tempDir(addTearDown);
    dirPath = dir.path;
    backend = FakePdfBackend({});
    writer = FakePdfWriter();
    c = ViewerController(
      loader: DocumentLoader(pdf: backend, writer: writer),
    )..animate = false;
    addTearDown(c.dispose);
  });

  FakePdf book(int pages) => FakePdf(
    [
      for (var i = 0; i < pages; i++)
        FakePage(
          lines: ['Page ${i + 1} text', i.isEven ? 'even world' : 'odd'],
        ),
    ],
    outline: const [
      PdfOutlineItem('Start', 0, [PdfOutlineItem('Inner', 1)]),
    ],
  );

  test('a PDF opens in the continuous layout, fitted to its width', () async {
    await c.open([pdfFile('a.pdf', book(3))]);
    expect(c.isPdf, isTrue);
    expect(c.count, 3);
    expect(c.layout, PageLayout.continuous);
    expect(c.zoomMode, ZoomMode.fitWidth);
    // With the thumbnails (the outline is not asked for by the file).
    expect(c.sidebar, SidebarMode.thumbnails);
    c.setViewport(const Size(628, 500));
    // (628 − 2 × 14) / 300.
    expect(c.scale, closeTo(2, 1e-9));
    expect(c.pageTop(1), 14 + 400 * 2 + 17);
    expect(c.contentSize.width, 628);
    expect(c.pageAtOffset(c.pageTop(2) + 5), 2);
    expect(c.hasOutline, isTrue);
  });

  test('pages: next, previous, first, last, two-page spreads', () async {
    await c.open([pdfFile('a.pdf', book(5))]);
    c.next();
    expect(c.current, 1);
    c.last();
    expect(c.current, 4);
    expect(c.canGoForward, isFalse);
    c.setLayout(PageLayout.two);
    // A book: the first page alone, then 2–3, 4–5.
    expect(c.current, 3);
    expect(c.spreadPages(c.current), [3, 4]);
    c.goTo(2);
    expect(c.current, 1);
    expect(c.spreadPages(c.current), [1, 2]);
    c.previous();
    expect(c.current, 0);
    expect(c.spreadPages(0), [0]);
    expect(c.canGoBack, isFalse);
    c.next();
    expect(c.current, 1);
    expect(c.spreadPages(c.current), [1, 2]);
    expect(c.zoomMode, ZoomMode.fit);
  });

  test('zoom steps of actual size, the fitted width, the limits', () async {
    await c.open([pdfFile('a.pdf', book(1))]);
    c.setViewport(const Size(628, 424));
    // Continuous: fitted to the width, (628 − 2 × 14) / 300 = 2.
    expect(c.scale, closeTo(2, 1e-9));
    c.actualSize();
    expect(c.scale, 1);
    expect(c.atActualSize, isTrue);
    c.zoomIn();
    expect(c.scale, closeTo(1.5, 1e-9));
    // The fitted width is a stop between the steps.
    c.zoomIn();
    expect(c.scale, closeTo(2, 1e-9));
    c.zoomIn();
    expect(c.scale, closeTo(3, 1e-9));
    c.zoomOut();
    c.zoomOut();
    c.zoomOut();
    c.zoomOut();
    expect(c.scale, closeTo(0.75, 1e-9));
    c.zoomTo(1000);
    expect(c.scale, PreviewMetrics.maxZoom);
    expect(c.canZoomIn, isFalse);
    c.zoomBy(1e-9);
    expect(c.scale, PreviewMetrics.minZoom);
    expect(c.canZoomOut, isFalse);
  });

  test('a PDF at actual size is its physical size on the display', () async {
    await c.open([pdfFile('a.pdf', book(1))]);
    c.displayPpi = 107;
    expect(c.actualScale, closeTo(107 / 72, 1e-9));
    c.actualSize();
    expect(c.scale, closeTo(107 / 72, 1e-9));
    expect(c.percent, 100);
    expect(c.maxScale, closeTo(30 * 107 / 72, 1e-9));
  });

  test('rotation turns the current page (both pages of a spread)', () async {
    await c.open([pdfFile('a.pdf', book(3))]);
    c.rotateRight();
    expect(c.pdf!.pageSize(0), const Size(400, 300));
    expect(c.pdf!.pageSize(1), const Size(300, 400));
    expect(c.edited, isTrue);
    c.rotateLeft();
    c.rotateLeft();
    expect(c.pdf!.turnsOf(0), 3);
    c.undo();
    c.undo();
    expect(c.pdf!.turnsOf(0), 1);
    c.setLayout(PageLayout.two);
    c.goTo(1);
    c.rotateRight();
    expect([for (var i = 0; i < 3; i++) c.pdf!.turnsOf(i)], [1, 1, 1]);
    expect(c.canFlip, isFalse);
  });

  test('search across pages, next and previous wrap around', () async {
    await c.open([pdfFile('a.pdf', book(4))]);
    await c.find('WORLD');
    expect(c.matches.map((m) => m.page), [0, 2]);
    expect(c.matchIndex, 0);
    c.findNext();
    expect(c.matchIndex, 1);
    expect(c.current, 2);
    c.findNext();
    expect(c.matchIndex, 0);
    c.findPrevious();
    expect(c.matchIndex, 1);
    await c.find('nothing like this');
    expect(c.matches, isEmpty);
    expect(c.searchDone, isTrue);
    c.closeSearch();
    expect(c.query, isEmpty);
  });

  test('selection and copy text', () async {
    await c.open([pdfFile('a.pdf', book(2))]);
    await c.loadText(0);
    c.select(0, 7, 0);
    expect(c.selectedText, 'Page 1');
    expect(c.canCopy, isTrue);
    await c.selectAll();
    expect(c.selectedText, 'Page 1 text\neven world\nPage 2 text\nodd');
    c.clearSelection();
    expect(c.canCopy, isFalse);
  });

  test('a protected PDF asks for its password', () async {
    final path = pdfFile(
      'secret.pdf',
      FakePdf([const FakePage()], password: 'pw'),
    );
    await c.open([path]);
    expect(c.document, isNull);
    expect(c.passwordFor, path);
    expect(c.passwordRetry, isFalse);
    await c.openPdf(path, password: 'wrong');
    expect(c.passwordRetry, isTrue);
    await c.openPdf(path, password: 'pw');
    expect(c.passwordFor, isNull);
    expect(c.count, 1);
  });

  test(
    'failures are collected: missing, not a picture, a second PDF',
    () async {
      final a = pdfFile('a.pdf', book(1));
      final b = pdfFile('b.pdf', book(1));
      final text = write(tempDirOf(dirPath), 'notes.txt', 'hello'.codeUnits);
      await c.open([a, b, text, '$dirPath/missing.png']);
      expect(c.isPdf, isTrue);
      expect(c.failures.map((f) => f.failure), [
        OpenFailure.unsupported,
        OpenFailure.unsupported,
        OpenFailure.missing,
      ]);
    },
  );

  test('several images open together with the thumbnails', () async {
    final dir = tempDirOf(dirPath);
    final a = write(dir, 'a.png', img.encodePng(halves(40, 20)));
    final b = write(dir, 'b.jpg', img.encodeJpg(halves(10, 30)));
    await c.open([a, b]);
    expect(c.count, 2);
    expect(c.sidebar, SidebarMode.thumbnails);
    expect(c.image!.size, const Size(40, 20));
    c.setViewport(const Size(400, 400));
    // Auto: smaller than the view, at its size.
    expect(c.scale, 1);
    c.zoomToFit();
    expect(c.scale, 10);
    c.next();
    expect(c.image!.name, 'b.jpg');
    c.flipHorizontal();
    c.rotateRight();
    expect(c.image!.turnedSize, const Size(30, 10));
    expect(c.image!.flipHorizontal, isTrue);
    // On a turned image a horizontal flip mirrors the stored vertical axis.
    c.flipHorizontal();
    expect(c.image!.flipVertical, isTrue);
  });

  test('the page cache renders on demand, steps the scale, evicts', () async {
    final doc = FakeDocument(book(3));
    final pages = PageImages(doc, maxBytes: 300 * 400 * 4 * 2);
    addTearDown(pages.dispose);
    expect(PageImages.stepOf(1), 0);
    expect(PageImages.stepOf(1.1), 1);
    expect(PageImages.scaleOf(4), 2);
    expect(pages.image(0, 1), isNull);
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(doc.renders, [(0, 1.0)]);
    expect(pages.image(0, 1)!.width, 300);
    // Another step: the old bitmap stands in while the new one renders.
    expect(pages.image(0, 2)!.width, 300);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(pages.image(0, 2)!.width, 600);
    // Over the budget, the least recently used goes.
    pages.image(1, 1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(pages.renders, 3);
    // Page 0 at 2× (1.9 MB) went over the 0.96 MB budget when page 1 arrived.
    expect(pages.image(0, 1), isNull);
    expect(pages.image(1, 1)!.width, 300);
  });
}
