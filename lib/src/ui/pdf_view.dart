// A PDF in the window: the pages in a continuous column 14 pt from the edges and 17 pt apart
// (built lazily, only the pages near the view are rendered), or one page fitted and centred, or
// two pages as a book (the first alone, then spreads whose pages touch, a faint shade at the
// spine). Dragging over a page selects its text; search matches are highlighted, the current
// one bright yellow.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../model/document.dart';
import '../model/viewer.dart';
import '../pdf/backend.dart';
import '../pdf/pages.dart';
import '../pdf/text.dart';
import '../style.dart';
import 'zoom_view.dart';

/// A secondary click on a page, at a global position, on an annotation or not.
typedef PageMenu = void Function(Offset at, (int, PdfAnnotation)? annotation);

/// A click on a note's icon: its popover opens from `anchor`.
typedef NoteOpener =
    void Function(BuildContext anchor, int page, PdfAnnotation note);

class PdfView extends StatefulWidget {
  const PdfView({
    super.key,
    required this.controller,
    this.onContextMenu,
    this.onNote,
  });
  final ViewerController controller;
  final PageMenu? onContextMenu;
  final NoteOpener? onNote;

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  DateTime _turned = DateTime(0);

  ViewerController get controller => widget.controller;

  /// In the single and two-page layouts a scroll that cannot move the page turns it.
  void _signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (controller.layout == PageLayout.continuous) return;
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed || keys.isControlPressed) return;
    final v = controller.vertical;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    if (v.hasClients) {
      final p = v.position;
      final atEnd = dy > 0 ? p.pixels >= p.maxScrollExtent : p.pixels <= 0;
      if (!atEnd) return;
    }
    final now = DateTime.now();
    if (now.difference(_turned) < const Duration(milliseconds: 350)) return;
    _turned = now;
    dy > 0 ? controller.next() : controller.previous();
  }

  @override
  Widget build(BuildContext context) {
    final pdf = controller.pdf;
    final pages = controller.pages;
    if (pdf == null || pages == null) return const SizedBox.expand();
    return Listener(onPointerSignal: _signal, child: _pages(pdf, pages));
  }

  Widget _pages(PdfItem pdf, PageImages pages) {
    return ListenableBuilder(
      listenable: pages,
      builder: (context, _) {
        final scale = controller.scale;
        final top = ZoomInset.of(context);
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
                          top: i == 0 ? top + controller.margin : 0,
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
                            onContextMenu: widget.onContextMenu,
                            onNote: widget.onNote,
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
                for (final (k, page) in spread.indexed)
                  PageTile(
                    key: ValueKey('page $page'),
                    controller: controller,
                    page: page,
                    size: pdf.pageSize(page) * scale,
                    onContextMenu: widget.onContextMenu,
                    onNote: widget.onNote,
                    // The pages of a spread touch, with a faint shade at the spine.
                    spine: spread.length < 2
                        ? null
                        : (k == 0 ? AxisDirection.right : AxisDirection.left),
                  ),
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
    this.spine,
    this.onContextMenu,
    this.onNote,
  });

  final ViewerController controller;
  final int page;
  final PageMenu? onContextMenu;
  final NoteOpener? onNote;

  /// On screen, rotation included.
  final Size size;

  /// The side of the book's spine in a two-page spread.
  final AxisDirection? spine;

  @override
  State<PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<PageTile> {
  int? _anchor;

  ViewerController get c => widget.controller;

  /// A point of the tile in page points (unrotated).
  Offset _pagePoint(Offset local) {
    final pdf = c.pdf!;
    final own = pdf.ownSize(widget.page);
    final turned = pdf.pageSize(widget.page);
    final scale = turned.width == 0 ? 1.0 : widget.size.width / turned.width;
    return unturnPoint(local / scale, own, pdf.turnsOf(widget.page));
  }

  /// The annotation under `local`, the last drawn first.
  PdfAnnotation? _annotationAt(Offset local) {
    final p = _pagePoint(local);
    for (final a in c.annotationsOf(widget.page).reversed) {
      final hit = a.kind == PdfMarkupKind.note
          ? a.bounds.contains(p)
          : a.quads.any((q) => q.inflate(1).contains(p));
      if (hit) return a;
    }
    return null;
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
    final own = pdf.ownSize(widget.page);
    final turned = pdf.pageSize(widget.page);
    final scale = turned.width == 0 ? 1.0 : widget.size.width / turned.width;
    final source = c.sourceOf(widget.page);
    final image = source == null ? null : c.pages?.image(source, scale * dpr);
    final layout = c.textOf(widget.page);
    final turns = pdf.turnsOf(widget.page);
    final annotations = c.annotationsOf(widget.page);
    final chosen = c.chosenAnnotation;
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
        onTapDown: (d) {
          c.clearSelection();
          final a = _annotationAt(d.localPosition);
          c.chooseAnnotation(a == null ? null : (widget.page, a.id));
        },
        onSecondaryTapUp: (d) {
          final a = _annotationAt(d.localPosition);
          if (a != null) c.chooseAnnotation((widget.page, a.id));
          widget.onContextMenu?.call(
            d.globalPosition,
            a == null ? null : (widget.page, a),
          );
        },
        onPanEnd: (_) {
          // Highlighting: the selection is marked when the drag ends.
          if (c.highlighting && c.canCopy && c.canAnnotate) {
            unawaited(c.markSelection());
          }
        },
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
                blurRadius: PreviewMetrics.pageShadow,
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
              for (final a in annotations)
                if (chosen == (widget.page, a.id) &&
                    a.kind != PdfMarkupKind.note)
                  CustomPaint(
                    key: ValueKey('chosen annotation ${a.id}'),
                    painter: _Highlights([
                      for (final q in a.quads)
                        (turnRect(q, own, turns), const Color(0x33000000)),
                    ], scale),
                  ),
              // The notes' icons open their popover.
              for (final a in annotations)
                if (a.kind == PdfMarkupKind.note)
                  Positioned.fromRect(
                    rect: _scaled(turnRect(a.bounds, own, turns), scale),
                    child: Builder(
                      builder: (anchor) => GestureDetector(
                        key: ValueKey('note ${a.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          c.chooseAnnotation((widget.page, a.id));
                          widget.onNote?.call(anchor, widget.page, a);
                        },
                      ),
                    ),
                  ),
              if (widget.spine case final side?)
                DecoratedBox(
                  key: const ValueKey('spine'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: side == AxisDirection.right
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: Alignment.center,
                      stops: const [0, 0.08],
                      colors: const [Color(0x14000000), Color(0x00000000)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Rect _scaled(Rect r, double scale) => Rect.fromLTRB(
  r.left * scale,
  r.top * scale,
  r.right * scale,
  r.bottom * scale,
);

/// Boxes behind the text: multiplied over the page, so the glyphs stay dark (selection
/// #b8d4fd, the current match #ffff3b).
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
        Paint()
          ..color = color
          ..blendMode = BlendMode.multiply,
      );
    }
  }

  @override
  bool shouldRepaint(_Highlights old) => true;
}

/// The thumbnail of a page, as large as fits in `box`.
class PageThumbnail extends StatelessWidget {
  const PageThumbnail({
    super.key,
    required this.controller,
    required this.page,
    required this.box,
  });

  final ViewerController controller;
  final int page;
  final Size box;

  @override
  Widget build(BuildContext context) {
    final pdf = controller.pdf!;
    final size = pdf.pageSize(page);
    final scale = size.isEmpty
        ? 1.0
        : math.min(box.width / size.width, box.height / size.height);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final source = controller.sourceOf(page);
    final image = source == null
        ? null
        : controller.pages?.image(source, scale * dpr);
    final colors = PreviewColors.of(context);
    return Container(
      width: size.width * scale,
      height: size.height * scale,
      decoration: BoxDecoration(
        color: colors.placeholder,
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 2)],
      ),
      child: image == null
          ? null
          : RotatedBox(
              quarterTurns: pdf.turnsOf(page),
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
    );
  }
}
