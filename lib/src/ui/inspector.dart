// The inspector (Tools › Show Inspector, ⌘I, or the toolbar's button; PREVIEW-02 › Files): a
// 270 pt pane inside the window on the right, with four tabs on a segmented control at its top
// (it remembers the last one): General (name, kind, size, modified; the image's dimensions and
// colour, or the PDF's pages, page size and metadata), More Info (sections that fold: the
// image's properties, its EXIF fields), Keywords (a PDF's, editable with + and −), and
// Annotations (page, kind, author, date). Rows sit in 250 pt rounded group boxes, 37 pt apart.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../images/decode.dart';
import '../images/formats.dart';
import '../model/markup.dart';
import '../model/viewer.dart';
import '../pdf/backend.dart';
import '../style.dart';
import 'symbol.dart';

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
      ..addAll(_modifiedRow(image.path, l))
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
    final size = pdf.pageCount == 0
        ? null
        : pdf.pageSize(c.current.clamp(0, pdf.pageCount - 1));
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
      ..addAll(_modifiedRow(pdf.path, l))
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

/// The file's modification date, when it can be read.
List<(String?, String)> _modifiedRow(String path, AppLocalizations l) {
  try {
    final when = File(path).lastModifiedSync();
    return [
      (l.infoModified, DateFormat.yMMMd(l.localeName).add_Hm().format(when)),
    ];
  } on FileSystemException {
    return const [];
  }
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

enum InspectorTab { general, more, keywords, annotations }

class Inspector extends StatefulWidget {
  const Inspector({super.key, required this.controller});
  final ViewerController controller;

  /// The last tab shown, for the next time it opens.
  static InspectorTab lastTab = InspectorTab.general;

  @override
  State<Inspector> createState() => _InspectorState();
}

class _InspectorState extends State<Inspector> {
  final Set<String> _folded = {};
  final TextEditingController _keyword = TextEditingController();
  int? _chosenKeyword;

  ViewerController get c => widget.controller;

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final tab = Inspector.lastTab;
    if (tab == InspectorTab.annotations) unawaited(c.loadAllAnnotations());
    final Widget body = switch (tab) {
      InspectorTab.general => _rowsView(_general(l), colors),
      InspectorTab.more => _more(l, colors),
      InspectorTab.keywords => _keywords(l, colors),
      InspectorTab.annotations => _annotations(l, colors),
    };
    return Container(
      key: const ValueKey('inspector'),
      width: PreviewMetrics.inspectorWidth,
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(left: BorderSide(color: colors.sidebarLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Center(
              child: SegmentedControl(
                key: const ValueKey('inspector tabs'),
                segments: [
                  Segment(
                    icon: (color) => PreviewSymbol(
                      'info',
                      size: 14,
                      color: color,
                      fallback: 'i',
                    ),
                    semanticLabel: l.inspectorGeneral,
                  ),
                  Segment(
                    icon: (color) => PreviewSymbol(
                      'list-bullet',
                      size: 14,
                      color: color,
                      fallback: '≡',
                    ),
                    semanticLabel: l.inspectorMore,
                  ),
                  Segment(
                    icon: (color) => PreviewSymbol(
                      'tag',
                      size: 14,
                      color: color,
                      fallback: '#',
                    ),
                    semanticLabel: l.inspectorKeywords,
                  ),
                  Segment(
                    icon: (color) => PreviewSymbol(
                      'pencil',
                      size: 14,
                      color: color,
                      fallback: '✎',
                    ),
                    semanticLabel: l.inspectorAnnotations,
                  ),
                ],
                selected: {tab.index},
                onChanged: (i) =>
                    setState(() => Inspector.lastTab = InspectorTab.values[i]),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  List<(String?, String)> _general(AppLocalizations l) {
    final rows = inspectorRows(c, l);
    // The EXIF fields are in More Info.
    final exif = rows.indexWhere((r) => r.$1 == null);
    return exif < 0 ? rows : rows.sublist(0, exif);
  }

  Widget _group(List<Widget> rows, PreviewColors colors) => Container(
    width: PreviewMetrics.inspectorGroup,
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: colors.window.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: rows),
  );

  Widget _row(String label, String value, PreviewColors colors) => SizedBox(
    height: PreviewMetrics.inspectorRow,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(label, style: previewText(12, color: colors.text)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: previewText(12, color: colors.secondary),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _rowsView(List<(String?, String)> rows, PreviewColors colors) =>
      ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _group([
            for (final (label, value) in rows)
              if (label != null) _row(label, value, colors),
          ], colors),
        ],
      );

  Widget _more(AppLocalizations l, PreviewColors colors) {
    final rows = inspectorRows(c, l);
    final sections = <(String, List<(String, String)>)>[];
    var title = l.inspectorGeneral;
    var current = <(String, String)>[];
    for (final (label, value) in rows) {
      if (label == null) {
        sections.add((title, current));
        title = value;
        current = [];
      } else if (label != l.infoName && label != l.infoKind) {
        current.add((label, value));
      }
    }
    sections.add((title, current));
    return ListView(
      key: const ValueKey('more info'),
      padding: const EdgeInsets.all(10),
      children: [
        for (final (title, items) in sections)
          if (items.isNotEmpty) ...[
            GestureDetector(
              key: ValueKey('section $title'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(
                () => _folded.contains(title)
                    ? _folded.remove(title)
                    : _folded.add(title),
              ),
              child: SizedBox(
                height: 28,
                child: Row(
                  children: [
                    SizedBox(
                      width: 9,
                      height: 9,
                      child: OutlineTriangle(
                        open: !_folded.contains(title),
                        color: colors.secondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: previewText(
                        12,
                        color: colors.text,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_folded.contains(title))
              _group([
                for (final (label, value) in items) _row(label, value, colors),
              ], colors),
          ],
      ],
    );
  }

  Widget _keywords(AppLocalizations l, PreviewColors colors) {
    final words = c.keywords;
    final editable = c.isPdf && c.loader.writer != null;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.window.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: words.isEmpty
                  ? Center(
                      child: Text(
                        l.noKeywords,
                        key: const ValueKey('no keywords'),
                        style: previewText(12, color: colors.secondary),
                      ),
                    )
                  : ListView(
                      key: const ValueKey('keywords'),
                      children: [
                        for (final (i, w) in words.indexed)
                          GestureDetector(
                            key: ValueKey('keyword $i'),
                            onTap: () => setState(() => _chosenKeyword = i),
                            child: Container(
                              height: 24,
                              color: _chosenKeyword == i
                                  ? PreviewColors.accent
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                w,
                                style: previewText(
                                  12,
                                  color: _chosenKeyword == i
                                      ? const Color(0xFFFFFFFF)
                                      : colors.text,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (editable)
            SilicaTextField(
              key: const ValueKey('keyword field'),
              controller: _keyword,
              placeholder: l.newKeyword,
              onSubmitted: (_) => _addKeyword(),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              SilicaButton(
                key: const ValueKey('keyword add'),
                label: '+',
                onPressed: editable ? _addKeyword : null,
              ),
              const SizedBox(width: 4),
              SilicaButton(
                key: const ValueKey('keyword remove'),
                label: '−',
                onPressed:
                    editable &&
                        _chosenKeyword != null &&
                        _chosenKeyword! < words.length
                    ? () {
                        final next = [...words]..removeAt(_chosenKeyword!);
                        setState(() => _chosenKeyword = null);
                        c.setKeywords(next);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addKeyword() {
    final word = _keyword.text.trim();
    if (word.isEmpty) return;
    _keyword.clear();
    c.setKeywords([...c.keywords, word]);
  }

  Widget _annotations(AppLocalizations l, PreviewColors colors) {
    final date = DateFormat.yMd(l.localeName).add_Hm();
    final rows = <(String, String, String, String)>[
      if (c.isPdf)
        for (final (page, a) in c.allAnnotations)
          (
            '${page + 1}',
            annotationKind(a.kind, l),
            a.author,
            a.modified == null ? '' : date.format(a.modified!),
          )
      else if (c.image case final image?)
        for (final shape in image.markup)
          ('1', shapeKindName(shape.kind, l), '', ''),
    ];
    Widget cell(String text, double width, {bool bold = false}) => SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: previewText(
          11,
          color: bold ? colors.secondary : colors.text,
          weight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
    return ListView(
      key: const ValueKey('annotation table'),
      padding: const EdgeInsets.all(10),
      children: [
        Row(
          children: [
            cell(l.columnPage, 40, bold: true),
            cell(l.columnType, 70, bold: true),
            cell(l.columnAuthor, 60, bold: true),
            cell(l.columnDate, 80, bold: true),
          ],
        ),
        const SizedBox(height: 4),
        for (final (page, kind, author, date) in rows)
          SizedBox(
            height: 22,
            child: Row(
              children: [
                cell(page, 40),
                cell(kind, 70),
                cell(author, 60),
                cell(date, 80),
              ],
            ),
          ),
      ],
    );
  }
}

String annotationKind(PdfMarkupKind kind, AppLocalizations l) => switch (kind) {
  PdfMarkupKind.highlight => l.kindHighlight,
  PdfMarkupKind.underline => l.underline,
  PdfMarkupKind.strikeOut => l.strikethrough,
  PdfMarkupKind.note => l.note,
};

String shapeKindName(ShapeKind kind, AppLocalizations l) => switch (kind) {
  ShapeKind.line => l.shapeLine,
  ShapeKind.arrow => l.shapeArrow,
  ShapeKind.rectangle => l.shapeRectangle,
  ShapeKind.roundedRectangle => l.shapeRoundedRectangle,
  ShapeKind.oval => l.shapeOval,
  ShapeKind.speechBubble => l.shapeBubble,
  ShapeKind.star => l.shapeStar,
  ShapeKind.polygon => l.shapePolygon,
  ShapeKind.text => l.shapeText,
};
