// Preview's measurements and colours, from PREVIEW-01 and PREVIEW-02 (silica-reference #101,
// #102, measured 2026-10-15 on the reference at 1×, dark and light). A value that was not
// measured is marked *provisional*; `docs/spec/` lists both kinds.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// Sizes and timings (points at 1×).
abstract final class PreviewMetrics {
  // --- Window (PREVIEW-01 › Windows and chrome) ----------------------------------------------

  /// The smallest window, for images and PDFs alike.
  static const Size minWindow = Size(708, 224);

  /// The window before a document decides its size (the Open dialog, an empty window): the
  /// smallest window's width, a little taller. *Provisional* (no empty window on the reference).
  static const Size initialWindow = Size(708, 500);

  /// An image that fits opens at 100 %: the window is the image's width and the image's height
  /// plus the toolbar and this much above and below it.
  static const double imageInset = 26;

  /// A larger image opens fitted in the tallest window, which keeps this much free under it,
  /// with these bands at the sides of the fitted image.
  static const double screenBottomGap = 40;
  static const double fittedSideBand = 8;

  /// The screen assumed when neither Flutter nor the embedder tells its size (the embedder
  /// reports no display to Flutter yet): a common laptop's logical size. *Provisional*
  /// (silica-desktop#171).
  static const Size fallbackScreen = Size(1440, 900);

  /// Where the compositor puts a new document window on the reference (from the left edge and
  /// the top of the screen), and the cascade of the next ones. Silica's compositor places the
  /// windows; Preview cannot (silica-desktop#172).
  static const Offset windowOrigin = Offset(4, 34);
  static const double windowCascade = 29;

  // --- Toolbar (kit `Apps/Preview/Toolbar *`; the pieces' widths with 4 pt of padding) --------

  /// The view piece (two 32 pt segments), the zoom piece (three), the highlight piece (two) and
  /// a one-button piece, and the search piece (a 200 pt field).
  static const double viewPiece = 72;
  static const double zoomPiece = 104;
  static const double highlightPiece = 72;
  static const double buttonPiece = 40;
  static const double searchPiece = 208;

  /// The title's narrowest width before items move into the overflow menu. *Provisional.*
  static const double titleMinWidth = 80;

  /// The title popover (name, location).
  static const Size titlePopover = Size(400, 96);

  /// The find bar under the toolbar while searching (kit `Page search`: 36).
  static const double findBarHeight = 36;

  /// The markup toolbar under the toolbar (shown and hidden at once, no animation). The first
  /// time it shows over an image shown whole, the window grows by 31 pt.
  static const double markupBarHeight = 36;
  static const double markupGrowth = 31;

  // --- Sidebar (PREVIEW-01 › Sidebar) ---------------------------------------------------------

  /// Width: 160 by default, resizable from 160 to 400, a 1 pt divider; 199 while it shows the
  /// search results.
  static const double sidebarWidth = 160;
  static const double sidebarMinWidth = 160;
  static const double sidebarMaxWidth = 400;
  static const double sidebarSearchWidth = 200;
  static const double sidebarDivider = 1;

  /// Thumbnails (kit `Sidebar Thumbnails`, `Sidebar Images`): a cell 144 wide (8 from the
  /// sidebar's edges) holding a 104 pt wide page (a 120 pt wide image) 20 (12) from its sides and
  /// 8 from its top, the 14 pt label 2 under it and 4 below that; 8 between cells. The image
  /// grows by 155 pt for 180 pt of sidebar (measured: 260 at 340).
  static const double thumbnailImage = 104;
  static const double thumbnailPhoto = 120;
  static const double thumbnailGrowth = 155 / 180;
  static const double thumbnailInset = 8;
  static const double thumbnailLabelGap = 2;
  static const double thumbnailLabel = 14;
  static const double thumbnailLabelBottom = 4;
  static const double thumbnailGap = 8;
  static const double thumbnailRadius = 10;
  static const double thumbnailCellMargin = 8;

