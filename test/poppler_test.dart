// The real PDF backend against PDFs written by the tests (skipped without poppler-glib).

import 'dart:io';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:preview/src/pdf/backend.dart';
import 'package:preview/src/pdf/poppler.dart';
import 'package:preview/src/pdf/text.dart';

import 'support/samples.dart';

void main() {
  final skip = PopplerBackend.available ? false : 'poppler-glib not installed';

  test('pages, sizes, outline, text and a render', () async {
    final dir = tempDir(addTearDown);
    final path = write(
      dir,
      'two.pdf',
      textPdf([
        ['Hello world', 'second line'],
        ['Another page with world'],
      ]),
    );
    final doc = await const PopplerBackend().open(path);
    addTearDown(doc.close);
    expect(doc.pageCount, 2);
    expect(doc.pageSizes.first.width, closeTo(300, 0.01));
    expect(doc.pageSizes.first.height, closeTo(400, 0.01));
    expect(
      [for (final o in doc.outline) (o.title, o.page)],
      [('Chapter 1', 0), ('Chapter 2', 1)],
    );
    final layout = await doc.text(0);
    expect(layout.text, contains('Hello world'));
    expect(layout.rects.length, greaterThanOrEqualTo(11));
    final hello = layout.rects[layout.text.indexOf('H')];
    // Text at y 360 from the bottom of a 400 pt page: near the top.
    expect(hello.top, lessThan(60));
    final matches = findInLayout(1, await doc.text(1), 'WORLD');
    expect(matches, hasLength(1));
    final at = charAt(layout, hello.center);
    expect(at?.$1, layout.text.indexOf('H'));
    final bitmap = await doc.render(0, 2);
    expect(bitmap.width, 600);
    expect(bitmap.height, 800);
    expect(bitmap.bgra.length, 600 * 800 * 4);
    // White paper, dark text somewhere.
    expect(bitmap.bgra.sublist(0, 4), [255, 255, 255, 255]);
    expect(bitmap.bgra.any((b) => b < 100), isTrue);
  }, skip: skip);

  test('a file that is not a PDF fails as invalid', () async {
    final dir = tempDir(addTearDown);
    final path = write(dir, 'bad.pdf', '%PDF-1.4 nothing here'.codeUnits);
    await expectLater(
      const PopplerBackend().open(path),
      throwsA(
        isA<PdfOpenException>().having(
          (e) => e.failure,
          'failure',
          PdfOpenFailure.invalid,
        ),
      ),
    );
  }, skip: skip);

  test('page mode and keywords', () async {
    final dir = tempDir(addTearDown);
    final path = write(
      dir,
      'one.pdf',
      textPdf([
        ['Hello'],
        ['Bye'],
      ]),
    );
    final doc = await const PopplerBackend().open(path);
    addTearDown(doc.close);
    expect(doc.pageMode, PdfPageMode.outlines);
    expect(doc.info.keywords, '');
    expect(doc.info.encrypted, isFalse);
  }, skip: skip);

  test('annotations: add, list, render, change, remove, save', () async {
    final dir = tempDir(addTearDown);
    final path = write(
      dir,
      'notes.pdf',
      textPdf([
        ['Hello world', 'second line'],
        ['Another page'],
      ]),
    );
    final doc = await const PopplerBackend().open(path);
    addTearDown(doc.close);
    expect(await doc.annotations(0), isEmpty);
    final layout = await doc.text(0);
    final start = layout.text.indexOf('Hello');
    final word = layout.rects
        .sublist(start, start + 5)
        .reduce((a, b) => a.expandToInclude(b));
    final highlight = await doc.addMarkup(
      0,
      PdfMarkupKind.highlight,
      [word],
      0xFFFFFF00,
      author: 'Tester',
      contents: 'look',
    );
    expect(highlight.kind, PdfMarkupKind.highlight);
    expect(highlight.quads, hasLength(1));
    expect(highlight.quads.first.left, closeTo(word.left, 0.5));
    expect(highlight.quads.first.top, closeTo(word.top, 0.5));
    expect(highlight.quads.first.bottom, closeTo(word.bottom, 0.5));
    expect(highlight.bounds.overlaps(word), isTrue);
    expect(highlight.argb, 0xFFFFFF00);
    expect(highlight.author, 'Tester');
    expect(highlight.contents, 'look');

    // The page is drawn with the highlight: yellow (no blue) inside the word, between glyphs.
    final bitmap = await doc.render(0, 1);
    var yellow = 0;
    for (var y = word.top.ceil(); y < word.bottom.floor(); y++) {
      for (var x = word.left.ceil(); x < word.right.floor(); x++) {
        final i = (y * bitmap.width + x) * 4;
        final (b, g, r) = (
          bitmap.bgra[i],
          bitmap.bgra[i + 1],
          bitmap.bgra[i + 2],
        );
        if (r > 200 && g > 200 && b < 120) yellow++;
      }
    }
    expect(yellow, greaterThan(20));

    final under = await doc.addMarkup(1, PdfMarkupKind.underline, [
      const Rect.fromLTWH(40, 30, 60, 14),
    ], 0xFF00FF00);
    final strike = await doc.addMarkup(1, PdfMarkupKind.strikeOut, [
      const Rect.fromLTWH(40, 30, 60, 14),
      const Rect.fromLTWH(40, 50, 30, 14),
    ], 0xFFFF0000);
    expect(strike.quads, hasLength(2));
    final note = await doc.addNote(
      1,
      const Offset(100, 200),
      0xFFFFD60A,
      author: 'Tester',
      contents: 'a note',
    );
    expect(note.kind, PdfMarkupKind.note);
    expect(note.bounds.left, closeTo(100, 0.5));
    expect(note.bounds.top, closeTo(200, 0.5));
    expect(note.bounds.width, closeTo(22, 0.5));

    await doc.updateAnnotation(
      0,
      highlight.id,
      argb: 0xFF33CC33,
      contents: 'green',
    );
    final changed = (await doc.annotations(0)).single;
    expect(changed.id, highlight.id);
    expect(changed.argb, 0xFF33CC33);
    expect(changed.contents, 'green');
    await doc.removeAnnotation(1, under.id);
    expect(
      [for (final a in await doc.annotations(1)) a.id],
      [strike.id, note.id],
    );

    final copy = '${dir.path}/copy.pdf';
    await doc.saveTo(copy);
    final again = await const PopplerBackend().open(copy);
    addTearDown(again.close);
    final first = (await again.annotations(0)).single;
    expect(first.kind, PdfMarkupKind.highlight);
    expect(first.argb, 0xFF33CC33);
    expect(first.author, 'Tester');
    expect(first.contents, 'green');
    expect(first.quads.single.left, closeTo(word.left, 0.5));
    expect(first.quads.single.top, closeTo(word.top, 0.5));
    expect(
      [for (final a in await again.annotations(1)) a.kind],
      [PdfMarkupKind.strikeOut, PdfMarkupKind.note],
    );

    // Saving over the file it was opened from replaces it.
    await again.removeAnnotation(0, first.id);
    await again.saveTo(copy);
    final third = await const PopplerBackend().open(copy);
    addTearDown(third.close);
    expect(await third.annotations(0), isEmpty);
    expect(await third.annotations(1), hasLength(2));
    expect(dir.listSync().map((f) => f.path.split('/').last).toSet(), {
      'notes.pdf',
      'copy.pdf',
    });
  }, skip: skip);

  test('a save to a folder that does not exist fails cleanly', () async {
    final dir = tempDir(addTearDown);
    final path = write(
      dir,
      'one.pdf',
      textPdf([
        ['Hello'],
      ]),
    );
    final doc = await const PopplerBackend().open(path);
    addTearDown(doc.close);
    await expectLater(
      doc.saveTo('${dir.path}/missing/out.pdf'),
      throwsA(isA<PdfSaveException>()),
    );
    expect(File('${dir.path}/missing').existsSync(), isFalse);
  }, skip: skip);

  test('annotations on rotated pages keep the text layout space', () async {
    for (final rotate in [0, 90, 180, 270]) {
      final dir = tempDir(addTearDown);
      final path = write(
        dir,
        'r.pdf',
        textPdf([
          ['Hello world'],
        ], rotate: rotate),
      );
      final doc = await const PopplerBackend().open(path);
      addTearDown(doc.close);
      final layout = await doc.text(0);
      final word = layout.rects
          .sublist(0, 5)
          .reduce((a, b) => a.expandToInclude(b));
      final added = await doc.addMarkup(0, PdfMarkupKind.highlight, [
        word,
      ], 0xFFFFFF00);
      expect(added.modified, isNotNull);
      await doc.saveTo('${dir.path}/saved.pdf');
      final again = await const PopplerBackend().open('${dir.path}/saved.pdf');
      addTearDown(again.close);
      final read = (await again.annotations(0)).single;
      for (final r in [added.quads.single, read.quads.single, read.bounds]) {
        expect(r.left, closeTo(word.left, 0.5), reason: '$rotate');
        expect(r.top, closeTo(word.top, 0.5), reason: '$rotate');
        expect(r.right, closeTo(word.right, 0.5), reason: '$rotate');
        expect(r.bottom, closeTo(word.bottom, 0.5), reason: '$rotate');
      }
    }
  }, skip: skip);
}
