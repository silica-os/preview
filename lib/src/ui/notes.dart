// Highlights and Notes in the sidebar (PREVIEW-01 › Sidebar, PREVIEW-02 › PDF features): a
// 19 pt header, then one row per annotation in page order. A highlight row (127 pt) has its
// page, its author on the right, a 3 pt bar of its colour and the marked text (three lines); a
// note row (114 pt) has a yellow strip and the note's text. A click goes to the annotation and
// chooses it.

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../model/viewer.dart';
import '../pdf/backend.dart';
import '../style.dart';

/// The text of `layout` under `quads`.
String textUnder(PdfTextLayout layout, List<Rect> quads) {
  final out = StringBuffer();
  for (var i = 0; i < layout.length; i++) {
    final centre = layout.rects[i].center;
    if (quads.any((q) => q.inflate(1).contains(centre))) {
      out.write(layout.chars[i]);
    }
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class NotesSidebar extends StatelessWidget {
  const NotesSidebar({
    super.key,
    required this.controller,
    required this.top,
    this.active = true,
  });
  final ViewerController controller;
  final double top;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = controller;
    final all = c.allAnnotations;
    return Listener(
      onPointerDown: (_) => c.focusSidebar(true),
      child: Container(
        key: const ValueKey('notes sidebar'),
        width: c.sidebarWidth,
        decoration: BoxDecoration(
          color: colors.sidebar,
          border: Border(right: BorderSide(color: colors.sidebarLine)),
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) => true,
          child: ListView.builder(
            padding: EdgeInsets.only(top: top, bottom: 6),
            itemCount: all.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return SizedBox(
                  height: PreviewMetrics.notesHeader,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.highlightsAndNotes,
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
              final (page, a) = all[i - 1];
              return _Row(
                controller: c,
                page: page,
                annotation: a,
                focused: active && c.sidebarFocused,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.controller,
    required this.page,
    required this.annotation,
    required this.focused,
  });
  final ViewerController controller;
  final int page;
  final PdfAnnotation annotation;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = controller;
    final a = annotation;
    final note = a.kind == PdfMarkupKind.note;
    final chosen = c.chosenAnnotation == (page, a.id);
    final fg = chosen && focused ? const Color(0xFFFFFFFF) : null;
    final layout = c.textOf(page);
    if (layout == null && !note) c.loadText(page).then((_) => c.changed());
    final text = note
        ? a.contents
        : (layout == null ? '' : textUnder(layout, a.quads));
    return GestureDetector(
      key: ValueKey('note row ${a.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        c.jumpTo(page);
        c.chooseAnnotation((page, a.id));
      },
      child: Container(
        height: note ? PreviewMetrics.noteRow : PreviewMetrics.highlightRow,
        margin: const EdgeInsets.symmetric(
          horizontal: PreviewMetrics.contentsSelectionInset,
        ),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: chosen
              ? (focused ? colors.selection : colors.selectionInactive)
              : null,
          borderRadius: BorderRadius.circular(PreviewMetrics.contentsRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.pageNumber(page + 1),
                    style: previewText(
                      11,
                      color: fg ?? colors.secondary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    a.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: previewText(11, color: fg ?? colors.secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: note ? 8 : PreviewMetrics.noteBar,
                    color: Color(a.argb | 0xFF000000),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: previewText(11, color: fg ?? colors.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
