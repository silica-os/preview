// A PDF in the window: the pages in a continuous column (built lazily, only the pages near the
// view are rendered), or one page, or two pages side by side. Dragging over a page selects its
// text; search matches are highlighted, the current one stronger.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../model/viewer.dart';
import '../pdf/text.dart';
import '../style.dart';
import 'zoom_view.dart';

class PdfView extends StatelessWidget {
  const PdfView({super.key, required this.controller});
  final ViewerController controller;

  @override
  Widget build(BuildContext context) {
    final pdf = controller.pdf;
    final pages = controller.pages;
    if (pdf == null || pages == null) return const SizedBox.expand();
    return ListenableBuilder(
      listenable: pages,
      builder: (context, _) {
        final scale = controller.scale;
        if (controller.layout == PageLayout.continuous) {
          return ZoomScroller(
            controller: controller,
            vertical: true,
            builder: (context, view) =>
                NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.depth == 0 && n is ScrollUpdateNotification) {
                      controller.scrolled();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    key: const ValueKey('pages'),
                    controller: controller.vertical,
                    itemCount: pdf.pageCount,
                    itemBuilder: (context, i) {
                      final size = pdf.pageSize(i);
                      final lastPage = i == pdf.pageCount - 1;
                      return Padding(
                        padding: EdgeInsets.only(
                          top: i == 0 ? controller.margin : 0,
                          bottom: lastPage
                              ? controller.margin
                              : PreviewMetrics.pageGap,
                        ),
                        child: Center(
                          child: PageTile(
                            key: ValueKey('page $i'),
                            controller: controller,
                            page: i,
                            size: size * scale,
                          ),
                        ),
                      );
                    },
                  ),
                ),
          );
        }
        final spread = controller.spreadPages(controller.current);
        return ZoomScroller(
          controller: controller,
          builder: (context, view) => Padding(
            padding: EdgeInsets.all(controller.margin),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final (k, page) in spread.indexed) ...[
                  if (k > 0) const SizedBox(width: PreviewMetrics.pageGap),
                  PageTile(
                    key: ValueKey('page $page'),
                    controller: controller,
                    page: page,
                    size: pdf.pageSize(page) * scale,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One page at its size on screen: the rendered bitmap (white until it arrives), the
/// highlights, and text selection by dragging.
class PageTile extends StatefulWidget {
  const PageTile({
    super.key,
    required this.controller,
    required this.page,
    required this.size,
  });

  final ViewerController controller;
  final int page;

  /// On screen, rotation included.
  final Size size;

  @override
  State<PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<PageTile> {
  int? _anchor;

  ViewerController get c => widget.controller;

  /// A point of the tile in page points (unrotated).
  Offset _pagePoint(Offset local) {
    final own = c.pdf!.handle.pageSizes[widget.page];
    final turned = c.pdf!.pageSize(widget.page);
    final scale = turned.width == 0 ? 1.0 : widget.size.width / turned.width;
    return unturnPoint(local / scale, own, c.pdf!.quarterTurns);
  }

  int? _index(Offset local, {bool end = false}) {
    final layout = c.textOf(widget.page);
    if (layout == null) return null;
    final hit = charAt(layout, _pagePoint(local));
    if (hit == null) return null;
    final (i, after) = hit;
    return end && after ? i + 1 : i;
  }

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    final pdf = c.pdf!;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final own = pdf.handle.pageSizes[widget.page];
    final turned = pdf.pageSize(widget.page);
    final scale = turned.width == 0 ? 1.0 : widget.size.width / turned.width;
    final image = c.pages?.image(widget.page, scale * dpr);
    final layout = c.textOf(widget.page);
    final turns = pdf.quarterTurns;
    final highlights = <(Rect, Color)>[];
    if (layout != null) {
      for (final (i, m) in c.matches.indexed) {
        if (m.page != widget.page) continue;
        final color = i == c.matchIndex ? colors.currentMatch : colors.match;
        for (final r in rangeRects(layout, m.start, m.end)) {
          highlights.add((turnRect(r, own, turns), color));
        }
      }
      for (final s in c.selection) {
        if (s.page != widget.page) continue;
        for (final r in rangeRects(layout, s.start, s.end)) {
          highlights.add((turnRect(r, own, turns), colors.textSelection));
        }
      }
    }
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      // The text is read when the pointer comes over the page, ready for a drag.
      onEnter: (_) => c.loadText(widget.page).then((_) {
        if (mounted) setState(() {});
      }),
      child: GestureDetector(
        dragStartBehavior: DragStartBehavior.down,
        onTapDown: (_) => c.clearSelection(),
        onPanStart: (d) async {
          await c.loadText(widget.page);
          if (!mounted) return;
          _anchor = _index(d.localPosition);
        },
        onPanUpdate: (d) {
          final anchor = _anchor;
          final end = _index(d.localPosition, end: true);
          if (anchor == null || end == null) return;
          c.select(widget.page, anchor, end);
        },
        child: Container(
          width: widget.size.width,
          height: widget.size.height,
          decoration: BoxDecoration(
            color: colors.placeholder,
            boxShadow: [
              BoxShadow(
                color: colors.pageShadow,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                RotatedBox(
                  quarterTurns: turns,
                  child: RawImage(
                    image: image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              if (highlights.isNotEmpty)
                CustomPaint(painter: _Highlights(highlights, scale)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Highlights extends CustomPainter {
  _Highlights(this.boxes, this.scale);
  final List<(Rect, Color)> boxes;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (r, color) in boxes) {
      final box = Rect.fromLTRB(
        r.left * scale,
        r.top * scale,
        r.right * scale,
        r.bottom * scale,
      ).inflate(math.max(0.5, scale * 0.5));
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_Highlights old) => true;
}

/// The thumbnail of a page, `side` points on its longest side.
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({
    super.key,
    required this.controller,
    required this.page,
    required this.side,
  });

  final ViewerController controller;
  final int page;
  final double side;

  @override
  Widget build(BuildContext context) {
    final pdf = controller.pdf!;
    final size = pdf.pageSize(page);
    final scale = side / math.max(size.width, size.height);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final image = controller.pages?.image(page, scale * dpr);
    final colors = PreviewColors.of(context);
    return Container(
      width: size.width * scale,
      height: size.height * scale,
      decoration: BoxDecoration(
        color: colors.placeholder,
        boxShadow: [BoxShadow(color: colors.pageShadow, blurRadius: 2)],
      ),
      child: image == null
          ? null
          : RotatedBox(
              quarterTurns: pdf.quarterTurns,
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
    );
  }
}
