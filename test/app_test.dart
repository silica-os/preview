// The window: opening, zoom, rotation, the sidebar, page navigation, search, selection, export,
// Get Info and the password sheet. Files live in temporary directories; dialogs and the PDF
// backend are fakes, the clipboard is mocked, nothing reaches the desktop.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:preview/src/export/export.dart';
import 'package:preview/src/model/document.dart';
import 'package:preview/src/model/viewer.dart';
import 'package:preview/src/pdf/backend.dart';
import 'package:preview/src/portal.dart';
import 'package:preview/src/ui/app.dart';
import 'package:preview/src/ui/window.dart';

import 'support/fake_pdf.dart';
import 'support/samples.dart';

class FakeDialogs implements FileDialogs {
  final List<List<String>?> opens = [];
  String? savePath;
  int openCalls = 0;
  final List<String> saveNames = [];

  @override
  Future<List<String>?> open({
    required String title,
    bool multiple = true,
  }) async {
    openCalls++;
    return opens.isEmpty ? null : opens.removeAt(0);
  }

  @override
  Future<String?> save({required String title, required String name}) async {
    saveNames.add(name);
    return savePath;
  }
}

void main() {
  late FakeDialogs dialogs;
  late FakePdfBackend backend;
  late Directory dir;
  late List<(ImageItem, ExportOptions, String)> exports;
  ViewerController? controller;

  setUp(() {
    dialogs = FakeDialogs();
    backend = FakePdfBackend({});
    dir = tempDir(addTearDown);
    exports = [];
    controller = null;
  });

  Future<ViewerController> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PreviewApp(
        loader: DocumentLoader(pdf: backend),
        dialogs: dialogs,
        locale: locale,
        onController: (c) => controller = c,
        exporter: (item, options, path) async =>
            exports.add((item, options, path)),
      ),
    );
    await tester.pump();
    return controller!;
  }

  /// Lets file reads and decoding finish (they run outside the test's fake time).
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'did not settle');
    await tester.pump();
  }

  Future<void> openFiles(
    WidgetTester tester,
    ViewerController c,
    List<String> paths,
  ) async {
    var done = false;
    c.open(paths).then((_) => done = true);
    await settle(tester, () => done);
  }

  Future<void> keys(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool command = true,
    bool shift = false,
    bool option = false,
  }) async {
    final held = [
      if (command) LogicalKeyboardKey.metaLeft,
      if (shift) LogicalKeyboardKey.shiftLeft,
      if (option) LogicalKeyboardKey.altLeft,
    ];
    for (final k in held) {
      await tester.sendKeyDownEvent(k);
    }
    await tester.sendKeyEvent(key);
    for (final k in held.reversed) {
      await tester.sendKeyUpEvent(k);
    }
    await tester.pump();
  }

  String png(String name, int w, int h) =>
      write(dir, name, img.encodePng(halves(w, h)));

  String pdf(String name, FakePdf fake) {
    final path = write(dir, name, '%PDF-1.4\n'.codeUnits);
    backend.files[path] = fake;
    return path;
  }

  FakePdf book(int n) => FakePdf(
    [
      for (var i = 0; i < n; i++)
        FakePage(lines: ['Page ${i + 1}', if (i == 2) 'hidden world']),
    ],
    outline: const [PdfOutlineItem('One', 0), PdfOutlineItem('Three', 2)],
  );

  /// Taps a menu item: the menu blinks, then acts (timers, no frames in between).
  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets(
    'launched without files: the Open dialog, then the empty window',
    (tester) async {
      final path = png('photo.png', 200, 100);
      final c = await pump(tester);
      expect(dialogs.openCalls, 1);
      expect(find.byKey(const ValueKey('empty open')), findsOneWidget);
      dialogs.opens.add([path]);
      await tester.tap(find.byKey(const ValueKey('empty open')));
      await settle(tester, () => c.document != null);
      expect(dialogs.openCalls, 2);
      expect(text(tester, 'title'), 'photo.png');
      expect(text(tester, 'subtitle'), '200 × 100 pixels');
      // ⌘O asks again.
      await keys(tester, LogicalKeyboardKey.keyO);
      expect(dialogs.openCalls, 3);
    },
  );

  testWidgets('zoom: buttons, ⌘+ ⌘− ⌘0 ⌘9', (tester) async {
    final c = await pump(tester);
    await openFiles(tester, c, [png('a.png', 200, 100)]);
    expect(c.scale, 1);
    await tester.tap(find.byKey(const ValueKey('zoom in')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.scale, closeTo(1.25, 1e-9));
    await tester.tap(find.byKey(const ValueKey('zoom out')));
    await tester.pump(const Duration(milliseconds: 300));
    await keys(tester, LogicalKeyboardKey.minus);
    expect(c.scale, closeTo(0.8, 1e-9));
    await keys(tester, LogicalKeyboardKey.equal);
    expect(c.scale, closeTo(1, 1e-9));
    await keys(tester, LogicalKeyboardKey.digit9);
    // View 1000 × 648: min(1000 / 200, 648 / 100).
    expect(c.scale, closeTo(5, 1e-9));
    await keys(tester, LogicalKeyboardKey.digit0);
    expect(c.scale, 1);
  });

  testWidgets('rotate with the button and ⌘L ⌘R; flip from the context menu', (
    tester,
  ) async {
    final c = await pump(tester);
    await openFiles(tester, c, [png('a.png', 200, 100)]);
    await tester.tap(find.byKey(const ValueKey('rotate')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.image!.quarterTurns, 3);
    await keys(tester, LogicalKeyboardKey.keyR);
    await keys(tester, LogicalKeyboardKey.keyR);
    expect(c.image!.quarterTurns, 1);
    await keys(tester, LogicalKeyboardKey.keyL);
    expect(c.image!.quarterTurns, 0);
    await tester.tapAt(const Offset(500, 400), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsOneWidget);
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await choose(tester, 'Flip Horizontal');
    expect(c.image!.flipHorizontal, isTrue);
  });

  testWidgets('several images: thumbnails, choosing one, hiding the sidebar', (
    tester,
  ) async {
    final c = await pump(tester);
    await openFiles(tester, c, [png('a.png', 40, 20), png('b.png', 20, 40)]);
    expect(find.byKey(const ValueKey('thumbnails')), findsOneWidget);
    expect(text(tester, 'subtitle'), '1 of 2');
    await tester.tap(find.byKey(const ValueKey('thumbnail 1')));
    await tester.pump();
    expect(text(tester, 'subtitle'), '2 of 2');
    expect(text(tester, 'title'), 'a.png');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(c.current, 0);
    await tester.tap(find.byKey(const ValueKey('sidebar toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('sidebar')), findsNothing);
    await keys(tester, LogicalKeyboardKey.digit2, option: true);
    expect(find.byKey(const ValueKey('thumbnails')), findsOneWidget);
  });

  testWidgets('PDF pages: next, Go to Page, layouts, table of contents', (
    tester,
  ) async {
    final c = await pump(tester);
    await openFiles(tester, c, [pdf('book.pdf', book(5))]);
    expect(text(tester, 'subtitle'), 'Page 1 of 5');
    await keys(tester, LogicalKeyboardKey.arrowDown, option: true);
    expect(text(tester, 'subtitle'), 'Page 2 of 5');
    await keys(tester, LogicalKeyboardKey.keyG, option: true);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('page field')), '4');
    await tester.tap(find.byKey(const ValueKey('sheet accept')));
    await tester.pumpAndSettle();
    expect(text(tester, 'subtitle'), 'Page 4 of 5');
    // The sidebar button's menu: the layouts.
    await tester.tap(find.byKey(const ValueKey('view options')));
    await tester.pumpAndSettle();
    await choose(tester, 'Two Pages');
    expect(c.layout, PageLayout.two);
    expect(find.byKey(const ValueKey('page 2')), findsOneWidget);
    expect(find.byKey(const ValueKey('page 3')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(c.current, 4);
    await keys(tester, LogicalKeyboardKey.digit3, option: true);
    expect(find.byKey(const ValueKey('contents')), findsOneWidget);
    await tester.tap(find.text('One'));
    await tester.pump();
    expect(c.current, 0);
  });

  testWidgets('search with ⌘F, select and copy text', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    final c = await pump(tester);
    await openFiles(tester, c, [pdf('book.pdf', book(4))]);
    await keys(tester, LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(find.byKey(const ValueKey('search field')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('search field')), 'WORLD');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester, () => c.searchDone && c.matches.isNotEmpty);
    expect(c.matches.single.page, 2);
    expect(text(tester, 'subtitle'), '1 of 1');
    await keys(tester, LogicalKeyboardKey.escape, command: false);
    expect(c.searching, isFalse);
    // Drag across "Page 3" on the third page.
    c.goTo(0);
    await tester.pump();
    var loaded = false;
    c.loadText(0).then((_) => loaded = true);
    await settle(tester, () => loaded);
    final page = find.byKey(const ValueKey('page 0'));
    final origin = tester.getTopLeft(page);
    final scale = c.scale;
    await tester.dragFrom(
      origin + Offset(21 * scale, 26 * scale),
      Offset(30 * scale, 0),
      kind: PointerDeviceKind.mouse,
    );
    await settle(tester, () => c.canCopy);
    expect(c.selectedText, 'Page');
    await keys(tester, LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(copied, ['Page']);
  });

  testWidgets('export: the options sheet, JPEG quality, the Save dialog', (
    tester,
  ) async {
    final c = await pump(tester);
    await openFiles(tester, c, [png('photo.png', 20, 10)]);
    dialogs.savePath = '${dir.path}/out.jpg';
    final window = tester.state<PreviewWindowState>(find.byType(PreviewWindow));
    window.export();
    await tester.pumpAndSettle();
    expect(find.text('Export “photo.png”'), findsOneWidget);
    expect(find.byKey(const ValueKey('export quality')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('export format')));
    await tester.pumpAndSettle();
    await choose(tester, 'JPEG');
    expect(find.byKey(const ValueKey('export quality')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('export save')));
    await tester.pumpAndSettle();
    expect(dialogs.saveNames, ['photo.jpg']);
    expect(exports.single.$2.format, ExportFormat.jpeg);
    expect(exports.single.$3, '${dir.path}/out.jpg');
  });

  testWidgets('Get Info with ⌘I', (tester) async {
    final c = await pump(tester);
    await openFiles(tester, c, [png('photo.png', 20, 10)]);
    await keys(tester, LogicalKeyboardKey.keyI);
    expect(find.byKey(const ValueKey('inspector')), findsOneWidget);
    expect(find.text('20 × 10 pixels'), findsWidgets);
    expect(find.text('PNG image'), findsOneWidget);
    await keys(tester, LogicalKeyboardKey.keyI);
    expect(find.byKey(const ValueKey('inspector')), findsNothing);
  });

  testWidgets('a protected PDF: the password sheet', (tester) async {
    final c = await pump(tester);
    final path = pdf('secret.pdf', FakePdf([const FakePage()], password: 'pw'));
    await openFiles(tester, c, [path]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('password field')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('password field')), 'pw');
    await tester.tap(find.byKey(const ValueKey('sheet accept')));
    await settle(tester, () => c.document != null);
    expect(text(tester, 'title'), 'secret.pdf');
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a file that cannot open: the alert', (tester) async {
    final c = await pump(tester);
    await openFiles(tester, c, ['${dir.path}/missing.png']);
    expect(find.text('The file couldn\'t be opened'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.byKey(const ValueKey('alert')), findsNothing);
  });

  testWidgets('in Italian', (tester) async {
    final c = await pump(tester, locale: const Locale('it'));
    await openFiles(tester, c, [pdf('libro.pdf', book(3))]);
    expect(text(tester, 'subtitle'), 'Pagina 1 di 3');
  });
}
