// The window's sheets: the export options (format and JPEG quality, then the Save dialog),
// the password of a protected PDF, and Go to Page. Layout *provisional* (PREVIEW-02).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../export/export.dart';
import '../style.dart';

const double _sheetWidth = 360;
const double _labelWidth = 72;

/// The export options; null if cancelled.
Future<ExportOptions?> showExportSheet(
  BuildContext context, {
  required String name,
  ExportOptions initial = const ExportOptions(ExportFormat.png),
}) => showWindowSheet<ExportOptions>(
  context,
  semanticLabel: AppLocalizations.of(context).exportDialogTitle,
  builder: (context, sheet) =>
      _ExportSheet(name: name, initial: initial, close: sheet.close),
);

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({
    required this.name,
    required this.initial,
    required this.close,
  });
  final String name;
  final ExportOptions initial;
  final void Function([ExportOptions?]) close;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late ExportFormat _format = widget.initial.format;
  late double _quality = widget.initial.quality;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    Widget row(String label, Widget control) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: previewText(13, color: colors.text),
            ),
          ),
          const SizedBox(width: 8),
          control,
        ],
      ),
    );
    return SizedBox(
      width: _sheetWidth,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.exportTitle(widget.name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: previewText(
                13,
                color: colors.text,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            row(
              l.format,
              PopUpButton<ExportFormat>(
                key: const ValueKey('export format'),
                width: 160,
                items: [
                  for (final f in ExportFormat.values) PopUpItem(f, f.label),
                ],
                value: _format,
                onChanged: (f) => setState(() => _format = f),
              ),
            ),
            if (_format == ExportFormat.jpeg)
              row(
                l.quality,
                Row(
                  children: [
                    Text(
                      l.qualityLeast,
                      style: previewText(11, color: colors.secondary),
                    ),
                    const SizedBox(width: 6),
                    SilicaSlider(
                      key: const ValueKey('export quality'),
                      width: 140,
                      value: _quality,
                      onChanged: (v) => setState(() => _quality = v),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.qualityBest,
                      style: previewText(11, color: colors.secondary),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SilicaButton(
                  key: const ValueKey('export cancel'),
                  label: l.cancel,
                  onPressed: () => widget.close(),
                ),
                const SizedBox(width: 8),
                SilicaButton(
                  key: const ValueKey('export save'),
                  label: l.save,
                  role: ButtonRole.primary,
                  onPressed: () =>
                      widget.close(ExportOptions(_format, quality: _quality)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A sheet with a message, one text field and two buttons; the text, or null if cancelled.
Future<String?> showFieldSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String accept,
  String placeholder = '',
  bool secure = false,
  Key? fieldKey,
}) => showWindowSheet<String>(
  context,
  semanticLabel: title,
  builder: (context, sheet) => _FieldSheet(
    title: title,
    message: message,
    accept: accept,
    placeholder: placeholder,
    secure: secure,
    fieldKey: fieldKey,
    close: sheet.close,
  ),
);

class _FieldSheet extends StatefulWidget {
  const _FieldSheet({
    required this.title,
    required this.message,
    required this.accept,
    required this.placeholder,
    required this.secure,
    required this.fieldKey,
    required this.close,
  });
  final String title;
  final String message;
  final String accept;
  final String placeholder;
  final bool secure;
  final Key? fieldKey;
  final void Function([String?]) close;

  @override
  State<_FieldSheet> createState() => _FieldSheetState();
}

class _FieldSheetState extends State<_FieldSheet> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _accept() => widget.close(_text.text);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    return SizedBox(
      width: _sheetWidth,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: previewText(
                13,
                color: colors.text,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.message, style: previewText(12, color: colors.text)),
            const SizedBox(height: 12),
            SilicaTextField(
              key: widget.fieldKey,
              controller: _text,
              autofocus: true,
              secure: widget.secure,
              placeholder: widget.placeholder,
              onSubmitted: (_) => _accept(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SilicaButton(label: l.cancel, onPressed: () => widget.close()),
                const SizedBox(width: 8),
                SilicaButton(
                  key: const ValueKey('sheet accept'),
                  label: widget.accept,
                  role: ButtonRole.primary,
                  onPressed: _accept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
