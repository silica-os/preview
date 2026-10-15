// The app: the language (English, Italian), the active window state from Ossido, and the
// lifecycle of a document app. Closing the window keeps Preview running without windows, as
// on the reference; a reopen (the Dock, the Launcher) builds a new window and shows the Open
// dialog. Launched without files, Preview shows the Open dialog too; cancelling it leaves the
// app without windows.

import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../export/export.dart';
import '../model/document.dart';
import '../model/viewer.dart';
import '../portal.dart';
import '../style.dart';
import 'window.dart';

/// The system languages resolved against ours, English when none matches.
Locale resolveLocale(List<Locale> preferred) =>
    basicLocaleListResolution(preferred, AppLocalizations.supportedLocales);

class PreviewApp extends StatefulWidget {
  const PreviewApp({
    super.key,
    required this.loader,
    required this.dialogs,
    this.files = const [],
    this.locale,
    this.onController,
    this.exporter = exportImage,
  });

  final DocumentLoader loader;
  final FileDialogs dialogs;
  final Exporter exporter;

  /// The files from the command line, for the first window.
  final List<String> files;

  /// A fixed language (tests); null follows the system.
  final Locale? locale;

  /// Each new window's controller (tests).
  final ValueChanged<ViewerController>? onController;

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> with WidgetsBindingObserver {
  late Locale _locale =
      widget.locale ?? resolveLocale(PlatformDispatcher.instance.locales);
  bool _active = _isActive(WidgetsBinding.instance.lifecycleState);
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onStateChange: (state) => setState(() => _active = _isActive(state)),
  );
  late List<String> _files = widget.files;

  static bool _isActive(AppLifecycleState? s) =>
      s == null || s == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (widget.locale != null || locales == null) return;
    setState(() => _locale = resolveLocale(locales));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Localizations(
    locale: _locale,
    delegates: const [
      AppLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    child: DefaultTextEditingShortcuts(
      child: ScrollConfiguration(
        behavior: const SilicaScrollBehavior(),
        child: Builder(
          builder: (context) => ColoredBox(
            color: PreviewColors.of(context).window,
            child: _ActiveScope(
              active: _active,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => SilicaAppWindow(
                      builder: (context) {
                        final files = _files;
                        _files = const [];
                        return _Window(
                          loader: widget.loader,
                          dialogs: widget.dialogs,
                          files: files,
                          onController: widget.onController,
                          exporter: widget.exporter,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Whether the window is the active one: above the overlay, so the window built in an overlay
/// entry follows it.
class _ActiveScope extends InheritedWidget {
  const _ActiveScope({required this.active, required super.child});
  final bool active;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ActiveScope>()?.active ??
      true;

  @override
  bool updateShouldNotify(_ActiveScope old) => old.active != active;
}

/// One window with its own controller: built again from scratch on every reopen.
class _Window extends StatefulWidget {
  const _Window({
    required this.loader,
    required this.dialogs,
    required this.files,
    this.onController,
    this.exporter = exportImage,
  });

  final DocumentLoader loader;
  final FileDialogs dialogs;
  final Exporter exporter;
  final List<String> files;
  final ValueChanged<ViewerController>? onController;

  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> {
  late final ViewerController _controller = ViewerController(
    loader: widget.loader,
  );
  final GlobalKey<PreviewWindowState> _window = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.onController?.call(_controller);
    if (widget.files.isNotEmpty) {
      unawaited(_controller.open(widget.files));
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_window.currentState?.open(initial: true)),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PreviewWindow(
    key: _window,
    controller: _controller,
    dialogs: widget.dialogs,
    active: _ActiveScope.of(context),
    onOpenCancelled: () => unawaited(SilicaApp.closeWindow()),
    exporter: widget.exporter,
  );
}
