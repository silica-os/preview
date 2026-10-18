// The app: the language (English, Italian), the active window state from Ossido, and the
// lifecycle of a document app. Closing the window keeps Preview running without windows, as
// on the reference; a reopen (the Dock, the Launcher) builds a new window and shows the Open
// dialog. Launched without files, Preview shows the Open dialog too; cancelling it leaves the
// app without windows.

import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../args.dart';
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
    this.screenSize = systemScreenSize,
  });

  final DocumentLoader loader;
  final FileDialogs dialogs;
  final Exporter exporter;

  /// The screen's size (tests give one).
  final ScreenSize screenSize;

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

  /// The window's controller: files of a later launch (Open With while Preview runs) replace
  /// what it shows.
  ViewerController? _current;

  static bool _isActive(AppLifecycleState? s) =>
      s == null || s == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle;
    SilicaApp.onOpen = _onOpen;
    // Dates in the inspector, in every language.
    unawaited(initializeDateFormatting());
  }

  /// The Open dialog could not be shown: the window opens empty and says why.
  bool _dialogUnavailable = false;

  /// The Open panel alone, while there is no window (launch without a document, a reopen, File ›
  /// Open… with no window): true when there is something to show.
  Future<bool> _chooseDocument() async {
    // Files of a second launch already waiting.
    if (_files.isNotEmpty) return true;
    final l = lookupAppLocalizations(_locale);
    List<String>? paths;
    try {
      paths = await widget.dialogs.open(title: l.openDialogTitle);
    } on FileDialogUnavailable {
      // No portal (outside Silica): the empty window with its Open button and the reason.
      _dialogUnavailable = true;
      return true;
    }
    if (!mounted || paths == null || paths.isEmpty) return false;
    _files = paths;
    return true;
  }

  /// Files of a second launch. The embedder has one window per app, so the document shown is
  /// replaced (edits are saved first, as closing the window does). With no window yet (the
  /// reopen is still building it) they open in the next one.
  void _onOpen(List<String> args) {
    final files = filesFromArgs(args);
    if (files.isEmpty) return;
    final controller = _current;
    if (controller == null || controller.disposed) {
      _files = files;
      return;
    }
    unawaited(_openIn(controller, files));
  }

  Future<void> _openIn(ViewerController controller, List<String> files) async {
    try {
      if (controller.edited) await controller.save();
    } on Object {
      // The file stays as it was.
    }
    if (!controller.disposed) await controller.open(files);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (widget.locale != null || locales == null) return;
    setState(() => _locale = resolveLocale(locales));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SilicaApp.onOpen = null;
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
        // The Amalfi tokens with the Preview palette (`App/Preview/*`), light and dark.
        child: AmalfiTheme(
          app: 'Preview',
          child: Builder(
            builder: (context) => ColoredBox(
              color: PreviewColors.of(context).window,
              child: _ActiveScope(
                active: _active,
                child: Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => SilicaAppWindow(
                        // A document app (APP-LC): without a document, at launch and at a
                        // reopen, only the Open panel shows; no empty window (preview#24).
                        startsWithDocument: widget.files.isNotEmpty,
                        chooseDocument: _chooseDocument,
                        windowlessBuilder: (context, open) =>
                            _WindowlessMenus(onOpen: open),
                        builder: (context) {
                          final files = _files;
                          _files = const [];
                          final unavailable = _dialogUnavailable;
                          _dialogUnavailable = false;
                          return _Window(
                            loader: widget.loader,
                            dialogs: widget.dialogs,
                            files: files,
                            dialogUnavailable: unavailable,
                            onController: (controller) {
                              _current = controller;
                              widget.onController?.call(controller);
                            },
                            exporter: widget.exporter,
                            screenSize: widget.screenSize,
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
    this.dialogUnavailable = false,
    this.onController,
    this.exporter = exportImage,
    this.screenSize = systemScreenSize,
  });

  final DocumentLoader loader;
  final FileDialogs dialogs;
  final Exporter exporter;
  final ScreenSize screenSize;
  final List<String> files;

  /// The Open dialog could not be shown: the window says why.
  final bool dialogUnavailable;
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
    } else if (widget.dialogUnavailable) {
      // File › Open… says the dialog cannot be shown.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_window.currentState?.open()),
      );
    }
  }

  @override
  void dispose() {
    // Closing the window saves the changes (there is no question to answer, as on the
    // reference), then lets go of the document.
    unawaited(_controller.saveAndDispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PreviewWindow(
    key: _window,
    controller: _controller,
    dialogs: widget.dialogs,
    active: _ActiveScope.of(context),
    exporter: widget.exporter,
    screenSize: widget.screenSize,
  );
}

/// The menus Preview offers with no window (the app menu, File › Open…), as the reference does
/// after its Open panel was cancelled.
class _WindowlessMenus extends StatelessWidget {
  const _WindowlessMenus({required this.onOpen});

  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SilicaWindowlessMenuBar(
      menus: [
        SilicaMenus.app(l.appName),
        SilicaMenu(
          label: l.menuFile,
          menus: [
            SilicaMenuItem(
              label: l.open,
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                meta: true,
              ),
              onSelected: () => unawaited(onOpen()),
            ),
          ],
        ),
      ],
    );
  }
}
