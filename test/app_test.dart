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
import 'package:preview/src/ui/markup_bar.dart';
import 'package:preview/src/ui/menus.dart';
import 'package:preview/src/ui/window.dart';
import 'package:preview/l10n/app_localizations.dart';
import 'package:preview/src/model/markup.dart';
import 'package:preview/src/style.dart';
import 'package:silica_ui/silica_ui.dart';

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
  late FakePdfWriter writer;
  late Directory dir;
  late List<(ImageItem, ExportOptions, String)> exports;
  ViewerController? controller;

  setUp(() {
    dialogs = FakeDialogs();
    backend = FakePdfBackend({});
    writer = FakePdfWriter();
    dir = tempDir(addTearDown);
    exports = [];
    controller = null;
  });

  /// Preview launched with [files] (Open With). Without a document only the Open panel
  /// would show, and no window (preview#24).
  Future<ViewerController> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Size size = const Size(1000, 700),
    Size? screen,
    required List<String> files,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      PreviewApp(
        loader: DocumentLoader(pdf: backend, writer: writer),
        dialogs: dialogs,
        files: files,
        locale: locale,
        onController: (c) => controller = c,
        exporter: (item, options, path) async =>
            exports.add((item, options, path)),
        screenSize: (_) async => screen,
      ),
    );
    await tester.pump();
    // The files are read (outside the test's fake time) before the test goes on.
    final c = controller!;
    for (var i = 0; i < 100 && (i == 0 || c.loading); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pump();
    return c;
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

  /// The texts of the toolbar's title block: the name, then the second line when there is one.
  List<String> titleTexts(WidgetTester tester) => [
    for (final t in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(AmalfiTitlePiece),
        matching: find.byType(Text),
      ),
    ))
      t.data!,
  ];

  String titleOf(WidgetTester tester) => titleTexts(tester).first;

  String? subtitleOf(WidgetTester tester) {
    final texts = titleTexts(tester);
    return texts.length > 1 ? texts[1] : null;
  }

  /// Presses segment `index` of the action capsule with the key `key` (32 pt segments).
  Future<void> tapSegment(WidgetTester tester, String key, int index) async {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    await tester.tapAt(Offset(rect.left + 16 + 32.0 * index, rect.center.dy));
  }

  testWidgets(
    'launched without files: only the Open panel, no empty window (preview#24)',
    (tester) async {
      final app = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SilicaApp.channel,
        (call) async {
          app.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SilicaApp.channel,
          null,
        ),
      );
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        PreviewApp(
          loader: DocumentLoader(pdf: backend, writer: writer),
          dialogs: dialogs,
          locale: const Locale('en'),
          onController: (c) => controller = c,
        ),
      );
      await tester.pump();
      // The window goes before its first frame; the Open panel is the only thing shown.
      expect(app.map((c) => c.method), contains('closeWindow'));
      expect(dialogs.openCalls, 1);
      expect(find.byType(PreviewWindow), findsNothing);
      expect(find.byKey(const ValueKey('empty open')), findsNothing);
      // Cancelled: still no window; the menus still offer File › Open….
      await tester.pump();
      expect(find.byType(PreviewWindow), findsNothing);
      expect(app.map((c) => c.method), isNot(contains('openWindow')));
      final bar = tester.widget<SilicaWindowlessMenuBar>(
        find.byType(SilicaWindowlessMenuBar),
      );
      final file = bar.menus.whereType<SilicaMenu>().firstWhere(
        (m) => m.label == 'File',
      );
      final open = file.menus.single as SilicaMenuItem;
      expect(open.label, 'Open…');
      // A file chosen there: the window, with it.
      final path = png('photo.png', 200, 100);
      dialogs.opens.add([path]);
      open.onSelected!();
      await settle(tester, () => controller?.document != null);
      expect(dialogs.openCalls, 2);
      expect(find.byType(PreviewWindow), findsOneWidget);
      expect(titleOf(tester), 'photo.png');
      // One image: no second line.
      expect(subtitleOf(tester), isNull);
      await tester.pump();
      expect(app.map((c) => c.method), contains('openWindow'));
      // ⌘O asks again.
      await keys(tester, LogicalKeyboardKey.keyO);
      expect(dialogs.openCalls, 3);
    },
  );

  testWidgets(
    'a reopen with no window shows the Open panel alone (preview#24)',
    (tester) async {
      await pump(tester, files: [png('a.png', 20, 10)]);
      await SilicaApp.handle('lastWindowClosed', const {});
      await tester.pump();
      expect(find.byType(PreviewWindow), findsNothing);
      final opened = dialogs.openCalls;
      await SilicaApp.handle('reopen', const {'windowless': true});
      await tester.pump();
      await tester.pump();
      // Cancelled (the fake answers nothing): no window.
      expect(dialogs.openCalls, opened + 1);
      expect(find.byType(PreviewWindow), findsNothing);
    },
  );

  testWidgets('a new image sizes the window: 100 % plus 52 + 26 + 26', (
    tester,
  ) async {
    final sizes = <Map<Object?, Object?>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SilicaWindow.channel,
      (call) async {
        if (call.method == 'setSize') {
          sizes.add(call.arguments as Map<Object?, Object?>);
        }
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SilicaWindow.channel,
        null,
      ),
    );
    await pump(
      tester,
      screen: const Size(2560, 1440),
      files: [png('a.png', 900, 500)],
    );
    await tester.pump();
    expect(sizes.single['width'], 900);
    expect(sizes.single['height'], 604);
  });

  testWidgets('the toolbar: the measured places at 1200 pt', (tester) async {
    await pump(
      tester,
      size: const Size(1200, 800),
      files: [pdf('book.pdf', book(3))],
    );
    Rect at(String key) => tester.getRect(find.byKey(ValueKey(key)));
    // Pieces: the window buttons' slot of 96, the view piece (a 73 × 36 capsule, 4 pt of
    // padding, 8 from the top), the title block from x 177.
    expect(at('view menu button'), const Rect.fromLTWH(100, 8, 73, 36));
    expect(tester.getTopLeft(find.byType(AmalfiTitlePiece)).dx, 177);
    // The zoom group is three segments, the highlight group two.
    expect(at('zoom').size, const Size(110, 36));
    expect(at('highlight').size, const Size(73, 36));
    // The search field (200) ends 4 pt of padding and the bar's 8 pt from the right edge.
    final search = at('search field');
    expect(search.right, closeTo(1200 - 8 - 4, 0.5));
    expect(search.width, 200);
    expect(search.height, 36);
  });

  testWidgets('a narrow window: the search circle and the overflow menu', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(708, 500),
      files: [pdf('a long name for a document.pdf', book(2))],
    );
    expect(find.byKey(const ValueKey('search circle')), findsOneWidget);
    expect(find.byKey(const ValueKey('overflow')), findsOneWidget);
    expect(find.byKey(const ValueKey('search field')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('overflow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('overflow menu')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // The circle opens the field in a popover, ready to type in.
    await tester.tap(find.byKey(const ValueKey('search circle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search field')), findsOneWidget);
    final field = find.descendant(
      of: find.byKey(const ValueKey('search field')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zoom: steps with the buttons and keys, animated', (
    tester,
  ) async {
    final c = await pump(tester, files: [png('a.png', 200, 100)]);
    expect(c.scale, 1);
    // Actual size is off at 100 %.
    expect(
      tester
          .widget<AmalfiActionSegments>(find.byKey(const ValueKey('zoom')))
          .segments[1]
          .enabled,
      isFalse,
    );
    await tapSegment(tester, 'zoom', 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Half way through the 200 ms step.
    expect(c.scale, greaterThan(1));
    expect(c.scale, lessThan(1.5));
    await tester.pump(const Duration(milliseconds: 150));
    expect(c.scale, closeTo(1.5, 1e-9));
    await tapSegment(tester, 'zoom', 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await keys(tester, LogicalKeyboardKey.minus);
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.scale, closeTo(0.75, 1e-9));
    await keys(tester, LogicalKeyboardKey.equal);
    await tester.pump(const Duration(milliseconds: 250));
    expect(c.scale, closeTo(1, 1e-9));
    await keys(tester, LogicalKeyboardKey.digit9);
    // View 1000 × 648: min(1000 / 200, 648 / 100).
    expect(c.scale, closeTo(5, 1e-9));
    await tapSegment(tester, 'zoom', 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(c.scale, 1);
  });

  testWidgets('rotate with the button and ⌘L ⌘R; flip from the context menu', (
    tester,
  ) async {
    final c = await pump(tester, files: [png('a.png', 200, 100)]);
    await tester.tap(find.byKey(const ValueKey('rotate')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.image!.quarterTurns, 3);
    expect(subtitleOf(tester), 'Edited');
    await keys(tester, LogicalKeyboardKey.keyR);
    await keys(tester, LogicalKeyboardKey.keyR);
    expect(c.image!.quarterTurns, 1);
    await keys(tester, LogicalKeyboardKey.keyL);
    expect(c.image!.quarterTurns, 0);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(500, 400), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsOneWidget);
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await choose(tester, 'Flip Horizontal');
    expect(c.image!.flipHorizontal, isTrue);
    // Undo, four times back to the file: no longer edited.
    for (var i = 0; i < 5; i++) {
      await keys(tester, LogicalKeyboardKey.keyZ);
    }
    expect(c.edited, isFalse);
    expect(subtitleOf(tester), isNull);
  });

  testWidgets('several images: thumbnails, choosing one, hiding the sidebar', (
    tester,
  ) async {
    final c = await pump(
      tester,
      files: [png('a.png', 40, 20), png('b.png', 20, 40)],
    );
    expect(find.byKey(const ValueKey('thumbnails')), findsOneWidget);
    expect(subtitleOf(tester), '2 documents, 2 pages in all');
    await tester.tap(find.byKey(const ValueKey('thumbnail 1')));
    await tester.pump();
    expect(titleOf(tester), 'b.png');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(c.current, 0);
    await keys(tester, LogicalKeyboardKey.digit1, option: true);
    // The sidebar slides out in 220 ms.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('sidebar')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('sidebar')), findsNothing);
    await keys(tester, LogicalKeyboardKey.digit2, option: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('thumbnails')), findsOneWidget);
    // The thumbnail menu: sort by name, close one.
    await tester.tap(
      find.byKey(const ValueKey('thumbnail 1')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('thumbnail menu')), findsOneWidget);
    await choose(tester, 'Close');
    expect(c.count, 1);
  });

  testWidgets('the view menu: sidebar kinds and the layouts', (tester) async {
    final c = await pump(tester, files: [pdf('book.pdf', book(5))]);
    expect(subtitleOf(tester), 'Page 1 of 5');
    await keys(
      tester,
      LogicalKeyboardKey.arrowDown,
      command: false,
      option: true,
    );
    expect(subtitleOf(tester), 'Page 2 of 5');
    await keys(tester, LogicalKeyboardKey.keyG, option: true);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('page field')), '4');
    await tester.tap(find.byKey(const ValueKey('sheet accept')));
    await tester.pumpAndSettle();
    expect(subtitleOf(tester), 'Page 4 of 5');
    // Back to where Go to Page jumped from.
    await keys(tester, LogicalKeyboardKey.bracketLeft);
    expect(c.current, 1);
    await tapSegment(tester, 'view menu button', 0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('view menu')), findsOneWidget);
    await choose(tester, 'Two Pages');
    expect(c.layout, PageLayout.two);
    expect(find.byKey(const ValueKey('page 1')), findsOneWidget);
    expect(find.byKey(const ValueKey('page 2')), findsOneWidget);
    expect(find.byKey(const ValueKey('spine')), findsNWidgets(2));
    await keys(tester, LogicalKeyboardKey.digit1);
    expect(c.layout, PageLayout.continuous);
    await keys(tester, LogicalKeyboardKey.digit3, option: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('contents')), findsOneWidget);
    await tester.tap(find.text('Three'));
    await tester.pump();
    expect(c.current, 2);
    await keys(tester, LogicalKeyboardKey.digit6, option: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('contact sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('contact 4')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.current, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sidebar is resized by its edge, 160 to 400', (tester) async {
    final c = await pump(tester, files: [pdf('book.pdf', book(3))]);
    expect(tester.getSize(find.byKey(const ValueKey('sidebar'))).width, 160);
    await tester.drag(
      find.byKey(const ValueKey('sidebar resizer')),
      const Offset(100, 0),
    );
    await tester.pump();
    expect(c.sidebarWidth, 260);
    await tester.drag(
      find.byKey(const ValueKey('sidebar resizer')),
      const Offset(-300, 0),
    );
    await tester.pump();
    expect(c.sidebarWidth, 160);
  });

  testWidgets('bookmarks: ⌘D, the bookmarks list', (tester) async {
    final c = await pump(tester, files: [pdf('book.pdf', book(3))]);
    c.goTo(2);
    await tester.pump();
    await keys(tester, LogicalKeyboardKey.keyD);
    expect(c.bookmarks, [2]);
    expect(subtitleOf(tester), 'Page 3 of 3 — Edited');
    await keys(tester, LogicalKeyboardKey.digit5, option: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('bookmark 2')), findsOneWidget);
    expect(find.text('Page 3'), findsOneWidget);
  });

  testWidgets('search: Return, the find bar, the results, Done', (
    tester,
  ) async {
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
    final c = await pump(tester, files: [pdf('book.pdf', book(4))]);
    await keys(tester, LogicalKeyboardKey.keyF);
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('search field')), 'WORLD');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, () => c.searchDone && c.matches.isNotEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.matches.single.page, 2);
    expect(find.byKey(const ValueKey('find bar')), findsOneWidget);
    expect(text(tester, 'find status'), 'Found on 1 page');
    expect(find.byKey(const ValueKey('result 2')), findsOneWidget);
    // The sidebar widens to 200 for the results.
    expect(tester.getSize(find.byKey(const ValueKey('sidebar'))).width, 200);
    await tester.tap(find.byKey(const ValueKey('find done')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.searching, isFalse);
    expect(find.byKey(const ValueKey('find bar')), findsNothing);
    // Drag across "Page 1" on the first page.
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
    // Highlight it from the toolbar's colour menu: green.
    await tapSegment(tester, 'highlight', 1);
    await tester.pumpAndSettle();
    await choose(tester, 'Green');
    await settle(tester, () => backend.opened.single.annots.isNotEmpty);
    expect(
      backend.opened.single.annots.single.argb,
      HighlightColour.green.color.toARGB32(),
    );
  });

  testWidgets('highlights and notes: the list, a note and its popover', (
    tester,
  ) async {
    final c = await pump(tester, files: [pdf('book.pdf', book(3))]);
    var done = false;
    c.addNote(contents: 'first note').then((_) => done = true);
    await settle(tester, () => done);
    await keys(tester, LogicalKeyboardKey.digit4, option: true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('notes sidebar')), findsOneWidget);
    expect(find.text('first note'), findsOneWidget);
    final note = backend.opened.single.annots.single;
    await tester.tap(find.byKey(ValueKey('note ${note.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note popover')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('note text')), 'edited');
    await tester.tap(find.byKey(const ValueKey('note done')));
    await settle(
      tester,
      () => backend.opened.single.annots.single.contents == 'edited',
    );
  });

  testWidgets('export: the options sheet, JPEG quality, the Save dialog', (
    tester,
  ) async {
    await pump(tester, files: [png('photo.png', 20, 10)]);
    dialogs.savePath = '${dir.path}/out.jpg';
    final window = tester.state<PreviewWindowState>(find.byType(PreviewWindow));
    window.export();
    await tester.pumpAndSettle();
    expect(find.text('Export “photo.png”'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('export sheet'))).width,
      408,
    );
    expect(find.byKey(const ValueKey('export quality')), findsNothing);
    // The halves sample has no transparency: no alpha check box.
    expect(find.byKey(const ValueKey('export alpha')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('export format')));
    await tester.pumpAndSettle();
    expect(find.text('TIFF'), findsWidgets);
    await choose(tester, 'JPEG');
    expect(find.byKey(const ValueKey('export quality')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('export save')));
    await tester.pumpAndSettle();
    expect(dialogs.saveNames, ['photo.jpg']);
    expect(exports.single.$2.format, ExportFormat.jpeg);
    expect(exports.single.$2.quality, 0.85);
    expect(exports.single.$3, '${dir.path}/out.jpg');
  });

  testWidgets('export of a PNG with transparency offers the alpha', (
    tester,
  ) async {
    final transparent = img.Image(width: 4, height: 4, numChannels: 4)
      ..clear(img.ColorRgba8(0, 0, 0, 0));
    await pump(
      tester,
      files: [write(dir, 'clear.png', img.encodePng(transparent))],
    );
    final window = tester.state<PreviewWindowState>(find.byType(PreviewWindow));
    window.export();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('export alpha')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('export cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('the inspector: a 260 pt pane with four tabs', (tester) async {
    await pump(tester, files: [png('photo.png', 20, 10)]);
    await keys(tester, LogicalKeyboardKey.keyI);
    expect(find.byKey(const ValueKey('inspector')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('inspector'))).width, 260);
    expect(find.text('20 × 10 pixels'), findsWidgets);
    expect(find.text('PNG image'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inspector tabs')));
    await tester.pump(const Duration(milliseconds: 300));
    await keys(tester, LogicalKeyboardKey.keyI);
    expect(find.byKey(const ValueKey('inspector')), findsNothing);
  });

  testWidgets('a protected PDF: the password in the window', (tester) async {
    final path = pdf('secret.pdf', FakePdf([const FakePage()], password: 'pw'));
    final c = await pump(tester, files: [path]);
    await tester.pump();
    expect(find.byKey(const ValueKey('password view')), findsOneWidget);
    expect(titleOf(tester), 'secret.pdf');
    expect(
      tester.getSize(find.byKey(const ValueKey('password field'))),
      const Size(PreviewMetrics.passwordField, 28),
    );
    // The field has the keyboard.
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('password field')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(text(tester, 'password message'), 'Type the password to open it.');
    await tester.enterText(find.byKey(const ValueKey('password field')), 'no');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, () => c.passwordRetry);
    // A wrong password empties the field and changes the line.
    expect(text(tester, 'password message'), 'That password is not right.');
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('password field')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      isEmpty,
    );
    await tester.enterText(find.byKey(const ValueKey('password field')), 'pw');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, () => c.document != null);
    expect(titleOf(tester), 'secret.pdf');
  });

  testWidgets('the slideshow: the HUD, turning, Esc', (tester) async {
    final c = await pump(tester, files: [pdf('book.pdf', book(3))]);
    await keys(tester, LogicalKeyboardKey.keyF, shift: true);
    expect(find.byKey(const ValueKey('slideshow')), findsOneWidget);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(500, 300));
    await gesture.moveTo(const Offset(510, 310));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('slideshow hud'))),
      PreviewMetrics.slideshowHud,
    );
    await tester.tap(find.byKey(const ValueKey('slideshow next')));
    await tester.pump();
    expect(c.current, 1);
    // Playing: the next page after about 5 s.
    await tester.pump(const Duration(seconds: 5));
    expect(c.current, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('slideshow')), findsNothing);
    await gesture.removePointer();
  });

  testWidgets('markup: the strip, a rectangle, its handles, delete', (
    tester,
  ) async {
    final c = await pump(tester, files: [png('photo.png', 400, 200)]);
    await keys(tester, LogicalKeyboardKey.keyA, shift: true);
    expect(find.byKey(const ValueKey('markup bar')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('markup bar'))).height, 36);
    await tester.tap(find.byKey(const ValueKey('markup shapes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('markup shapes popover')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shape rectangle')));
    await tester.pumpAndSettle();
    expect(c.image!.markup.single.kind, ShapeKind.rectangle);
    expect(c.chosenShape, isNotNull);
    expect(subtitleOf(tester), 'Edited');
    // The border colour popover colours the chosen shape.
    await tester.tap(find.byKey(const ValueKey('markup border colour')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bright 0')));
    await tester.pumpAndSettle();
    expect(c.image!.markup.single.stroke, brightColours[0]);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(c.image!.markup, isEmpty);
    await keys(tester, LogicalKeyboardKey.keyA, shift: true);
    expect(find.byKey(const ValueKey('markup bar')), findsNothing);
  });

  testWidgets('Adjust Size: the sheet, half the width, proportional', (
    tester,
  ) async {
    final c = await pump(tester, files: [png('photo.png', 400, 200)]);
    final window = tester.state<PreviewWindowState>(find.byType(PreviewWindow));
    findCommand(
      window.menus(AppLocalizations.of(window.context)),
      'preview.adjust_size',
    )!.run!();
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('adjust size sheet'))).width,
      PreviewMetrics.adjustSizeWidth,
    );
    await tester.enterText(find.byKey(const ValueKey('adjust width')), '200');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('adjust ok')));
    await tester.pumpAndSettle();
    expect(c.image!.size, const Size(200, 100));
  });

  testWidgets('Edit Permissions: passwords must match', (tester) async {
    final c = await pump(tester, files: [pdf('book.pdf', book(1))]);
    final window = tester.state<PreviewWindowState>(find.byType(PreviewWindow));
    findCommand(
      window.menus(AppLocalizations.of(window.context)),
      'preview.permissions',
    )!.run!();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('permissions sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('allow printing')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('permissions apply')));
    await tester.pump();
    expect(find.byKey(const ValueKey('permissions problem')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('owner password')), 'o');
    await tester.enterText(
      find.byKey(const ValueKey('owner password again')),
      'o',
    );
    await tester.tap(find.byKey(const ValueKey('permissions apply')));
    await tester.pumpAndSettle();
    expect(c.pdf!.newSecurity!.printing, isFalse);
    expect(c.pdf!.newSecurity!.ownerPassword, 'o');
    expect(c.edited, isTrue);
  });

  testWidgets('Revert asks first, then brings the file back', (tester) async {
    final path = png('photo.png', 20, 10);
    final c = await pump(tester, files: [path]);
    await keys(tester, LogicalKeyboardKey.keyR);
    final window = tester.state<PreviewWindowState>(find.byType(PreviewWindow));
    findCommand(
      window.menus(AppLocalizations.of(window.context)),
      'preview.revert',
    )!.run!();
    await tester.pump();
    expect(find.byKey(const ValueKey('alert')), findsOneWidget);
    await tester.tap(find.text('Revert'));
    await settle(tester, () => !c.edited && c.image!.quarterTurns == 0);
  });

  testWidgets('a drag from the title moves the window', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SilicaWindow.channel,
      (call) async {
        calls.add(call.method);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SilicaWindow.channel,
        null,
      ),
    );
    await pump(tester, files: [png('photo.png', 20, 10)]);
    calls.clear();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('title block'))),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, contains('startMove'));
  });

  testWidgets('the title popover renames the file', (tester) async {
    final path = png('photo.png', 20, 10);
    final c = await pump(tester, files: [path]);
    await tester.tap(find.byKey(const ValueKey('title block')));
    // The bar's double-click recognizer holds the click for its timeout.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('title popover'))).width,
      PreviewMetrics.titlePopover.width - 32,
    );
    // The name field has the keyboard, the name selected.
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('rename field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.focusNode.hasFocus, isTrue);
    expect(
      field.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await tester.enterText(
      find.byKey(const ValueKey('rename field')),
      'picture.png',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await settle(tester, () => c.image!.name == 'picture.png');
    expect(File('${dir.path}/picture.png').existsSync(), isTrue);
  });

  testWidgets('a file that cannot open: the alert', (tester) async {
    await pump(tester, files: ['${dir.path}/missing.png']);
    expect(find.text('The file couldn\'t be opened'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.byKey(const ValueKey('alert')), findsNothing);
  });

  testWidgets('in Italian', (tester) async {
    await pump(
      tester,
      locale: const Locale('it'),
      files: [pdf('libro.pdf', book(3))],
    );
    expect(subtitleOf(tester), 'Pagina 1 di 3');
  });

  group('menu bar model', () {
    PlatformMenu menu(List<PlatformMenuItem> bar, String label) =>
        bar.whereType<PlatformMenu>().firstWhere((m) => m.label == label);
    List<PlatformMenuItem> items(PlatformMenu m) => [
      for (final g in m.menus)
        if (g is PlatformMenuItemGroup) ...g.members else g,
    ];
    PlatformMenuItem item(
      List<PlatformMenuItem> bar,
      String menuName,
      String label,
    ) => items(menu(bar, menuName)).firstWhere((i) => i.label == label);

    Future<List<PlatformMenuItem>> model(WidgetTester tester) async {
      final window = tester.state<PreviewWindowState>(
        find.byType(PreviewWindow),
      );
      final l = AppLocalizations.of(window.context);
      return silicaMenuModel(l, window.menus(l, unavailable: true));
    }

    testWidgets('the menus of the bar, in order', (tester) async {
      await pump(tester, files: [pdf('book.pdf', book(3))]);
      // As published: silica_ui adds the standard Window and Help menus (silica-ui#99), whose
      // titles the bar gives.
      final bar = SilicaMenus.withStandard(await model(tester));
      expect(
        [for (final m in bar.whereType<PlatformMenu>()) m.label],
        ['Preview', 'File', 'Edit', 'View', 'Go', 'Tools', '', ''],
      );
      expect(
        [for (final m in bar.whereType<SilicaMenu>()) m.role],
        [
          SilicaMenuRole.app,
          for (var i = 0; i < 5; i++) SilicaMenuRole.none,
          SilicaMenuRole.window,
          SilicaMenuRole.help,
        ],
      );
      // The standard app menu: About first, enabled with an action; no Settings… (Preview has
      // no settings window).
      final app = (bar.first as SilicaMenu).menus;
      final about = (app.first as PlatformMenuItemGroup).members.single;
      expect((about as SilicaMenuItem).role, SilicaMenuItemRole.about);
      expect(about.onSelected, isNotNull);
      expect(
        app
            .whereType<PlatformMenuItemGroup>()
            .expand((g) => g.members)
            .any(
              (i) =>
                  i is SilicaMenuItem && i.role == SilicaMenuItemRole.settings,
            ),
        isFalse,
      );
    });

    testWidgets('states follow the document; unavailable items are disabled', (
      tester,
    ) async {
      final c = await pump(tester, files: [pdf('book.pdf', book(3))]);
      var bar = await model(tester);
      SilicaMenuItem at(String m, String label) =>
          item(bar, m, label) as SilicaMenuItem;
      expect(at('File', 'Open…').enabled, isTrue);
      expect(at('View', 'Thumbnails').checked, isTrue);
      expect(at('View', 'Continuous Scroll').checked, isTrue);
      expect(at('View', 'Two Pages').checked, isFalse);
      expect(at('Edit', 'Undo').enabled, isFalse);
      for (final (m, label) in [
        ('File', 'Print…'),
        ('File', 'Duplicate'),
        ('Edit', 'Cut'),
        ('Edit', 'Paste'),
        ('Tools', 'Crop'),
        ('Tools', 'Remove Background'),
      ]) {
        expect(at(m, label).enabled, isFalse, reason: label);
      }
      expect(
        (items(menu(bar, 'Edit')).firstWhere((i) => i.label == 'Find')
                as SilicaMenu)
            .enabled,
        isTrue,
      );
      c.setLayout(PageLayout.two);
      await tester.pump();
      bar = await model(tester);
      expect(at('View', 'Two Pages').checked, isTrue);
      expect(at('View', 'Continuous Scroll').checked, isFalse);
    });

    testWidgets('choosing an item runs its action', (tester) async {
      final c = await pump(tester, files: [pdf('book.pdf', book(3))]);
      var bar = await model(tester);
      item(bar, 'View', 'Single Page').onSelected!();
      await tester.pump();
      expect(c.layout, PageLayout.single);
      item(bar, 'View', 'Hide Sidebar').onSelected!();
      await tester.pump();
      expect(c.sidebar, SidebarMode.none);
      expect(
        (item(bar, 'File', 'Open…') as SilicaMenuItem).shortcut,
        isA<SingleActivator>(),
      );
    });
  });

  group('share and open while running', () {
    const channel = MethodChannel('silica/dbus', JSONMethodCodec());
    late List<Map> calls;

    void service({required bool present}) {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = call.arguments as Map;
            calls.add(args);
            if (!present) throw MissingPluginException();
            return args['method'] == 'Targets'
                ? [
                    [
                      ['copy', 'Copy', ''],
                      ['dev.frascella.Mail', 'Mail', ''],
                    ],
                  ]
                : [true];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    }

    Future<void> flush(WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pump();
    }

    testWidgets('Share appears with targets and sends the open file', (
      tester,
    ) async {
      service(present: true);
      final path = png('a.png', 40, 30);
      await pump(tester, files: [path]);
      await flush(tester);
      expect(find.byKey(const ValueKey('share')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share')));
      await flush(tester);
      await tester.tap(find.text('Mail'));
      await flush(tester);
      final share = calls.lastWhere((a) => a['method'] == 'Share');
      expect(share['args'], [
        'dev.frascella.Mail',
        ['file://$path'],
      ]);
    });

    testWidgets('without the share service there is no Share button', (
      tester,
    ) async {
      service(present: false);
      await pump(tester, files: [png('a.png', 40, 30)]);
      await flush(tester);
      expect(calls, isNotEmpty);
      expect(find.byKey(const ValueKey('share')), findsNothing);
    });

    testWidgets('files of a second launch replace the document shown', (
      tester,
    ) async {
      service(present: false);
      final first = png('first.png', 40, 30);
      final second = png('second.png', 50, 20);
      final c = await pump(tester, files: [first]);
      expect(c.files, [first]);
      expect(SilicaApp.onOpen, isNotNull);
      SilicaApp.onOpen!(['--flag', 'file://$second']);
      await settle(tester, () => c.files.isNotEmpty && c.files.first == second);
      expect(c.files, [second]);
    });
  });
}
