// The toolbar (52 pt, unified with the window; Ossido draws the window buttons): the sidebar
// button with the menu of sidebar and page layout choices, the title with the page count
// below it, and on the right the zoom pair, Rotate and Search (PDFs). Share and Markup are not
// shown until they work (silica-linux/preview issues). All sizes *provisional* (PREVIEW-01).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/viewer.dart';
import '../style.dart';
import 'symbol.dart';

class PreviewToolbar extends StatefulWidget {
  const PreviewToolbar({
    super.key,
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.searchField,
    required this.onSearch,
    required this.viewMenu,
  });

  final ViewerController controller;
  final String title;
  final String? subtitle;
  final bool active;

  /// The search field, shown in place of the Search button while searching.
  final Widget searchField;
  final VoidCallback onSearch;

  /// The entries of the sidebar button's menu.
  final List<MenuEntry> Function() viewMenu;

  @override
  State<PreviewToolbar> createState() => _PreviewToolbarState();
}

class _PreviewToolbarState extends State<PreviewToolbar> {
  OverlayEntry? _menu;
  bool _hovered = false;

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  void _closeMenu() {
    _menu?.remove();
    _menu = null;
  }

  void _openMenu(BuildContext anchorContext) {
    final box = anchorContext.findRenderObject();
    final overlay = Overlay.maybeOf(context);
    if (box is! RenderBox || overlay == null) return;
    _closeMenu();
    final at = box.localToGlobal(Offset(0, box.size.height + 4));
    _menu = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: MenuHost(
          key: const ValueKey('view menu'),
          anchor: at,
          opaque: true,
          entries: widget.viewMenu(),
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    final colors = ToolbarColors.of(context);
    final open = c.document != null;
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
            child: Row(
              children: [
                const SizedBox(
                  width:
                      PreviewMetrics.windowButtonsEnd +
                      PreviewMetrics.toolbarLeadingGap,
                ),
                if (open)
                  Builder(
                    builder: (anchor) => _tip(
                      l.sidebarTooltip,
                      ToolbarCapsule(
                        key: const ValueKey('sidebar button'),
                        children: [
                          ToolbarSegment(
                            key: const ValueKey('sidebar toggle'),
                            width: PreviewMetrics.sidebarSegment,
                            chosen: c.sidebar != SidebarMode.none,
                            onTap: c.toggleSidebar,
                            icon: _icon('sidebar', '▯'),
                          ),
                          ToolbarSegment(
                            key: const ValueKey('view options'),
                            width: PreviewMetrics.chevronSegment,
                            onPress: () => _openMenu(anchor),
                            icon: _icon('chevron-down', '⌄', size: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: PreviewMetrics.titleGap),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          key: const ValueKey('title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: previewText(
                            PreviewMetrics.titleSize,
                            weight: FontWeight.w600,
                            color: widget.active
                                ? colors.title
                                : colors.titleInactive,
                          ),
                        ),
                        if (widget.subtitle case final subtitle?)
                          Text(
                            subtitle,
                            key: const ValueKey('subtitle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: previewText(
                              PreviewMetrics.subtitleSize,
                              color: colors.titleInactive,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (open) ...[
                  ToolbarCapsule(
                    key: const ValueKey('zoom'),
                    separators: true,
                    children: [
                      ToolbarSegment(
                        key: const ValueKey('zoom out'),
                        width: PreviewMetrics.zoomSegment,
                        enabled: c.canZoomOut,
                        onTap: c.zoomOut,
                        icon: _icon('zoom-out', '−'),
                      ),
                      ToolbarSegment(
                        key: const ValueKey('zoom in'),
                        width: PreviewMetrics.zoomSegment,
                        enabled: c.canZoomIn,
                        onTap: c.zoomIn,
                        icon: _icon('zoom-in', '+'),
                      ),
                    ],
                  ),
                  const SizedBox(width: PreviewMetrics.toolbarGap),
                  _tip(
                    l.rotateTooltip,
                    ToolbarCapsule(
                      key: const ValueKey('rotate'),
                      children: [
                        ToolbarSegment(
                          width: PreviewMetrics.roundButton,
                          onTap: c.rotateLeft,
                          icon: _icon('arrow-counterclockwise', '↺'),
                        ),
                      ],
                    ),
                  ),
                  if (c.isPdf) ...[
                    const SizedBox(width: PreviewMetrics.toolbarGap),
                    if (c.searching)
                      widget.searchField
                    else
                      _tip(
                        l.searchTooltip,
                        ToolbarCapsule(
                          key: const ValueKey('search'),
                          children: [
                            ToolbarSegment(
                              width: PreviewMetrics.roundButton,
                              onTap: widget.onSearch,
                              icon: _icon('search', '⌕'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                const SizedBox(width: PreviewMetrics.toolbarTrailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
