// A locked PDF (PREVIEW-02 › PDF features › Password): the password is asked inside the window,
// in place of the pages (kit `Apps/Preview/Password`). A lock glyph (32), a bold line saying the
// document is protected, a smaller line asking for the password, and a secure field (244 × 28)
// with the focus. A wrong
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
  void initState() {
    super.initState();
    // The field has the keyboard at once (the window's own focus would keep it otherwise).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

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
            PreviewSymbol(
              'lock',
              size: PreviewMetrics.lockGlyph,
              color: colors.tertiary,
              fallback: '🔒',
            ),
            const SizedBox(height: 12),
            Text(
              l.passwordProtected,
              style: AmalfiType.headline(color: colors.text),
            ),
            const SizedBox(height: 4),
            Text(
              widget.wrong ? l.passwordInvalid : l.passwordEnter,
              key: const ValueKey('password message'),
              style: AmalfiType.caption(color: colors.secondary),
            ),
            const SizedBox(height: 12),
            AmalfiSecureField(
              key: const ValueKey('password field'),
              controller: _text,
              focusNode: _focus,
              width: PreviewMetrics.passwordField,
              placeholder: l.passwordPlaceholder,
              semanticLabel: l.passwordPlaceholder,
              errorText: widget.wrong ? l.passwordInvalid : null,
              onSubmitted: (text) {
                if (text.isNotEmpty) widget.onPassword(text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
