// Markup on an image (PREVIEW-02 › Markup): shapes (line, arrow, rectangle, rounded rectangle,
// oval, speech bubble, star, polygon) and text boxes, each with a border colour, a fill, a line
// width, dashes, line ends and a shadow, or a font size, colour, style and alignment. They are
// kept in the image's own pixels and written into it when the image is saved or exported.

import 'dart:math' as math;
import 'dart:ui' hide TextStyle;

import 'package:flutter/painting.dart' show TextStyle, TextDecoration;

enum ShapeKind {
  line,
  arrow,
  rectangle,
  roundedRectangle,
  oval,
  speechBubble,
  star,
  polygon,
  text,
}

/// Which ends of a line carry an arrowhead.
enum LineEnds { none, start, end, both }

/// The line widths of the shape style popover, thin to thick. *Provisional* (the six widths
/// were seen, not measured; the rectangle's default is 3).
const List<double> lineWidths = [1, 2, 3, 5, 8, 12];

class MarkupShape {
  MarkupShape({
    required this.kind,
    required this.a,
    required this.b,
    this.stroke = const Color(0xFF000000),
    this.fill,
    this.lineWidth = 3,
    this.dashed = false,
    this.shadow = false,
    LineEnds? ends,
    this.text = '',
    this.fontSize = 24,
    this.textColor = const Color(0xFFFF2600),
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.align = TextAlign.left,
  }) : ends = ends ?? (kind == ShapeKind.arrow ? LineEnds.end : LineEnds.none);

  final ShapeKind kind;

  /// Two corners (or a line's two ends), in image pixels.
  Offset a;
  Offset b;

  Color stroke;
  Color? fill;
  double lineWidth;
  bool dashed;
  bool shadow;
  LineEnds ends;

  // Text boxes.
  String text;
  double fontSize;
  Color textColor;
  bool bold;
  bool italic;
  bool underline;
  TextAlign align;

  bool get isLine => kind == ShapeKind.line || kind == ShapeKind.arrow;

  Rect get rect => Rect.fromPoints(a, b);

  MarkupShape copy() => MarkupShape(
    kind: kind,
    a: a,
    b: b,
    stroke: stroke,
    fill: fill,
    lineWidth: lineWidth,
    dashed: dashed,
    shadow: shadow,
    ends: ends,
    text: text,
    fontSize: fontSize,
    textColor: textColor,
    bold: bold,
    italic: italic,
    underline: underline,
    align: align,
  );

  /// Moves the shape by `d`.
  void translate(Offset d) {
    a += d;
    b += d;
  }

  /// Whether `p` (image pixels) is on the shape, `slop` pixels around it counting.
  bool hit(Offset p, double slop) {
    if (isLine) return _segmentDistance(p, a, b) <= slop + lineWidth / 2;
    return rect.inflate(slop).contains(p);
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len = ab.distanceSquared;
    if (len == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  /// The outline of a closed shape.
  Path outline() {
    final r = rect;
    switch (kind) {
      case ShapeKind.rectangle:
      case ShapeKind.text:
        return Path()..addRect(r);
      case ShapeKind.roundedRectangle:
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            r,
            Radius.circular(math.min(r.width, r.height) * 0.15),
          ),
        );
      case ShapeKind.oval:
        return Path()..addOval(r);
      case ShapeKind.speechBubble:
        final body = Rect.fromLTRB(
          r.left,
          r.top,
          r.right,
          r.bottom - r.height * 0.2,
        );
        final radius = math.min(body.width, body.height) * 0.2;
        return Path()
          ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)))
          ..moveTo(body.left + body.width * 0.2, body.bottom - 1)
          ..lineTo(body.left + body.width * 0.12, r.bottom)
          ..lineTo(body.left + body.width * 0.38, body.bottom - 1)
          ..close();
      case ShapeKind.star:
        return _star(r, 5);
      case ShapeKind.polygon:
        return _polygon(r, 6);
      case ShapeKind.line:
      case ShapeKind.arrow:
        return Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy);
    }
  }

  static Path _star(Rect r, int points) {
    final c = r.center;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final k = i.isEven ? 1.0 : 0.45;
      final p = Offset(
        c.dx + math.cos(angle) * r.width / 2 * k,
        c.dy + math.sin(angle) * r.height / 2 * k,
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static Path _polygon(Rect r, int sides) {
    final c = r.center;
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / sides;
      final p = Offset(
        c.dx + math.cos(angle) * r.width / 2,
        c.dy + math.sin(angle) * r.height / 2,
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  /// `path` with dashes three line widths long.
  Path _dash(Path path) {
    final out = Path();
    final dash = math.max(2.0, lineWidth * 3);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        out.addPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          Offset.zero,
        );
        d += dash * 2;
      }
    }
    return out;
  }

  Path _arrowHead(Offset tip, Offset from) {
    final dir = tip - from;
    if (dir.distance == 0) return Path();
    final unit = dir / dir.distance;
    final size = math.max(8.0, lineWidth * 4);
    final normal = Offset(-unit.dy, unit.dx);
    final base = tip - unit * size;
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + normal * size * 0.5).dx, (base + normal * size * 0.5).dy)
      ..lineTo((base - normal * size * 0.5).dx, (base - normal * size * 0.5).dy)
      ..close();
  }

  void paint(Canvas canvas) {
    if (kind == ShapeKind.text) {
      _paintText(canvas);
      return;
    }
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = stroke
      ..strokeWidth = lineWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final shape = outline();
    if (shadow) {
      canvas.drawShadow(
        shape,
        const Color(0xFF000000),
        3,
        fill != null && fill!.a < 1,
      );
    }
    if (!isLine && fill != null) {
      canvas.drawPath(shape, Paint()..color = fill!);
    }
    canvas.drawPath(dashed ? _dash(shape) : shape, strokePaint);
    if (isLine) {
      final head = Paint()..color = stroke;
      if (ends == LineEnds.end || ends == LineEnds.both) {
        canvas.drawPath(_arrowHead(b, a), head);
      }
      if (ends == LineEnds.start || ends == LineEnds.both) {
        canvas.drawPath(_arrowHead(a, b), head);
      }
    }
  }

  TextStyle get textStyle => TextStyle(
    fontFamily: 'Inter',
    package: 'silica_ui',
    fontSize: fontSize,
    color: textColor,
    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    decoration: underline ? TextDecoration.underline : TextDecoration.none,
  );

  void _paintText(Canvas canvas) {
    final r = rect;
    if (fill != null) canvas.drawRect(r, Paint()..color = fill!);
    final builder =
        ParagraphBuilder(ParagraphStyle(textAlign: align, maxLines: null))
          ..pushStyle(textStyle.getTextStyle())
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ParagraphConstraints(width: math.max(1, r.width - 8)));
    canvas.drawParagraph(paragraph, r.topLeft + const Offset(4, 2));
    paragraph.dispose();
  }
}
