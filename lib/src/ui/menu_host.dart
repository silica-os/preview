// Menus over the window: the entries the app declares (`MenuEntry`, shared with the menu bar's
// model) shown as an Amalfi menu (Glass/Thick, rows of 24) at a point, dismissed by a press
// outside, by Esc or by choosing an item. A `MenuCustom` row (the colour row of a highlight's
// menu) is drawn in a panel of its own above the menu.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// `entries` as Amalfi menu entries; a [MenuCustom] has no Amalfi equivalent and is left out
/// (see [PreviewMenuHost]).
List<AmalfiMenuEntry> amalfiEntries(List<MenuEntry> entries) => [
  for (final e in entries)
    switch (e) {
      MenuAction() => AmalfiMenuAction(
        e.label,
        shortcut: e.shortcut,
        checked: e.checked,
        enabled: e.enabled,
        icon: e.icon == null
            ? null
            : Builder(
                builder: (context) => e.icon!(
                  IconTheme.of(context).color ?? const Color(0xFF000000),
                ),
              ),
        onSelected: e.onSelected,
        submenu: e.submenu == null ? null : amalfiEntries(e.submenu!),
      ),
      MenuDivider() => const AmalfiMenuDivider(),
      MenuSection() => AmalfiMenuSection(e.label),
      MenuCustom() => null,
    },
].whereType<AmalfiMenuEntry>().toList();

/// A menu at [anchor] (global), filling the overlay entry that holds it.
class PreviewMenuHost extends StatefulWidget {
  const PreviewMenuHost({
    super.key,
    required this.entries,
    required this.anchor,
    required this.onDismissed,
  });

  final List<MenuEntry> entries;
  final Offset anchor;
  final VoidCallback onDismissed;

  @override
  State<PreviewMenuHost> createState() => _PreviewMenuHostState();
}

class _PreviewMenuHostState extends State<PreviewMenuHost> {
  bool _closed = false;

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final custom = [
      for (final e in widget.entries)
        if (e is MenuCustom) e,
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _close(),
          ),
        ),
        CustomSingleChildLayout(
          delegate: _Layout(widget.anchor),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                for (final row in custom)
                  AmalfiGlass(
                    material: AmalfiMaterials.thick,
                    radius: AmalfiMenuMetrics.radius,
                    opaque: true,
                    kind: AmalfiGlassKind.menu,
                    child: SizedBox(
                      height: row.height,
                      width: row.width,
                      child: row.builder(context, _close),
                    ),
                  ),
                AmalfiMenu(
                  entries: amalfiEntries(widget.entries),
                  opaque: true,
                  autofocus: true,
                  onDismiss: _close,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Layout extends SingleChildLayoutDelegate {
  const _Layout(this.anchor);
  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = anchor.dx;
    var y = anchor.dy;
    if (x + childSize.width > size.width) x = size.width - childSize.width;
    if (y + childSize.height > size.height) y = size.height - childSize.height;
    return Offset(x < 0 ? 0 : x, y < 0 ? 0 : y);
  }

  @override
  bool shouldRelayout(_Layout old) => old.anchor != anchor;
}
