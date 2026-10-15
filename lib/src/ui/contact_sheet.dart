// The contact sheet (PREVIEW-01 › Sidebar, View › Contact Sheet ⌥⌘6): a grid of every page or
// image over the whole content area. A 28 pt section header (a disclosure and the file's name),
// then cells of 152 × 216 holding a 120 × 170 page and its number. The chosen page sits on a
// gray rounded rectangle with its number in an accent pill. A click chooses a page; a double
// click shows it in the thumbnails view.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../model/viewer.dart';
import '../style.dart';
import 'image_view.dart';
import 'pdf_view.dart';
import 'zoom_view.dart';

class ContactSheet extends StatefulWidget {
  const ContactSheet({super.key, required this.controller});
  final ViewerController controller;

  @override
  State<ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<ContactSheet> {
  bool _open = true;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final colors = PreviewColors.of(context);
    final top = ZoomInset.of(context);
    final cell = PreviewMetrics.contactCell;
    final name = c.pdf?.name ?? c.images?.title ?? '';
    Widget grid() => LayoutBuilder(
      builder: (context, box) {
        final columns = math.max(1, (box.maxWidth / cell.width).floor());
        final rows = (c.count / columns).ceil();
        return ListView.builder(
          key: const ValueKey('contact sheet'),
          controller: _scroll,
          padding: EdgeInsets.only(top: top, bottom: 12),
          itemCount: 1 + (_open ? rows : 0),
          itemBuilder: (context, row) {
            if (row == 0) {
              return GestureDetector(
                key: const ValueKey('contact header'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = !_open),
                child: SizedBox(
                  height: PreviewMetrics.contactHeader,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 9,
                        height: 9,
                        child: OutlineTriangle(open: _open, color: colors.text),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: previewText(
                            12,
                            color: colors.text,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final first = (row - 1) * columns;
            return Row(
              children: [
                for (var i = first; i < math.min(first + columns, c.count); i++)
                  _Cell(controller: c, index: i),
              ],
            );
          },
        );
      },
    );
    final pages = c.pages;
    return ColoredBox(
      color: c.isPdf ? colors.pdfCanvas : colors.imageCanvas,
      child: pages == null
          ? grid()
          : ListenableBuilder(listenable: pages, builder: (_, _) => grid()),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.controller, required this.index});
  final ViewerController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = PreviewColors.of(context);
    final chosen = index == c.current;
    final page = PreviewMetrics.contactPage;
    final Widget picture;
    if (c.isPdf) {
      picture = PageThumbnail(controller: c, page: index, box: page);
    } else {
      final item = c.images!.images[index];
      final turned = item.turnedSize;
      final scale = math.min(
        page.width / math.max(1, turned.width),
        page.height / math.max(1, turned.height),
      );
      picture = ShownImage(item: item, scale: scale);
    }
    return GestureDetector(
      key: ValueKey('contact $index'),
      behavior: HitTestBehavior.opaque,
      onTap: () => c.goTo(index),
      onDoubleTap: () {
        c.setSidebar(SidebarMode.thumbnails);
        c.goTo(index);
      },
      child: SizedBox.fromSize(
        size: PreviewMetrics.contactCell,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: chosen ? colors.selectionInactive : null,
                borderRadius: BorderRadius.circular(
                  PreviewMetrics.thumbnailRadius,
                ),
              ),
              child: SizedBox.fromSize(
                size: page,
                child: Center(child: picture),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: chosen ? PreviewColors.accent : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                c.isPdf ? '${index + 1}' : c.images!.images[index].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: previewText(
                  11,
                  color: chosen ? const Color(0xFFFFFFFF) : colors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
