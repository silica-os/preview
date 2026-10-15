// The title popover (PREVIEW-01 › Title bar and toolbar): 502 × 150, under the title. The name
// field, with the name selected (Return or closing the popover renames the file), and where the
// file is. The reference also has tags, a location pop-up that moves the file, and a lock: not
// in Preview (preview issue on the title popover).

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/document.dart';
import '../style.dart';

class TitlePopover extends StatefulWidget {
  const TitlePopover({
    super.key,
    required this.path,
    required this.onRename,
    required this.close,
  });

  final String path;

  /// Renames the file to the name given (the popover closes after).
  final ValueChanged<String> onRename;
  final VoidCallback close;

  @override
  State<TitlePopover> createState() => _TitlePopoverState();
}

class _TitlePopoverState extends State<TitlePopover> {
  late final TextEditingController _name = TextEditingController(
    text: baseName(widget.path),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // The name without its extension is selected, ready to be replaced.
    final name = _name.text;
    final dot = name.lastIndexOf('.');
    _name.selection = TextSelection(
      baseOffset: 0,
      extentOffset: dot > 0 ? dot : name.length,
    );
  }

  @override
  void dispose() {
    _commit();
    _name.dispose();
    super.dispose();
  }

  void _commit() {
    if (_done) return;
    _done = true;
    final name = _name.text.trim();
    if (name.isEmpty || name == baseName(widget.path)) return;
    // After the popover is gone: renaming rebuilds the window.
    final rename = widget.onRename;
    Future.microtask(() => rename(name));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final slash = widget.path.lastIndexOf('/');
    final folder = slash <= 0 ? '/' : widget.path.substring(0, slash);
    Widget row(String label, Widget child) => Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: previewText(13, color: colors.text),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
    return SizedBox.fromSize(
      key: const ValueKey('title popover'),
      size: PreviewMetrics.titlePopover,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row(
              l.nameLabel,
              SilicaTextField(
                key: const ValueKey('rename field'),
                controller: _name,
                autofocus: true,
                onSubmitted: (_) {
                  _commit();
                  widget.close();
                },
              ),
            ),
            const SizedBox(height: 14),
            row(
              l.whereLabel,
              Text(
                folder,
                key: const ValueKey('where'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: previewText(13, color: colors.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
