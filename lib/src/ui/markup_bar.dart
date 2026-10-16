// The markup toolbar (kit `Apps/Preview/Image Markup`: a 36 pt strip and a 1 pt separator under
// the toolbar, its items centred in groups split by 1 × 20 separators, small (24 pt) glass
// capsules; shown and hidden at once).
//
// For an image Preview can write: Shapes ▾ (a 110 × 218 popover: line, arrow, rectangle, rounded
// rectangle, oval, speech bubble, star, polygon), Text, Adjust Size | Shape Style ▾ (120 × 417:
// six line widths, dashes, line ends, shadow), Border Colour ▾ and Fill Colour ▾ (270 × 300: a
// row of bright colours, a 12 × 10 grid of shades with "none" first), Text Style ▾ (289 × 138:
// colour, size, bold / italic / underline, alignment). For a PDF: Note. The reference's other
// tools (selection tools, instant alpha, sketch, sign, adjust colour, image description,
// redaction, shapes and text on PDFs) are not in Preview yet (#12, #13).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/markup.dart';
import '../model/viewer.dart';
import '../style.dart';
import 'popover.dart';
import 'symbol.dart';

/// The bright row of the colour popover: eleven colours, then white, gray and black.
/// *Provisional* values.
const List<Color> brightColours = [
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF00C7BE),
  Color(0xFF30B0C7),
  Color(0xFF32ADE6),
  Color(0xFF007AFF),
  Color(0xFF5856D6),
  Color(0xFFAF52DE),
  Color(0xFFFF2D55),
  Color(0xFFFFFFFF),
  Color(0xFF8E8E93),
  Color(0xFF000000),
];

/// The 12 × 10 grid of shades: grays, then twelve hues from dark to light (null: "none", the
/// first cell). *Provisional* values.
List<Color?> shadeGrid() => [
  for (var row = 0; row < 10; row++)
    for (var col = 0; col < 12; col++)
      if (row == 0 && col == 0)
        null
      else if (row == 0)
        HSLColor.fromAHSL(1, 0, 0, 1 - (col - 1) / 10).toColor()
      else
        HSLColor.fromAHSL(1, col * 30.0, 0.85, 0.12 + row * 0.085).toColor(),
];

class MarkupBar extends StatelessWidget {
  const MarkupBar({
    super.key,
    required this.controller,
    required this.onAddShape,
    required this.onAdjustSize,
    required this.onNote,
  });
  final ViewerController controller;
  final ValueChanged<ShapeKind> onAddShape;
  final VoidCallback onAdjustSize;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = controller;
    final item = c.image;
    final editable = item != null && item.writable;
    final shape = c.chosenShape;
    final style = shape ?? c.shapeTemplate;
    final List<Widget> groups;
    if (c.isPdf) {
      groups = [
        _Tool(
          keyName: 'markup note',
          tooltip: l.note,
          icon: 'message-ellipsis',
          fallback: '▤',
          enabled: c.canAnnotate,
          onTap: onNote,
        ),
      ];
    } else {
      groups = [
        _Popover(
          keyName: 'markup shapes',
          tooltip: l.shapes,
          icon: 'square',
          fallback: '□',
          enabled: editable,
          size: PreviewMetrics.shapesPopover,
          builder: (close) => _ShapesGrid(
            onShape: (kind) {
              close();
              onAddShape(kind);
            },
          ),
        ),
        _Tool(
          keyName: 'markup text',
          tooltip: l.shapeText,
          icon: 'text-cursor',
          fallback: 'T',
          enabled: editable,
          onTap: () => onAddShape(ShapeKind.text),
        ),
        _Tool(
          keyName: 'markup adjust size',
          tooltip: l.adjustSize,
          icon: 'arrow-up-left',
          fallback: '⤡',
          enabled: editable,
          onTap: onAdjustSize,
        ),
        const _Separator(),
        _Popover(
          keyName: 'markup shape style',
          tooltip: l.shapeStyle,
          icon: 'line-3',
          fallback: '≡',
          enabled: editable,
          size: PreviewMetrics.shapeStylePopover,
          builder: (close) => _ShapeStyle(controller: c),
        ),
        const _Separator(),
        _Popover(
          keyName: 'markup border colour',
          tooltip: l.borderColour,
          swatch: style.stroke,
          enabled: editable,
          size: PreviewMetrics.colourPopover,
          builder: (close) => ColourGrid(
            none: false,
            onColour: (color) {
              close();
              c.styleShape((s) => s.stroke = color ?? s.stroke);
            },
          ),
        ),
        _Popover(
          keyName: 'markup fill colour',
          tooltip: l.fillColour,
          swatch: style.fill,
          fillSwatch: true,
          enabled: editable,
          size: PreviewMetrics.colourPopover,
          builder: (close) => ColourGrid(
            none: true,
            onColour: (color) {
              close();
              c.styleShape((s) => s.fill = color);
            },
          ),
        ),
        const _Separator(),
        _Popover(
          keyName: 'markup text style',
          tooltip: l.textStyle,
          icon: 'text-size',
          fallback: 'A',
          enabled: editable,
          size: PreviewMetrics.textStylePopover,
          builder: (close) => _TextStyle(controller: c),
        ),
      ];
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const ValueKey('markup bar'),
          height: PreviewMetrics.markupBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: groups,
          ),
        ),
        SizedBox(height: 1, child: ColoredBox(color: colors.sidebarLine)),
      ],
    );
  }
}

