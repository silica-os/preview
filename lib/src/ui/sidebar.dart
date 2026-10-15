// The sidebar (PREVIEW-01 › Sidebar, PREVIEW-02 › Search): 160 pt by default, resizable from
// 160 to 400 by its edge, over the window's glass. It shows one of:
//
// - thumbnails: 117 × 174 cells (a 105 pt page, its number under it) on a 184 pt pitch, growing
//   with the sidebar; the current one on a rounded rectangle, the accent while the sidebar has
//   the focus, muted otherwise. PDF pages can be dragged to a new place (the others make room).
//   Several images: one section per file, the file's name under it.
// - the table of contents: the document's name (19 pt), entries 40 pt high, 12 pt per level;
//   the chosen entry on an inset rounded rectangle, accent with bold white text when focused.
// - bookmarks: a 30 pt header, then a row of 85 pt per bookmarked page (its number and the first
//   words of its text).
// - while searching, the results: a row of 77 pt per page with matches (thumbnail, "Page N",
//   the number of matches, the text around the first match).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/viewer.dart';
import '../pdf/backend.dart';
import '../style.dart';
import 'image_view.dart';
import 'pdf_view.dart';

/// Whether the sidebar shows the search results now.
bool showsResults(ViewerController c) =>
    c.isPdf && c.searching && c.query.trim().isNotEmpty;

/// The sidebar's width now (wider while it lists search results).
double sidebarWidthOf(ViewerController c) => showsResults(c)
    ? math.max(c.sidebarWidth, PreviewMetrics.sidebarSearchWidth)
    : c.sidebarWidth;

class PreviewSidebar extends StatelessWidget {
  const PreviewSidebar({
    super.key,
    required this.controller,
    this.active = true,
    this.top = 0,
    this.onPageMenu,
  });
  final ViewerController controller;
  final bool active;

  /// The toolbar band above it: the first row starts below.
  final double top;

  /// A secondary click on thumbnail `index` at a global position.
  final void Function(int index, Offset at)? onPageMenu;

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    final c = controller;
    final Widget child;
    if (showsResults(c)) {
      child = _Results(controller: c, top: top);
    } else {
      child = switch (c.sidebar) {
        SidebarMode.contents => _Contents(controller: c, top: top),
        SidebarMode.bookmarks => _Bookmarks(controller: c, top: top),
        _ => _Thumbnails(controller: c, top: top, onPageMenu: onPageMenu),
      };
    }
    return Listener(
      // A press in the sidebar gives it the focus: its selection turns to the accent.
      onPointerDown: (_) => c.focusSidebar(true),
      child: Container(
        key: const ValueKey('sidebar'),
        width: sidebarWidthOf(c),
        decoration: BoxDecoration(
          color: colors.sidebar,
          border: Border(
            right: BorderSide(
              color: colors.sidebarLine,
              width: PreviewMetrics.sidebarDivider,
            ),
          ),
        ),
        // The list's own scrolling does not move the toolbar's veil.
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) => true,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) => true,
            child: _Focused(active: active && c.sidebarFocused, child: child),
          ),
        ),
      ),
    );
  }
}

/// Whether the sidebar's selection shows in the accent colour.
class _Focused extends InheritedWidget {
  const _Focused({required this.active, required super.child});
  final bool active;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Focused>()?.active ?? true;

  @override
  bool updateShouldNotify(_Focused old) => old.active != active;
}

/// The selection fill for a chosen row or cell.
Color _selectionFill(BuildContext context) {
  final colors = PreviewColors.of(context);
  return _Focused.of(context) ? colors.selection : colors.selectionInactive;
}