  /// The tallest thumbnail for its width (an A4 portrait page fills it).
  static const double thumbnailAspect = 1.42;

  /// Several files in one window: one section per file.
  static const double sectionGap = 8;

  /// The width of the thumbnail image for a sidebar `width` wide.
  static double thumbnailWidth(double width, {bool photo = false}) =>
      (photo ? thumbnailPhoto : thumbnailImage) +
      (width - sidebarWidth) * thumbnailGrowth;

  /// Table of contents (kit `Sidebar Contents`): the document's name (Headline) 8 from the top,
  /// entries on a 40 pt pitch from 36, the chosen one on a 32 pt capsule inset 8 (radius 8),
  /// the disclosure (12) at 6 from the capsule and the title 10 after it, 12 per level.
  static const double contentsHeader = 36;
  static const double contentsRow = 40;
  static const double contentsCapsule = 32;
  static const double contentsIndent = 12;
  static const double contentsDisclosure = 12;
  static const double contentsSelectionInset = 8;
  static const double contentsRadius = 8;

  /// Highlights and notes: the header, a highlight row 80 and a note row 72, the 3 pt colour
  /// bar.
  static const double notesHeader = 36;
  static const double highlightRow = 80;
  static const double noteRow = 72;
  static const double noteBar = 3;

  /// Bookmarks: the header, rows of 80 (page caption and three lines of the page's text).
  static const double bookmarksHeader = 36;
  static const double bookmarkRow = 80;

  /// Search results in the sidebar (kit `Sidebar Search`): rows 72 on a 76 pitch with a
  /// 40 × 56 page thumbnail at 8; the text at 56 from the capsule.
  static const double resultRow = 72;
  static const double resultGap = 4;
  static const Size resultThumbnail = Size(40, 56);

  /// Contact sheet (kit `Apps/Preview/Contact Sheet`): a 28 pt header, cells of 152 × 216 on a
  /// 164 × 232 pitch (24 from the left, 12 below the header) holding a 120 × 172 page 16 in and
  /// 12 down; the number at 192 (left aligned), the chosen cell's pill (28 × 20) at 188.
  static const double contactHeader = 28;
  static const Size contactCell = Size(152, 216);
  static const Size contactPage = Size(120, 172);
  static const double contactPadding = 24;
  static const double contactGap = 12;
  static const double contactRowGap = 16;
  static const double contactFirstRow = 12;
  static const double contactPageLeft = 16;
  static const double contactPageTop = 12;
  static const double contactNumberTop = 192;
  static const double contactPillTop = 188;

  // --- Pages and images (PREVIEW-01 › Viewing, PDF display modes) ----------------------------

  /// Continuous scroll: 14 pt from the content edges, 17 pt between pages. The two pages of a
  /// spread touch.
  static const double pageMargin = 14;
  static const double pageGap = 17;

  /// The page shadow (`Apps/Preview/Page`): offset (0, 2), blur 8.
  static const double pageShadow = 8;

  /// Images fill the content area when fitted.
  static const double imageMargin = 0;

  /// The zoom steps, as a fraction of actual size (a PDF's actual size is its physical size on
  /// the display). The first and last are the limits.
  static const List<double> zoomSteps = [
    0.05, 0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.75, 1, 1.5, 2, 3, 4, 6, 8, //
    10, 15, 20, 30,
  ];
  static const double minZoom = 0.05;
  static const double maxZoom = 30;

  /// Points per inch of a PDF page.
  static const double pdfPointsPerInch = 72;

  /// The ⌘-scroll sensitivity: points of scroll for a factor of e. *Provisional* (pinch and
  /// smart zoom were not measured).
  static const double scrollZoomPoints = 200;

  /// Rendered pages are kept up to this many bytes; a page is never rendered past this many
  /// pixels per side (deeper zoom shows it enlarged).
  static const int pageCacheBytes = 256 << 20;
  static const int maxPagePixels = 8192;

  // --- Slideshow (PREVIEW-01 › Slideshow) -----------------------------------------------------

