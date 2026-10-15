// An image in the window: at the controller's scale, rotated and flipped, animated when it has
// several frames (GIF, WebP), drawn as vectors when it is an SVG.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../images/decode.dart';
import '../model/document.dart';
import '../model/viewer.dart';
import 'zoom_view.dart';

class ImageView extends StatelessWidget {
  const ImageView({super.key, required this.controller});
  final ViewerController controller;

  @override
  Widget build(BuildContext context) {
    final item = controller.image;
    if (item == null) return const SizedBox.expand();
    return ZoomScroller(
      controller: controller,
      builder: (context, _) => ShownImage(
        key: ValueKey(item.path),
        item: item,
        scale: controller.scale,
      ),
    );
  }
}

/// `item` at `scale`, with its rotation and flips.
class ShownImage extends StatelessWidget {
  const ShownImage({super.key, required this.item, required this.scale});
  final ImageItem item;
  final double scale;

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
          child: ImageContentView(content: item.content, scale: scale),
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
