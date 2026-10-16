// The find bar (kit `Apps/Preview/PDF Search`: 36 pt and a 1 pt separator under the toolbar while
// a search is shown): "Sort by" with two choices (by number of matches, by page), "Found on N
// pages", previous and next, and Done, which ends the search.

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
    Widget icon(String name, String fallback) => Builder(
      builder: (context) => PreviewSymbol(
        name,
        size: 14,
        color: IconTheme.of(context).color ?? colors.text,
        fallback: fallback,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const ValueKey('find bar'),
          height: PreviewMetrics.findBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  l.sortBy,
                  style: AmalfiType.caption(color: colors.secondary),
                ),
                const SizedBox(width: 8),
                AmalfiSegmentedControl(
                  key: const ValueKey('search order'),
                  size: AmalfiControlSize.small,
                  segments: [
                    AmalfiSegment.text(l.sortRank),
                    AmalfiSegment.text(l.sortPage),
                  ],
                  selected: {c.searchOrder.index},
                  onChanged: (s) =>
                      c.setSearchOrder(SearchOrder.values[s.first]),
                ),
                const Spacer(),
                Text(
                  status,
                  key: const ValueKey('find status'),
                  style: AmalfiType.callout(color: colors.secondary),
                ),
                const Spacer(),
                AmalfiActionSegments(
                  key: const ValueKey('find previous next'),
                  size: AmalfiControlSize.small,
                  segments: [
                    AmalfiSegment.icon(
                      icon('chevron-left', '‹'),
                      semanticLabel: l.findPrevious,
                      tooltip: l.findPrevious,
                    ),
                    AmalfiSegment.icon(
                      icon('chevron-right', '›'),
                      semanticLabel: l.findNext,
                      tooltip: l.findNext,
                    ),
                  ],
                  onPressed: c.matches.isEmpty
                      ? null
                      : (i) => i == 0 ? c.findPrevious() : c.findNext(),
                ),
                const SizedBox(width: 16),
                AmalfiPushButton(
                  key: const ValueKey('find done'),
                  label: l.done,
                  size: AmalfiControlSize.small,
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 1, child: ColoredBox(color: colors.sidebarLine)),
      ],
    );
  }
}