  /// The control HUD: 287 × 74, 32 pt from the bottom, radius 8, four 61 × 52 buttons.
  static const Size slideshowHud = Size(287, 74);
  static const double slideshowHudBottom = 32;
  static const double slideshowHudRadius = 8;
  static const Size slideshowButton = Size(61, 52);

  // --- Markup (PREVIEW-02 › Markup) -----------------------------------------------------------

  /// Selection handles: 10 pt circles with a 1 pt white ring.
  static const double handle = 10;

  /// Popovers under their buttons: the body is the content with the popover's 16 pt padding
  /// (the shapes in two columns of 28, 12 apart; the colour grid of 12 × 18 cells; the style
  /// rows 24 tall).
  static const Size shapesPopover = Size(100, 180);
  static const Size shapeStylePopover = Size(152, 380);
  static const Size colourPopover = Size(270, 258);
  static const Size textStylePopover = Size(289, 112);

  /// The colour adjustment panel and the resize sheet.
  static const Size adjustColourPanel = Size(334, 540);
  static const Size adjustSizeSheet = Size(417, 414);

  /// A note on a PDF page: the 22 pt icon and its popover.
  static const double noteIcon = 22;
  static const Size notePopover = Size(272, 152);

  // --- Files (PREVIEW-02 › PDF features, Files) -----------------------------------------------

  /// The password view in a locked PDF's window (kit `Apps/Preview/Password`): the lock glyph
  /// and the field.
  static const double lockGlyph = 32;
  static const double passwordField = 244;

  /// Sheets (the kit's `Export`, `Permissions` and `Adjust Size` cards on the 4 pt grid, 24 pt
  /// of padding): export, permissions, adjust size and the one-field sheet are this wide.
  static const double exportWidth = 408;
  static const double exportWhere = 200;
  static const double exportSlider = 200;
  static const double exportQuality = 0.85;
  static const double permissionsWidth = 340;
  static const double adjustSizeWidth = 416;
  static const double fieldSheetWidth = 360;
  static const Size revertAlert = Size(280, 170);

  /// The inspector (`Apps/Preview/Inspector`): a 260 pt pane (`components.md`; the kit's window
  /// master draws 268) with 8 pt of padding (the kit's), rows 36 pt apart in group boxes of
  /// radius 10, 8 between boxes.
  static const double inspectorWidth = 260;
  static const double inspectorPadding = 8;
  static const double inspectorRow = 36;
  static const double inspectorGroupRadius = 10;
  static const double inspectorGap = 8;

  // --- Motion ---------------------------------------------------------------------------------

  /// A zoom step (menu, keys, toolbar), and the toolbar's actual size button.
  static const Duration zoomAnimation = Duration(milliseconds: 200);
  static const Duration actualSizeAnimation = Duration(milliseconds: 95);

  /// The sidebar slides out in 220 ms and back in 250 ms.
  static const Duration sidebarHide = Duration(milliseconds: 220);
  static const Duration sidebarShow = Duration(milliseconds: 250);

  /// Rotate and flip on an image.
  static const Duration rotateAnimation = Duration(milliseconds: 220);
  static const Duration flipAnimation = Duration(milliseconds: 185);

  /// The slideshow turns a page about every 5 s, with a dissolve (its length *provisional*).
  static const Duration slideshowInterval = Duration(seconds: 5);
  static const Duration slideshowDissolve = Duration(milliseconds: 500);

  /// After a zoom, pages are rendered again at the new scale once it holds this long.
  static const Duration rerenderDelay = Duration(milliseconds: 120);
}

/// The colours of the window, from the Amalfi tokens (`AmalfiColors`) and the Preview palette
/// (`App/Preview/*`), light and dark.
@immutable
class PreviewColors {
  const PreviewColors({
    required this.window,
    required this.imageCanvas,
    required this.pdfCanvas,
    required this.sidebar,
    required this.sidebarLine,
    required this.text,
    required this.secondary,
    required this.tertiary,
    required this.onAccent,
    required this.selection,
    required this.selectionInactive,
    required this.contentsInactive,
    required this.pageShadow,
    required this.pageBorder,
    required this.textSelection,
    required this.match,
    required this.currentMatch,
    required this.placeholder,
    required this.handle,
    required this.ink,
    required this.inkStrong,
    required this.dark,
  });

