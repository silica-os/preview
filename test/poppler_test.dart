// The real PDF backend against PDFs written by the tests (skipped without poppler-glib).

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
}
