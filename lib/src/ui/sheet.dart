// The window's modal sheets on Amalfi: the window behind is dimmed by the Amalfi scrim
// (`Text/Primary` at 16 %), and the card (an `AmalfiDialog`: `Surface/Raised`, radius 20) comes
// in centred on the window. The motion is the measured one of the reference's card sheets
// (silica_ui CT-SH-01): the scrim fades in over ~295 ms; the card follows ~67 ms later, fading
// in and moving down 20 pt in ~268 ms; closing fades the card in ~224 ms and the scrim ~40 ms
// later. The sheet is modal for its window (what is behind takes no clicks); Esc cancels.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

/// An open sheet: [close] hides it and completes [showPreviewSheet] with a value.
class PreviewSheet<T> {
  PreviewSheet._();
  final Completer<T?> _done = Completer<T?>();
  VoidCallback? _hide;

  void close([T? value]) {
    if (_done.isCompleted) return;
    _done.complete(value);
    _hide?.call();
  }
}

const Duration _scrimIn = Duration(milliseconds: 295);
const Duration _cardDelay = Duration(milliseconds: 67);
const Duration _cardIn = Duration(milliseconds: 268);
const Duration _cardOut = Duration(milliseconds: 224);
const Duration _scrimOutDelay = Duration(milliseconds: 40);
const double _cardDrop = 20;

/// Shows a sheet over the window of `context` (it needs an [Overlay]). The future completes
/// with the value given to [PreviewSheet.close] (null when cancelled with Esc).
Future<T?> showPreviewSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, PreviewSheet<T> sheet) builder,
  String? semanticLabel,
  bool cancelOnEscape = true,
}) {
  final overlay = Overlay.of(context);
  final theme = AmalfiTheme.of(context);
  final route = PreviewSheet<T>._();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => AmalfiTheme(
      brightness: theme.brightness,
      app: theme.app,
      child: _SheetLayer<T>(
        route: route,
        cancelOnEscape: cancelOnEscape,
        semanticLabel: semanticLabel,
        builder: builder,
        onGone: () {
          entry.remove();
          entry.dispose();
        },
      ),
    ),
  );
  overlay.insert(entry);
  return route._done.future;
}

class _SheetLayer<T> extends StatefulWidget {
  const _SheetLayer({
    required this.route,
    required this.cancelOnEscape,
    required this.semanticLabel,
    required this.builder,
    required this.onGone,
  });

  final PreviewSheet<T> route;
  final bool cancelOnEscape;
  final String? semanticLabel;
  final Widget Function(BuildContext context, PreviewSheet<T> sheet) builder;
  final VoidCallback onGone;

  @override
  State<_SheetLayer<T>> createState() => _SheetLayerState<T>();
}

class _SheetLayerState<T> extends State<_SheetLayer<T>>
    with TickerProviderStateMixin {
  late final AnimationController _scrim = AnimationController(
    vsync: this,
    duration: _scrimIn,
    reverseDuration: _cardOut,
  );
  late final AnimationController _card = AnimationController(
    vsync: this,
    duration: _cardIn,
    reverseDuration: _cardOut,
  );
  final FocusScopeNode _focus = FocusScopeNode();
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    widget.route._hide = _hide;
    _scrim.forward();
    _delay = Timer(_cardDelay, () {
      if (mounted) _card.forward();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _scrim.dispose();
    _card.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _hide() async {
    _delay?.cancel();
    final card = _card.reverse();
    await Future<void>.delayed(_scrimOutDelay);
    if (!mounted) return;
    await Future.wait([card, _scrim.reverse()]);
    if (mounted) widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final content = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              if (widget.cancelOnEscape) widget.route.close();
              return null;
            },
          ),
        },
        child: FocusScope(
          node: _focus,
          child: Focus(
            autofocus: true,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: widget.semanticLabel,
              child: Builder(
                builder: (context) => widget.builder(context, widget.route),
              ),
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        // The scrim dims what is under the toolbar, and takes the clicks of the window behind.
        Positioned(
          left: 0,
          right: 0,
          top: AmalfiToolbarMetrics.toolbarHeight,
          bottom: 0,
          child: AbsorbPointer(
            child: FadeTransition(
              opacity: _scrim,
              child: const AmalfiSheetScrim(),
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _card,
            builder: (context, child) {
              final t = _card.status == AnimationStatus.reverse
                  ? 0.0
                  : Curves.easeOut.transform(1 - _card.value);
              return Opacity(
                opacity: _card.value,
                child: Transform.translate(
                  offset: Offset(0, -_cardDrop * t),
                  child: child,
                ),
              );
            },
            child: content,
          ),
        ),
      ],
    );
  }
}