/// A header row: a caption in the secondary colour.
Widget _header(BuildContext context, String text, double height) {
  final colors = PreviewColors.of(context);
  return SizedBox(
    height: height,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: previewText(
            11,
            color: colors.secondary,
            weight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

/// `text` shortened in the middle to fit `width` with `style` (file names keep their
/// extension).
String middleTruncate(String text, TextStyle style, double width) {
  bool fits(String t) {
    final p = TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final ok = p.width <= width;
    p.dispose();
    return ok;
  }

  if (width <= 0 || fits(text)) return text;
  var keep = text.length - 1;
  while (keep > 1) {
    final head = (keep + 1) ~/ 2;
    final tail = keep - head;
    final t =
        '${text.substring(0, head)}…${text.substring(text.length - tail)}';
    if (fits(t)) return t;
    keep--;
  }
  return '…';
}

// ---------------------------------------------------------------------------------------------
// Thumbnails.

class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.controller,
    required this.top,
    this.onPageMenu,
  });
  final ViewerController controller;
  final double top;
  final void Function(int index, Offset at)? onPageMenu;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final pages = c.pages;
    Widget list(BoxConstraints box) {
      final width = sidebarWidthOf(c);
      final image = PreviewMetrics.thumbnailWidth(width);
      final padding = EdgeInsets.only(
        top: top + PreviewMetrics.thumbnailGap,
        bottom: PreviewMetrics.thumbnailGap,
        right: PreviewMetrics.sidebarScroller,
      );
      Widget cell(int i) => _ThumbnailCell(
        key: ValueKey('thumbnail $i'),
        controller: c,
        index: i,
        imageWidth: image,
        onMenu: onPageMenu,
      );
      if (c.isPdf) {
        return ReorderableList(
          key: const ValueKey('thumbnails'),
          padding: padding,
          itemCount: c.count,
          onReorderItem: c.movePage,
          proxyDecorator: (child, index, animation) =>
              Opacity(opacity: 0.6, child: child),
          itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
            key: ValueKey('page cell ${c.pdf!.pages[i].hashCode}'),
            index: i,
            child: cell(i),
          ),
        );
      }
      return ListView.builder(
        key: const ValueKey('thumbnails'),
        padding: padding,
        itemCount: c.count,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : PreviewMetrics.sectionGap),
          child: cell(i),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) => pages == null
          ? list(box)
          // Rebuilt when a page bitmap arrives.
          : ListenableBuilder(listenable: pages, builder: (_, _) => list(box)),
    );
  }
}

