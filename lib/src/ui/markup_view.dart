// The markup over an image (PREVIEW-02 › Markup › Annotations on the image): the shapes and
// text boxes, and, while the markup toolbar is shown, choosing them with a click, moving them by
// dragging, resizing them by their handles (10 pt circles #316ec8 with a white ring, at the
// corners and the middle of the sides, or at a line's ends), and editing a text box's text with
// a double click. Each change is one step of Undo.

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../model/document.dart';
import '../model/markup.dart';
import '../model/viewer.dart';
import '../style.dart';

/// Paints `item`'s markup in a box of the image's displayed size, with the handles of `chosen`.
class MarkupPainter extends CustomPainter {
  MarkupPainter(this.item, this.chosen, {this.handleColor});
  final ImageItem item;
  final MarkupShape? chosen;
  final Color? handleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final own = item.content.size;
    final kx = size.width / own.width;
    final ky = size.height / own.height;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..scale(kx, ky);
    for (final shape in item.markup) {
      shape.paint(canvas);
    }
    canvas.restore();
    final shape = chosen;
    if (shape == null || !item.markup.contains(shape)) return;
    final ring = Paint()..color = const Color(0xFFFFFFFF);
    final dot = Paint()..color = handleColor ?? const Color(0xFF316EC8);
    if (shape.kind == ShapeKind.text) {
      // A thin gray outline around a text box.
      final r = shape.rect;
      canvas.drawRect(
        Rect.fromLTRB(r.left * kx, r.top * ky, r.right * kx, r.bottom * ky),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF9A9A9A)
          ..strokeWidth = 1,
      );
    }
    for (final h in handlesOf(shape)) {
      final p = Offset(h.dx * kx, h.dy * ky);
      canvas
        ..drawCircle(p, PreviewMetrics.handle / 2 + 1, ring)
        ..drawCircle(p, PreviewMetrics.handle / 2, dot);
    }
  }

  @override
  bool shouldRepaint(MarkupPainter old) => true;
}

/// The handles of a shape, in image pixels: a line's two ends, or the corners and the middles
/// of the sides (a text box: its two sides).
List<Offset> handlesOf(MarkupShape shape) {
  if (shape.isLine) return [shape.a, shape.b];
  final r = shape.rect;
  if (shape.kind == ShapeKind.text) return [r.centerLeft, r.centerRight];
  return [
    r.topLeft,
    r.topCenter,
    r.topRight,
    r.centerRight,
    r.bottomRight,
    r.bottomCenter,
    r.bottomLeft,
    r.centerLeft,
  ];
}

class MarkupLayer extends StatefulWidget {
  const MarkupLayer({
    super.key,
    required this.controller,
    required this.item,
    required this.scale,
    required this.interactive,
  });
  final ViewerController controller;
  final ImageItem item;
  final double scale;
  final bool interactive;

  @override
  State<MarkupLayer> createState() => _MarkupLayerState();
}

class _MarkupLayerState extends State<MarkupLayer> {
  List<MarkupShape>? _before;
  int? _handle;
  bool _moving = false;
  Offset _last = Offset.zero;
  MarkupShape? _editing;
  final TextEditingController _text = TextEditingController();

  ViewerController get c => widget.controller;
  ImageItem get item => widget.item;

  @override
  void dispose() {
    _commitText();
    _text.dispose();
    super.dispose();
  }

  /// Displayed points per image pixel.
  double _k(Size box) => box.width / item.content.size.width;

  MarkupShape? _shapeAt(Offset p, double slop) {
    for (final shape in item.markup.reversed) {
      if (shape.hit(p, slop)) return shape;
    }
    return null;
  }

  void _start(Offset local, Size box) {
    final k = _k(box);
    final p = local / k;
    final slop = PreviewMetrics.handle / k;
    final chosen = c.chosenShape;
    _handle = null;
    _moving = false;
    if (chosen != null && item.markup.contains(chosen)) {
      final handles = handlesOf(chosen);
      for (var i = 0; i < handles.length; i++) {
        if ((handles[i] - p).distance <= slop) {
          _handle = i;
          break;
        }
      }
    }
    if (_handle == null) {
      final hit = _shapeAt(p, slop / 2);
      if (hit == null) return;
      if (hit != chosen) c.chooseShape(hit);
      _moving = true;
    }
    _before = [for (final s in item.markup) s.copy()];
    _last = p;
  }

