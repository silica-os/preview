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
  /// (silica-desktop issue on the screen size).
  static const Size fallbackScreen = Size(1440, 900);

  /// Where the compositor puts a new document window on the reference (from the left edge and
  /// the top of the screen), and the cascade of the next ones. Silica's compositor places the
  /// windows; Preview cannot (silica-desktop issue on window placement).
  static const Offset windowOrigin = Offset(4, 34);
  static const double windowCascade = 29;

  // --- Toolbar (PREVIEW-01 › Title bar and toolbar; x from the window's left edge) -----------

  /// A toolbar capsule is its segments plus a 1 pt outline on each side (silica_ui); the
  /// segment widths below give the measured outer widths.
  static const double capsuleOutline = 2;

  /// The view menu button: a 57 pt slot from x 92 with a 50 × 38 capsule in it (the sidebar
  /// glyph and a chevron; it opens the view menu).
  static const double viewSlotLeft = 92;
  static const double viewSlot = 57;
  static const double viewButton = 50 - capsuleOutline;

  /// The title block starts at x 164: the name 13 pt bold over a 11 pt secondary line.
  static const double titleLeft = 164;
  static const double titleSize = 13;
  static const double subtitleSize = 11;

  /// The zoom group: zoom out, actual size, zoom in (a 113 × 38 capsule with 1 pt separators;
  /// the segments were read as 38, 36 and 39 with the outline and the separators).
  static const double zoomOutSegment = 37;
  static const double actualSizeSegment = 35;
  static const double zoomInSegment = 37;
  static const double separator = 1;

  /// The highlight group (PDF): the highlight button and its colour menu chevron (76 × 38).
  static const double highlightSegment = 37;
  static const double highlightMenuSegment = 36;

  /// Rotate, a 38 pt circle (the remove background and form filling buttons beside it are not
  /// in Preview).
  static const double rotateSegment = 36;

  /// The markup button, a single circle 40 wide.
  static const double markupButton = 40 - capsuleOutline;

  /// The inspector button, a 38 pt circle (the share button beside it is not in Preview).
  static const double inspectorSegment = 36;

  /// Gaps between the groups, left to right: zoom | highlight | rotate, markup | inspector |
  /// search, and the search field's right margin.
  static const double gapAfterZoom = 6;
  static const double gapAfterHighlight = 7;
  static const double gapAfterTools = 0;
  static const double gapAfterMarkup = 8;
  static const double gapBeforeSearch = 3;
  static const double toolbarTrailing = 7;

  /// The search field fills the rest of the toolbar, at least this wide; narrower, it
  /// collapses into a magnifier circle and the items that do not fit go into the overflow
  /// circle (both 38 × 38).
  static const double searchMinWidth = 273;

  /// The widest search field seen. *Provisional* as a limit.
  static const double searchMaxWidth = 327;
  static const double roundButton = 38 - capsuleOutline;

  /// The title's narrowest width before items move into the overflow menu. *Provisional.*
  static const double titleMinWidth = 80;

  /// The title popover (name, location).
  static const Size titlePopover = Size(502, 150);

  /// The find bar under the toolbar while searching.
  static const double findBarHeight = 36;
  static const Size findDoneButton = Size(50, 26);

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
  static const double sidebarSearchWidth = 199;
  static const double sidebarDivider = 1;

  /// The scroller at the sidebar's right edge: the cells are centred in the rest.
  static const double sidebarScroller = 17;

  /// Thumbnails: a 105 pt wide page image in a 117 pt cell (6 pt inset), a 3 pt gap and the
  /// 16 pt page number under it; 10 pt between cells. The image grows by 155 pt for 180 pt of
  /// sidebar (260 at 340).
  static const double thumbnailImage = 105;
  static const double thumbnailGrowth = 155 / 180;
  static const double thumbnailInset = 6;
  static const double thumbnailLabelGap = 3;
  static const double thumbnailLabel = 16;
  static const double thumbnailGap = 10;
  static const double thumbnailRadius = 8;

  /// The tallest thumbnail for its width (an A4 portrait page fills it).
  static const double thumbnailAspect = 1.42;

  /// Several files in one window: one section per file, 5 pt apart.
  static const double sectionGap = 5;

  /// The width of the thumbnail image for a sidebar `width` wide.
  static double thumbnailWidth(double width) =>
      thumbnailImage + (width - sidebarWidth) * thumbnailGrowth;

  /// Table of contents: the document row 19, entries 40, 12 pt per level, the disclosure at
  /// x 12, the selection inset 10 pt from the sidebar's edges.
  static const double contentsHeader = 19;
  static const double contentsRow = 40;
  static const double contentsIndent = 12;
  static const double contentsDisclosure = 12;
  static const double contentsSelectionInset = 10;
  static const double contentsRadius = 8;

  /// Highlights and notes: the header 19, a highlight row 127, a note row 114, the 3 pt colour
  /// bar.
  static const double notesHeader = 19;
  static const double highlightRow = 127;
  static const double noteRow = 114;
  static const double noteBar = 3;

  /// Bookmarks: the header 30, rows 85 (page caption and three lines of the page's text).
  static const double bookmarksHeader = 30;
  static const double bookmarkRow = 85;

  /// Search results in the sidebar: rows 77 with a 40 × 52 page thumbnail.
  static const double resultRow = 77;
  static const Size resultThumbnail = Size(40, 52);

  /// Contact sheet: a 28 pt section header, cells 152 × 216 holding a 120 × 170 page.
  static const double contactHeader = 28;
  static const Size contactCell = Size(152, 216);
  static const Size contactPage = Size(120, 170);

  // --- Pages and images (PREVIEW-01 › Viewing, PDF display modes) ----------------------------

  /// Continuous scroll: 14 pt from the content edges, 17 pt between pages. The two pages of a
  /// spread touch.
  static const double pageMargin = 14;
  static const double pageGap = 17;

  /// The light page shadow: the gutter darkens over the last 14 pt next to the page.
  static const double pageShadow = 14;

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

  /// Popovers under their buttons.
  static const Size shapesPopover = Size(110, 218);
  static const Size shapeStylePopover = Size(120, 417);
  static const Size colourPopover = Size(270, 300);
  static const Size textStylePopover = Size(289, 138);

  /// The colour adjustment panel and the resize sheet.
  static const Size adjustColourPanel = Size(334, 540);
  static const Size adjustSizeSheet = Size(417, 414);

  /// A note on a PDF page: the 22 pt icon and its popover.
  static const double noteIcon = 22;
  static const Size notePopover = Size(274, 154);

  // --- Files (PREVIEW-02 › PDF features, Files) -----------------------------------------------

  /// The password view in a locked PDF's window: the lock glyph and the field.
  static const Size lockGlyph = Size(58, 45);
  static const Size passwordField = Size(242, 24);

  /// Sheets: export (406 wide, the name field 232 × 26, the location pop-up 200, the quality
  /// slider 182, buttons 81 × 26), permissions, the revert alert.
  static const double exportWidth = 406;
  static const Size exportNameField = Size(232, 26);
  static const double exportWhere = 200;
  static const double exportSlider = 182;
  static const Size exportButton = Size(81, 26);
  static const double exportQuality = 0.85;
  static const Size permissionsSheet = Size(339, 487);
  static const Size revertAlert = Size(292, 170);

  /// The inspector: a 270 pt pane on the right of the window, rows in 250 pt group boxes on a
  /// 37 pt pitch.
  static const double inspectorWidth = 270;
  static const double inspectorGroup = 250;
  static const double inspectorRow = 37;

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

