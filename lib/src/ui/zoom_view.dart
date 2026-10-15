// The scrolling, zooming area shared by images and PDF pages: content larger than the window
// scrolls both ways, smaller content sits in the middle on the canvas colour. Pinch on a
// trackpad and ⌘-scroll (or Ctrl-scroll) zoom around the pointer.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../model/viewer.dart';
import '../style.dart';

/// Pinch and ⌘-scroll zoom over `child`, at the pointer.
class ZoomGestures extends StatefulWidget {
  const ZoomGestures({
    super.key,
    required this.controller,
    required this.child,
  });

  final ViewerController controller;
  final Widget child;

  @override
  State<ZoomGestures> createState() => _ZoomGesturesState();
}

class _ZoomGesturesState extends State<ZoomGestures> {
  double _lastScale = 1;

  static bool get _commandHeld {
    final keys = HardwareKeyboard.instance;
    return keys.isMetaPressed || keys.isControlPressed;
  }

  void _signal(PointerSignalEvent event) {
    if (event is PointerScaleEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        widget.controller.zoomBy(
          (e as PointerScaleEvent).scale,
          focal: e.localPosition,
        );
      });
      return;
    }
    if (event is! PointerScrollEvent || !_commandHeld) return;
    // Registered first, the zoom wins over the scroll views below.
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final scroll = e as PointerScrollEvent;
      widget.controller.zoomBy(
        math.exp(-scroll.scrollDelta.dy / PreviewMetrics.scrollZoomPoints),
        focal: scroll.localPosition,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: _signal,
    onPointerPanZoomStart: (_) => _lastScale = 1,
    onPointerPanZoomUpdate: (e) {
      if (e.scale == _lastScale || e.scale <= 0) return;
      widget.controller.zoomBy(e.scale / _lastScale, focal: e.localPosition);
      _lastScale = e.scale;
    },
    child: widget.child,
  );
}

/// The scroll area: `content` (sized by the controller's [ViewerController.contentSize])
/// centred when smaller than the view, scrolling when larger. With [vertical] the child is
/// the vertical scroll view itself (the continuous PDF layout, built lazily).
class ZoomScroller extends StatelessWidget {
  const ZoomScroller({
    super.key,
    required this.controller,
    required this.builder,
    this.vertical = false,
  });

  final ViewerController controller;

  /// Builds the content for the view size.
  final Widget Function(BuildContext context, Size viewport) builder;

  /// The child scrolls vertically by itself (it uses [ViewerController.vertical]).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    return ColoredBox(
      color: colors.canvas,
      child: LayoutBuilder(
        builder: (context, box) {
          final view = box.biggest;
          controller.setViewport(view);
          final content = controller.contentSize;
          final width = math.max(view.width, content.width);
          final height = math.max(view.height, content.height);
          final behavior = ScrollConfiguration.of(
            context,
          ).copyWith(scrollbars: false);
          final inner = vertical
              ? SizedBox(
                  width: width,
                  height: view.height,
                  child: builder(context, view),
                )
              : SizedBox(
                  width: width,
                  height: view.height,
                  child: SingleChildScrollView(
                    key: const ValueKey('vertical scroll'),
                    controller: controller.vertical,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Center(
                        child: SizedBox(
                          width: content.width,
                          height: content.height,
                          child: builder(context, view),
                        ),
                      ),
                    ),
                  ),
                );
          return ZoomGestures(
            controller: controller,
            child: ScrollConfiguration(
              behavior: behavior,
              child: SilicaScrollbar(
                controller: controller.vertical,
                notificationPredicate: (n) => n.depth == 1,
                child: SilicaScrollbar(
                  controller: controller.horizontal,
                  axis: Axis.horizontal,
                  notificationPredicate: (n) => n.depth == 0,
                  child: SingleChildScrollView(
                    key: const ValueKey('horizontal scroll'),
                    controller: controller.horizontal,
                    scrollDirection: Axis.horizontal,
                    child: inner,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
