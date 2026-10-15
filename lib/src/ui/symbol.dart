// Toolbar symbols from silica-icons (`SILICA_ICONS_DIR/symbols/regular`), as the other Silica
// apps draw them; without the directory (tests, a bare checkout) a text glyph stands in.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  static String? directory = Platform.environment['SILICA_ICONS_DIR'];

  @override
  Widget build(BuildContext context) {
    final dir = directory;
    final file = dir == null ? null : File('$dir/symbols/regular/$name.svg');
    if (file == null || !file.existsSync()) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(fallback, style: previewText(size * 0.8, color: color)),
        ),
      );
    }
    return SvgPicture.file(
      file,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
