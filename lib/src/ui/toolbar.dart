// The toolbar (PREVIEW-01 › Title bar and toolbar): 52 pt, glass over the content that scrolls
// under it; Ossido draws the window buttons. Left to right: the view menu button (the sidebar
// glyph and a chevron, opening the view menu) in a 57 pt slot at x 92; the title block from
// x 164 (the name, 13 pt bold, over a second line: "Page N of M", "Edited", "N documents");
// then the zoom group (out, actual size, in), the highlight group (PDF; disabled for images),
// Rotate, the markup circle, the inspector, and the search field filling the rest. When the
// window is too narrow the search field becomes a magnifier circle and the tools that do not
// fit go into an overflow circle with a menu.
//
// Not shown in Preview: remove background (#19) and form filling (#15), share (no share
// service in Silica, #1).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/viewer.dart';
import '../style.dart';
import 'symbol.dart';

/// What the toolbar's buttons do besides the controller's actions.
class ToolbarActions {
  const ToolbarActions({
    required this.viewMenu,
    required this.titlePopover,
    required this.searchField,
    required this.collapsedSearch,
    this.searchCircleKey,
    this.highlight,
    this.highlightMenu,
    this.highlighting = false,
    this.markup,
    this.markupShown = false,
  });

  /// The entries of the view menu.
  final List<MenuEntry> Function() viewMenu;

  /// Opens the title popover under the title (null: no popover, nothing open).
  final void Function(BuildContext anchor)? titlePopover;

  /// The search field, at a width.
  final Widget Function(double width) searchField;

  /// The magnifier circle shown in a narrow window: opens the search field in a popover.
  final void Function(BuildContext anchor) collapsedSearch;

  /// The key of the magnifier circle (⌘F opens its popover).
  final GlobalKey? searchCircleKey;

  /// The highlight button and its menu chevron (null: not offered); [highlighting]: on.
  final VoidCallback? highlight;
  final void Function(BuildContext anchor)? highlightMenu;
  final bool highlighting;

  /// The markup button (null: not offered); [markupShown]: the markup toolbar is shown.
  final VoidCallback? markup;
  final bool markupShown;
}

/// One tool of the right side: its key, its width with the gap after it, and how to build it
/// or list it in the overflow menu.
class _Tool {
  const _Tool(this.id, this.width, this.gap, this.build, this.menu);
  final String id;
  final double width;
  final double gap;
  final Widget Function() build;
  final MenuEntry Function() menu;
}

class PreviewToolbar extends StatefulWidget {
  const PreviewToolbar({
    super.key,
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.actions,
  });

  final ViewerController controller;
  final String title;
  final String? subtitle;
  final bool active;
  final ToolbarActions actions;

  @override
  State<PreviewToolbar> createState() => _PreviewToolbarState();
}

class _PreviewToolbarState extends State<PreviewToolbar> {
  OverlayEntry? _menu;
  bool _hovered = false;
  bool _titleHovered = false;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _closeMenu() {
    _menu?.remove();
    _menu = null;
  }

