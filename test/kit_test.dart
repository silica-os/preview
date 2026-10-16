// The window against the masters of the Amalfi kit page `App · Preview` (silica-design,
// `kit/symbols/Apps/Preview/*`): the frames are those of the JSON, in whole points, in a
// 1040 × 680 window (the kit's window master). The window's right padding is the user's 16
// (components.md), not the kit's 8, so the toolbar's right side is 8 pt to the left of the
// master's. Tests never read silica-design: the numbers are copied here with their source.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:preview/src/model/document.dart';
import 'package:preview/src/model/viewer.dart';
import 'package:preview/src/pdf/backend.dart';
import 'package:preview/src/portal.dart';
import 'package:preview/src/style.dart';
import 'package:preview/src/ui/app.dart';
import 'package:preview/src/ui/pdf_view.dart' show PageThumbnail;
import 'package:silica_ui/silica_ui.dart';

import 'support/fake_pdf.dart';
import 'support/samples.dart';

class _Dialogs implements FileDialogs {
  @override
  Future<List<String>?> open({
    required String title,
    bool multiple = true,
  }) async => null;
  @override
  Future<String?> save({required String title, required String name}) async =>
      null;
}

void main() {
  late FakePdfBackend backend;
  late Directory dir;
  ViewerController? controller;

  setUp(() {
    backend = FakePdfBackend({});
    dir = tempDir(addTearDown);
    controller = null;
  });

  Future<ViewerController> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(1040, 680);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      PreviewApp(
        loader: DocumentLoader(pdf: backend, writer: FakePdfWriter()),
        dialogs: _Dialogs(),
        locale: const Locale('en'),
        onController: (c) => controller = c,
        screenSize: (_) async => const Size(2560, 1440),
      ),
    );
    await tester.pump();
    return controller!;
  }

  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'did not settle');
    await tester.pump(const Duration(seconds: 1));
  }

  /// A PDF of `n` pages of 208 × 296 pt: its thumbnails are the kit's 104 × 148.
  String pdf(String name, int n, {bool outline = false}) {
    final path = write(dir, name, '%PDF-1.4\n'.codeUnits);
    backend.files[path] = FakePdf(
      [
        for (var i = 0; i < n; i++)
          FakePage(
            size: const Size(208, 296),
            lines: ['Page ${i + 1}', 'Whisk the zest into the eggs'],
          ),
      ],
      outline: outline
          ? const [
              PdfOutlineItem('Introduction', 0),
              PdfOutlineItem('Ingredients', 1),
              PdfOutlineItem('Method', 2),
            ]
          : const [],
    );
    return path;
  }

  String png(String name) => write(dir, name, img.encodePng(halves(560, 420)));

  Rect at(WidgetTester tester, Finder finder) => tester.getRect(finder);
  Rect key(WidgetTester tester, String k) =>
      at(tester, find.byKey(ValueKey(k)));

  group('palette (App/Preview/* in tokens.json)', () {
    test('light', () {
      final c = PreviewColors.from(const AmalfiThemeData.light(app: 'Preview'));
      expect(c.imageCanvas, const Color(0xFFFFFFFF));
      expect(c.pdfCanvas, const Color(0xFFF3F0EA));
      expect(c.placeholder, const Color(0xFFFFFFFF));
      expect(c.handle, const Color(0xFF316EC8));
      expect(c.currentMatch, const Color(0xFFFFFF3B));
      expect(c.ink, const Color(0xFFD3CDC4));
      expect(c.inkStrong, const Color(0xFF8F887D));
      expect(c.pageShadow, const Color(0x1F000000));
      expect(HighlightColour.yellow.color, const Color(0xFFF5D164));
    });

    test('dark', () {
      final c = PreviewColors.from(const AmalfiThemeData.dark(app: 'Preview'));
      expect(c.imageCanvas, const Color(0xFF2F2D2C));
      expect(c.pdfCanvas, const Color(0xFF2B2927));
      expect(
        c.placeholder,
        const Color(0xFFFFFFFF),
        reason: 'paper stays white',
      );
      expect(c.pageShadow, const Color(0x52000000));
      expect(c.dark, isTrue);
    });
  });

  testWidgets('Toolbar PDF: 52 tall, the pieces in order and in size', (
    tester,
  ) async {
    final c = await pump(tester);
    c.open([pdf('Lemon recipes.pdf', 12)]);
    await settle(tester, () => c.document != null);
    expect(key(tester, 'toolbar'), const Rect.fromLTWH(0, 0, 1040, 52));
    // Piece View [96,0 72×52]: its capsule at [4,10 64×32] (two 32 segments).
    expect(
      key(tester, 'view menu button'),
      const Rect.fromLTWH(100, 10, 64, 32),
    );
    // Right side, from the window's right edge less 16: Search piece 208 (field 200 × 32),
    // Inspector, Markup, Rotate 40 (a 32 circle), Highlight 72 (64), Zoom 104 (96).
    expect(key(tester, 'search field'), const Rect.fromLTWH(820, 10, 200, 32));
    expect(
      key(tester, 'inspector button'),
      const Rect.fromLTWH(780, 10, 32, 32),
    );
    expect(key(tester, 'markup'), const Rect.fromLTWH(740, 10, 32, 32));
    expect(key(tester, 'rotate'), const Rect.fromLTWH(700, 10, 32, 32));
    expect(key(tester, 'highlight'), const Rect.fromLTWH(628, 10, 64, 32));
    expect(key(tester, 'zoom'), const Rect.fromLTWH(524, 10, 96, 32));
    // `Piece/Title + Subtitle` [168,0 …×52]: it starts where the view piece ends.
    expect(tester.getTopLeft(find.byType(AmalfiTitlePiece)).dx, 168);
  });

  testWidgets('Toolbar Image: no highlight, the view piece for one image', (
    tester,
  ) async {
    final c = await pump(tester);
    c.open([png('Positano.jpg.png')]);
    await settle(tester, () => c.document != null);
    final highlight = tester.widget<AmalfiActionSegments>(
      find.byKey(const ValueKey('highlight')),
    );
    // `Piece/Preview Highlight Off`: the capsule is there, disabled.
    expect(highlight.onPressed, isNull);
    expect(key(tester, 'highlight').size, const Size(64, 32));
  });

  testWidgets('PDF Thumbnails: 160 wide, cells 144 on a 184 pitch', (
    tester,
  ) async {
    final c = await pump(tester);
    c.open([pdf('Lemon recipes.pdf', 12)]);
    await settle(tester, () => c.document != null);
    c.setSidebar(SidebarMode.thumbnails);
    c.goTo(1);
    await tester.pump(const Duration(seconds: 1));
    // Window 1040 × 680: the sidebar [0,52 160×628]; the content [160,52 880×628].
    expect(key(tester, 'sidebar'), const Rect.fromLTWH(0, 52, 160, 628));
    // The page 2 cell (`Current page` [8,192 144×176] in the sidebar's frame, 52 lower here).
    final chosen = key(tester, 'chosen thumbnail');
    expect(chosen, const Rect.fromLTWH(8, 52 + 192, 144, 176));
    // Page 1's thumbnail [28,16 104×148]: 20 in from the cell, 8 down.
    final first = at(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('thumbnail 0')),
        matching: find.byType(PageThumbnail),
      ),
    );
    expect(first, const Rect.fromLTWH(28, 52 + 16, 104, 148));
    // Pitch 184.
    expect(
      key(tester, 'thumbnail 1').top - key(tester, 'thumbnail 0').top,
      184,
    );
  });

  testWidgets('PDF Contents: the name, entries on a 40 pt pitch, 32 pt capsule', (
    tester,
  ) async {
    final c = await pump(tester);
    c.open([pdf('Lemon recipes.pdf', 12, outline: true)]);
    await settle(tester, () => c.document != null);
    c.setSidebar(SidebarMode.contents);
    await tester.pump(const Duration(seconds: 1));
    expect(key(tester, 'sidebar').width, 160);
    // `Document name` [12,8 136×18], entry 1 text at [36,43 112×18] (disclosure at 14).
    final name = find.text('Lemon recipes.pdf').last;
    expect(tester.getTopLeft(name), const Offset(12, 52 + 8));
    final first = key(tester, 'contents 0');
    final second = key(tester, 'contents 1');
    expect(second.top - first.top, 40);
    expect(
      first.top,
      52 + 36 - 4,
      reason: 'the 40 pt row holds the 32 pt capsule',
    );
    expect(first.left, 0);
  });

  testWidgets(
    'PDF Search: 200 wide sidebar, rows of 72 on a 76 pitch, the find bar',
    (tester) async {
      final c = await pump(tester);
      c.open([pdf('Lemon recipes.pdf', 12)]);
      await settle(tester, () => c.document != null);
      c.setSidebar(SidebarMode.thumbnails);
      await tester.tap(find.byKey(const ValueKey('search field')));
      await tester.enterText(
        find.byKey(const ValueKey('search field')),
        'zest',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester, () => c.searchDone);
      // `Sidebar Search` [0,52 200×628], the find bar [200,52 840×36] and its 1 pt separator.
      expect(key(tester, 'sidebar'), const Rect.fromLTWH(0, 52, 200, 628));
      expect(key(tester, 'find bar'), const Rect.fromLTWH(200, 52, 840, 36));
      // 72 pt rows with 4 pt between them (the hit area includes the gap).
      expect(key(tester, 'result 0').size.height, 72 + 4);
      expect(key(tester, 'result 1').top - key(tester, 'result 0').top, 76);
      // Done: a small push button, 24 tall; previous and next: a 48 × 24 capsule.
      expect(key(tester, 'find done').height, 24);
      expect(key(tester, 'find previous next').size, const Size(48, 24));
    },
  );

  testWidgets('Inspector: 260 wide, four tabs, groups with rows of 36', (
    tester,
  ) async {
    final c = await pump(tester);
    c.open([png('Positano.jpg.png')]);
    await settle(tester, () => c.document != null);
    c.toggleInspector();
    await tester.pump(const Duration(seconds: 1));
    final inspector = key(tester, 'inspector');
    expect(inspector, const Rect.fromLTWH(780, 52, 260, 628));
    // `Inspector tabs` (One 4 Icon Large): 136 × 32, centred, 8 from the top.
    final tabs = key(tester, 'inspector tabs');
    expect(tabs.size, const Size(136, 32));
    expect(tabs.center.dx, closeTo(inspector.center.dx, 1));
    expect(tabs.top, 52 + PreviewMetrics.inspectorPadding);
  });

  testWidgets('Image Markup: the 36 pt strip with its 1 pt separator', (
    tester,
  ) async {
    final c = await pump(tester);
    c.open([png('Positano.jpg.png')]);
    await settle(tester, () => c.document != null);
    await tester.tap(find.byKey(const ValueKey('markup')));
    await tester.pump(const Duration(seconds: 1));
    // `Markup strip` [0,52 1040×36], `Separator` [0,88 1040×1]; the buttons are 24 tall
    // (`Segments/Action/Icon 2/Small`: 48 × 24 at y 58).
    expect(key(tester, 'markup bar'), const Rect.fromLTWH(0, 52, 1040, 36));
    final shapes = key(tester, 'markup shapes');
    expect(shapes.size, const Size(48, 24));
    expect(shapes.top, 58);
    expect(key(tester, 'markup shape style').size, const Size(48, 24));
    // The content starts under the separator (the kit's photo is at y 192 in a taller area).
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('markup bar'))).dy + 36 + 1,
      89,
    );
  });

  testWidgets(
    'Contact Sheet: header 28, cells 152 × 216 on a 164 × 232 pitch',
    (tester) async {
      final c = await pump(tester);
      c.open([pdf('Lemon recipes.pdf', 12)]);
      await settle(tester, () => c.document != null);
      c.setSidebar(SidebarMode.contactSheet);
      c.goTo(1);
      // The sidebar slides out (no sidebar beside the sheet).
      await tester.pumpAndSettle();
      expect(
        key(tester, 'contact header'),
        const Rect.fromLTWH(0, 52, 1040, 28),
      );
      // `Chosen cell` [188,92 152×216].
      expect(key(tester, 'contact 1'), const Rect.fromLTWH(188, 92, 152, 216));
      expect(key(tester, 'contact 0').left, 24);
      expect(key(tester, 'contact 6').top - key(tester, 'contact 0').top, 232);
      // Six columns fit 1040: `Page 7` is on the second row.
      expect(key(tester, 'contact 6').left, 24);
    },
  );

  testWidgets('Locked PDF: the lock, the lines and a 244 × 28 secure field', (
    tester,
  ) async {
    final c = await pump(tester);
    final path = write(dir, 'Locked.pdf', '%PDF-1.4\n'.codeUnits);
    backend.files[path] = FakePdf([const FakePage()], password: 'pw');
    c.open([path]);
    await settle(tester, () => c.passwordFor != null);
    expect(
      key(tester, 'password field').size,
      const Size(PreviewMetrics.passwordField, 28),
    );
    // Centred in the content: the master's field is [458,0 244×28] in a 1040 window.
    expect(key(tester, 'password field').center.dx, closeTo(520, 1));
  });

  testWidgets('Empty window: the prompt and a primary Open button', (
    tester,
  ) async {
    await pump(tester);
    final open = key(tester, 'empty open');
    expect(open.height, 28);
    expect(open.center.dx, closeTo(520, 1));
    expect(key(tester, 'toolbar').height, 52);
  });

  testWidgets('light and dark: the window is Surface/Window', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await pump(tester, brightness: brightness);
      final colors = AmalfiColors.of(brightness);
      final window = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(AmalfiWindow),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(window.color, colors.surfaceWindow);
    }
  });
}
