// The Preview window: toolbar, sidebar and the image or the pages; the keyboard shortcuts, the
// context menu with the app's menus, the sheets (export, password, go to page), the inspector
// and the alerts. What happens is the controller's (model/viewer.dart); this file wires it to
// the user.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../export/export.dart';
import '../model/document.dart';
import '../model/viewer.dart';
import '../portal.dart';
import '../style.dart';
import 'image_view.dart';
import 'inspector.dart';
import 'menus.dart';
import 'pdf_view.dart';
import 'sheets.dart';
import 'sidebar.dart';
import 'toolbar.dart';

/// An alert over the window: title, message.
typedef WindowAlert = (String, String?);

class PreviewWindow extends StatefulWidget {
  const PreviewWindow({
    super.key,
    required this.controller,
    required this.dialogs,
    this.active = true,
    this.onOpenCancelled,
    this.exporter = exportImage,
  });

  final ViewerController controller;

  /// Writes an exported image (tests replace it).
  final Exporter exporter;
  final FileDialogs dialogs;
  final bool active;

  /// The Open dialog shown at launch or on a reopen was cancelled (the window goes away, as the
  /// reference's Open panel leaves the app without windows).
  final VoidCallback? onOpenCancelled;

  @override
  State<PreviewWindow> createState() => PreviewWindowState();
}

