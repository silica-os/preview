// Changes to documents and how they reach the files: page edits, bookmarks, PDF annotations,
// image markup and sizes, undo and redo, the "Edited" state, saving, reverting, renaming; the
// window size of a new document; the sidebar's sizes and kinds; search results.

import 'dart:io';
import 'dart:ui' show Color, Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:preview/src/model/document.dart';
import 'package:preview/src/model/history.dart';
import 'package:preview/src/model/markup.dart';
import 'package:preview/src/model/viewer.dart';
import 'package:preview/src/model/window_size.dart';
import 'package:preview/src/pdf/backend.dart';
import 'package:preview/src/pdf/qpdf.dart';
import 'package:preview/src/style.dart';

import 'support/fake_pdf.dart';
import 'support/samples.dart';

void main() {
  late FakePdfBackend backend;
  late FakePdfWriter writer;
  late ViewerController c;
  late Directory dir;

  String pdfFile(String name, FakePdf pdf) {
    final path = write(dir, name, '%PDF-1.4\n'.codeUnits);
    backend.files[path] = pdf;
    return path;
  }

  FakePdf book(
    int pages, {
    PdfPageMode mode = PdfPageMode.none,
    List<PdfOutlineItem> outline = const [],
  }) => FakePdf(
    [
      for (var i = 0; i < pages; i++)
        FakePage(lines: ['Page ${i + 1} text', 'world $i']),
    ],
    pageMode: mode,
    outline: outline,
  );

  setUp(() {
    dir = tempDir(addTearDown);
    backend = FakePdfBackend({});
    writer = FakePdfWriter();
    c = ViewerController(
      loader: DocumentLoader(pdf: backend, writer: writer),
    )..animate = false;
    addTearDown(c.dispose);
  });

  group('history', () {
    test('edited until saved; undoing back to the saved state clears it', () {
      final h = EditHistory();
      var value = 0;
      expect(h.edited, isFalse);
      value = 1;
      h.record(Edit(undo: () => value = 0, redo: () => value = 1));
      expect(h.edited, isTrue);
      h.undo();
      expect(value, 0);
      expect(h.edited, isFalse);
      h.redo();
      expect(value, 1);
      h.saved();
      expect(h.edited, isFalse);
      h.undo();
      expect(h.edited, isTrue);
      // A new edit after an undo drops the redo.
      h.record(Edit(undo: () {}, redo: () {}));
      expect(h.canRedo, isFalse);
    });
  });

  group('window size', () {
    const screen = Size(2560, 1440);
    final room = windowRoom(screen);

    test('the room under the menu bar keeps 40 pt free at the bottom', () {
      expect(room, const Size(2552, 1366));
    });

    test('an image that fits opens at 100 % with 26 pt above and below', () {
      expect(
        imageWindowSize(const Size(1600, 1000), room: room),
        const Size(1600, 1104),
      );
      expect(
        imageWindowSize(const Size(600, 900), room: room),
        const Size(708, 1004),
      );
      expect(
        imageWindowSize(const Size(200, 150), room: room),
        const Size(708, 328),
      );
    });

    test('with the sidebar the content keeps the smallest width', () {
      expect(
        imageWindowSize(const Size(800, 600), sidebar: 160, room: room),
        const Size(960, 704),
      );
      expect(
        imageWindowSize(const Size(400, 300), sidebar: 160, room: room),
        const Size(868, 404),
      );
    });

    test('a larger image opens fitted in the tallest window', () {
      final size = imageWindowSize(const Size(12000, 8000), room: room);
      expect(size.height, 1366);
      expect(size.width, closeTo(1987, 1));
    });

    test('a PDF: the sidebar, the page at actual size, the full height', () {
      final size = pdfWindowSize(595, actualScale: 1, room: room);
      expect(size, const Size(160 + 28 + 595, 1366));
    });

    test('never below the smallest window', () {
      final size = imageWindowSize(
        const Size(10, 10),
        room: const Size(300, 200),
      );
      expect(size, PreviewMetrics.minWindow);
    });
  });

  group('PDF', () {
    test('a file that asks for its outline opens in the contents', () async {
      await c.open([
        pdfFile(
          'a.pdf',
          book(
            2,
            mode: PdfPageMode.outlines,
            outline: const [PdfOutlineItem('One', 0)],
          ),
        ),
      ]);
      expect(c.sidebar, SidebarMode.contents);
    });

    test('pages: delete, insert blank, move, with undo', () async {
      await c.open([pdfFile('a.pdf', book(3))]);
      c.goTo(1);
      c.deletePage();
      expect([for (final p in c.pdf!.pages) p.source], [0, 2]);
      expect(c.edited, isTrue);
      c.undo();
      expect([for (final p in c.pdf!.pages) p.source], [0, 1, 2]);
      expect(c.edited, isFalse);
      c.goTo(0);
      c.insertBlankPage();
      expect(c.count, 4);
      expect(c.current, 1);
      expect(c.pdf!.pages[1].isBlank, isTrue);
      expect(c.textOf(1)!.text, isEmpty);
      c.movePage(0, 3);
      expect([for (final p in c.pdf!.pages) p.source], [null, 1, 2, 0]);
      c.undo();
      expect([for (final p in c.pdf!.pages) p.source], [0, null, 1, 2]);
      c.redo();
      expect(c.current, 3);
    });

    test('bookmarks: added on the current page, listed in order', () async {
      await c.open([pdfFile('a.pdf', book(4))]);
      c.goTo(2);
      c.toggleBookmark();
      c.goTo(0);
      c.toggleBookmark();
      expect(c.bookmarks, [0, 2]);
      expect(c.currentBookmarked, isTrue);
      c.toggleBookmark();
      expect(c.bookmarks, [2]);
      expect(c.canShowSidebar(SidebarMode.bookmarks), isTrue);
    });

    test('a selection becomes a highlight; undo removes it', () async {
      await c.open([pdfFile('a.pdf', book(2))]);
      await c.loadText(0);
      c.select(0, 0, 4);
      await c.markSelection();
      final doc = backend.opened.single;
      expect(doc.annots, hasLength(1));
      expect(doc.annots.single.kind, PdfMarkupKind.highlight);
      expect(doc.annots.single.argb, HighlightColour.yellow.color.toARGB32());
      expect(c.selection, isEmpty);
      expect(c.edited, isTrue);
      expect(c.allAnnotations.single.$1, 0);
      c.undo();
      await pumpEventQueue();
      expect(doc.annots, isEmpty);
      c.redo();
      await pumpEventQueue();
      expect(doc.annots, hasLength(1));
    });

    test('underline and colours from the menu, a note, removal', () async {
      await c.open([pdfFile('a.pdf', book(1))]);
      await c.loadText(0);
      c.select(0, 0, 4);
      c.setMarkupStyle(const MarkupStyle(PdfMarkupKind.underline));
      await pumpEventQueue();
      final doc = backend.opened.single;
      expect(doc.annots.single.kind, PdfMarkupKind.underline);
      expect(c.highlighting, isTrue);
      final note = await c.addNote(contents: 'hello');
      expect(note!.kind, PdfMarkupKind.note);
      await c.updateAnnotation(0, note, contents: 'changed');
      expect(doc.annots.last.contents, 'changed');
      await c.removeAnnotation(0, c.annotationsOf(0).last);
      expect(doc.annots, hasLength(1));
    });

    test(
      'saving writes the annotations, then the pages through the writer',
      () async {
        final path = pdfFile('a.pdf', book(3));
        await c.open([path]);
        c.rotateRight();
        c.goTo(2);
        c.toggleBookmark();
        c.goTo(1);
        c.deletePage();
        c.setKeywords(['one', 'two']);
        await c.save();
        final doc = backend.opened.first;
        expect(doc.saves, hasLength(1));
        final w = writer.writes.single;
        expect(w.out, path);
        expect(w.keywords, 'one, two');
        expect([for (final p in w.pages) (p as SourcePage).index], [0, 2]);
        expect((w.pages.first as SourcePage).quarterTurns, 1);
        expect(w.pages.last.bookmarked, isTrue);
        expect((w.pages.first as SourcePage).path, doc.saves.single);
        // The annotated copy is gone; the document is shown again from the file, not edited.
        expect(File(doc.saves.single).existsSync(), isFalse);
        expect(c.edited, isFalse);
        expect(c.bookmarks, [1]);
      },
    );

    test('a PDF with only annotations is saved without the writer', () async {
      final path = pdfFile('a.pdf', book(1));
      await c.open([path]);
      await c.loadText(0);
      c.select(0, 0, 4);
      await c.markSelection();
      await c.save();
      expect(writer.writes, isEmpty);
      expect(File(path).readAsStringSync(), contains('fake'));
    });

    test('permissions chosen are written on save', () async {
      final path = pdfFile('a.pdf', book(1));
      await c.open([path]);
      const security = PdfSecurity(
        userPassword: 'pw',
        ownerPassword: 'owner',
        printing: false,
      );
      c.setSecurity(security);
      expect(c.edited, isTrue);
      await c.save();
      expect(writer.writes.single.security, security);
    });

    test('search results by page, in rank or page order', () async {
      await c.open([
        pdfFile(
          'a.pdf',
          FakePdf([
            const FakePage(lines: ['one world']),
            const FakePage(lines: ['world world world']),
            const FakePage(lines: ['nothing']),
          ]),
        ),
      ]);
      await c.find('world');
      expect(c.resultPages, [(1, 3), (0, 1)]);
      c.setSearchOrder(SearchOrder.page);
      expect(c.resultPages, [(0, 1), (1, 3)]);
      c.showResult(1);
      expect(c.matches[c.matchIndex].page, 1);
      expect(c.canGoBackInHistory, isTrue);
      c.back();
      expect(c.current, 0);
    });

    test('the sidebar: kinds, its width from 160 to 400', () async {
      await c.open([pdfFile('a.pdf', book(2))]);
      expect(c.canShowSidebar(SidebarMode.contents), isFalse);
      c.setSidebar(SidebarMode.bookmarks);
      c.toggleSidebar();
      expect(c.sidebar, SidebarMode.none);
      c.toggleSidebar();
      expect(c.sidebar, SidebarMode.bookmarks);
      c.resizeSidebar(50);
      expect(c.sidebarWidth, 160);
      c.resizeSidebar(1000);
      expect(c.sidebarWidth, 400);
      expect(PreviewMetrics.thumbnailWidth(160), 105);
      expect(PreviewMetrics.thumbnailWidth(340), closeTo(260, 1e-9));
    });

    test('Page Down in the single page layout turns the page', () async {
      await c.open([pdfFile('a.pdf', book(3))]);
      c.setLayout(PageLayout.single);
      c.scrollPage(1);
      expect(c.current, 1);
      c.scrollPage(-1);
      expect(c.current, 0);
    });
  });

  group('images', () {
    late String path;

    setUp(() {
      path = write(dir, 'photo.png', img.encodePng(halves(40, 20)));
    });

    test('rotating a PNG is an edit, saved into the file', () async {
      await c.open([path]);
      c.rotateRight();
      expect(c.edited, isTrue);
      expect(c.canRevert, isTrue);
      await c.save();
      expect(c.edited, isFalse);
      final back = img.decodePng(File(path).readAsBytesSync())!;
      expect((back.width, back.height), (20, 40));
      // The reloaded image is the file as written: no turn left to apply.
      expect(c.image!.quarterTurns, 0);
      expect(c.image!.size, const Size(20, 40));
    });

    test('revert brings back the file as it was opened', () async {
      final original = File(path).readAsBytesSync();
      await c.open([path]);
      c.flipHorizontal();
      await c.save();
      expect(File(path).readAsBytesSync(), isNot(original));
      await c.revert();
      expect(File(path).readAsBytesSync(), original);
      expect(c.edited, isFalse);
    });

    test('an SVG turns for viewing only: nothing to save', () async {
      final svg = write(
        dir,
        'a.svg',
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="20"/>'
            .codeUnits,
      );
      await c.open([svg]);
      c.rotateLeft();
      expect(c.image!.quarterTurns, 3);
      expect(c.edited, isFalse);
    });

    test('markup: add, style, delete, undo; written into the image', () async {
      await c.open([path]);
      final shape = MarkupShape(
        kind: ShapeKind.rectangle,
        a: const Offset(5, 5),
        b: const Offset(15, 15),
        fill: const Color(0xFF00FF00),
      );
      c.addShape(shape);
      expect(c.image!.markup, [shape]);
      expect(c.chosenShape, shape);
      c.styleShape((s) => s.lineWidth = 8);
      expect(shape.lineWidth, 8);
      expect(c.shapeTemplate.lineWidth, 8);
      c.undo();
      expect(c.image!.markup.single.lineWidth, 3);
      c.deleteShape();
      // Nothing chosen after the undo: delete does nothing.
      expect(c.image!.markup, hasLength(1));
      c.chooseShape(c.image!.markup.single);
      c.deleteShape();
      expect(c.image!.markup, isEmpty);
      c.undo();
      expect(c.image!.markup, hasLength(1));
      await c.save();
      final back = img.decodePng(File(path).readAsBytesSync())!;
      // The green fill is in the pixels now.
      expect(back.getPixel(10, 10).g, greaterThan(200));
      expect(back.getPixel(10, 10).r, lessThan(50));
    });

    test('Adjust Size writes the image at its new size', () async {
      await c.open([path]);
      c.resizeImage(const Size(20, 10));
      expect(c.image!.size, const Size(20, 10));
      expect(c.edited, isTrue);
      await c.save();
      final back = img.decodePng(File(path).readAsBytesSync())!;
      expect((back.width, back.height), (20, 10));
    });

    test('rename moves the file and keeps the window on it', () async {
      await c.open([path]);
      await c.rename('renamed.png');
      expect(File(path).existsSync(), isFalse);
      expect(File('${dir.path}/renamed.png').existsSync(), isTrue);
      expect(c.image!.name, 'renamed.png');
      write(dir, 'taken.png', [1]);
      await expectLater(
        c.rename('taken.png'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('several images: close one, sort them', () async {
      final b = write(dir, 'b.png', img.encodePng(halves(4, 4)));
      final a = write(dir, 'a.png', img.encodePng(halves(8, 4)));
      await c.open([b, path, a]);
      expect(c.several, isTrue);
      c.sortImages(ImageOrder.name);
      expect(
        [for (final i in c.images!.images) i.name],
        ['a.png', 'b.png', 'photo.png'],
      );
      c.sortImages(null);
      expect(c.images!.images.first.name, 'b.png');
      c.closeImage(0);
      expect(c.count, 2);
    });

    test('image zoom steps: 75 %, 100 %, 150 %; 5 % to 3000 %', () async {
      await c.open([path]);
      c.setViewport(const Size(400, 400));
      expect(c.scale, 1);
      c.zoomOut();
      expect(c.scale, 0.75);
      c.zoomIn();
      c.zoomIn();
      expect(c.scale, 1.5);
      c.zoomTo(0.0001);
      expect(c.scale, 0.05);
      c.zoomTo(1e6);
      expect(c.scale, 30);
    });
  });

  test('markup shapes hit-test and move', () {
    final line = MarkupShape(
      kind: ShapeKind.line,
      a: Offset.zero,
      b: const Offset(10, 0),
    );
    expect(line.hit(const Offset(5, 1), 1), isTrue);
    expect(line.hit(const Offset(5, 8), 1), isFalse);
    final box = MarkupShape(
      kind: ShapeKind.oval,
      a: const Offset(10, 10),
      b: Offset.zero,
    );
    expect(box.rect, const Rect.fromLTWH(0, 0, 10, 10));
    box.translate(const Offset(5, 0));
    expect(box.rect.left, 5);
    expect(box.copy().rect, box.rect);
  });
}
