// A locked PDF (PREVIEW-02 › PDF features › Password): the password is asked inside the window,
// in place of the pages. A lock glyph (58 × 45), a bold line saying the document is protected,
// a smaller line asking for the password, and a secure field 242 × 24 with the focus. A wrong
// password clears the field and changes the second line; there is no shake. The right one
// unlocks the document at once.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../style.dart';
import 'symbol.dart';

class PasswordView extends StatefulWidget {
  const PasswordView({
    super.key,
    required this.wrong,
    required this.attempt,
    required this.onPassword,
  });

  /// The last password was wrong.
  final bool wrong;

  /// Counts the passwords tried: a new wrong one empties the field.
  final int attempt;
  final ValueChanged<String> onPassword;

  @override
  State<PasswordView> createState() => _PasswordViewState();
}

class _PasswordViewState extends State<PasswordView> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'password');

  @override
  void didUpdateWidget(PasswordView old) {
    super.didUpdateWidget(old);
    // A wrong password: the field is emptied, the focus stays.
    if (widget.wrong && widget.attempt != old.attempt) {
      _text.clear();
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    return ColoredBox(
      key: const ValueKey('password view'),
      color: colors.pdfCanvas,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.fromSize(
              size: PreviewMetrics.lockGlyph,
              child: PreviewSymbol(
                'lock',
                size: PreviewMetrics.lockGlyph.height,
                color: colors.secondary,
                fallback: '🔒',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.passwordProtected,
              style: previewText(
                13,
                color: colors.text,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.wrong ? l.passwordInvalid : l.passwordEnter,
              key: const ValueKey('password message'),
              style: previewText(11, color: colors.secondary),
            ),
            const SizedBox(height: 12),
            SizedBox.fromSize(
              size: PreviewMetrics.passwordField,
              child: SilicaTextField(
                key: const ValueKey('password field'),
                controller: _text,
                focusNode: _focus,
                autofocus: true,
                secure: true,
                width: PreviewMetrics.passwordField.width,
                placeholder: l.passwordPlaceholder,
                onSubmitted: (text) {
                  if (text.isNotEmpty) widget.onPassword(text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