class _ThumbnailCell extends StatelessWidget {
  const _ThumbnailCell({
    super.key,
    required this.controller,
    required this.index,
    required this.imageWidth,
    this.onMenu,
  });
  final ViewerController controller;
  final int index;
  final double imageWidth;
  final void Function(int index, Offset at)? onMenu;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = PreviewColors.of(context);
    final chosen = c.isPdf
        ? c.spreadPages(c.current).contains(index)
        : index == c.current;
    final focused = _Focused.of(context);
    final labelStyle = previewText(
      11,
      color: chosen && focused ? const Color(0xFFFFFFFF) : colors.secondary,
      weight: chosen ? FontWeight.w600 : FontWeight.w400,
    );
    final box = Size(imageWidth, imageWidth * PreviewMetrics.thumbnailAspect);
    final Widget picture;
    final String label;
    if (c.isPdf) {
      final page = c.pdf!.pageSize(index);
      final scale = math.min(box.width / page.width, box.height / page.height);
      picture = SizedBox(
        width: box.width,
        height: page.height * scale,
        child: Center(
          child: PageThumbnail(controller: c, page: index, box: box),
        ),
      );
      label = '${index + 1}';
    } else {
      final item = c.images!.images[index];
      final turned = item.turnedSize;
      final scale = math.min(
        box.width / math.max(1, turned.width),
        box.height / math.max(1, turned.height),
      );
      picture = SizedBox(
        width: box.width,
        height: turned.height * scale,
        child: Center(
          child: ShownImage(item: item, scale: scale),
        ),
      );
      label = middleTruncate(
        item.name,
        labelStyle,
        imageWidth + 2 * PreviewMetrics.thumbnailInset - 8,
      );
    }
    final bookmarked = c.isPdf && c.pdf!.pages[index].bookmarked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => c.jumpTo(index),
      onSecondaryTapUp: onMenu == null
          ? null
          : (d) {
              c.goTo(index);
              onMenu!(index, d.globalPosition);
            },
      child: Padding(
        padding: const EdgeInsets.only(bottom: PreviewMetrics.thumbnailGap),
        child: Center(
          child: Container(
            key: chosen ? const ValueKey('chosen thumbnail') : null,
            width: imageWidth + 2 * PreviewMetrics.thumbnailInset,
            padding: const EdgeInsets.only(top: PreviewMetrics.thumbnailInset),
            decoration: BoxDecoration(
              color: chosen ? _selectionFill(context) : null,
              borderRadius: BorderRadius.circular(
                PreviewMetrics.thumbnailRadius,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    picture,
                    if (bookmarked)
                      const Positioned(
                        top: -2,
                        right: 4,
                        child: _BookmarkRibbon(),
                      ),
                  ],
                ),
                const SizedBox(height: PreviewMetrics.thumbnailLabelGap),
                SizedBox(
                  height: PreviewMetrics.thumbnailLabel,
                  child: Center(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: labelStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark of a bookmarked page on its thumbnail.
class _BookmarkRibbon extends StatelessWidget {
  const _BookmarkRibbon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    key: ValueKey('bookmark ribbon'),
    width: 10,
    height: 14,
    child: CustomPaint(painter: _RibbonPainter()),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.72)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFE5483A));
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => false;
}

// ---------------------------------------------------------------------------------------------
// Table of contents.

/// The table of contents. Levels below the first start folded.
class _Contents extends StatefulWidget {
  const _Contents({required this.controller, required this.top});
  final ViewerController controller;
  final double top;

  @override
  State<_Contents> createState() => _ContentsState();
}

class _ContentsState extends State<_Contents> {
  final Set<PdfOutlineItem> _open = {};
  PdfOutlineItem? _chosen;

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    final c = widget.controller;
    final rows = <(PdfOutlineItem, int)>[];
    void walk(List<PdfOutlineItem> items, int depth) {
      for (final item in items) {
        rows.add((item, depth));
        if (_open.contains(item)) walk(item.children, depth + 1);
      }
    }

    walk(c.pdf?.handle.outline ?? const [], 0);
    final width = sidebarWidthOf(c);
    final headerStyle = previewText(
      11,
      color: colors.secondary,
      weight: FontWeight.w700,
    );
    return ListView.builder(
      key: const ValueKey('contents'),
      padding: EdgeInsets.only(top: widget.top, bottom: 6),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _header(
            context,
            middleTruncate(c.pdf?.name ?? '', headerStyle, width - 24),
            PreviewMetrics.contentsHeader,
          );
        }
        final (item, depth) = rows[i - 1];
        final page = item.page;
        final opened = _open.contains(item);
        final chosen = item == _chosen;
        final focused = _Focused.of(context);
        final textColor = chosen && focused
            ? const Color(0xFFFFFFFF)
            : (page == null ? colors.secondary : colors.text);
        return GestureDetector(
          key: ValueKey('contents ${i - 1}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _chosen = item);
            if (page != null) c.jumpTo(page);
          },
          child: SizedBox(
            height: PreviewMetrics.contentsRow,
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: PreviewMetrics.contentsSelectionInset,
              ),
              decoration: BoxDecoration(
                color: chosen
                    ? (focused ? colors.selection : colors.contentsInactive)
                    : null,
                borderRadius: BorderRadius.circular(
                  PreviewMetrics.contentsRadius,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width:
                        PreviewMetrics.contentsDisclosure -
                        PreviewMetrics.contentsSelectionInset +
                        depth * PreviewMetrics.contentsIndent,
                  ),
                  SizedBox(
                    width: 14,
                    child: item.children.isEmpty
                        ? null
                        : GestureDetector(
                            key: ValueKey('disclosure ${i - 1}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(
                              () =>
                                  opened ? _open.remove(item) : _open.add(item),
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 9,
                                height: 9,
                                child: OutlineTriangle(
                                  open: opened,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: previewText(
                        12,
                        color: textColor,
                        weight: chosen && focused
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Bookmarks.

class _Bookmarks extends StatelessWidget {
  const _Bookmarks({required this.controller, required this.top});
  final ViewerController controller;
  final double top;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = controller;
    final marks = c.bookmarks;
    return ListView.builder(
      key: const ValueKey('bookmarks'),
      padding: EdgeInsets.only(top: top, bottom: 6),
      itemCount: marks.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _header(context, l.bookmarks, PreviewMetrics.bookmarksHeader);
        }
        final page = marks[i - 1];
        final chosen = c.current == page;
        final focused = _Focused.of(context);
        final fg = chosen && focused ? const Color(0xFFFFFFFF) : null;
        return GestureDetector(
          key: ValueKey('bookmark $page'),
          behavior: HitTestBehavior.opaque,
          onTap: () => c.jumpTo(page),
          child: Container(
            height: PreviewMetrics.bookmarkRow,
            margin: const EdgeInsets.symmetric(
              horizontal: PreviewMetrics.contentsSelectionInset,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: chosen ? _selectionFill(context) : null,
              borderRadius: BorderRadius.circular(
                PreviewMetrics.contentsRadius,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.pageNumber(page + 1),
                  style: previewText(
                    11,
                    color: fg ?? colors.secondary,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                _PageExcerpt(
                  controller: c,
                  page: page,
                  style: previewText(11, color: fg ?? colors.text),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The first words of a page, three lines.
class _PageExcerpt extends StatefulWidget {
  const _PageExcerpt({
    required this.controller,
    required this.page,
    required this.style,
  });
  final ViewerController controller;
  final int page;
  final TextStyle style;

  @override
  State<_PageExcerpt> createState() => _PageExcerptState();
}

class _PageExcerptState extends State<_PageExcerpt> {
  @override
  Widget build(BuildContext context) {
    final layout = widget.controller.textOf(widget.page);
    if (layout == null) {
      widget.controller.loadText(widget.page).then((_) {
        if (mounted) setState(() {});
      });
    }
    final text = (layout?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return Text(
      text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Search results.

class _Results extends StatelessWidget {
  const _Results({required this.controller, required this.top});
  final ViewerController controller;
  final double top;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = controller;
    final results = c.resultPages;
    final currentPage = c.matchIndex >= 0 && c.matchIndex < c.matches.length
        ? c.matches[c.matchIndex].page
        : -1;
    final pages = c.pages;
    Widget list() => ListView.builder(
      key: const ValueKey('results'),
      padding: EdgeInsets.only(top: top, bottom: 6),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final (page, count) = results[i];
        final chosen = page == currentPage;
        final focused = _Focused.of(context);
        final fg = chosen && focused ? const Color(0xFFFFFFFF) : null;
        final match = c.matches.firstWhere((m) => m.page == page);
        final layout = c.textOf(page);
        return GestureDetector(
          key: ValueKey('result $page'),
          behavior: HitTestBehavior.opaque,
          onTap: () => c.showResult(page),
          child: Container(
            height: PreviewMetrics.resultRow,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: chosen ? _selectionFill(context) : null,
              borderRadius: BorderRadius.circular(
                PreviewMetrics.contentsRadius,
              ),
            ),
            child: Row(
              children: [
                SizedBox.fromSize(
                  size: PreviewMetrics.resultThumbnail,
                  child: Center(
                    child: PageThumbnail(
                      controller: c,
                      page: page,
                      box: PreviewMetrics.resultThumbnail,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.pageNumber(page + 1),
                              maxLines: 1,
                              style: previewText(
                                11,
                                color: fg ?? colors.text,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            l.resultCount(count),
                            style: previewText(
                              10,
                              color: fg ?? colors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (layout != null)
                        Text.rich(
                          _snippet(
                            layout,
                            match.start,
                            match.end,
                            previewText(10, color: fg ?? colors.secondary),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (pages == null) return list();
    return ListenableBuilder(listenable: pages, builder: (_, _) => list());
  }

  /// The words around a match, the match in bold.
  static TextSpan _snippet(
    PdfTextLayout layout,
    int start,
    int end,
    TextStyle style,
  ) {
    String clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ');
    final before = clean(layout.slice(math.max(0, start - 40), start));
    final cut = before.indexOf(' ');
    return TextSpan(
      style: style,
      children: [
        TextSpan(
          text: start > 40 && cut >= 0
              ? '…${before.substring(cut + 1)}'
              : before,
        ),
        TextSpan(
          text: clean(layout.slice(start, end)),
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: clean(layout.slice(end, end + 80))),
      ],
    );
  }
}

/// The handle on the sidebar's edge that resizes it.
class SidebarResizer extends StatelessWidget {
  const SidebarResizer({super.key, required this.controller});
  final ViewerController controller;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.resizeColumn,
    child: GestureDetector(
      key: const ValueKey('sidebar resizer'),
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onHorizontalDragUpdate: (d) =>
          controller.resizeSidebar(controller.sidebarWidth + d.delta.dx),
      child: const SizedBox(width: 6),
    ),
  );
}