/// A 1 × 20 separator between the groups of the strip.
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1,
    height: 20,
    child: ColoredBox(color: PreviewColors.of(context).sidebarLine),
  );
}

/// A glyph in a small action segment's colour (through [IconTheme]).
Widget _glyph(String name, String fallback, {double size = 14}) => Builder(
  builder: (context) => PreviewSymbol(
    name,
    size: size,
    color: IconTheme.of(context).color ?? const Color(0xFF000000),
    fallback: fallback,
  ),
);

/// A markup button: a small (24 pt) glass circle.
class _Tool extends StatelessWidget {
  const _Tool({
    required this.keyName,
    required this.tooltip,
    required this.icon,
    required this.fallback,
    required this.enabled,
    required this.onTap,
  });
  final String keyName;
  final String tooltip;
  final String icon;
  final String fallback;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AmalfiActionSegments(
    key: ValueKey(keyName),
    size: AmalfiControlSize.small,
    onPressed: enabled ? (_) => onTap() : null,
    segments: [
      AmalfiSegment.icon(
        _glyph(icon, fallback),
        semanticLabel: tooltip,
        tooltip: tooltip,
      ),
    ],
  );
}

/// A markup button with a chevron (a 48 × 24 capsule of two segments) that opens a popover
/// under it.
class _Popover extends StatefulWidget {
  const _Popover({
    required this.keyName,
    required this.tooltip,
    required this.enabled,
    required this.size,
    required this.builder,
    this.icon,
    this.fallback = '',
    this.swatch,
    this.fillSwatch = false,
  });
  final String keyName;
  final String tooltip;
  final bool enabled;
  final Size size;
  final Widget Function(VoidCallback close) builder;
  final String? icon;
  final String fallback;

  /// A colour swatch in place of the icon.
  final Color? swatch;
  final bool fillSwatch;

  @override
  State<_Popover> createState() => _PopoverState();
}

class _PopoverState extends State<_Popover> {
  PopoverHandle? _handle;

  @override
  void dispose() {
    _handle?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget face = widget.icon != null
        ? _glyph(widget.icon!, widget.fallback)
        : _Swatch(color: widget.swatch, size: 14, none: widget.fillSwatch);
    return Builder(
      builder: (anchor) => AmalfiActionSegments(
        key: ValueKey(widget.keyName),
        size: AmalfiControlSize.small,
        onPressed: !widget.enabled
            ? null
            : (_) {
                _handle?.close();
                _handle = showPopover(
                  anchor,
                  size: widget.size,
                  key: ValueKey('${widget.keyName} popover'),
                  builder: (context, handle) => widget.builder(handle.close),
                );
              },
        segments: [
          AmalfiSegment.icon(
            face,
            semanticLabel: widget.tooltip,
            tooltip: widget.tooltip,
          ),
          AmalfiSegment.icon(
            _glyph('chevron-down', '⌄', size: 12),
            semanticLabel: widget.tooltip,
          ),
        ],
      ),
    );
  }
}