/// The colours, light and dark.
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
    required this.selection,
    required this.selectionInactive,
    required this.contentsInactive,
    required this.pageShadow,
    required this.textSelection,
    required this.match,
    required this.currentMatch,
    required this.placeholder,
    required this.handle,
  });

  /// The toolbar band and the empty window.
  final Color window;

  /// Around an image, behind PDF pages.
  final Color imageCanvas;
  final Color pdfCanvas;

  /// The sidebar's glass over Silica's backdrop, and its divider.
  final Color sidebar;
  final Color sidebarLine;
  final Color text;
  final Color secondary;

  /// The selected thumbnail or entry: the accent while the sidebar has the focus, muted when
  /// the focus is in the page; the table of contents' unfocused selection.
  final Color selection;
  final Color selectionInactive;
  final Color contentsInactive;

  /// The page shadow, blurred over [PreviewMetrics.pageShadow].
  final Color pageShadow;

  /// Selected text, search matches, the current match.
  final Color textSelection;
  final Color match;
  final Color currentMatch;

  /// A page not drawn yet.
  final Color placeholder;

  /// Markup handles.
  final Color handle;

  static const Color accent = Color(0xFF296FFB);

  static const PreviewColors light = PreviewColors(
    window: Color(0xFFFFFFFF),
    imageCanvas: Color(0xFFFFFFFF),
    pdfCanvas: Color(0xFFFCFCFC),
    sidebar: Color(0xFFEEEDEC),
    // Provisional: the divider was not sampled.
    sidebarLine: Color(0xFFD9D9D9),
    text: Color(0xFF262626),
    secondary: Color(0xFF808080),
    selection: accent,
    selectionInactive: Color(0xFF9DA9C4),
    // Provisional: measured in dark only.
    contentsInactive: Color(0xFFDCDCDC),
    // #fcfcfc darkens to #f1f1f1 next to the page.
    pageShadow: Color(0x16000000),
    textSelection: Color(0xFFB8D4FD),
    // Provisional: only the current match was measured.
    match: Color(0x66FFFF3B),
    currentMatch: Color(0xFFFFFF3B),
    placeholder: Color(0xFFFFFFFF),
    handle: Color(0xFF316EC8),
  );

  static const PreviewColors dark = PreviewColors(
    window: Color(0xFF2B2B2B),
    imageCanvas: Color(0xFF2F2D2C),
    pdfCanvas: Color(0xFF2B2927),
    sidebar: Color(0xFF2D2A26),
    // Provisional: the divider was not sampled.
    sidebarLine: Color(0xFF111111),
    text: Color(0xFFE6E6E6),
    secondary: Color(0xFF9A9A9A),
    selection: accent,
    selectionInactive: Color(0xFF3F4B65),
    contentsInactive: Color(0xFF4A4844),
    // Barely visible in dark.
    pageShadow: Color(0x16000000),
    textSelection: Color(0xFFB8D4FD),
    match: Color(0x66FFFF3B),
    currentMatch: Color(0xFFFFFF3B),
    placeholder: Color(0xFFFFFFFF),
    handle: Color(0xFF316EC8),
  );

  static PreviewColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
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
