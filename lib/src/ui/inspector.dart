// Get Info (Tools › Show Inspector, ⌘I): a floating panel over the window with the file's
// name, kind, size, the image's dimensions and colour model and its EXIF fields, or the PDF's
// pages, page size and metadata. Size and layout *provisional* (PREVIEW-02).

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../images/decode.dart';
import '../images/formats.dart';
import '../model/viewer.dart';
import '../style.dart';

/// "1.2 MB" with decimal units, as the reference's file sizes.
String formatBytes(int bytes, String locale) {
  final number = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 1;
  if (bytes < 1000) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${number.format(value)} ${units[unit]}';
}

/// The rows of Get Info for what is current: (label, value); a null label starts a section
/// headed by the value.
List<(String?, String)> inspectorRows(ViewerController c, AppLocalizations l) {
  final locale = l.localeName;
  final grouped = NumberFormat.decimalPattern(locale);
  final rows = <(String?, String)>[];
  final image = c.image;
  final pdf = c.pdf;
  if (image != null) {
    rows
      ..add((l.infoName, image.name))
      ..add((l.infoKind, l.kindImage(image.format.label)))
      ..add((
        l.infoSize,
        l.fileSize(
          formatBytes(image.fileSize, locale),
          grouped.format(image.fileSize),
        ),
      ))
      ..add((
        l.infoDimensions,
        l.pixels(image.size.width.round(), image.size.height.round()),
      ))
      ..add((l.infoColour, colourName(image.colour.model, l)));
    if (image.colour.depth case final depth?)
      rows.add((l.infoDepth, l.bits(depth)));
    if (image.colour.model != ColourModel.vector) {
      rows.add((l.infoAlpha, image.colour.alpha ? l.yes : l.no));
    }
    final content = image.content;
    if (content is RasterContent && content.frames > 1) {
      rows.add((l.infoFrames, '${content.frames}'));
    }
    if (image.exif.isNotEmpty) {
      rows.add((null, l.infoExif));
      for (final (key, value) in image.exif) {
        rows.add((exifLabel(key, l), value));
      }
    }
  } else if (pdf != null) {
    final info = pdf.handle.info;
    final size = pdf.handle.pageSizes.isEmpty
        ? null
        : pdf.handle.pageSizes[c.current];
    final points = NumberFormat.decimalPattern(locale)
      ..maximumFractionDigits = 0;
    rows
      ..add((l.infoName, pdf.name))
      ..add((l.infoKind, l.kindPdf))
      ..add((
        l.infoSize,
        l.fileSize(
          formatBytes(pdf.fileSize, locale),
          grouped.format(pdf.fileSize),
        ),
      ))
      ..add((l.infoPages, '${pdf.pageCount}'));
    if (size != null) {
      rows.add((
        l.infoPageSize,
        l.points(points.format(size.width), points.format(size.height)),
      ));
    }
    for (final (label, value) in [
      (l.infoVersion, info.version),
      (l.infoTitle, info.title),
      (l.infoAuthor, info.author),
      (l.infoSubject, info.subject),
      (l.infoCreator, info.creator),
      (l.infoProducer, info.producer),
    ]) {
      if (value.trim().isNotEmpty) rows.add((label, value.trim()));
    }
  }
  return rows;
}

String colourName(ColourModel model, AppLocalizations l) => switch (model) {
  ColourModel.rgb => l.colourRgb,
  ColourModel.gray => l.colourGray,
  ColourModel.cmyk => l.colourCmyk,
  ColourModel.indexed => l.colourIndexed,
  ColourModel.vector => l.colourVector,
  ColourModel.unknown => l.colourUnknown,
};

String exifLabel(String key, AppLocalizations l) => switch (key) {
  'Image Make' => l.exifImageMake,
  'Image Model' => l.exifImageModel,
  'EXIF LensModel' => l.exifLensModel,
  'EXIF DateTimeOriginal' => l.exifDateTimeOriginal,
  'EXIF ExposureTime' => l.exifExposureTime,
  'EXIF FNumber' => l.exifFNumber,
  'EXIF ISOSpeedRatings' => l.exifISOSpeedRatings,
  'EXIF FocalLength' => l.exifFocalLength,
  'EXIF Flash' => l.exifFlash,
  'Image Software' => l.exifImageSoftware,
  _ => key,
};

class Inspector extends StatelessWidget {
  const Inspector({
    super.key,
    required this.controller,
    required this.position,
    required this.onMove,
  });

  final ViewerController controller;
  final Offset position;
  final ValueChanged<Offset> onMove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final rows = inspectorRows(controller, l);
    return FloatingPanel(
      key: const ValueKey('inspector'),
      title: l.inspectorTitle,
      size: PreviewMetrics.inspectorSize,
      position: position,
      onMove: onMove,
      onClose: controller.closeInspector,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        children: [
          for (final (label, value) in rows)
            if (label == null)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(
                  value,
                  style: previewText(
                    11,
                    color: colors.secondary,
                    weight: FontWeight.w600,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: PreviewMetrics.inspectorLabelWidth,
                      child: Text(
                        label,
                        textAlign: TextAlign.right,
                        style: previewText(11, color: colors.secondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value,
                        style: previewText(11, color: colors.text),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
