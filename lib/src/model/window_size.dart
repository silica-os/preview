// The size a window takes for a newly opened document (PREVIEW-01 › Default window size):
//
// - an image that fits opens at 100 %: as wide as the image, as tall as the image plus the
//   toolbar and 26 pt above and below it (a small image counts as 708 × 224);
// - a larger image opens fitted into the tallest window (its bottom 40 pt above the screen's
//   edge), as wide as the fitted image plus 8 pt bands at its sides;
// - a PDF opens as tall as the screen allows, as wide as the sidebar and its widest page at
//   actual size with the page margins, fitted to that width;
// - several images open with the sidebar, the content as for one image;
// - never below the smallest window, never beyond the screen.

import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:silica_ui/silica_ui.dart' show toolbarHeight;

import '../style.dart';

/// The room for a window on a `screen`: the reference's placement (4 pt from the left, 4 pt
/// under the menu bar, y 34) and the free bottom taken away (1366 pt on a 1440 pt screen).
Size windowRoom(Size screen) => Size(
  math.max(0, screen.width - 2 * PreviewMetrics.windowOrigin.dx),
  math.max(
    0,
    screen.height -
        PreviewMetrics.windowOrigin.dy -
        PreviewMetrics.screenBottomGap,
  ),
);

/// The window for one image (or the current one of several) of `image` points, with a sidebar
/// `sidebar` wide, on a screen leaving `room` (see [windowRoom]).
Size imageWindowSize(Size image, {double sidebar = 0, required Size room}) {
  final chrome = toolbarHeight + 2 * PreviewMetrics.imageInset;
  // A small image counts as large as the smallest window: 200 × 150 opens 708 × 328, and the
  // content beside a sidebar is at least 708 wide (400 × 300 with the sidebar: 868 × 404).
  var size = Size(
    math.max(image.width, PreviewMetrics.minWindow.width) + sidebar,
    math.max(image.height, PreviewMetrics.minWindow.height) + chrome,
  );
  if (size.width > room.width || size.height > room.height) {
    // Fitted: as tall as possible, the image filling the content height.
    final content = room.height - toolbarHeight;
    var scale = content / image.height;
    final band = 2 * PreviewMetrics.fittedSideBand;
    if (image.width * scale + band + sidebar > room.width) {
      scale = (room.width - band - sidebar) / image.width;
    }
    size = Size(
      image.width * scale + band + sidebar,
      math.min(room.height, image.height * scale + toolbarHeight),
    );
  }
  return _limit(size, room);
}

/// The window for a PDF whose widest page is `pageWidth` points, shown at `actualScale`
/// pixels per point, with the sidebar `sidebar` wide.
Size pdfWindowSize(
  double pageWidth, {
  required double actualScale,
  double sidebar = PreviewMetrics.sidebarWidth,
  required Size room,
}) => _limit(
  Size(
    sidebar + 2 * PreviewMetrics.pageMargin + pageWidth * actualScale,
    room.height,
  ),
  room,
);

Size _limit(Size size, Size room) => Size(
  math.max(
    PreviewMetrics.minWindow.width,
    math.min(size.width, math.max(room.width, PreviewMetrics.minWindow.width)),
  ),
  math.max(
    PreviewMetrics.minWindow.height,
    math.min(
      size.height,
      math.max(room.height, PreviewMetrics.minWindow.height),
    ),
  ),
);