  void _openMenu(BuildContext anchorContext, List<MenuEntry> entries, Key key) {
    final box = anchorContext.findRenderObject();
    final overlay = Overlay.maybeOf(context);
    if (box is! RenderBox || overlay == null) return;
    _closeMenu();
    final at = box.localToGlobal(Offset(0, box.size.height + 4));
    _menu = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: MenuHost(
          key: key,
          anchor: at,
          opaque: true,
          entries: entries,
          onDismissed: _closeMenu,
        ),
      ),
    );
    overlay.insert(_menu!);
  }

  Widget Function(Color) _icon(
    String name,
    String fallback, {
    double size = 18,
  }) =>
      (color) =>
          PreviewSymbol(name, size: size, color: color, fallback: fallback);

  Widget _tip(String message, Widget child) =>
      SilicaTooltip(message: message, child: child);

  /// The width the title block needs.
  double _titleWidth(TextStyle title, TextStyle subtitle) {
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final sub = widget.subtitle;
    return math.max(
          measure(widget.title, title),
          sub == null ? 0 : measure(sub, subtitle),
        ) +
        // The document icon before it and the chevron after it, on hover.
        (widget.actions.titlePopover == null ? 0 : 14);
  }

  List<_Tool> _tools(AppLocalizations l) {
    final c = widget.controller;
    final a = widget.actions;
    final open = c.document != null;
    return [
      if (a.highlight != null)
        _Tool(
          'highlight',
          PreviewMetrics.highlightSegment +
              PreviewMetrics.highlightMenuSegment +
              PreviewMetrics.separator +
              PreviewMetrics.capsuleOutline,
          PreviewMetrics.gapAfterHighlight,
          () => Builder(
            builder: (anchor) => _tip(
              l.highlightTooltip,
              ToolbarCapsule(
                key: const ValueKey('highlight'),
                separators: true,
                children: [
                  ToolbarSegment(
                    key: const ValueKey('highlight toggle'),
                    width: PreviewMetrics.highlightSegment,
                    enabled: c.isPdf,
                    chosen: a.highlighting,
                    onTap: a.highlight,
                    icon: _icon('paintbrush', '✎'),
                  ),
                  ToolbarSegment(
                    key: const ValueKey('highlight menu'),
                    width: PreviewMetrics.highlightMenuSegment,
                    enabled: c.isPdf,
                    onPress: () => a.highlightMenu?.call(anchor),
                    icon: _icon('chevron-down', '⌄', size: 11),
                  ),
                ],
              ),
            ),
          ),
          () => MenuAction(
            l.highlightTooltip,
            enabled: c.isPdf,
            onSelected: a.highlight,
          ),
        ),
      _Tool(
        'rotate',
        PreviewMetrics.rotateSegment + PreviewMetrics.capsuleOutline,
        PreviewMetrics.gapAfterTools,
        () => _tip(
          l.rotateTooltip,
          ToolbarCapsule(
            key: const ValueKey('rotate'),
            children: [
              ToolbarSegment(
                width: PreviewMetrics.rotateSegment,
                enabled: open,
                onTap: c.rotateLeft,
                icon: _icon('arrow-counterclockwise', '↺'),
              ),
            ],
          ),
        ),
        () => MenuAction(l.rotateLeft, enabled: open, onSelected: c.rotateLeft),
      ),
      if (a.markup != null)
        _Tool(
          'markup',
          PreviewMetrics.markupButton + PreviewMetrics.capsuleOutline,
          PreviewMetrics.gapAfterMarkup,
          () => _tip(
            l.markupTooltip,
            ToolbarCapsule(
              key: const ValueKey('markup'),
              children: [
                ToolbarSegment(
                  width: PreviewMetrics.markupButton,
                  enabled: open,
                  chosen: a.markupShown,
                  onTap: a.markup,
                  icon: _icon('pencil', '✎'),
                ),
              ],
            ),
          ),
          () => MenuAction(
            a.markupShown ? l.hideMarkupToolbar : l.showMarkupToolbar,
            enabled: open,
            onSelected: a.markup,
          ),
        )
      else
        const _Tool('gap', 0, PreviewMetrics.gapAfterMarkup, _none, _noMenu),
      _Tool(
        'inspector',
        PreviewMetrics.inspectorSegment + PreviewMetrics.capsuleOutline,
        PreviewMetrics.gapBeforeSearch,
        () => _tip(
          l.inspectorTooltip,
          ToolbarCapsule(
            key: const ValueKey('inspector button'),
            children: [
              ToolbarSegment(
                width: PreviewMetrics.inspectorSegment,
                enabled: open,
                chosen: c.inspector,
                onTap: c.toggleInspector,
                icon: _icon('info', 'ⓘ'),
              ),
            ],
          ),
        ),
        () => MenuAction(
          c.inspector ? l.hideInspector : l.showInspector,
          enabled: open,
          onSelected: c.toggleInspector,
        ),
      ),
    ];
  }

  static Widget _none() => const SizedBox.shrink();
  static MenuEntry _noMenu() => const MenuDivider();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    final colors = ToolbarColors.of(context);
    final open = c.document != null;
    final titleStyle = previewText(
      PreviewMetrics.titleSize,
      weight: FontWeight.w700,
      color: widget.active ? colors.title : colors.titleInactive,
    );
    final subtitleStyle = previewText(
      PreviewMetrics.subtitleSize,
      color: colors.titleInactive,
    );
    final zoomWidth =
        PreviewMetrics.zoomOutSegment +
        PreviewMetrics.actualSizeSegment +
        PreviewMetrics.zoomInSegment +
        2 * PreviewMetrics.separator +
        PreviewMetrics.capsuleOutline;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ToolbarScope(
        active: widget.active,
        hovered: _hovered,
        child: WindowDragArea(
          child: SizedBox(
            key: const ValueKey('toolbar'),
            height: toolbarHeight,
            child: LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth;
                final tools = open ? _tools(l) : <_Tool>[];
                // Fit: the title keeps what it needs (at least titleMinWidth); then the search
                // field shrinks to its minimum, collapses to a circle, and the tools move into
                // the overflow menu from the right.
                final titleNeed = math.max(
                  PreviewMetrics.titleMinWidth,
                  _titleWidth(titleStyle, subtitleStyle),
                );
                double toolsWidth(List<_Tool> shown) =>
                    shown.fold(0, (sum, t) => sum + t.width + t.gap);
                const fixedLeft = PreviewMetrics.titleLeft;
                final zoom = open ? zoomWidth + PreviewMetrics.gapAfterZoom : 0;
                var shown = [...tools];
                final hidden = <_Tool>[];
                var search = PreviewMetrics.searchMinWidth;
                var collapsed = false;
                double need() =>
                    fixedLeft +
                    titleNeed +
                    zoom +
                    toolsWidth(shown) +
                    (hidden.isEmpty
                        ? 0
                        : PreviewMetrics.roundButton +
                              PreviewMetrics.gapBeforeSearch) +
                    (open ? search : 0) +
                    PreviewMetrics.toolbarTrailing;
                if (need() > width && open) {
                  collapsed = true;
                  search =
                      PreviewMetrics.roundButton +
                      PreviewMetrics.capsuleOutline;
                }
                while (need() > width && shown.any((t) => t.width > 0)) {
                  final last = shown.lastIndexWhere((t) => t.width > 0);
                  hidden.insert(0, shown.removeAt(last));
                }
                if (!collapsed && open) {
                  // The search field takes the rest beyond the title's need, within its range.
                  search = (width - need() + search).clamp(
                    PreviewMetrics.searchMinWidth,
                    PreviewMetrics.searchMaxWidth,
                  );
                }
                return Row(
                  children: [
                    const SizedBox(width: PreviewMetrics.viewSlotLeft),
                    SizedBox(
                      width: PreviewMetrics.viewSlot,
                      child: open
                          ? Center(
                              child: Builder(
                                builder: (anchor) => _tip(
                                  l.viewMenuTooltip,
                                  ToolbarCapsule(
                                    key: const ValueKey('view menu button'),
                                    children: [
                                      ToolbarSegment(
                                        width: PreviewMetrics.viewButton,
                                        onPress: () => _openMenu(
                                          anchor,
                                          widget.actions.viewMenu(),
                                          const ValueKey('view menu'),
                                        ),
                                        icon: (color) => Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _icon('sidebar', '▯')(color),
                                            const SizedBox(width: 2),
                                            _icon('chevron-down', '⌄', size: 9)(
                                              color,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
                    Expanded(child: _title(titleStyle, subtitleStyle)),
                    if (open) ...[
                      _tip(
                        l.zoomTooltip,
                        ToolbarCapsule(
                          key: const ValueKey('zoom'),
                          separators: true,
                          children: [
                            ToolbarSegment(
                              key: const ValueKey('zoom out'),
                              width: PreviewMetrics.zoomOutSegment,
                              enabled: c.canZoomOut,
                              onTap: c.zoomOut,
                              icon: _icon('zoom-out', '−'),
                            ),
                            ToolbarSegment(
                              key: const ValueKey('actual size'),
                              width: PreviewMetrics.actualSizeSegment,
                              enabled: !c.atActualSize,
                              onTap: () => c.actualSize(fromToolbar: true),
                              icon: (color) => Text(
                                '1:1',
                                style: previewText(
                                  12,
                                  color: color,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ToolbarSegment(
                              key: const ValueKey('zoom in'),
                              width: PreviewMetrics.zoomInSegment,
                              enabled: c.canZoomIn,
                              onTap: c.zoomIn,
                              icon: _icon('zoom-in', '+'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PreviewMetrics.gapAfterZoom),
                      for (final t in shown) ...[
                        if (t.width > 0) t.build(),
                        SizedBox(width: t.gap),
                      ],
                      if (hidden.isNotEmpty) ...[
                        Builder(
                          builder: (anchor) => ToolbarCapsule(
                            key: const ValueKey('overflow'),
                            children: [
                              ToolbarSegment(
                                width: PreviewMetrics.roundButton,
                                onPress: () => _openMenu(anchor, [
                                  for (final t in hidden)
                                    if (t.width > 0) t.menu(),
                                ], const ValueKey('overflow menu')),
                                icon: _icon('chevron-right', '»', size: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: PreviewMetrics.gapBeforeSearch),
                      ],
                      if (collapsed)
                        Builder(
                          key: widget.actions.searchCircleKey,
                          builder: (anchor) => ToolbarCapsule(
                            key: const ValueKey('search circle'),
                            children: [
                              ToolbarSegment(
                                width: PreviewMetrics.roundButton,
                                enabled: c.isPdf,
                                onPress: () =>
                                    widget.actions.collapsedSearch(anchor),
                                icon: _icon('search', '⌕'),
                              ),
                            ],
                          ),
                        )
                      else
                        widget.actions.searchField(search),
                    ],
                    const SizedBox(width: PreviewMetrics.toolbarTrailing),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// The gap between the view menu slot and the title (x 149 to 164); the document icon
  /// shows in it on hover.
  static const double _titleGap =
      PreviewMetrics.titleLeft -
      PreviewMetrics.viewSlotLeft -
      PreviewMetrics.viewSlot;

  Widget _title(TextStyle titleStyle, TextStyle subtitleStyle) {
    final popover = widget.actions.titlePopover;
    final colors = ToolbarColors.of(context);
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          key: const ValueKey('title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (widget.subtitle case final subtitle?)
          Text(
            subtitle,
            key: const ValueKey('subtitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle,
          ),
      ],
    );
    if (popover == null) {
      return Padding(
        padding: const EdgeInsets.only(left: _titleGap),
        child: Align(alignment: Alignment.centerLeft, child: text),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        onEnter: (_) => setState(() => _titleHovered = true),
        onExit: (_) => setState(() => _titleHovered = false),
        child: Builder(
          builder: (anchor) => GestureDetector(
            key: const ValueKey('title block'),
            behavior: HitTestBehavior.opaque,
            onTap: () => popover(anchor),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The document icon and the chevron show on hover.
                SizedBox(
                  width: _titleGap,
                  child: Opacity(
                    opacity: _titleHovered ? 1 : 0,
                    child: PreviewSymbol(
                      'doc',
                      size: 12,
                      color: colors.titleInactive,
                      fallback: '▢',
                    ),
                  ),
                ),
                Flexible(child: text),
                const SizedBox(width: 4),
                Opacity(
                  key: const ValueKey('title chevron'),
                  opacity: _titleHovered ? 1 : 0,
                  child: PreviewSymbol(
                    'chevron-down',
                    size: 10,
                    color: colors.titleInactive,
                    fallback: '⌄',
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
