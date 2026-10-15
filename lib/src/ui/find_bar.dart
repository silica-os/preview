// The find bar (PREVIEW-02 › Search): a 36 pt band under the toolbar while a search is shown.
// "Sort by" with two toggles (by number of matches, by page), "Found on N pages", previous and
// next, and Done (50 × 26), which ends the search.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/viewer.dart';
import '../style.dart';
import 'symbol.dart';

class FindBar extends StatelessWidget {
  const FindBar({super.key, required this.controller, required this.onDone});
  final ViewerController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = controller;
    final pages = c.resultPages.length;
    final status = !c.searchDone && c.matches.isEmpty
        ? l.searching
        : (c.matches.isEmpty ? l.noMatches : l.foundOnPages(pages));
    Widget icon(String name, String fallback, Color color) =>
        PreviewSymbol(name, size: 12, color: color, fallback: fallback);
    return SizedBox(
      key: const ValueKey('find bar'),
      height: PreviewMetrics.findBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Text(l.sortBy, style: previewText(11, color: colors.secondary)),
            const SizedBox(width: 6),
            SegmentedControl(
              key: const ValueKey('search order'),
              size: ControlSize.small,
              segments: [
                Segment(label: l.sortRank),
                Segment(label: l.sortPage),
              ],
              selected: {c.searchOrder.index},
              onChanged: (i) => c.setSearchOrder(SearchOrder.values[i]),
            ),
            const Spacer(),
            Text(
              status,
              key: const ValueKey('find status'),
              style: previewText(11, color: colors.secondary),
            ),
            const Spacer(),
            SegmentedControl(
              key: const ValueKey('find previous next'),
              size: ControlSize.small,
              mode: SegmentedMode.momentary,
              segments: [
                Segment(
                  icon: (color) => icon('chevron-left', '‹', color),
                  semanticLabel: l.findPrevious,
                ),
                Segment(
                  icon: (color) => icon('chevron-right', '›', color),
                  semanticLabel: l.findNext,
                ),
              ],
              onChanged: c.matches.isEmpty
                  ? null
                  : (i) => i == 0 ? c.findPrevious() : c.findNext(),
            ),
            const SizedBox(width: 8),
            SilicaButton(
              key: const ValueKey('find done'),
              label: l.done,
              minWidth: PreviewMetrics.findDoneButton.width,
              onPressed: onDone,
            ),
          ],
        ),
      ),
    );
  }
}