/// A colour swatch; null with `none` draws the red slash of "no colour".
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.size = 20, this.none = true});
  final Color? color;
  final double size;
  final bool none;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color ?? const Color(0xFFFFFFFF),
      border: Border.all(color: const Color(0x33000000)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: color == null && none ? CustomPaint(painter: _SlashPainter()) : null,
  );
}

class _SlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawLine(
    Offset(size.width, 0),
    Offset(0, size.height),
    Paint()
      ..color = const Color(0xFFE5322D)
      ..strokeWidth = 1.5,
  );

  @override
  bool shouldRepaint(_SlashPainter old) => false;
}

/// The colour popover's content: the bright row and the grid of shades.
class ColourGrid extends StatelessWidget {
  const ColourGrid({super.key, required this.none, required this.onColour});

  /// Offers "no colour" (a fill).
  final bool none;
  final ValueChanged<Color?> onColour;

  @override
  Widget build(BuildContext context) {
    final grid = shadeGrid();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (i, color) in brightColours.indexed)
              GestureDetector(
                key: ValueKey('bright $i'),
                onTap: () => onColour(color),
                child: _Swatch(color: color, size: 15),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            crossAxisCount: 12,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (i, color) in grid.indexed)
                if (color == null && !none)
                  const SizedBox.shrink()
                else
                  GestureDetector(
                    key: ValueKey('shade $i'),
                    onTap: () => onColour(color),
                    child: _Swatch(color: color, size: 18),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShapesGrid extends StatelessWidget {
  const _ShapesGrid({required this.onShape});
  final ValueChanged<ShapeKind> onShape;

  static const _kinds = [
    ShapeKind.line,
    ShapeKind.arrow,
    ShapeKind.rectangle,
    ShapeKind.roundedRectangle,
    ShapeKind.oval,
    ShapeKind.speechBubble,
    ShapeKind.star,
    ShapeKind.polygon,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final kind in _kinds)
          GestureDetector(
            key: ValueKey('shape ${kind.name}'),
            onTap: () => onShape(kind),
            child: SizedBox(
              width: 28,
              height: 28,
              child: CustomPaint(painter: ShapeGlyph(kind, colors.text)),
            ),
          ),
      ],
    );
  }
}

/// A shape drawn small, as its button.
class ShapeGlyph extends CustomPainter {
  ShapeGlyph(this.kind, this.color);
  final ShapeKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.15;
    final line = kind == ShapeKind.line || kind == ShapeKind.arrow;
    MarkupShape(
      kind: kind,
      a: line ? Offset(inset, size.height - inset) : Offset(inset, inset),
      b: line
          ? Offset(size.width - inset, inset)
          : Offset(size.width - inset, size.height - inset),
      stroke: color,
      lineWidth: 1.5,
    ).paint(canvas);
  }

  @override
  bool shouldRepaint(ShapeGlyph old) => old.kind != kind || old.color != color;
}

class _ShapeStyle extends StatefulWidget {
  const _ShapeStyle({required this.controller});
  final ViewerController controller;

  @override
  State<_ShapeStyle> createState() => _ShapeStyleState();
}

class _ShapeStyleState extends State<_ShapeStyle> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = widget.controller;
    final style = c.chosenShape ?? c.shapeTemplate;
    void change(void Function(MarkupShape s) f) {
      c.styleShape(f);
      setState(() {});
    }

    Widget row({
      required String key,
      required bool checked,
      required VoidCallback onTap,
      required Widget child,
    }) => GestureDetector(
      key: ValueKey(key),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 24,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: checked
                  ? AmalfiGlyph(
                      AmalfiGlyphs.checkmark,
                      size: 12,
                      color: colors.text,
                    )
                  : null,
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(height: 1, child: ColoredBox(color: colors.sidebarLine)),
    );
    return Column(
      children: [
        for (final w in lineWidths)
          row(
            key: 'width $w',
            checked: style.lineWidth == w,
            onTap: () => change((s) => s.lineWidth = w),
            child: Container(height: w.clamp(1, 10), color: colors.text),
          ),
        row(
          key: 'dashed',
          checked: style.dashed,
          onTap: () => change((s) => s.dashed = !s.dashed),
          child: Text(l.dashed, style: AmalfiType.body(color: colors.text)),
        ),
        divider(),
        for (final (ends, label) in [
          (LineEnds.none, '—'),
          (LineEnds.start, '←'),
          (LineEnds.end, '→'),
          (LineEnds.both, '↔'),
        ])
          row(
            key: 'ends ${ends.name}',
            checked: style.ends == ends,
            onTap: () => change((s) => s.ends = ends),
            child: Text(label, style: AmalfiType.body(color: colors.text)),
          ),
        divider(),
        row(
          key: 'shadow',
          checked: style.shadow,
          onTap: () => change((s) => s.shadow = !s.shadow),
          child: Text(l.shadow, style: AmalfiType.body(color: colors.text)),
        ),
      ],
    );
  }
}

