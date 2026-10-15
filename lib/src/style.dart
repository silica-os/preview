// Preview's measurements and colours. The reference (PREVIEW-01, PREVIEW-02 in
// silica-reference) is not measured yet: every value here is *provisional*, an estimate of the
// reference until the measurements arrive, and `docs/spec/` lists them.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// Sizes and timings. *Provisional* (PREVIEW-01/02 not measured yet).
abstract final class PreviewMetrics {
  /// The window at launch, and the smallest one.
  static const Size initialWindow = Size(900, 700);
  static const Size minWindow = Size(420, 300);

  /// The x where the window buttons end (as the other apps: traffic lights at +18…+64).
  static const double windowButtonsEnd = 80;

  /// Gap between the window buttons and the sidebar button, between toolbar groups, and the
  /// right margin of the toolbar.
  static const double toolbarLeadingGap = 8;
  static const double toolbarGap = 8;
  static const double toolbarTrailing = 10;

  /// The sidebar button: the sidebar glyph and the chevron of its menu.
  static const double sidebarSegment = 38;
  static const double chevronSegment = 22;

  /// The zoom pair's segments and the round buttons.
  static const double zoomSegment = 38;
  static const double roundButton = 38;

  /// The search field when open.
  static const double searchWidth = 200;

  /// Title 15 pt semibold over a 11 pt subtitle, 12 pt after the sidebar button.
  static const double titleSize = 13;
  static const double subtitleSize = 11;
  static const double titleGap = 12;

  /// The sidebar: width, the thumbnails' longest side, the gap between them, the label below.
  static const double sidebarWidth = 168;
  static const double thumbnailSide = 112;
  static const double thumbnailGap = 14;
  static const double thumbnailLabel = 16;
  static const double selectionRadius = 6;
  static const double contentsRow = 24;
  static const double contentsIndent = 14;

  /// The gap around and between PDF pages.
  static const double pageMargin = 12;
  static const double pageGap = 10;

  /// Images fill the window to its edges when fitted.
  static const double imageMargin = 0;

  /// One zoom step (⌘+ / ⌘−), the zoom limits, and the ⌘-scroll sensitivity (points of scroll
  /// for a factor of e).
  static const double zoomStep = 1.25;
  static const double minZoom = 0.05;
  static const double maxZoom = 32;
  static const double scrollZoomPoints = 200;

  /// Rendered pages are kept up to this many bytes; a page is never rendered past this many
  /// pixels per side (deeper zoom shows it enlarged).
  static const int pageCacheBytes = 256 << 20;
  static const int maxPagePixels = 8192;

  /// After a zoom, pages are rendered again at the new scale once it holds this long.
  static const Duration rerenderDelay = Duration(milliseconds: 120);

  /// The inspector panel.
  static const Size inspectorSize = Size(280, 360);
  static const double inspectorLabelWidth = 104;
}

/// The colours, light and dark. *Provisional.*
@immutable
class PreviewColors {
  const PreviewColors({
    required this.window,
    required this.canvas,
    required this.sidebar,
    required this.sidebarLine,
    required this.text,
    required this.secondary,
    required this.selection,
    required this.selectionInactive,
    required this.pageShadow,
    required this.textSelection,
    required this.match,
    required this.currentMatch,
    required this.placeholder,
  });

  /// The toolbar band and the empty window.
  final Color window;

  /// Around the image or the pages.
  final Color canvas;
  final Color sidebar;
  final Color sidebarLine;
  final Color text;
  final Color secondary;

  /// The chosen thumbnail's rounded backdrop, and the same in an inactive window.
  final Color selection;
  final Color selectionInactive;
  final Color pageShadow;

  /// Selected text on a page, search matches and the current match.
  final Color textSelection;
  final Color match;
  final Color currentMatch;

  /// A page not drawn yet.
  final Color placeholder;

  static const PreviewColors light = PreviewColors(
    window: Color(0xFFFFFFFF),
    canvas: Color(0xFFE6E6E6),
    sidebar: Color(0xFFF2F2F2),
    sidebarLine: Color(0xFFD9D9D9),
    text: Color(0xFF262626),
    secondary: Color(0xFF808080),
    selection: Color(0xFFD5D5D5),
    selectionInactive: Color(0xFFDCDCDC),
    pageShadow: Color(0x33000000),
    textSelection: Color(0x663D8CFF),
    match: Color(0x66FFD60A),
    currentMatch: Color(0xAAFF9F0A),
    placeholder: Color(0xFFFFFFFF),
  );

  static const PreviewColors dark = PreviewColors(
    window: Color(0xFF2B2B2B),
    canvas: Color(0xFF1E1E1E),
    sidebar: Color(0xFF262626),
    sidebarLine: Color(0xFF111111),
    text: Color(0xFFE6E6E6),
    secondary: Color(0xFF9A9A9A),
    selection: Color(0xFF464646),
    selectionInactive: Color(0xFF3A3A3A),
    pageShadow: Color(0x66000000),
    textSelection: Color(0x663D8CFF),
    match: Color(0x66FFD60A),
    currentMatch: Color(0xAAFF9F0A),
    placeholder: Color(0xFFFFFFFF),
  );

  static PreviewColors of(BuildContext context) =>
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
      ? dark
      : light;
}

/// Inter at `size`, in `color`.
TextStyle previewText(
  double size, {
  required Color color,
  FontWeight weight = FontWeight.w400,
}) => uiText(size: size, color: color).copyWith(fontWeight: weight);
