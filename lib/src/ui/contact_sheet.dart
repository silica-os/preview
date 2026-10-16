// The contact sheet (kit `Apps/Preview/Contact Sheet`, View › Contact Sheet ⌥⌘6): a grid of
// every page or image over the whole content area. A 28 pt header (a disclosure and the file's
// name), then cells of 152 × 216 on a 164 × 232 pitch holding a 120 × 172 page and its number
// (left aligned under the page). The chosen page sits on a rounded rectangle with its number in
// an accent pill. A click chooses a page; a double click shows it in the thumbnails view.

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
        final columns = math.max(
          1,
          ((box.maxWidth -
                      PreviewMetrics.contactPadding +
                      PreviewMetrics.contactGap) /
                  (cell.width + PreviewMetrics.contactGap))
              .floor(),
        );
        final rows = (c.count / columns).ceil();
        return ListView.builder(
          key: const ValueKey('contact sheet'),
          controller: _scroll,
          padding: EdgeInsets.only(top: top, bottom: 16),
          itemCount: 1 + (_open ? rows : 0),
          itemBuilder: (context, row) {
            if (row == 0) {
              // The header sits on the window's surface over the grid's canvas.
              return GestureDetector(
                key: const ValueKey('contact header'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = !_open),
                child: SizedBox(
                  height: PreviewMetrics.contactHeader,
                  child: ColoredBox(
                    color: colors.window,
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        AmalfiGlyph(
                          _open
                              ? AmalfiGlyphs.chevronDown
                              : AmalfiGlyphs.chevronRight,
                          size: 12,
                          color: colors.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AmalfiType.headline(color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final first = (row - 1) * columns;
            return Padding(
              padding: EdgeInsets.only(
                left: PreviewMetrics.contactPadding,
                top: row == 1
                    ? PreviewMetrics.contactFirstRow
                    : PreviewMetrics.contactRowGap,
              ),
              child: Row(
                spacing: PreviewMetrics.contactGap,
                children: [
                  for (
                    var i = first;
                    i < math.min(first + columns, c.count);
                    i++
                  )
                    _Cell(controller: c, index: i),
                ],
              ),
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
    final label = c.isPdf ? '${index + 1}' : c.images!.images[index].name;
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
        child: Stack(
          children: [
            if (chosen)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: AmalfiTheme.of(context).colors.lineSeparator,
                    shape: AmalfiSmoothBorder(radius: 10),
                  ),
                ),
              ),
            Positioned(
              left: PreviewMetrics.contactPageLeft,
              top: PreviewMetrics.contactPageTop,
              width: page.width,
              height: page.height,
              child: Center(child: picture),
            ),
            if (chosen)
              Positioned(
                left: 0,
                right: 0,
                top: PreviewMetrics.contactPillTop,
                child: Center(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.selection,
                      shape: AmalfiSmoothBorder(radius: 10),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 20,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AmalfiType.caption(color: colors.onAccent),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                right: 0,
                top: PreviewMetrics.contactNumberTop,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AmalfiType.caption(color: colors.secondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
