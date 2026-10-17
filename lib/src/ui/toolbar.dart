// The toolbar (kit `Apps/Preview/Toolbar PDF`, `Toolbar Image`): 52 pt, flat on
// `Surface/Window`, built from pieces; its controls are Glass/Regular capsules 32 pt tall.
// Left to right: the window buttons' slot (Ossido draws them), the view piece (the sidebar
// glyph and a chevron, opening the view menu), the title block (the name over a second line:
// "Page N of M", "Edited", "N documents"; clicking it opens the title popover), then the zoom
// group (out, actual size, in), the highlight group (PDF; disabled for images), Rotate, the
// markup button, the inspector button and the search field. When the window is too narrow the
// search field becomes a magnifier button and the tools that do not fit go into an overflow
// button with a menu.
//
// Share (the system share service, silica-desktop#217) follows the inspector and is drawn only
// when the service has targets for the open file. Not shown in Preview: remove background (#19)
// and form filling (#15).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/viewer.dart';
import '../style.dart';
import 'menu_host.dart';
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
    this.share,
  });

  /// Opens the Share menu under [anchor]'s button (null: the service has no targets for the
  /// open file, so the button is not drawn).
  final void Function(BuildContext anchor)? share;

  /// The entries of the view menu.
  final List<MenuEntry> Function() viewMenu;

  /// Opens the title popover under the title (null: no popover, nothing open).
  final void Function(BuildContext anchor)? titlePopover;

  /// The search field (200 wide).
  final Widget Function() searchField;

  /// The magnifier button shown in a narrow window: opens the search field in a popover.
  final void Function(BuildContext anchor) collapsedSearch;

  /// The key of the magnifier button (⌘F opens its popover).
  final GlobalKey? searchCircleKey;

  /// The highlight button and its menu chevron (null: not offered); [highlighting]: on.
  final VoidCallback? highlight;
  final void Function(BuildContext anchor)? highlightMenu;
  final bool highlighting;

  /// The markup button (null: not offered); [markupShown]: the markup toolbar is shown.
  final VoidCallback? markup;
  final bool markupShown;
}

/// One tool of the right side: its width (a piece, 4 pt of padding on each side), and how to
/// build it or list it in the overflow menu.
class _Tool {
  const _Tool(this.id, this.width, this.build, this.menu);
  final String id;
  final double width;
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