class _TextStyle extends StatefulWidget {
  const _TextStyle({required this.controller});
  final ViewerController controller;

  @override
  State<_TextStyle> createState() => _TextStyleState();
}

class _TextStyleState extends State<_TextStyle> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final c = widget.controller;
    final style = c.chosenShape ?? c.shapeTemplate;
    void change(void Function(MarkupShape s) f) {
      c.styleShape(f);
      setState(() {});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Row(
          spacing: 8,
          children: [
            Text(l.textColour, style: AmalfiType.body(color: colors.text)),
            AmalfiColorWell(
              key: const ValueKey('text colour'),
              style: AmalfiColorWellStyle.minimal,
              color: style.textColor,
              semanticLabel: l.textColour,
              onChanged: (color) => change((s) => s.textColor = color),
            ),
            const Spacer(),
            Text(
              '${style.fontSize.round()} pt',
              key: const ValueKey('text size'),
              style: AmalfiType.body(color: colors.text),
            ),
            AmalfiStepper(
              key: const ValueKey('text size stepper'),
              value: style.fontSize,
              min: 6,
              max: 288,
              semanticLabel: l.textSize,
              onChanged: (v) => change((s) => s.fontSize = v),
            ),
          ],
        ),
        Row(
          children: [
            AmalfiSegmentedControl(
              key: const ValueKey('text emphasis'),
              selection: AmalfiSegmentedSelection.any,
              size: AmalfiControlSize.small,
              segments: [
                AmalfiSegment.icon(
                  _glyph('text-bold', 'B', size: 12),
                  semanticLabel: l.bold,
                ),
                AmalfiSegment.icon(
                  _glyph('text-italic', 'I', size: 12),
                  semanticLabel: l.italic,
                ),
                AmalfiSegment.icon(
                  _glyph('text-underline', 'U', size: 12),
                  semanticLabel: l.underline,
                ),
              ],
              selected: {
                if (style.bold) 0,
                if (style.italic) 1,
                if (style.underline) 2,
              },
              onChanged: (now) => change((s) {
                final before = {
                  if (s.bold) 0,
                  if (s.italic) 1,
                  if (s.underline) 2,
                };
                for (final i
                    in before.union(now).difference(before.intersection(now))) {
                  if (i == 0) s.bold = !s.bold;
                  if (i == 1) s.italic = !s.italic;
                  if (i == 2) s.underline = !s.underline;
                }
              }),
            ),
            const Spacer(),
            AmalfiSegmentedControl(
              key: const ValueKey('text alignment'),
              size: AmalfiControlSize.small,
              segments: [
                for (final (icon, fallback, label) in [
                  ('text-align-left', '⇤', l.alignLeft),
                  ('text-align-center', '↔', l.alignCenter),
                  ('text-align-right', '⇥', l.alignRight),
                  ('text-justify', '≡', l.alignJustify),
                ])
                  AmalfiSegment.icon(
                    _glyph(icon, fallback, size: 12),
                    semanticLabel: label,
                  ),
              ],
              selected: {
                switch (style.align) {
                  TextAlign.center => 1,
                  TextAlign.right || TextAlign.end => 2,
                  TextAlign.justify => 3,
                  _ => 0,
                },
              },
              onChanged: (now) => change(
                (s) => s.align = const [
                  TextAlign.left,
                  TextAlign.center,
                  TextAlign.right,
                  TextAlign.justify,
                ][now.first],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
