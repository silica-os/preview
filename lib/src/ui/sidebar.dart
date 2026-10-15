// The sidebar: thumbnails of the images or the pages (the current one on a rounded backdrop),
// or the PDF's table of contents with its levels folded and unfolded.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../model/viewer.dart';
import '../pdf/backend.dart';
import '../style.dart';
import 'image_view.dart';
import 'pdf_view.dart';

class PreviewSidebar extends StatelessWidget {
  const PreviewSidebar({
    super.key,
    required this.controller,
    this.active = true,
  });
  final ViewerController controller;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    final child = controller.sidebar == SidebarMode.contents
        ? _Contents(controller: controller)
        : _Thumbnails(controller: controller, active: active);
    return Container(
      key: const ValueKey('sidebar'),
      width: PreviewMetrics.sidebarWidth,
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(right: BorderSide(color: colors.sidebarLine)),
      ),
      child: child,
    );
  }
}

class _Thumbnails extends StatelessWidget {
  const _Thumbnails({required this.controller, required this.active});
  final ViewerController controller;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    final pages = controller.pages;
    Widget list() => ListView.builder(
      key: const ValueKey('thumbnails'),
      padding: const EdgeInsets.symmetric(
        vertical: PreviewMetrics.thumbnailGap / 2,
      ),
      itemCount: controller.count,
      itemBuilder: (context, i) {
        final chosen = controller.isPdf
            ? controller.spreadPages(controller.current).contains(i)
            : i == controller.current;
        final label = controller.isPdf
            ? '${i + 1}'
            : controller.images!.images[i].name;
        return GestureDetector(
          key: ValueKey('thumbnail $i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.goTo(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: PreviewMetrics.thumbnailGap / 2,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: chosen
                        ? (active ? colors.selection : colors.selectionInactive)
                        : null,
                    borderRadius: BorderRadius.circular(
                      PreviewMetrics.selectionRadius,
                    ),
                  ),
                  child: controller.isPdf
                      ? PageThumbnail(
                          controller: controller,
                          page: i,
                          side: PreviewMetrics.thumbnailSide,
                        )
                      : _ImageThumbnail(controller: controller, index: i),
                ),
                SizedBox(
                  height: PreviewMetrics.thumbnailLabel,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: previewText(11, color: colors.secondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    // Rebuilt from scratch when a page bitmap arrives (an identical widget would be skipped).
    if (pages == null) return list();
    return ListenableBuilder(
      listenable: pages,
      builder: (context, _) => list(),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({required this.controller, required this.index});
  final ViewerController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final item = controller.images!.images[index];
    final turned = item.turnedSize;
    final scale =
        PreviewMetrics.thumbnailSide /
        math.max(1, math.max(turned.width, turned.height));
    return ShownImage(item: item, scale: scale);
  }
}

/// The table of contents. Levels below the first start folded.
class _Contents extends StatefulWidget {
  const _Contents({required this.controller});
  final ViewerController controller;

  @override
  State<_Contents> createState() => _ContentsState();
}

class _ContentsState extends State<_Contents> {
  final Set<PdfOutlineItem> _open = {};

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    final rows = <(PdfOutlineItem, int)>[];
    void walk(List<PdfOutlineItem> items, int depth) {
      for (final item in items) {
        rows.add((item, depth));
        if (_open.contains(item)) walk(item.children, depth + 1);
      }
    }

    walk(widget.controller.pdf?.handle.outline ?? const [], 0);
    final current = widget.controller.current;
    return ListView.builder(
      key: const ValueKey('contents'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (item, depth) = rows[i];
        final page = item.page;
        final opened = _open.contains(item);
        return GestureDetector(
          key: ValueKey('contents $i'),
          behavior: HitTestBehavior.opaque,
          onTap: page == null ? null : () => widget.controller.goTo(page),
          child: SizedBox(
            height: PreviewMetrics.contentsRow,
            child: Row(
              children: [
                SizedBox(width: 6 + depth * PreviewMetrics.contentsIndent),
                SizedBox(
                  width: 16,
                  child: item.children.isEmpty
                      ? null
                      : GestureDetector(
                          key: ValueKey('disclosure $i'),
                          onTap: () => setState(
                            () => opened ? _open.remove(item) : _open.add(item),
                          ),
                          child: Text(
                            opened ? '▾' : '▸',
                            style: previewText(11, color: colors.secondary),
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: previewText(
                      12,
                      color: page == null ? colors.secondary : colors.text,
                      weight: page == current
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (page != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 8),
                    child: Text(
                      '${page + 1}',
                      style: previewText(11, color: colors.secondary),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
