// The window's sheets (kit `Apps/Preview/Export`, `Permissions`, `Adjust Size`; behaviour from
// PREVIEW-02 › Files, PDF features, Markup), each an Amalfi dialog card on the window's scrim:
//
// - Export: the format (JPEG, PDF, PNG, TIFF) with its options: the JPEG quality slider (Least
//   … Best, 0.85 by default), the PNG alpha check box (only for an image with transparency), the
//   permissions of a PDF; the file size of the result, live; Cancel and Save. The name and the
//   folder are asked next by the desktop's Save dialog.
// - Edit Permissions: a password to open the document (and its confirmation), the five
//   permissions, and the owner password that guards them.
// - Adjust Size: a preset or custom size, width and height linked when scaling
//   proportionally, the unit, the resolution, and the resulting size.
// - Go to Page: the page number.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../export/export.dart';
import '../model/document.dart';
import '../pdf/qpdf.dart';
import '../style.dart';
import 'inspector.dart' show formatBytes;
import 'sheet.dart';

/// The chosen export, with the permissions of an exported PDF.
class ExportChoice extends ExportOptions {
  const ExportChoice(
    super.format, {
    super.quality,
    super.alpha,
    super.ppi,
    this.security,
  });
  final PdfSecurity? security;
}

/// A form row of a sheet: the label at the leading side (right aligned in a [labelWidth] box),
/// then the control.
Widget _row(
  BuildContext context,
  String label,
  Widget control, {
  double labelWidth = 96,
}) {
  final colors = AmalfiTheme.of(context).colors;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: labelWidth,
        child: Text(
          label,
          textAlign: TextAlign.right,
          style: AmalfiType.body(color: colors.textSecondary),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Align(alignment: Alignment.centerLeft, child: control),
      ),
    ],
  );
}

/// The footer of a sheet: Cancel, then the default button.
Widget _footer(Widget cancel, Widget accept) =>
    AmalfiDialogFooter(actions: [cancel, accept]);

