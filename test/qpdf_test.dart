// The qpdf writer against PDFs written by the tests, read back with poppler (skipped without
// libqpdf or poppler-glib).

import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:preview/src/pdf/backend.dart';
import 'package:preview/src/pdf/poppler.dart';
import 'package:preview/src/pdf/qpdf.dart';

import 'support/fake_pdf.dart';
import 'support/samples.dart';

void main() {
  final skip = !QpdfWriter.available
      ? 'libqpdf not installed'
      : !PopplerBackend.available
      ? 'poppler-glib not installed'
      : false;
  const writer = QpdfWriter();
  const poppler = PopplerBackend();

  late Directory dir;
  late String three;
  setUp(() {
    dir = tempDir(addTearDown);
    three = write(
      dir,
      'three.pdf',
      textPdf([
        ['first page'],
        ['second page'],
        ['third page'],
      ]),
    );
  });

  Future<PdfDocumentHandle> open(String path, {String? password}) async {
    final doc = await poppler.open(path, password: password);
    addTearDown(doc.close);
    return doc;
  }

  Future<List<String>> texts(PdfDocumentHandle doc) async => [
    for (var i = 0; i < doc.pageCount; i++) (await doc.text(i)).text.trim(),
  ];

  test('reorder, delete, rotate and insert a blank page', () async {
    final out = '${dir.path}/out.pdf';
    await writer.write([
      SourcePage(three, 2),
      SourcePage(three, 0, quarterTurns: 1),
      const BlankPage(Size(200, 100)),
    ], out);
    final doc = await open(out);
    expect(doc.pageCount, 3);
    expect(await texts(doc), ['third page', 'first page', '']);
    expect(doc.pageSizes[0], const Size(300, 400));
    // Turned a quarter: the page is now landscape.
    expect(doc.pageSizes[1], const Size(400, 300));
    expect(doc.pageSizes[2], const Size(200, 100));
    // The outline still leads to the pages it pointed at (chapter 2 was deleted).
    final outline = {for (final o in doc.outline) o.title: o.page};
    expect(outline['Chapter 1'], 1);
    expect(outline['Chapter 3'], 0);
    expect(doc.pageMode, PdfPageMode.outlines);
  }, skip: skip);

  test('turns add to the page rotation, and can turn it back', () async {
    final turned = write(
      dir,
      'turned.pdf',
      textPdf([
        ['a'],
      ], rotate: 90),
    );
    final out = '${dir.path}/out.pdf';
    await writer.write([SourcePage(turned, 0, quarterTurns: 3)], out);
    expect((await open(out)).pageSizes.single, const Size(300, 400));
    await writer.write([SourcePage(turned, 0, quarterTurns: -2)], out);
    expect((await open(out)).pageSizes.single, const Size(400, 300));
  }, skip: skip);

  test('pages from two files, and a page used twice', () async {
    final other = write(
      dir,
      'other.pdf',
      textPdf([
        ['from the other file'],
      ]),
    );
    final out = '${dir.path}/out.pdf';
    await writer.write([
      SourcePage(three, 0),
      SourcePage(other, 0),
      SourcePage(three, 0),
      SourcePage(other, 0),
      SourcePage(three, 0),
    ], out);
    final doc = await open(out);
    expect(await texts(doc), [
      'first page',
      'from the other file',
      'first page',
      'from the other file',
      'first page',
    ]);
  }, skip: skip);

  test('writing over a source replaces it', () async {
    await writer.write([SourcePage(three, 1)], three);
    expect(await texts(await open(three)), ['second page']);
    expect(dir.listSync().map((f) => f.path.split('/').last).toList(), [
      'three.pdf',
    ]);
  }, skip: skip);

  test('bookmarks travel with their pages; keywords', () async {
    final out = '${dir.path}/out.pdf';
    await writer.write(
      [
        SourcePage(three, 0),
        SourcePage(three, 1, bookmarked: true),
        SourcePage(three, 2),
      ],
      out,
      keywords: 'silica, test',
    );
    expect((await writer.read(out)).bookmarks, [1]);
    expect((await open(out)).info.keywords, 'silica, test');
    final moved = '${dir.path}/moved.pdf';
    await writer.write([
      SourcePage(out, 1, bookmarked: true),
      SourcePage(out, 0),
      SourcePage(out, 2, bookmarked: true),
    ], moved);
    expect((await writer.read(moved)).bookmarks, [0, 2]);
    // Unmarked when written without the flag.
    await writer.write([SourcePage(moved, 0)], moved);
    expect((await writer.read(moved)).bookmarks, isEmpty);
    expect((await writer.read(moved)).security, isNull);
  }, skip: skip);

  test('encryption: a password to open, permissions, removal', () async {
    final locked = '${dir.path}/locked.pdf';
    await writer.write(
      [SourcePage(three, 0), SourcePage(three, 1)],
      locked,
      security: const PdfSecurity(
        userPassword: 'silica',
        ownerPassword: 'owner',
        printing: false,
        assembling: false,
      ),
    );
    await expectLater(
      poppler.open(locked),
      throwsA(
        isA<PdfOpenException>().having(
          (e) => e.failure,
          'failure',
          PdfOpenFailure.encrypted,
        ),
      ),
    );
    final doc = await open(locked, password: 'silica');
    expect(doc.pageCount, 2);
    expect(doc.info.encrypted, isTrue);
    await expectLater(
      writer.read(locked),
      throwsA(
        isA<PdfWriteException>().having(
          (e) => e.failure,
          'failure',
          PdfWriteFailure.password,
        ),
      ),
    );
    final security = (await writer.read(locked, password: 'silica')).security;
    expect(security, isNotNull);
    expect(security!.userPassword, 'silica');
    expect(security.printing, isFalse);
    expect(security.assembling, isFalse);
    expect(security.copying, isTrue);
    expect(security.annotating, isTrue);
    expect(security.formFilling, isTrue);

    // Kept as it is when rewritten without a security.
    final kept = '${dir.path}/kept.pdf';
    await writer.write([SourcePage(locked, 1, password: 'silica')], kept);
    await expectLater(poppler.open(kept), throwsA(isA<PdfOpenException>()));
    expect((await open(kept, password: 'silica')).pageCount, 1);

    // Removed with an open security.
    final open_ = '${dir.path}/open.pdf';
    await writer.write(
      [SourcePage(locked, 0, password: 'silica')],
      open_,
      security: const PdfSecurity(),
    );
    expect((await open(open_)).info.encrypted, isFalse);
    expect((await writer.read(open_)).security, isNull);
  }, skip: skip);

  test('only permissions: opens without a password', () async {
    final out = '${dir.path}/restricted.pdf';
    await writer.write(
      [SourcePage(three, 0)],
      out,
      security: const PdfSecurity(ownerPassword: 'owner', copying: false),
    );
    final doc = await open(out);
    expect(doc.info.encrypted, isTrue);
    final security = (await writer.read(out)).security!;
    expect(security.userPassword, isNull);
    expect(security.copying, isFalse);
    expect(security.printing, isTrue);
  }, skip: skip);

  test(
    'failures: a missing source, a page out of range, a bad folder',
    () async {
      Matcher fails(PdfWriteFailure kind) => throwsA(
        isA<PdfWriteException>().having((e) => e.failure, 'failure', kind),
      );
      await expectLater(
        writer.write([
          SourcePage('${dir.path}/none.pdf', 0),
        ], '${dir.path}/o.pdf'),
        fails(PdfWriteFailure.source),
      );
      await expectLater(
        writer.write([SourcePage(three, 7)], '${dir.path}/o.pdf'),
        fails(PdfWriteFailure.source),
      );
      await expectLater(
        writer.write([SourcePage(three, 0)], '${dir.path}/no/such/o.pdf'),
        fails(PdfWriteFailure.output),
      );
      expect(File('${dir.path}/o.pdf').existsSync(), isFalse);
    },
    skip: skip,
  );

  test('annotations saved by poppler survive a page rewrite', () async {
    final doc = await open(three);
    await doc.addMarkup(1, PdfMarkupKind.highlight, [
      const Rect.fromLTWH(40, 30, 60, 14),
    ], 0xFFFFFF00);
    final annotated = '${dir.path}/annotated.pdf';
    await doc.saveTo(annotated);
    final out = '${dir.path}/out.pdf';
    await writer.write([SourcePage(annotated, 1)], out);
    final again = await open(out);
    expect(
      [for (final a in await again.annotations(0)) a.kind],
      [PdfMarkupKind.highlight],
    );
  }, skip: skip);

  test('the fake writer records and answers', () async {
    final fake = FakePdfWriter();
    await fake.write(
      const [SourcePage('a.pdf', 0, bookmarked: true), BlankPage(Size(10, 10))],
      'out.pdf',
      keywords: 'k',
    );
    expect(fake.writes.single.keywords, 'k');
    expect((await fake.read('out.pdf')).bookmarks, [0]);
    fake.failure = const PdfWriteException(PdfWriteFailure.output);
    await expectLater(fake.read('out.pdf'), throwsA(isA<PdfWriteException>()));
  });
}
