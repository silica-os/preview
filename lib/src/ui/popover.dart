// A popover opened from a control by code (the title, the markup buttons): silica_ui's popover
// body with its arrow towards the control, placed below it (or where it fits), closing on a
// click outside and on Esc.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// An open popover; [close] removes it.
class PopoverHandle {
  PopoverHandle._(this._entry, this._onClosed);
  final OverlayEntry _entry;
  final VoidCallback? _onClosed;
  bool _closed = false;

  bool get isOpen => !_closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _entry.remove();
    _onClosed?.call();
  }
}

/// Shows `builder`'s content in a popover of `size` under the widget of `anchor`. `builder`
/// gets the handle to close it.
PopoverHandle? showPopover(
  BuildContext anchor, {
  required Size size,
  required Widget Function(BuildContext context, PopoverHandle handle) builder,
  Key? key,
  TipEdge preferred = TipEdge.bottom,
  VoidCallback? onClosed,
}) {
  final box = anchor.findRenderObject();
  final overlayState = Overlay.maybeOf(anchor);
  if (box is! RenderBox || !box.attached || overlayState == null) return null;
  final overlayBox = overlayState.context.findRenderObject();
  if (overlayBox is! RenderBox) return null;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlayBox) & box.size;
  late final PopoverHandle handle;
  final entry = OverlayEntry(
    builder: (context) {
      final place = placePopover(
        anchor: rect,
        size: size,
        bounds: Offset.zero & overlayBox.size,
        preferred: preferred,
      );
      return Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                if (!place.rect.contains(e.localPosition)) handle.close();
              },
            ),
          ),
          Positioned.fromRect(
            rect: place.rect,
            child: FocusScope(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      handle.close,
                },
                child: PopoverPanel(
                  key: key,
                  edge: place.edge,
                  tip: place.tip,
                  child: Builder(
                    builder: (context) => builder(context, handle),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
  handle = PopoverHandle._(entry, onClosed);
  overlayState.insert(entry);
  return handle;
}