/// The export options; null if cancelled.
Future<ExportChoice?> showExportSheet(
  BuildContext context, {
  required String name,
  ExportOptions initial = const ExportOptions(ExportFormat.png),
  bool pdfOnly = false,
  bool alpha = false,
  PdfWriter? writer,
  Future<PdfSecurity?> Function([PdfSecurity? initial])? onPermissions,
  Future<int?> Function(ExportOptions options)? estimate,
}) => showPreviewSheet<ExportChoice>(
  context,
  semanticLabel: AppLocalizations.of(context).exportDialogTitle,
  builder: (context, sheet) => _ExportSheet(
    name: name,
    initial: initial,
    pdfOnly: pdfOnly,
    alpha: alpha,
    onPermissions: writer == null ? null : onPermissions,
    estimate: estimate,
    close: sheet.close,
  ),
);

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({
    required this.name,
    required this.initial,
    required this.pdfOnly,
    required this.alpha,
    required this.onPermissions,
    required this.estimate,
    required this.close,
  });
  final String name;
  final ExportOptions initial;
  final bool pdfOnly;
  final bool alpha;
  final Future<PdfSecurity?> Function([PdfSecurity? initial])? onPermissions;
  final Future<int?> Function(ExportOptions options)? estimate;
  final void Function([ExportChoice?]) close;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late ExportFormat _format = widget.pdfOnly
      ? (widget.initial.format == ExportFormat.tiff
            ? ExportFormat.pdf
            : widget.initial.format)
      : widget.initial.format;
  late double _quality = widget.initial.quality;
  late bool _alpha = widget.initial.alpha;
  late int _ppi = widget.initial.ppi;
  PdfSecurity? _security;
  int? _size;
  Timer? _sizing;
  int _generation = 0;

  ExportOptions get _options =>
      ExportOptions(_format, quality: _quality, alpha: _alpha, ppi: _ppi);

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void dispose() {
    _sizing?.cancel();
    super.dispose();
  }

  /// The file size of the result, measured once the options hold still.
  void _measure() {
    final estimate = widget.estimate;
    if (estimate == null) return;
    _sizing?.cancel();
    final generation = ++_generation;
    _sizing = Timer(const Duration(milliseconds: 150), () async {
      final size = await estimate(_options);
      if (mounted && generation == _generation) setState(() => _size = size);
    });
  }

  void _set(VoidCallback change) {
    setState(change);
    _measure();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = AmalfiTheme.of(context).colors;
    final formats = widget.pdfOnly
        ? const [ExportFormat.jpeg, ExportFormat.pdf, ExportFormat.png]
        : ExportFormat.values;
    final pageImage =
        widget.pdfOnly &&
        (_format == ExportFormat.png || _format == ExportFormat.jpeg);
    return KeyedSubtree(
      key: const ValueKey('export sheet'),
      child: AmalfiDialog(
        title: l.exportTitle(widget.name),
        layout: AmalfiDialogLayout.generic,
        width: PreviewMetrics.exportWidth,
        children: [
          _row(
            context,
            l.format,
            AmalfiPopUpButton<ExportFormat>(
              key: const ValueKey('export format'),
              width: PreviewMetrics.exportWhere,
              items: [
                for (final f in formats)
                  AmalfiPopUpItem(value: f, label: f.label),
              ],
              value: _format,
              onChanged: (f) => _set(() => _format = f),
            ),
          ),
          if (_format == ExportFormat.jpeg)
            _row(
              context,
              l.quality,
              SizedBox(
                width: PreviewMetrics.exportSlider,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AmalfiSlider(
                      key: const ValueKey('export quality'),
                      value: _quality,
                      onChanged: (v) => setState(() => _quality = v),
                      onChangeEnd: (_) => _measure(),
                      semanticLabel: l.quality,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.qualityLeast,
                          style: AmalfiType.caption(
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          l.qualityBest,
                          style: AmalfiType.caption(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (pageImage)
            _row(
              context,
              l.resolution,
              AmalfiPopUpButton<int>(
                key: const ValueKey('export resolution'),
                width: PreviewMetrics.exportWhere,
                items: [
                  for (final v in ExportOptions.ppis)
                    AmalfiPopUpItem(value: v, label: l.ppiValue(v)),
                ],
                value: _ppi,
                onChanged: (v) => _set(() => _ppi = v),
              ),
            ),
          if (_format == ExportFormat.png && widget.alpha)
            _row(
              context,
              '',
              AmalfiCheckbox(
                key: const ValueKey('export alpha'),
                label: l.alpha,
                value: _alpha,
                onChanged: (v) => _set(() => _alpha = v),
              ),
            ),
          if (_format == ExportFormat.pdf && widget.onPermissions != null)
            _row(
              context,
              '',
              AmalfiPushButton(
                key: const ValueKey('export permissions'),
                label: l.permissionsButton,
                onPressed: () async {
                  final chosen = await widget.onPermissions!(_security);
                  if (chosen != null && mounted) {
                    setState(() => _security = chosen);
                  }
                },
              ),
            ),
          if (widget.estimate != null)
            _row(
              context,
              l.fileSizeLabel,
              Text(
                _size == null ? '—' : formatBytes(_size!, l.localeName),
                key: const ValueKey('export size'),
                style: AmalfiType.body(color: colors.textPrimary),
              ),
            ),
        ],
        footer: _footer(
          AmalfiPushButton(
            key: const ValueKey('export cancel'),
            label: l.cancel,
            onPressed: () => widget.close(),
          ),
          AmalfiPushButton(
            key: const ValueKey('export save'),
            label: l.save,
            variant: AmalfiPushButtonVariant.primary,
            onPressed: () => widget.close(
              ExportChoice(
                _format,
                quality: _quality,
                alpha: _alpha,
                ppi: _ppi,
                security: _security,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Edit Permissions.

/// The permissions and passwords of a PDF; null if cancelled.
Future<PdfSecurity?> showPermissionsSheet(
  BuildContext context, {
  PdfSecurity? initial,
}) => showPreviewSheet<PdfSecurity>(
  context,
  semanticLabel: AppLocalizations.of(context).editPermissions,
  builder: (context, sheet) =>
      _PermissionsSheet(initial: initial, close: sheet.close),
);

class _PermissionsSheet extends StatefulWidget {
  const _PermissionsSheet({required this.initial, required this.close});
  final PdfSecurity? initial;
  final void Function([PdfSecurity?]) close;

  @override
  State<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<_PermissionsSheet> {
  late bool _needsPassword = widget.initial?.userPassword != null;
  late final TextEditingController _user = TextEditingController(
    text: widget.initial?.userPassword ?? '',
  );
  late final TextEditingController _userAgain = TextEditingController(
    text: widget.initial?.userPassword ?? '',
  );
  late final TextEditingController _owner = TextEditingController(
    text: widget.initial?.ownerPassword ?? '',
  );
  late final TextEditingController _ownerAgain = TextEditingController(
    text: widget.initial?.ownerPassword ?? '',
  );
  late bool _printing = widget.initial?.printing ?? true;
  late bool _copying = widget.initial?.copying ?? true;
  late bool _assembling = widget.initial?.assembling ?? true;
  late bool _annotating = widget.initial?.annotating ?? true;
  late bool _forms = widget.initial?.formFilling ?? true;
  String? _problem;

  @override
  void dispose() {
    for (final c in [_user, _userAgain, _owner, _ownerAgain]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _restricted =>
      !_printing || !_copying || !_assembling || !_annotating || !_forms;

  void _apply(AppLocalizations l) {
    if (_needsPassword && _user.text.isEmpty) {
      setState(() => _problem = l.passwordMissing);
      return;
    }
    if (_needsPassword && _user.text != _userAgain.text) {
      setState(() => _problem = l.passwordsDiffer);
      return;
    }
    if (_owner.text != _ownerAgain.text) {
      setState(() => _problem = l.passwordsDiffer);
      return;
    }
    if (_restricted && _owner.text.isEmpty) {
      setState(() => _problem = l.ownerPasswordMissing);
      return;
    }
    widget.close(
      PdfSecurity(
        userPassword: _needsPassword ? _user.text : null,
        ownerPassword: _owner.text.isEmpty ? null : _owner.text,
        printing: _printing,
        copying: _copying,
        assembling: _assembling,
        annotating: _annotating,
        formFilling: _forms,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = AmalfiTheme.of(context).colors;
    // The fields fill the card's width (340 less its 24 pt padding).
    const fieldWidth = PreviewMetrics.permissionsWidth - 48;
    Widget field(String key, TextEditingController c, String hint, bool on) =>
        AmalfiSecureField(
          key: ValueKey(key),
          controller: c,
          enabled: on,
          width: fieldWidth,
          placeholder: hint,
          semanticLabel: hint,
        );
    Widget check(String key, String label, bool value, ValueChanged<bool> on) =>
        AmalfiCheckbox(
          key: ValueKey(key),
          label: label,
          value: value,
          onChanged: (v) => setState(() => on(v)),
        );
    Widget heading(String text) =>
        Text(text, style: AmalfiType.headline(color: colors.textPrimary));
    return KeyedSubtree(
      key: const ValueKey('permissions sheet'),
      child: AmalfiDialog(
        title: l.editPermissions,
        layout: AmalfiDialogLayout.generic,
        width: PreviewMetrics.permissionsWidth,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              AmalfiCheckbox(
                key: const ValueKey('require password'),
                label: l.requirePassword,
                value: _needsPassword,
                onChanged: (v) => setState(() => _needsPassword = v),
              ),
              field(
                'user password',
                _user,
                l.passwordPlaceholder,
                _needsPassword,
              ),
              field(
                'user password again',
                _userAgain,
                l.verify,
                _needsPassword,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              heading(l.permissions),
              check(
                'allow printing',
                l.allowPrinting,
                _printing,
                (v) => _printing = v,
              ),
              check(
                'allow copying',
                l.allowCopying,
                _copying,
                (v) => _copying = v,
              ),
              check(
                'allow assembling',
                l.allowAssembling,
                _assembling,
                (v) => _assembling = v,
              ),
              check(
                'allow annotating',
                l.allowAnnotating,
                _annotating,
                (v) => _annotating = v,
              ),
              check('allow forms', l.allowForms, _forms, (v) => _forms = v),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              heading(l.ownerPassword),
              field('owner password', _owner, l.passwordPlaceholder, true),
              field('owner password again', _ownerAgain, l.verify, true),
              if (_problem case final problem?)
                Text(
                  problem,
                  key: const ValueKey('permissions problem'),
                  style: AmalfiType.caption(color: colors.paletteTerracotta),
                ),
            ],
          ),
        ],
        footer: _footer(
          AmalfiPushButton(label: l.cancel, onPressed: () => widget.close()),
          AmalfiPushButton(
            key: const ValueKey('permissions apply'),
            label: l.apply,
            variant: AmalfiPushButtonVariant.primary,
            onPressed: () => _apply(l),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Adjust Size.

/// The units of the Adjust Size sheet.
enum SizeUnit { pixels, percent, inches, centimetres, millimetres, points }

/// The presets of "Fit into". *Provisional* (the list was not opened).
const List<Size> fitPresets = [
  Size(320, 240),
  Size(640, 480),
  Size(800, 600),
  Size(1024, 768),
  Size(1280, 1024),
  Size(1920, 1080),
];

/// The new size in pixels; null if cancelled.
Future<Size?> showAdjustSizeSheet(
  BuildContext context, {
  required ImageItem item,
}) => showPreviewSheet<Size>(
  context,
  semanticLabel: AppLocalizations.of(context).adjustSize,
  builder: (context, sheet) => _AdjustSizeSheet(item: item, close: sheet.close),
);

class _AdjustSizeSheet extends StatefulWidget {
  const _AdjustSizeSheet({required this.item, required this.close});
  final ImageItem item;
  final void Function([Size?]) close;

  @override
  State<_AdjustSizeSheet> createState() => _AdjustSizeSheetState();
}

class _AdjustSizeSheetState extends State<_AdjustSizeSheet> {
  late Size _pixels = widget.item.size;
  SizeUnit _unit = SizeUnit.pixels;
  double _resolution = 72;
  bool _proportional = true;
  int? _preset;
  late final TextEditingController _width = TextEditingController();
  late final TextEditingController _height = TextEditingController();
  late final TextEditingController _dpi = TextEditingController(text: '72');

  Size get _original => widget.item.size;

  @override
  void initState() {
    super.initState();
    _show();
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _dpi.dispose();
    super.dispose();
  }

  /// Pixels for one unit.
  double _per(SizeUnit unit, {required bool horizontal}) => switch (unit) {
    SizeUnit.pixels => 1,
    SizeUnit.percent => (horizontal ? _original.width : _original.height) / 100,
    SizeUnit.inches => _resolution,
    SizeUnit.centimetres => _resolution / 2.54,
    SizeUnit.millimetres => _resolution / 25.4,
    SizeUnit.points => _resolution / 72,
  };

  String _format(double v) {
    final rounded = (v * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(2);
  }

  void _show() {
    _width.text = _format(_pixels.width / _per(_unit, horizontal: true));
    _height.text = _format(_pixels.height / _per(_unit, horizontal: false));
  }

  void _typed({required bool width}) {
    final value = double.tryParse(
      (width ? _width.text : _height.text).replaceAll(',', '.'),
    );
    if (value == null || value <= 0) return;
    final px = value * _per(_unit, horizontal: width);
    final ratio = _original.width / _original.height;
    setState(() {
      _preset = null;
      if (width) {
        _pixels = Size(px, _proportional ? px / ratio : _pixels.height);
        if (_proportional) {
          _height.text = _format(
            _pixels.height / _per(_unit, horizontal: false),
          );
        }
      } else {
        _pixels = Size(_proportional ? px * ratio : _pixels.width, px);
        if (_proportional) {
          _width.text = _format(_pixels.width / _per(_unit, horizontal: true));
        }
      }
    });
  }

  void _choosePreset(int? index) {
    setState(() {
      _preset = index;
      if (index == null) return;
      final box = fitPresets[index];
      final scale = math.min(
        box.width / _original.width,
        box.height / _original.height,
      );
      _pixels = _original * scale;
      _show();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = AmalfiTheme.of(context).colors;
    final unitLabels = {
      SizeUnit.pixels: l.unitPixels,
      SizeUnit.percent: l.unitPercent,
      SizeUnit.inches: l.unitInches,
      SizeUnit.centimetres: l.unitCentimetres,
      SizeUnit.millimetres: l.unitMillimetres,
      SizeUnit.points: l.unitPoints,
    };
    final pixels = Size(
      _pixels.width.roundToDouble().clamp(1.0, 32768.0),
      _pixels.height.roundToDouble().clamp(1.0, 32768.0),
    );
    final percent =
        (pixels.width * pixels.height) /
        (_original.width * _original.height) *
        100;
    final before = widget.item.fileSize;
    final after = (before * percent / 100).round();
    Widget numberField(String key, TextEditingController c, VoidCallback on) =>
        AmalfiTextField(
          key: ValueKey(key),
          controller: c,
          width: 112,
          semanticLabel: key,
          onChanged: (_) => on(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
        );
    return KeyedSubtree(
      key: const ValueKey('adjust size sheet'),
      child: AmalfiDialog(
        title: l.adjustSize,
        layout: AmalfiDialogLayout.generic,
        width: PreviewMetrics.adjustSizeWidth,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              _row(
                context,
                l.fitInto,
                AmalfiPopUpButton<int>(
                  key: const ValueKey('fit into'),
                  width: 200,
                  items: [
                    AmalfiPopUpItem(value: -1, label: l.custom),
                    for (final (i, s) in fitPresets.indexed)
                      AmalfiPopUpItem(
                        value: i,
                        label: l.pixels(s.width.round(), s.height.round()),
                      ),
                  ],
                  value: _preset ?? -1,
                  onChanged: (i) => _choosePreset(i < 0 ? null : i),
                ),
              ),
              _row(
                context,
                l.widthLabel,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    numberField(
                      'adjust width',
                      _width,
                      () => _typed(width: true),
                    ),
                    AmalfiPopUpButton<SizeUnit>(
                      key: const ValueKey('size unit'),
                      width: 120,
                      items: [
                        for (final u in SizeUnit.values)
                          AmalfiPopUpItem(value: u, label: unitLabels[u]!),
                      ],
                      value: _unit,
                      onChanged: (u) => setState(() {
                        _unit = u;
                        _show();
                      }),
                    ),
                  ],
                ),
              ),
              _row(
                context,
                l.heightLabel,
                numberField(
                  'adjust height',
                  _height,
                  () => _typed(width: false),
                ),
              ),
              _row(
                context,
                '',
                AmalfiCheckbox(
                  key: const ValueKey('scale proportionally'),
                  label: l.scaleProportionally,
                  value: _proportional,
                  onChanged: (v) => setState(() {
                    _proportional = v;
                    if (v) _typed(width: true);
                  }),
                ),
              ),
              _row(
                context,
                l.resolution,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    numberField('resolution', _dpi, () {
                      final v = double.tryParse(_dpi.text.replaceAll(',', '.'));
                      if (v == null || v <= 0) return;
                      setState(() {
                        _resolution = v;
                        _show();
                      });
                    }),
                    Text(
                      l.pixelsPerInch,
                      style: AmalfiType.body(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 1, child: AmalfiWindowSeparator()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                l.resultingSize,
                style: AmalfiType.headline(color: colors.textPrimary),
              ),
              Text(
                l.resultingDetail(
                  '${percent.round()}',
                  formatBytes(before, l.localeName),
                  formatBytes(after, l.localeName),
                ),
                key: const ValueKey('resulting size'),
                style: AmalfiType.callout(color: colors.textSecondary),
              ),
            ],
          ),
        ],
        footer: _footer(
          AmalfiPushButton(label: l.cancel, onPressed: () => widget.close()),
          AmalfiPushButton(
            key: const ValueKey('adjust ok'),
            label: l.ok,
            variant: AmalfiPushButtonVariant.primary,
            onPressed: () => widget.close(pixels),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// A field: Go to Page.

/// A sheet with a message, one text field and two buttons; the text, or null if cancelled.
Future<String?> showFieldSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String accept,
  String placeholder = '',
  bool secure = false,
  Key? fieldKey,
}) => showPreviewSheet<String>(
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
    final colors = AmalfiTheme.of(context).colors;
    return AmalfiDialog(
      title: widget.title,
      layout: AmalfiDialogLayout.generic,
      width: PreviewMetrics.fieldSheetWidth,
      children: [
        Text(
          widget.message,
          style: AmalfiType.callout(color: colors.textSecondary),
        ),
        AmalfiTextField(
          key: widget.fieldKey,
          controller: _text,
          autofocus: true,
          obscureText: widget.secure,
          width: PreviewMetrics.fieldSheetWidth - 48,
          placeholder: widget.placeholder,
          semanticLabel: widget.title,
          onSubmitted: (_) => _accept(),
        ),
      ],
      footer: _footer(
        AmalfiPushButton(label: l.cancel, onPressed: () => widget.close()),
        AmalfiPushButton(
          key: const ValueKey('sheet accept'),
          label: widget.accept,
          variant: AmalfiPushButtonVariant.primary,
          onPressed: _accept,
        ),
      ),
    );
  }
}