  void _update(Offset local, Size box) {
    final shape = c.chosenShape;
    if (shape == null || _before == null) return;
    final p = local / _k(box);
    final d = p - _last;
    _last = p;
    if (_moving) {
      shape.translate(d);
    } else if (_handle != null) {
      _resize(shape, _handle!, p);
    }
    c.changed();
  }

  void _resize(MarkupShape shape, int handle, Offset p) {
    if (shape.isLine) {
      handle == 0 ? shape.a = p : shape.b = p;
      return;
    }
    var r = shape.rect;
    if (shape.kind == ShapeKind.text) {
      r = handle == 0
          ? Rect.fromLTRB(math.min(p.dx, r.right - 8), r.top, r.right, r.bottom)
          : Rect.fromLTRB(r.left, r.top, math.max(p.dx, r.left + 8), r.bottom);
    } else {
      var (l, t, rt, b) = (r.left, r.top, r.right, r.bottom);
      switch (handle) {
        case 0:
          (l, t) = (p.dx, p.dy);
        case 1:
          t = p.dy;
        case 2:
          (rt, t) = (p.dx, p.dy);
        case 3:
          rt = p.dx;
        case 4:
          (rt, b) = (p.dx, p.dy);
        case 5:
          b = p.dy;
        case 6:
          (l, b) = (p.dx, p.dy);
        case 7:
          l = p.dx;
      }
      r = Rect.fromLTRB(
        math.min(l, rt),
        math.min(t, b),
        math.max(l, rt),
        math.max(t, b),
      );
    }
    shape
      ..a = r.topLeft
      ..b = r.bottomRight;
  }

  void _end() {
    final before = _before;
    _before = null;
    _handle = null;
    _moving = false;
    if (before == null) return;
    c.recordMarkup(item, before);
  }

  void _tap(Offset local, Size box) {
    final k = _k(box);
    final hit = _shapeAt(local / k, PreviewMetrics.handle / 2 / k);
    _commitText();
    c.chooseShape(hit);
  }

  void _doubleTap(Offset local, Size box) {
    final k = _k(box);
    final hit = _shapeAt(local / k, PreviewMetrics.handle / 2 / k);
    if (hit == null || hit.kind != ShapeKind.text) return;
    c.chooseShape(hit);
    setState(() {
      _editing = hit;
      _text.text = hit.text;
    });
  }

  void _commitText() {
    final shape = _editing;
    if (shape == null) return;
    _editing = null;
    if (shape.text == _text.text || !item.markup.contains(shape)) return;
    final before = [for (final s in item.markup) s.copy()];
    shape.text = _text.text;
    c.recordMarkup(item, before);
  }

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      painter: MarkupPainter(
        item,
        widget.interactive ? c.chosenShape : null,
        handleColor: PreviewColors.of(context).handle,
      ),
    );
    if (!widget.interactive) return painter;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final k = _k(size);
        final editing = _editing;
        Offset? tapAt;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              key: const ValueKey('markup layer'),
              behavior: HitTestBehavior.opaque,
              // A drag starts where the button went down (a handle, a shape).
              dragStartBehavior: DragStartBehavior.down,
              onTapDown: (d) => tapAt = d.localPosition,
              onTap: () {
                if (tapAt != null) _tap(tapAt!, size);
              },
              onDoubleTapDown: (d) => _doubleTap(d.localPosition, size),
              onDoubleTap: () {},
              onPanStart: (d) => _start(d.localPosition, size),
              onPanUpdate: (d) => _update(d.localPosition, size),
              onPanEnd: (_) => _end(),
              onPanCancel: _end,
              child: painter,
            ),
            if (editing != null)
              Positioned(
                left: editing.rect.left * k,
                top: editing.rect.top * k,
                width: math.max(60, editing.rect.width * k),
                child: AmalfiTextField(
                  key: const ValueKey('text box field'),
                  controller: _text,
                  autofocus: true,
                  size: AmalfiFieldSize.small,
                  width: math.max(60, editing.rect.width * k),
                  semanticLabel: 'Text',
                  onSubmitted: (_) => setState(_commitText),
                ),
              ),
          ],
        );
      },
    );
  }
}