class PreviewWindowState extends State<PreviewWindow> {
  final FocusNode _focus = FocusNode(debugLabel: 'preview window');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'search');
  final TextEditingController _search = TextEditingController();
  Timer? _searchDelay;
  OverlayEntry? _menu;
  WindowAlert? _alert;
  Offset? _inspectorAt;
  String? _askedPassword;
  Document? _sized;

  ViewerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  @override
  void didUpdateWidget(PreviewWindow old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _searchDelay?.cancel();
    _menu?.remove();
    _focus.dispose();
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (c.failures.isNotEmpty && _alert == null) {
      _alert = (
        l.openFailedTitle(c.failures.length),
        c.failures.map((f) => _failureText(f, l)).join('\n'),
      );
      c.failures.clear();
    }
    final path = c.passwordFor;
    if (path != null && path != _askedPassword) {
      _askedPassword = path;
      WidgetsBinding.instance.addPostFrameCallback((_) => _askPassword(path));
    }
    if (c.document != null && c.document != _sized) {
      _sized = c.document;
      _fitWindow();
    }
    if (!c.searching && _search.text.isNotEmpty) _search.clear();
    setState(() {});
  }

  String _failureText(OpenException f, AppLocalizations l) {
    final name = baseName(f.path);
    return switch (f.failure) {
      OpenFailure.missing => l.failMissing(name),
      OpenFailure.unsupported when f.detail.contains('PDF') => l.failOnePdf(
        name,
      ),
      OpenFailure.unsupported => l.failUnsupported(name),
      OpenFailure.damaged || OpenFailure.encrypted => l.failDamaged(name),
      OpenFailure.noPdfLibrary => l.failNoPdf(name),
    };
  }

  /// A newly opened single image gets a window of its size (within the screen), as on the
  /// reference; PDFs and several images keep the window. *Provisional* (PREVIEW-01).
  void _fitWindow() {
    final item = c.image;
    if (item == null || c.count != 1) return;
    final view = View.maybeOf(context);
    if (view == null) return;
    final screen = view.display.size / view.display.devicePixelRatio;
    if (screen.isEmpty) return;
    final turned = item.turnedSize;
    final limit = Size(
      screen.width * 0.85,
      screen.height * 0.85 - toolbarHeight,
    );
    final scale = math.min(
      1.0,
      math.min(limit.width / turned.width, limit.height / turned.height),
    );
    final size = Size(
      math.max(PreviewMetrics.minWindow.width, turned.width * scale),
      math.max(
        PreviewMetrics.minWindow.height,
        turned.height * scale + toolbarHeight,
      ),
    );
    unawaited(SilicaWindow.setSize(size));
  }

  // -------------------------------------------------------------------------------------------
  // Actions.

  /// File › Open…: the portal's Open dialog. `initial`: shown at launch or on a reopen.
  Future<void> open({bool initial = false}) async {
    final l = AppLocalizations.of(context);
    List<String>? paths;
    try {
      paths = await widget.dialogs.open(title: l.openDialogTitle);
    } on FileDialogUnavailable {
      if (!mounted) return;
      setState(() => _alert = (l.dialogUnavailable, l.dialogUnavailableDetail));
      return;
    }
    if (!mounted) return;
    if (paths == null || paths.isEmpty) {
      if (initial && c.document == null) widget.onOpenCancelled?.call();
      return;
    }
    await c.open(paths);
  }

  /// File › Export…: the options sheet, then the portal's Save dialog.
  Future<void> export() async {
    final item = c.image;
    if (item == null) return;
    final l = AppLocalizations.of(context);
    final options = await showExportSheet(context, name: item.name);
    if (options == null || !mounted) return;
    String? path;
    try {
      path = await widget.dialogs.save(
        title: l.exportDialogTitle,
        name: options.fileName(item.path),
      );
    } on FileDialogUnavailable {
      if (!mounted) return;
      setState(() => _alert = (l.dialogUnavailable, l.dialogUnavailableDetail));
      return;
    }
    if (path == null) return;
    try {
      await widget.exporter(item, options, path);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _alert = (l.exportFailed, '$e'));
    }
  }

  Future<void> _goToPage() async {
    final l = AppLocalizations.of(context);
    final text = await showFieldSheet(
      context,
      title: l.goToTitle,
      message: l.goToMessage(c.count),
      accept: l.go,
      fieldKey: const ValueKey('page field'),
    );
    final page = int.tryParse(text?.trim() ?? '');
    if (page == null) return;
    c.goTo(page - 1);
  }

  Future<void> _askPassword(String path) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final password = await showFieldSheet(
      context,
      title: l.passwordTitle(baseName(path)),
      message: c.passwordRetry ? l.passwordWrong : l.passwordMessage,
      accept: l.openButton,
      placeholder: l.passwordPlaceholder,
      secure: true,
      fieldKey: const ValueKey('password field'),
    );
    _askedPassword = null;
    if (password == null) {
      c.cancelPassword();
      return;
    }
    await c.openPdf(path, password: password);
  }

  void _find() {
    c.openSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _searchChanged(String text) {
    _searchDelay?.cancel();
    _searchDelay = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(c.find(text)),
    );
  }

  void _closeSearch() {
    _searchDelay?.cancel();
    c.closeSearch();
    _focus.requestFocus();
  }

  Future<void> _copy() async {
    final text = c.selectedText;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  List<AppMenu> menus(AppLocalizations l) => previewMenus(
    l,
    c,
    WindowActions(
      open: () => unawaited(open()),
      export: () => unawaited(export()),
      goToPage: () => unawaited(_goToPage()),
      find: _find,
      copy: () => unawaited(_copy()),
    ),
  );

  void _contextMenu(Offset at) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _menu?.remove();
    _menu = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: MenuHost(
          key: const ValueKey('context menu'),
          anchor: at,
          opaque: true,
          entries: menuEntries(menus(AppLocalizations.of(context))),
          onDismissed: () {
            _menu?.remove();
            _menu = null;
          },
        ),
      ),
    );
    overlay.insert(_menu!);
  }

  /// The sidebar button's menu: the sidebar kinds and the page layouts.
  List<MenuEntry> _viewMenu() {
    final all = menus(AppLocalizations.of(context));
    final view = all.firstWhere((m) => m.id == 'view');
    final entries = <MenuEntry>[];
    for (final command in view.items) {
      // Up to the zoom items: those are in the toolbar already.
      if (command != null && command.id == 'preview.actual_size') break;
      entries.add(
        command == null
            ? const MenuDivider()
            : MenuAction(
                command.label,
                shortcut: command.shortcut,
                checked: command.checked,
                enabled: command.enabled,
                onSelected: command.run,
              ),
      );
    }
    if (entries.isNotEmpty && entries.last is MenuDivider) entries.removeLast();
    return entries;
  }

  // -------------------------------------------------------------------------------------------
  // Keys.

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final l = AppLocalizations.of(context);
    if (runShortcut(menus(l), event, keyboard)) return KeyEventResult.handled;
    if (keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final continuous = c.isPdf && c.layout == PageLayout.continuous;
    void scrollBy(double dy) {
      if (!c.vertical.hasClients) return;
      final p = c.vertical.position;
      c.vertical.jumpTo(
        (p.pixels + dy).clamp(p.minScrollExtent, p.maxScrollExtent),
      );
      c.scrolled();
    }

    final page = c.viewport.height * 0.9;
    if (key == LogicalKeyboardKey.escape) {
      if (c.searching) {
        _closeSearch();
      } else {
        c.clearSelection();
      }
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        (key == LogicalKeyboardKey.arrowUp && !continuous)) {
      c.previous();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        (key == LogicalKeyboardKey.arrowDown && !continuous)) {
      c.next();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      scrollBy(-40);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      scrollBy(40);
    } else if (key == LogicalKeyboardKey.pageUp) {
      continuous ? scrollBy(-page) : c.previous();
    } else if (key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.space) {
      continuous ? scrollBy(page) : c.next();
    } else if (key == LogicalKeyboardKey.home) {
      c.first();
    } else if (key == LogicalKeyboardKey.end) {
      c.last();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // -------------------------------------------------------------------------------------------

  String? _subtitle(AppLocalizations l) {
    if (c.searching && c.query.trim().isNotEmpty) {
      if (!c.searchDone && c.matches.isEmpty) return l.searching;
      if (c.matches.isEmpty) return l.noMatches;
      return l.matchOf(c.matchIndex + 1, c.matches.length);
    }
    final doc = c.document;
    return switch (doc) {
      null => null,
      PdfDocument() => l.pageOf(c.current + 1, c.count),
      ImageDocument(:final images) when images.length > 1 => l.imageOf(
        c.current + 1,
        c.count,
      ),
      ImageDocument() => l.pixels(
        c.image!.size.width.round(),
        c.image!.size.height.round(),
      ),
    };
  }

  Widget _content(PreviewColors colors, AppLocalizations l) {
    if (c.document == null) {
      return ColoredBox(
        key: const ValueKey('empty'),
        color: colors.canvas,
        child: c.loading
            ? const SizedBox.expand()
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.emptyTitle,
                      style: previewText(15, color: colors.secondary),
                    ),
                    const SizedBox(height: 12),
                    SilicaButton(
                      key: const ValueKey('empty open'),
                      label: l.open,
                      onPressed: () => unawaited(open()),
                    ),
                  ],
                ),
              ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (d) => _contextMenu(d.globalPosition),
      child: c.isPdf ? PdfView(controller: c) : ImageView(controller: c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final title = c.document?.title ?? l.appName;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: colors.window,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PreviewToolbar(
                    controller: c,
                    title: title,
                    subtitle: _subtitle(l),
                    active: widget.active,
                    onSearch: _find,
                    viewMenu: _viewMenu,
                    searchField: SilicaSearchField(
                      key: const ValueKey('search field'),
                      labels: SearchFieldLabels(
                        placeholder: l.searchPlaceholder,
                        clear: l.searchClear,
                      ),
                      style: SearchFieldStyle.toolbar,
                      width: PreviewMetrics.searchWidth,
                      controller: _search,
                      focusNode: _searchFocus,
                      autofocus: true,
                      onChanged: _searchChanged,
                      onSubmitted: (_) =>
                          HardwareKeyboard.instance.isShiftPressed
                          ? c.findPrevious()
                          : c.findNext(),
                      onCancel: _closeSearch,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (c.document != null && c.sidebar != SidebarMode.none)
                          PreviewSidebar(controller: c, active: widget.active),
                        Expanded(child: _content(colors, l)),
                      ],
                    ),
                  ),
                ],
              ),
              if (c.inspector && c.document != null)
                Inspector(
                  controller: c,
                  position:
                      _inspectorAt ??
                      Offset(
                        math.max(
                          0,
                          box.maxWidth -
                              PreviewMetrics.inspectorSize.width -
                              16,
                        ),
                        toolbarHeight + 16,
                      ),
                  onMove: (at) => setState(() => _inspectorAt = at),
                ),
              if (_alert case (final title, final message))
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x33000000),
                    child: Center(
                      child: SilicaAlert(
                        key: const ValueKey('alert'),
                        title: title,
                        message: message,
                        opaque: true,
                        buttons: [
                          AlertButton(
                            l.ok,
                            role: AlertRole.primary,
                            onPressed: () {
                              setState(() => _alert = null);
                              _focus.requestFocus();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