  /// The overflow button, where the Share menu opens when Share sits in the overflow menu.
  BuildContext? _overflowAnchor;

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
        child: PreviewMenuHost(
          key: key,
          anchor: at,
          entries: entries,
          onDismissed: _closeMenu,
        ),
      ),
    );
    overlay.insert(_menu!);
  }

  Widget _icon(String name, String fallback, {double size = 20}) => Builder(
    builder: (context) => PreviewSymbol(
      name,
      size: size,
      color: IconTheme.of(context).color ?? const Color(0xFF000000),
      fallback: fallback,
    ),
  );

  /// A piece holding one control: 4 pt on each side.
  Widget _piece(Widget child) => AmalfiToolbarPiece(child: child);

  /// A one-segment capsule (a 36 pt circle), `chosen` when its function is on.
  Widget _button({
    required Key key,
    required String name,
    required String fallback,
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
    bool chosen = false,
  }) => AmalfiActionSegments(
    key: key,
    selected: chosen ? const {0} : const {},
    onPressed: enabled && onTap != null ? (_) => onTap() : null,
    segments: [
      AmalfiSegment.icon(
        _icon(name, fallback),
        semanticLabel: label,
        tooltip: label,
      ),
    ],
  );

  static const double _controlsWidth = AmalfiToolbarPieceMetrics.controlsWidth;

  List<_Tool> _tools(AppLocalizations l) {
    final c = widget.controller;
    final a = widget.actions;
    final open = c.document != null;
    return [
      if (a.highlight != null)
        _Tool(
          'highlight',
          PreviewMetrics.highlightPiece,
          () => Builder(
            builder: (anchor) => _piece(
              AmalfiActionSegments(
                key: const ValueKey('highlight'),
                selected: a.highlighting ? const {0} : const {},
                // The chevron's segment opens the colour menu, the other toggles.
                onPressed: c.isPdf
                    ? (i) => i == 0
                          ? a.highlight?.call()
                          : a.highlightMenu?.call(anchor)
                    : null,
                segments: [
                  AmalfiSegment.icon(
                    _icon('paintbrush', '✎'),
                    semanticLabel: l.highlightTooltip,
                    tooltip: l.highlightTooltip,
                  ),
                  AmalfiSegment.icon(
                    _icon('chevron-down', '⌄'),
                    semanticLabel: l.highlightTooltip,
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
        PreviewMetrics.buttonPiece,
        () => _piece(
          _button(
            key: const ValueKey('rotate'),
            name: 'arrow-counterclockwise',
            fallback: '↺',
            label: l.rotateTooltip,
            enabled: open,
            onTap: c.rotateLeft,
          ),
        ),
        () => MenuAction(l.rotateLeft, enabled: open, onSelected: c.rotateLeft),
      ),
      if (a.markup != null)
        _Tool(
          'markup',
          PreviewMetrics.buttonPiece,
          () => _piece(
            _button(
              key: const ValueKey('markup'),
              name: 'pencil',
              fallback: '✎',
              label: l.markupTooltip,
              enabled: open,
              chosen: a.markupShown,
              onTap: a.markup,
            ),
          ),
          () => MenuAction(
            a.markupShown ? l.hideMarkupToolbar : l.showMarkupToolbar,
            enabled: open,
            onSelected: a.markup,
          ),
        ),
      _Tool(
        'inspector',
        PreviewMetrics.buttonPiece,
        () => _piece(
          _button(
            key: const ValueKey('inspector button'),
            name: 'info',
            fallback: 'ⓘ',
            label: l.inspectorTooltip,
            enabled: open,
            chosen: c.inspector,
            onTap: c.toggleInspector,
          ),
        ),
        () => MenuAction(
          c.inspector ? l.hideInspector : l.showInspector,
          enabled: open,
          onSelected: c.toggleInspector,
        ),
      ),
      if (a.share != null)
        _Tool(
          'share',
          PreviewMetrics.buttonPiece,
          () => Builder(
            builder: (anchor) => _piece(
              _button(
                key: const ValueKey('share'),
                name: 'share',
                fallback: '⇪',
                label: l.shareTooltip,
                enabled: open,
                onTap: () => a.share?.call(anchor),
              ),
            ),
          ),
          () => MenuAction(
            l.shareTooltip,
            enabled: open,
            onSelected: () {
              final anchor = _overflowAnchor;
              if (anchor != null && anchor.mounted) a.share?.call(anchor);
            },
          ),
        ),
    ];
  }

  /// The width of `text` in `style`.
  static double _measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    final a = widget.actions;
    final open = c.document != null;
    final colors = AmalfiTheme.of(context).colors;
    final titleStyle = AmalfiType.headline(color: colors.textPrimary);
    final subtitleStyle = AmalfiType.caption(color: colors.textTertiary);
    return WindowDragArea(
      child: SizedBox(
        key: const ValueKey('toolbar'),
        height: AmalfiToolbarMetrics.toolbarHeight,
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth;
            final tools = open ? _tools(l) : <_Tool>[];
            // Fit: the title keeps what it needs (at least titleMinWidth); then the search
            // field collapses into its button, and the tools move into the overflow menu
            // from the right.
            final sub = widget.subtitle;
            final titleNeed = math.max(
              PreviewMetrics.titleMinWidth,
              math.max(
                    _measure(widget.title, titleStyle),
                    sub == null ? 0 : _measure(sub, subtitleStyle),
                  ) +
                  2 * AmalfiToolbarPieceMetrics.titlePadding,
            );
            final shown = [...tools];
            final hidden = <_Tool>[];
            var collapsed = false;
            double need() =>
                _controlsWidth +
                (open ? PreviewMetrics.viewPiece : 0) +
                titleNeed +
                (open ? PreviewMetrics.zoomPiece : 0) +
                shown.fold<double>(0, (sum, t) => sum + t.width) +
                (hidden.isEmpty ? 0 : PreviewMetrics.buttonPiece) +
                (open
                    ? (collapsed
                          ? PreviewMetrics.buttonPiece
                          : PreviewMetrics.searchPiece)
                    : 0) +
                PreviewMetrics.toolbarTrailing;
            if (open && need() > width) collapsed = true;
            while (open && need() > width && shown.isNotEmpty) {
              hidden.insert(0, shown.removeLast());
            }
            return AmalfiToolbar(
              active: widget.active,
              padding: const EdgeInsets.only(
                right: PreviewMetrics.toolbarTrailing,
              ),
              children: [
                // Ossido draws the window buttons here, at x 18 (measured).
                const SizedBox(width: _controlsWidth),
                if (open)
                  Builder(
                    builder: (anchor) => _piece(
                      AmalfiActionSegments(
                        key: const ValueKey('view menu button'),
                        onPressed: (_) => _openMenu(
                          anchor,
                          a.viewMenu(),
                          const ValueKey('view menu'),
                        ),
                        segments: [
                          AmalfiSegment.icon(
                            _icon('sidebar', '▯'),
                            semanticLabel: l.viewMenuTooltip,
                            tooltip: l.viewMenuTooltip,
                          ),
                          AmalfiSegment.icon(
                            _icon('chevron-down', '⌄'),
                            semanticLabel: l.viewMenuTooltip,
                            tooltip: l.viewMenuTooltip,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: open ? _title() : Center(child: _title())),
                if (open) ...[
                  _piece(
                    AmalfiActionSegments(
                      key: const ValueKey('zoom'),
                      onPressed: (i) => switch (i) {
                        0 => c.zoomOut(),
                        1 => c.actualSize(fromToolbar: true),
                        _ => c.zoomIn(),
                      },
                      segments: [
                        AmalfiSegment.icon(
                          _icon('zoom-out', '−'),
                          semanticLabel: l.zoomTooltip,
                          tooltip: l.zoomTooltip,
                          enabled: c.canZoomOut,
                        ),
                        AmalfiSegment.icon(
                          _icon('fullscreen', '1:1'),
                          semanticLabel: l.zoomTooltip,
                          enabled: !c.atActualSize,
                        ),
                        AmalfiSegment.icon(
                          _icon('zoom-in', '+'),
                          semanticLabel: l.zoomTooltip,
                          enabled: c.canZoomIn,
                        ),
                      ],
                    ),
                  ),
                  for (final t in shown) t.build(),
                  if (hidden.isNotEmpty)
                    Builder(
                      builder: (anchor) => _piece(
                        _button(
                          key: const ValueKey('overflow'),
                          name: 'chevron-right',
                          fallback: '»',
                          label: l.overflowTooltip,
                          enabled: true,
                          onTap: () => _openMenu(_overflowAnchor = anchor, [
                            for (final t in hidden) t.menu(),
                          ], const ValueKey('overflow menu')),
                        ),
                      ),
                    ),
                  if (collapsed)
                    Builder(
                      key: a.searchCircleKey,
                      builder: (anchor) => _piece(
                        _button(
                          key: const ValueKey('search circle'),
                          name: 'search',
                          fallback: '⌕',
                          label: l.searchPlaceholder,
                          enabled: c.isPdf,
                          onTap: () => a.collapsedSearch(anchor),
                        ),
                      ),
                    )
                  else
                    _piece(a.searchField()),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// The title block (the name over the second line); clicking it opens the title popover.
  Widget _title() {
    final popover = widget.actions.titlePopover;
    final open = widget.controller.document != null;
    final block = AmalfiTitlePiece(
      title: widget.title,
      subtitle: widget.subtitle,
      active: widget.active,
    );
    // The piece is as wide as its text (up to the room there is), at the leading side.
    final placed = open
        ? Align(alignment: AlignmentDirectional.centerStart, child: block)
        : block;
    if (popover == null) return placed;
    return Builder(
      builder: (anchor) => GestureDetector(
        key: const ValueKey('title block'),
        behavior: HitTestBehavior.opaque,
        onTap: () => popover(anchor),
        child: placed,
      ),
    );
  }
}
