// The window's sheets (PREVIEW-02 › Files, PDF features, Markup):
//
// - Export: 406 pt wide. The format (JPEG, PDF, PNG, TIFF) with its options: the JPEG quality
//   slider (182 pt, Least … Best, 0.85 by default), the PNG alpha check box (only for an image
//   with transparency), the permissions of a PDF; the file size of the result, live; Cancel and
//   Save (81 × 26). The name and the folder are asked next by the desktop's Save dialog.
// - Edit Permissions: 339 × 487. A password to open the document (and its confirmation), the
//   five permissions, and the owner password that guards them.
// - Adjust Size: 417 × 414, centred on the window. A preset or custom size, width and height
//   linked when scaling proportionally, the unit, the resolution, and the resulting size.
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

/// The chosen export, with the permissions of an exported PDF.
class ExportChoice extends ExportOptions {
  const ExportChoice(super.format, {super.quality, super.alpha, this.security});
  final PdfSecurity? security;
}

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
}) => showWindowSheet<ExportChoice>(
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
      ? ExportFormat.pdf
      : widget.initial.format;
  late double _quality = widget.initial.quality;
  late bool _alpha = widget.initial.alpha;
  PdfSecurity? _security;
  int? _size;
  Timer? _sizing;
  int _generation = 0;

  ExportOptions get _options =>
      ExportOptions(_format, quality: _quality, alpha: _alpha);

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
    final colors = PreviewColors.of(context);
    Widget row(String label, Widget control) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: previewText(13, color: colors.text),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: control),
        ],
      ),
    );
    final formats = widget.pdfOnly
        ? const [ExportFormat.pdf]
        : ExportFormat.values;
    return SizedBox(
      key: const ValueKey('export sheet'),
      width: PreviewMetrics.exportWidth,
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
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            row(
              l.format,
              PopUpButton<ExportFormat>(
                key: const ValueKey('export format'),
                width: PreviewMetrics.exportWhere,
                items: [for (final f in formats) PopUpItem(f, f.label)],
                value: _format,
                onChanged: (f) => _set(() => _format = f),
              ),
            ),
            if (_format == ExportFormat.jpeg)
              row(
                l.quality,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.qualityLeast,
                      style: previewText(11, color: colors.secondary),
                    ),
                    const SizedBox(width: 6),
                    SilicaSlider(
                      key: const ValueKey('export quality'),
                      width: PreviewMetrics.exportSlider,
                      value: _quality,
                      onChanged: (v) => setState(() => _quality = v),
                      onChangeEnd: (_) => _measure(),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.qualityBest,
                      style: previewText(11, color: colors.secondary),
                    ),
                  ],
                ),
              ),
            if (_format == ExportFormat.png && widget.alpha)
              row(
                '',
                SilicaCheckbox(
                  key: const ValueKey('export alpha'),
                  label: l.alpha,
                  value: _alpha,
                  onChanged: (v) => _set(() => _alpha = v),
                ),
              ),
            if (_format == ExportFormat.pdf && widget.onPermissions != null)
              row(
                '',
                Align(
                  alignment: Alignment.centerLeft,
                  child: SilicaButton(
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
              ),
            if (widget.estimate != null)
              row(
                l.fileSizeLabel,
                Text(
                  _size == null ? '—' : formatBytes(_size!, l.localeName),
                  key: const ValueKey('export size'),
                  style: previewText(13, color: colors.secondary),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SilicaButton(
                  key: const ValueKey('export cancel'),
                  label: l.cancel,
                  minWidth: PreviewMetrics.exportButton.width,
                  onPressed: () => widget.close(),
                ),
                const SizedBox(width: 8),
                SilicaButton(
                  key: const ValueKey('export save'),
                  label: l.save,
                  minWidth: PreviewMetrics.exportButton.width,
                  role: ButtonRole.primary,
                  onPressed: () => widget.close(
                    ExportChoice(
                      _format,
                      quality: _quality,
                      alpha: _alpha,
                      security: _security,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
}) => showWindowSheet<PdfSecurity>(
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
    final colors = PreviewColors.of(context);
    Widget field(String key, TextEditingController c, String hint, bool on) =>
        Padding(
          padding: const EdgeInsets.only(left: 24, top: 6),
          child: SilicaTextField(
            key: ValueKey(key),
            controller: c,
            secure: true,
            enabled: on,
            placeholder: hint,
          ),
        );
    Widget check(String key, String label, bool value, ValueChanged<bool> on) =>
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SilicaCheckbox(
            key: ValueKey(key),
            label: label,
            value: value,
            onChanged: (v) => setState(() => on(v)),
          ),
        );
    return SizedBox(
      key: const ValueKey('permissions sheet'),
      width: PreviewMetrics.permissionsSheet.width,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SilicaCheckbox(
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
            field('user password again', _userAgain, l.verify, _needsPassword),
            const SizedBox(height: 16),
            Text(
              l.permissions,
              style: previewText(
                13,
                color: colors.text,
                weight: FontWeight.w700,
              ),
            ),
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
            const SizedBox(height: 16),
            Text(
              l.ownerPassword,
              style: previewText(
                13,
                color: colors.text,
                weight: FontWeight.w700,
              ),
            ),
            field('owner password', _owner, l.passwordPlaceholder, true),
            field('owner password again', _ownerAgain, l.verify, true),
            if (_problem case final problem?)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  problem,
                  key: const ValueKey('permissions problem'),
                  style: previewText(11, color: const Color(0xFFE5322D)),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SilicaButton(label: l.cancel, onPressed: () => widget.close()),
                const SizedBox(width: 8),
                SilicaButton(
                  key: const ValueKey('permissions apply'),
                  label: l.apply,
                  role: ButtonRole.primary,
                  onPressed: () => _apply(l),
                ),
              ],
            ),
          ],
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
}) => showWindowSheet<Size>(
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
    final colors = PreviewColors.of(context);
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
    Widget label(String text) => SizedBox(
      width: 110,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: previewText(13, color: colors.text),
      ),
    );
    Widget numberField(String key, TextEditingController c, VoidCallback on) =>
        SizedBox(
          width: 106,
          height: 26,
          child: SilicaTextField(
            key: ValueKey(key),
            controller: c,
            onChanged: (_) => on(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
          ),
        );
    return SizedBox.fromSize(
      key: const ValueKey('adjust size sheet'),
      size: PreviewMetrics.adjustSizeSheet,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                label(l.fitInto),
                const SizedBox(width: 8),
                PopUpButton<int>(
                  key: const ValueKey('fit into'),
                  width: 200,
                  items: [
                    PopUpItem(-1, l.custom),
                    for (final (i, s) in fitPresets.indexed)
                      PopUpItem(i, l.pixels(s.width.round(), s.height.round())),
                  ],
                  value: _preset ?? -1,
                  onChanged: (i) => _choosePreset(i < 0 ? null : i),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                label(l.widthLabel),
                const SizedBox(width: 8),
                numberField('adjust width', _width, () => _typed(width: true)),
                const SizedBox(width: 8),
                PopUpButton<SizeUnit>(
                  key: const ValueKey('size unit'),
                  width: 120,
                  items: [
                    for (final u in SizeUnit.values)
                      PopUpItem(u, unitLabels[u]!),
                  ],
                  value: _unit,
                  onChanged: (u) => setState(() {
                    _unit = u;
                    _show();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                label(l.heightLabel),
                const SizedBox(width: 8),
                numberField(
                  'adjust height',
                  _height,
                  () => _typed(width: false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                label(l.resolution),
                const SizedBox(width: 8),
                numberField('resolution', _dpi, () {
                  final v = double.tryParse(_dpi.text.replaceAll(',', '.'));
                  if (v == null || v <= 0) return;
                  setState(() {
                    _resolution = v;
                    _show();
                  });
                }),
                const SizedBox(width: 8),
                Text(
                  l.pixelsPerInch,
                  style: previewText(13, color: colors.text),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 118),
              child: SilicaCheckbox(
                key: const ValueKey('scale proportionally'),
                label: l.scaleProportionally,
                value: _proportional,
                onChanged: (v) => setState(() {
                  _proportional = v;
                  if (v) _typed(width: true);
                }),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: colors.sidebarLine),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.resultingSize,
                    style: previewText(
                      11,
                      color: colors.secondary,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.resultingDetail(
                      '${percent.round()}',
                      formatBytes(before, l.localeName),
                      formatBytes(after, l.localeName),
                    ),
                    key: const ValueKey('resulting size'),
                    style: previewText(11, color: colors.text),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SilicaButton(
                  label: l.cancel,
                  minWidth: 71,
                  onPressed: () => widget.close(),
                ),
                const SizedBox(width: 8),
                SilicaButton(
                  key: const ValueKey('adjust ok'),
                  label: l.ok,
                  minWidth: 71,
                  role: ButtonRole.primary,
                  onPressed: () => widget.close(pixels),
                ),
              ],
            ),
          ],
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
      width: 360,
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
                weight: FontWeight.w700,
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
