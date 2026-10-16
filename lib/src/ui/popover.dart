// A popover opened from a control by code (the title, the markup buttons, the note): an Amalfi
// popover (Glass/Thick, radius 16, an arrow towards the control) placed below it (or where it
// fits), closing on a click outside and on Esc.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// An open popover; [close] removes it.
class PopoverHandle {
  PopoverHandle._(this._entry, this._onClosed, this._scope);
  final OverlayEntry _entry;
  final VoidCallback? _onClosed;
  final FocusScopeNode _scope;
  bool _closed = false;

  bool get isOpen => !_closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _entry.remove();
    // After the entry's widgets let go of it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scope.dispose());
    _onClosed?.call();
  }
}

/// Shows `builder`'s content in a popover whose body is `size` (the content with its 16 pt
/// padding) under the widget of `anchor`; the arrow adds its depth on the anchor's side.
/// `builder` gets the handle to close it.
PopoverHandle? showPopover(
  BuildContext anchor, {
  required Size size,
  required Widget Function(BuildContext context, PopoverHandle handle) builder,
  Key? key,
  AmalfiPopoverPlacement preferred = AmalfiPopoverPlacement.below,
  VoidCallback? onClosed,
}) {
  final box = anchor.findRenderObject();
  final overlayState = Overlay.maybeOf(anchor);
  if (box is! RenderBox || !box.attached || overlayState == null) return null;
  final overlayBox = overlayState.context.findRenderObject();
  if (overlayBox is! RenderBox) return null;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
  final theme = AmalfiTheme.of(anchor);
  late final PopoverHandle handle;
  final scope = FocusScopeNode(debugLabel: 'popover');
  final outer = Size(
    size.width +
        (preferred == AmalfiPopoverPlacement.leading ||
                preferred == AmalfiPopoverPlacement.trailing
            ? AmalfiPopoverMetrics.arrowDepth
            : 0),
    size.height +
        (preferred == AmalfiPopoverPlacement.below ||
                preferred == AmalfiPopoverPlacement.above
            ? AmalfiPopoverMetrics.arrowDepth
            : 0),
  );
  final entry = OverlayEntry(
    builder: (context) {
      final place = amalfiPopoverLayout(
        anchor: rect,
        size: outer,
        bounds: overlayBox.size,
        placement: preferred,
        textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
      return AmalfiTheme(
        brightness: theme.brightness,
        app: theme.app,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) {
                  if (!(place.offset & outer).contains(e.localPosition)) {
                    handle.close();
                  }
                },
              ),
            ),
            Positioned(
              left: place.offset.dx,
              top: place.offset.dy,
              width: outer.width,
              height: outer.height,
              child: FocusScope(
                node: scope,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        handle.close,
                  },
                  child: AmalfiPopover(
                    key: key,
                    arrowEdge: amalfiPopoverArrowEdge(place.placement),
                    arrowOffset: place.arrowOffset,
                    opaque: true,
                    child: Builder(
                      builder: (context) => builder(context, handle),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  handle = PopoverHandle._(entry, onClosed, scope);
  overlayState.insert(entry);
  // Once built, the popover has the keyboard: its first field or control.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (handle._closed) return;
    final first = scope.traversalDescendants
        .where((n) => n.canRequestFocus)
        .firstOrNull;
    (first ?? scope).requestFocus();
  });
  WidgetsBinding.instance.ensureVisualUpdate();
  return handle;
}