  /// The colours of [theme] (the Preview palette when the theme has none).
  factory PreviewColors.from(AmalfiThemeData theme) {
    final c = theme.colors;
    final app = theme.appColors is AmalfiPreviewColors
        ? theme.appColors! as AmalfiPreviewColors
        : (theme.isDark ? AmalfiPreviewColors.dark : AmalfiPreviewColors.light);
    return PreviewColors(
      window: c.surfaceWindow,
      imageCanvas: app.canvas,
      pdfCanvas: app.pagesBehind,
      sidebar: c.surfaceSidebar,
      sidebarLine: c.lineSeparator,
      text: c.textPrimary,
      secondary: c.textSecondary,
      tertiary: c.textTertiary,
      onAccent: c.textOnAccent,
      selection: c.accentAmalfi,
      // The chosen cell while the sidebar is not focused: a neutral capsule (the kit's
      // contact sheet draws the chosen page on a grey one).
      selectionInactive: c.surfaceControlPressed,
      contentsInactive: c.surfaceControlPressed,
      // `Apps/Preview/Page`: 0, 2, blur 8 (the shadow's blur is the CSS one).
      pageShadow: theme.isDark
          ? const Color(0x52000000)
          : const Color(0x1F000000),
      pageBorder: c.lineBorder,
      textSelection: c.accentAmalfi.withValues(alpha: 0.3),
      match: app.match.withValues(alpha: 0.6),
      currentMatch: app.match,
      placeholder: app.paper,
      handle: app.handle,
      ink: app.ink,
      inkStrong: app.inkStrong,
      dark: theme.isDark,
    );
  }

  /// The toolbar band and the empty window (`Surface/Window`).
  final Color window;

  /// Around an image, behind PDF pages (`App/Preview/Canvas`, `Pages Behind`).
  final Color imageCanvas;
  final Color pdfCanvas;

  /// The sidebar and the inspector (`Surface/Sidebar`), and their 1 pt edge.
  final Color sidebar;
  final Color sidebarLine;
  final Color text;
  final Color secondary;
  final Color tertiary;
  final Color onAccent;

  /// The chosen thumbnail or entry: the accent; neutral when the focus is in the page.
  final Color selection;
  final Color selectionInactive;
  final Color contentsInactive;

  /// The page shadow (blur 8, offset 2) and its 1 pt border.
  final Color pageShadow;
  final Color pageBorder;

  /// Selected text, search matches, the current match.
  final Color textSelection;
  final Color match;
  final Color currentMatch;

  /// A page not drawn yet (`App/Preview/Paper`).
  final Color placeholder;

  /// Markup handles.
  final Color handle;

  /// The ink of a page's text lines in the kit (`Ink`, `Ink Strong`): placeholders of
  /// thumbnails not rendered yet.
  final Color ink;
  final Color inkStrong;

  /// Whether this is the dark appearance.
  final bool dark;

  /// The colours in effect under [context].
  static PreviewColors of(BuildContext context) =>
      PreviewColors.from(AmalfiTheme.of(context));
}

/// The highlight colours of the toolbar's menu. Yellow is the measured colour on white paper;
/// the others are *provisional*.
enum HighlightColour {
  yellow(Color(0xFFF5D164)),
  green(Color(0xFF8FD16E)),
  blue(Color(0xFF7DB8F2)),
  pink(Color(0xFFF29CC3)),
  purple(Color(0xFFC39CF2));

  const HighlightColour(this.color);
  final Color color;
}

/// Inter at `size`, in `color`.
TextStyle previewText(
  double size, {
  required Color color,
  FontWeight weight = FontWeight.w400,
}) => uiText(size: size, color: color).copyWith(fontWeight: weight);
