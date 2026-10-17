// Symbols of the Icon Kit (Regular weight), set by `AmalfiSymbol` in the bundled Silica Symbols
// font, sharp at small sizes. A name the font lacks is read from an installed silica-icons; when
// it is in neither (tests, a bare checkout) a text glyph stands in.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../style.dart';

class PreviewSymbol extends StatelessWidget {
  const PreviewSymbol(
    this.name, {
    super.key,
    required this.size,
    required this.color,
    required this.fallback,
  });

  final String name;
  final double size;
  final Color color;

  /// The text glyph without silica-icons.
  final String fallback;

  @override
  Widget build(BuildContext context) => AmalfiSymbol(
    name,
    size: size,
    color: color,
    fallback: SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(fallback, style: previewText(size * 0.8, color: color)),
      ),
    ),
  );
}
