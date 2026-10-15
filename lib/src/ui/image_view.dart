// An image in the window: at the controller's scale, rotated and flipped (the turn animates in
// about 220 ms, a flip in about 185 ms, PREVIEW-02 › Markup), with its markup; animated when it
// has several frames (GIF, WebP: the reference shows a GIF's frames as pages and does not play
// it; Preview plays it), drawn as vectors when it is an SVG (the reference does not open SVG;
// Preview does).

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../images/decode.dart';
import '../model/document.dart';
import '../model/viewer.dart';
import '../style.dart';
import 'markup_view.dart';
import 'zoom_view.dart';

class ImageView extends StatefulWidget {
  const ImageView({super.key, required this.controller, this.markup = false});
  final ViewerController controller;

  /// The markup toolbar is shown: shapes can be chosen, moved and resized.
  final bool markup;

  @override
  State<ImageView> createState() => _ImageViewState();
}

class _ImageViewState extends State<ImageView>
    with SingleTickerProviderStateMixin {
  // Rotate and flip animate (≈ 220 ms and ≈ 185 ms).
  late final AnimationController _turn = AnimationController(
    vsync: this,
    value: 1,
  )..addListener(() => setState(() {}));
  late int _turns = widget.controller.turnCount;

  @override
  void didUpdateWidget(ImageView old) {
    super.didUpdateWidget(old);
    final c = widget.controller;
    if (c.turnCount != _turns) {
      _turns = c.turnCount;
      _turn.duration = c.lastFlip
          ? PreviewMetrics.flipAnimation
          : PreviewMetrics.rotateAnimation;
      unawaited(_turn.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final item = c.image;
    if (item == null) return const SizedBox.expand();
    final t = Curves.easeInOut.transform(_turn.value);
    return ZoomScroller(
      controller: c,
      builder: (context, _) {
        Widget shown = ShownImage(
          key: ValueKey(item.path),
          item: item,
          scale: c.scale,
          overlay: MarkupLayer(
            controller: c,
            item: item,
            scale: c.scale,
            interactive: widget.markup && item.writable,
          ),
        );
        if (t < 1) {
          shown = c.lastFlip
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(-1 + 2 * t, 1, 1),
                  child: shown,
                )
              : Transform.rotate(
                  angle: -c.lastTurn * (1 - t) * math.pi / 2,
                  child: shown,
                );
        }
        return shown;
      },
    );
  }
}

/// `item` at `scale`, with its rotation and flips, its markup drawn over it (or `overlay`,
/// which draws it and handles it).
class ShownImage extends StatelessWidget {
  const ShownImage({
    super.key,
    required this.item,
    required this.scale,
    this.overlay,
  });
  final ImageItem item;
  final double scale;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final size = item.size * scale;
    return RotatedBox(
      quarterTurns: item.quarterTurns,
      child: Transform.flip(
        flipX: item.flipHorizontal,
        flipY: item.flipVertical,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageContentView(content: item.content, scale: scale),
              if (overlay != null)
                overlay!
              else if (item.markup.isNotEmpty)
                CustomPaint(painter: MarkupPainter(item, null)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pixels or the vector picture of an image, filling its box.
class ImageContentView extends StatelessWidget {
  const ImageContentView({
    super.key,
    required this.content,
    required this.scale,
  });
  final ImageContent content;
  final double scale;

  @override
  Widget build(BuildContext context) => switch (content) {
    final RasterContent r when r.animation != null => AnimatedRaster(
      content: r,
      scale: scale,
    ),
    final RasterContent r => RawImage(
      image: r.image,
      fit: BoxFit.fill,
      // Enlarged far enough, the pixels show as squares.
      filterQuality: scale >= 3 ? FilterQuality.none : FilterQuality.medium,
    ),
    final VectorContent v => CustomPaint(painter: _PicturePainter(v)),
  };
}

class _PicturePainter extends CustomPainter {
  const _PicturePainter(this.content);
  final VectorContent content;

  @override
  void paint(Canvas canvas, Size size) {
    final own = content.size;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..scale(size.width / own.width, size.height / own.height)
      ..drawPicture(content.picture.picture)
      ..restore();
  }

  @override
  bool shouldRepaint(_PicturePainter old) => old.content != content;
}

/// An animated image: its frames in a loop, each for its own duration.
class AnimatedRaster extends StatefulWidget {
  const AnimatedRaster({super.key, required this.content, required this.scale});
  final RasterContent content;
  final double scale;

  @override
  State<AnimatedRaster> createState() => _AnimatedRasterState();
}

class _AnimatedRasterState extends State<AnimatedRaster> {
  ui.Image? _frame;
  Timer? _timer;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _schedule(const Duration(milliseconds: 100));
  }

  void _schedule(Duration wait) {
    // A frame without a duration shows for 100 ms, as browsers do.
    final delay = wait < const Duration(milliseconds: 20)
        ? const Duration(milliseconds: 100)
        : wait;
    _timer = Timer(delay, _advance);
  }

  Future<void> _advance() async {
    final codec = widget.content.animation;
    if (codec == null || _gone) return;
    try {
      final next = await codec.getNextFrame();
      if (_gone) {
        next.image.dispose();
        return;
      }
      setState(() {
        _frame?.dispose();
        _frame = next.image;
      });
      _schedule(next.duration);
    } on Object {
      // A broken frame stops the animation on the last good one.
    }
  }

  @override
  void dispose() {
    _gone = true;
    _timer?.cancel();
    _frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawImage(
    image: _frame ?? widget.content.image,
    fit: BoxFit.fill,
    filterQuality: widget.scale >= 3
        ? FilterQuality.none
        : FilterQuality.medium,
  );
}
