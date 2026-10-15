// The Preview window: the glass toolbar over the content that scrolls under it, the find bar
// and the markup toolbar under it, the sidebar (sliding in 250 ms and out in 220 ms, resizable
// from 160 to 400), the image or the pages (or the contact sheet, or the password view of a
// locked PDF), and the inspector pane on the right; the keyboard shortcuts, the context menus,
// the sheets, the popovers, the slideshow and the alerts. What happens is the controller's
// (model/viewer.dart); this file wires it to the user.

import 'dart:async';
import 'dart:io' show FileSystemException;
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../export/export.dart';
import '../model/document.dart';
import '../model/markup.dart';
import '../model/viewer.dart';
import '../model/window_size.dart';
import '../pdf/backend.dart';
import '../pdf/qpdf.dart';
import '../portal.dart';
import '../style.dart';
import 'contact_sheet.dart';
import 'find_bar.dart';
import 'image_view.dart';
import 'inspector.dart';
import 'markup_bar.dart';
import 'menus.dart';
import 'notes.dart';
import 'password_view.dart';
import 'pdf_view.dart';
import 'popover.dart';
import 'sheets.dart';
import 'sidebar.dart';
import 'slideshow.dart';
import 'symbol.dart';
import 'title_popover.dart';
import 'toolbar.dart';
import 'zoom_view.dart';

/// An alert over the window: title, message, and its buttons (none: OK).
typedef WindowAlert = (String, String?, List<AlertButton>?);

/// Where the size of the screen comes from: the display Flutter reports, or the embedder.
typedef ScreenSize = Future<Size?> Function(BuildContext context);

/// The screen in points: Flutter's display, else the embedder's `outputSize` on the
/// `silica/window` channel; null when neither knows it.
Future<Size?> systemScreenSize(BuildContext context) async {
  final view = View.maybeOf(context);
  if (view != null) {
    try {
      final size = view.display.size / view.display.devicePixelRatio;
      if (!size.isEmpty) return size;
    } on Object {
      // No display reported.
    }
  }
  try {
    final reply = await SilicaWindow.channel.invokeMethod<Object?>(
      'outputSize',
    );
    if (reply case {'width': final num w, 'height': final num h}) {
      return Size(w.toDouble(), h.toDouble());
    }
  } on Object {
    // The embedder does not answer it (yet): silica-desktop issue on the screen size.
  }
  return null;
}

class PreviewWindow extends StatefulWidget {
  const PreviewWindow({
    super.key,
    required this.controller,
    required this.dialogs,
    this.active = true,
    this.onOpenCancelled,
    this.exporter = exportImage,
    this.screenSize = systemScreenSize,
    this.onClose,
  });

  final ViewerController controller;

  /// Writes an exported image (tests replace it).
  final Exporter exporter;
  final FileDialogs dialogs;
  final bool active;

  /// The Open dialog shown at launch or on a reopen was cancelled (the window goes away, as the
  /// reference's Open panel leaves the app without windows).
  final VoidCallback? onOpenCancelled;

  /// The screen's size, for the size of the window of a new document.
  final ScreenSize screenSize;

  /// File › Close Window.
  final VoidCallback? onClose;

  @override
  State<PreviewWindow> createState() => PreviewWindowState();
}

class PreviewWindowState extends State<PreviewWindow>
    with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode(debugLabel: 'preview window');
  final FocusNode _searchFocus = FocusNode(debugLabel: 'search');
  final TextEditingController _search = TextEditingController();
  OverlayEntry? _menu;
  PopoverHandle? _popover;
  WindowAlert? _alert;
  Document? _sized;
  bool _markupShown = false;
  bool _toolbarShown = true;
  bool _slideshow = false;
  bool _findBar = false;

  /// The sidebar's presence: 0 hidden … 1 shown.
  late final AnimationController _sidebar = AnimationController(
    vsync: this,
    duration: PreviewMetrics.sidebarShow,
    reverseDuration: PreviewMetrics.sidebarHide,
    value: 0,
  )..addListener(() => setState(() {}));
  SidebarMode _shownMode = SidebarMode.none;

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
    _menu?.remove();
    _popover?.close();
    _sidebar.dispose();
    _focus.dispose();
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _sidebarWanted =>
      c.document != null &&
      ((c.sidebar != SidebarMode.none &&
              c.sidebar != SidebarMode.contactSheet) ||
          showsResults(c));

  void _changed() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (c.failures.isNotEmpty && _alert == null) {
      _alert = (
        l.openFailedTitle(c.failures.length),
        c.failures.map((f) => _failureText(f, l)).join('\n'),
        null,
      );
      c.failures.clear();
    }
    if (c.document != null && c.document != _sized) {
      final first = _sized == null;
      _sized = c.document;
      // A new document: the sidebar is there at once, as the window opens with it.
      if (_sidebarWanted) _sidebar.value = 1;
      if (first) unawaited(_fitWindow());
    }
    // The sidebar slides in and out.
    if (_sidebarWanted &&
        _sidebar.status != AnimationStatus.forward &&
        _sidebar.value < 1) {
      unawaited(_sidebar.forward());
    } else if (!_sidebarWanted &&
        _sidebar.status != AnimationStatus.reverse &&
        _sidebar.value > 0) {
      unawaited(_sidebar.reverse());
    }
    if (_sidebarWanted) _shownMode = c.sidebar;
    if (c.sidebar == SidebarMode.notes) unawaited(c.loadAllAnnotations());
    if (!c.searching) {
      _findBar = false;
      if (_search.text.isNotEmpty) _search.clear();
    }
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

  /// The window of a newly opened document takes its size (PREVIEW-01 › Default window size):
  /// an image at 100 % when it fits, a PDF as tall as the screen allows.
  Future<void> _fitWindow() async {
    final screen =
        await widget.screenSize(context) ?? PreviewMetrics.fallbackScreen;
    if (!mounted) return;
    final room = windowRoom(screen);
    final Size size;
    final item = c.image;
    if (item != null) {
      size = imageWindowSize(
        item.turnedSize,
        sidebar: c.sidebar == SidebarMode.none ? 0 : c.sidebarWidth,
        room: room,
      );
    } else if (c.isPdf) {
      size = pdfWindowSize(
        c.widestPage,
        actualScale: c.actualScale,
        sidebar: c.sidebar == SidebarMode.none ? 0 : c.sidebarWidth,
        room: room,
      );
    } else {
      return;
    }
    unawaited(SilicaWindow.setSize(size));
  }

  // -------------------------------------------------------------------------------------------
  // Actions.

  void _say(String title, [String? message]) =>
      setState(() => _alert = (title, message, null));

  /// File › Open…: the portal's Open dialog. `initial`: shown at launch or on a reopen.
  Future<void> open({bool initial = false}) async {
    final l = AppLocalizations.of(context);
    List<String>? paths;
    try {
      paths = await widget.dialogs.open(title: l.openDialogTitle);
    } on FileDialogUnavailable {
      if (!mounted) return;
      _say(l.dialogUnavailable, l.dialogUnavailableDetail);
      return;
    }
    if (!mounted) return;
    if (paths == null || paths.isEmpty) {
      if (initial && c.document == null) widget.onOpenCancelled?.call();
      return;
    }
    // What was open is saved before it is replaced.
    if (c.edited) await _save();
    _sized = null;
    await c.open(paths);
  }

  Future<void> _save() async {
    try {
      await c.save();
    } on Object catch (e) {
      if (!mounted) return;
      _say(AppLocalizations.of(context).saveFailed, '$e');
    }
  }

  /// File › Export…: the options sheet, then the portal's Save dialog.
  Future<void> export({ExportFormat? format}) async {
    final l = AppLocalizations.of(context);
    final item = c.image;
    final pdf = c.pdf;
    if (item == null && pdf == null) return;
    final name = item?.name ?? pdf!.name;
    final alpha = item?.transparent ?? false;
    final options = await showExportSheet(
      context,
      name: name,
      pdfOnly: pdf != null,
      alpha: alpha,
      initial: ExportOptions(
        format ?? (pdf != null ? ExportFormat.pdf : ExportFormat.png),
      ),
      writer: c.loader.writer,
      onPermissions: pdf == null ? null : _askPermissions,
    );
    if (options == null || !mounted) return;
    String? path;
    try {
      path = await widget.dialogs.save(
        title: l.exportDialogTitle,
        name: options.fileName(item?.path ?? pdf!.path),
      );
    } on FileDialogUnavailable {
      if (!mounted) return;
      _say(l.dialogUnavailable, l.dialogUnavailableDetail);
      return;
    }
    if (path == null) return;
    try {
      if (item != null) {
        await widget.exporter(item, options, path);
      } else {
        await c.writePdfTo(path, security: options.security);
      }
    } on Object catch (e) {
      if (!mounted) return;
      _say(l.exportFailed, '$e');
    }
  }

  Future<PdfSecurity?> _askPermissions([PdfSecurity? initial]) =>
      showPermissionsSheet(
        context,
        initial: initial ?? c.pdf?.newSecurity ?? c.pdf?.security,
      );

  Future<void> _editPermissions() async {
    final chosen = await _askPermissions();
    if (chosen == null) return;
    c.setSecurity(chosen);
  }

  Future<void> _revert() async {
    final l = AppLocalizations.of(context);
    final confirmed = Completer<bool>();
    setState(
      () => _alert = (
        l.revertTitle,
        l.revertMessage,
        [
          AlertButton(l.cancel, onPressed: () => confirmed.complete(false)),
          AlertButton(
            l.revert,
            role: AlertRole.primary,
            onPressed: () => confirmed.complete(true),
          ),
        ],
      ),
    );
    final ok = await confirmed.future;
    if (!mounted) return;
    setState(() => _alert = null);
    if (!ok) return;
    try {
      await c.revert();
    } on Object catch (e) {
      if (mounted) _say(l.revertFailed, '$e');
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
    c.jumpTo(page - 1);
  }

  Future<void> _adjustSize() async {
    final item = c.image;
    if (item == null) return;
    final size = await showAdjustSizeSheet(context, item: item);
    if (size != null) c.resizeImage(size);
  }

  final GlobalKey _searchCircle = GlobalKey();

  /// ⌘F: the focus goes to the search field (in a narrow window, its popover opens). Return
  /// in the field searches; the results go to the sidebar and the find bar.
  void _find() {
    if (!c.isPdf) return;
    c.openSearch();
    final circle = _searchCircle.currentContext;
    if (circle != null) {
      _collapsedSearch(circle);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _runSearch(String text) {
    if (text.trim().isEmpty) return;
    if (c.query == text && c.matches.isNotEmpty) {
      HardwareKeyboard.instance.isShiftPressed
          ? c.findPrevious()
          : c.findNext();
      return;
    }
    _popover?.close();
    setState(() => _findBar = true);
    unawaited(c.find(text));
  }

  void _findSelection() {
    final text = c.selectedText.trim();
    if (text.isEmpty) return;
    _search.text = text;
    _runSearch(text);
  }

  void _closeSearch() {
    c.closeSearch();
    _search.clear();
    _focus.requestFocus();
  }

  Future<void> _copy() async {
    final text = c.selectedText;
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  bool _grewForMarkup = false;

  /// Shows or hides the markup toolbar. The first time on an image shown whole, the window
  /// grows by 31 pt so the image keeps (almost) its size (PREVIEW-02 › Markup: toolbar).
  void _toggleMarkup() {
    if (c.document == null) return;
    setState(() => _markupShown = !_markupShown);
    if (_markupShown &&
        !_grewForMarkup &&
        c.image != null &&
        c.zoomMode != ZoomMode.manual) {
      _grewForMarkup = true;
      final size = MediaQuery.sizeOf(context);
      unawaited(
        SilicaWindow.setSize(
          Size(size.width, size.height + PreviewMetrics.markupGrowth),
        ),
      );
    }
  }

  void _addShape(ShapeKind kind) {
    final item = c.image;
    if (item == null || !item.writable) return;
    if (!_markupShown) setState(() => _markupShown = true);
    c.addShape(
      newShape(
        kind,
        item,
        text: AppLocalizations.of(context).textPlaceholder,
        style: c.shapeTemplate,
      ),
    );
  }

  Future<void> _addNote() async {
    if (!c.canAnnotate) return;
    final note = await c.addNote();
    if (note == null || !mounted) return;
  }

  VoidCallback? get _deleteAction {
    if (c.chosenShape != null) return c.deleteShape;
    final chosen = c.chosenAnnotation;
    if (chosen != null) {
      final (page, id) = chosen;
      final a = c.annotationsOf(page).where((a) => a.id == id).firstOrNull;
      if (a != null) return () => unawaited(c.removeAnnotation(page, a));
    }
    if (c.sidebarFocused &&
        c.isPdf &&
        c.canDeletePage &&
        c.loader.writer != null) {
      return c.deletePage;
    }
    return null;
  }

  Future<void> _rename(String name) async {
    final l = AppLocalizations.of(context);
    try {
      await c.rename(name);
    } on FileSystemException {
      if (mounted) _say(l.renameFailed(name));
    }
  }

  void _openTitlePopover(BuildContext anchor) {
    final path = c.image?.path ?? c.pdf?.path;
    if (path == null) return;
    _popover?.close();
    _popover = showPopover(
      anchor,
      size: PreviewMetrics.titlePopover,
      key: const ValueKey('title popover panel'),
      builder: (context, handle) => TitlePopover(
        path: path,
        onRename: (name) => unawaited(_rename(name)),
        close: handle.close,
      ),
    );
  }

  bool get _canWritePdf => c.loader.writer != null;

  List<AppMenu> menus(AppLocalizations l) => previewMenus(
    l,
    c,
    WindowActions(
      open: () => unawaited(open()),
      close: () {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          unawaited(SilicaApp.closeWindow());
        }
      },
      save: () => unawaited(_save()),
      rename: () {
        final anchor = _titleAnchor.currentContext;
        if (anchor != null) _openTitlePopover(anchor);
      },
      revert: () => unawaited(_revert()),
      export: () => unawaited(export()),
      exportPdf: () => unawaited(export(format: ExportFormat.pdf)),
      permissions: () => unawaited(_editPermissions()),
      goToPage: () => unawaited(_goToPage()),
      find: _find,
      findSelection: _findSelection,
      copy: () => unawaited(_copy()),
      delete: _deleteAction,
      markup: _toggleMarkup,
      markupShown: _markupShown,
      toolbar: () => setState(() => _toolbarShown = !_toolbarShown),
      toolbarShown: _toolbarShown,
      slideshow: () => setState(() => _slideshow = true),
      adjustSize: () => unawaited(_adjustSize()),
      addShape: _addShape,
      addNote: () => unawaited(_addNote()),
      canWritePdf: _canWritePdf,
    ),
  );

  final GlobalKey _titleAnchor = GlobalKey();

  void _showMenu(Offset at, List<MenuEntry> entries, {Key? key}) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _menu?.remove();
    _menu = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: MenuHost(
          key: key ?? const ValueKey('context menu'),
          anchor: at,
          opaque: true,
          entries: entries,
          onDismissed: () {
            _menu?.remove();
            _menu = null;
          },
        ),
      ),
    );
    overlay.insert(_menu!);
  }

  /// The context menu of the content (PREVIEW-02 › Context menus), then the app's menus.
  void _contextMenu(Offset at, {(int, PdfAnnotation)? annotation}) {
    final l = AppLocalizations.of(context);
    final all = menus(l);
    Command? cmd(String id) => findCommand(all, id);
    MenuAction from(Command command, {String? label, bool? checked}) =>
        MenuAction(
          label ?? command.label,
          shortcut: command.shortcut,
          enabled: command.enabled,
          checked: checked ?? command.checked,
          onSelected: command.run,
        );
    final entries = <MenuEntry>[
      if (annotation case (final page, final a)) ...[
        MenuCustom(
          height: 30,
          width: 260,
          builder: (context, close) => AnnotationStyleRow(
            annotation: a,
            onStyle: (style) {
              close();
              unawaited(c.updateAnnotation(page, a, argb: style.argb));
            },
          ),
        ),
        const MenuDivider(),
        MenuAction(
          a.kind == PdfMarkupKind.note ? l.removeNote : l.removeHighlight,
          onSelected: () => unawaited(c.removeAnnotation(page, a)),
        ),
        if (a.kind != PdfMarkupKind.note)
          MenuAction(
            l.addNote,
            enabled: c.canAnnotate,
            onSelected: () =>
                unawaited(c.addNote(at: a.bounds.topRight, contents: '')),
          ),
        const MenuDivider(),
      ],
      if (c.isPdf) ...[
        from(cmd('preview.copy')!),
        const MenuDivider(),
        from(cmd('preview.zoom_to_fit')!, label: l.autoSize),
        from(cmd('preview.zoom_in')!),
        from(cmd('preview.zoom_out')!),
        from(cmd('preview.actual_size')!),
        const MenuDivider(),
        from(cmd('preview.layout.single')!),
        from(cmd('preview.layout.continuous')!),
        from(cmd('preview.layout.two')!),
        const MenuDivider(),
        from(cmd('preview.next')!, label: l.nextPage),
        from(cmd('preview.previous')!, label: l.previousPage),
      ] else ...[
        from(cmd('preview.zoom_to_fit')!, label: l.autoSize),
        from(cmd('preview.zoom_in')!),
        from(cmd('preview.zoom_out')!),
        from(cmd('preview.actual_size')!),
      ],
      const MenuDivider(),
      ...menuEntries(all),
    ];
    _showMenu(at, entries);
  }

  /// The context menu of a thumbnail (PREVIEW-02 › Context menus).
  void _thumbnailMenu(int index, Offset at) {
    final l = AppLocalizations.of(context);
    final all = menus(l);
    Command? cmd(String id) => findCommand(all, id);
    MenuAction from(Command command) => MenuAction(
      command.label,
      shortcut: command.shortcut,
      enabled: command.enabled,
      onSelected: command.run,
    );
    final images = c.images;
    final List<MenuEntry> entries;
    if (images != null) {
      entries = [
        MenuAction(
          l.closeImage,
          enabled: images.images.length > 1,
          onSelected: () => c.closeImage(index),
        ),
        MenuAction(
          l.exportAs,
          onSelected: () {
            c.goTo(index);
            unawaited(export());
          },
        ),
        const MenuDivider(),
        MenuAction(
          l.sortBy,
          submenu: [
            for (final (order, label) in [
              (ImageOrder.name, l.sortName),
              (ImageOrder.path, l.sortPath),
              (ImageOrder.date, l.sortDate),
              (ImageOrder.size, l.sortSize),
              (ImageOrder.kind, l.sortKind),
            ])
              MenuAction(
                label,
                checked: c.imageOrder == order,
                onSelected: () => c.sortImages(order),
              ),
            const MenuDivider(),
            MenuAction(
              l.sortNone,
              checked: c.imageOrder == null,
              onSelected: () => c.sortImages(null),
            ),
          ],
        ),
      ];
    } else {
      entries = [
        from(cmd('preview.rotate_left')!),
        from(cmd('preview.rotate_right')!),
        const MenuDivider(),
        MenuAction(
          l.deletePage,
          enabled: c.canDeletePage && _canWritePdf,
          onSelected: c.deletePage,
        ),
        from(cmd('preview.insert_blank')!),
        const MenuDivider(),
        from(cmd('preview.bookmark')!),
      ];
    }
    _showMenu(at, entries, key: const ValueKey('thumbnail menu'));
  }

  /// The view menu of the toolbar's sidebar button: the sidebar kinds and the page layouts.
  List<MenuEntry> _viewMenu() {
    final all = menus(AppLocalizations.of(context));
    final view = all.firstWhere((m) => m.id == 'view');
    final entries = <MenuEntry>[];
    for (final command in view.items) {
      // Up to the zoom items: those are in the toolbar already.
      if (command != null && command.id == 'preview.actual_size') break;
      if (command != null &&
          command.id.startsWith('preview.layout.') &&
          !c.isPdf) {
        continue;
      }
      entries.add(
        command == null
            ? const MenuDivider()
            : MenuAction(
                command.label,
                checked: command.checked,
                enabled: command.enabled,
                onSelected: command.run,
              ),
      );
    }
    while (entries.isNotEmpty && entries.last is MenuDivider) {
      entries.removeLast();
    }
    return entries;
  }

  /// The highlight colours, underline and strikethrough.
  void _highlightMenu(BuildContext anchor) {
    final l = AppLocalizations.of(context);
    final box = anchor.findRenderObject();
    if (box is! RenderBox) return;
    final at = box.localToGlobal(Offset(0, box.size.height + 4));
    final current = c.markupStyle;
    _showMenu(at, [
      for (final (colour, label) in [
        (HighlightColour.yellow, l.colourYellow),
        (HighlightColour.green, l.colourGreen),
        (HighlightColour.blue, l.colourBlue),
        (HighlightColour.pink, l.colourPink),
        (HighlightColour.purple, l.colourPurple),
      ])
        MenuAction(
          label,
          icon: (color) => ColourDot(colour.color),
          checked:
              current.kind == PdfMarkupKind.highlight &&
              current.colour == colour,
          onSelected: () =>
              c.setMarkupStyle(MarkupStyle(PdfMarkupKind.highlight, colour)),
        ),
      const MenuDivider(),
      MenuAction(
        l.underline,
        checked: current.kind == PdfMarkupKind.underline,
        onSelected: () =>
            c.setMarkupStyle(const MarkupStyle(PdfMarkupKind.underline)),
      ),
      MenuAction(
        l.strikethrough,
        checked: current.kind == PdfMarkupKind.strikeOut,
        onSelected: () =>
            c.setMarkupStyle(const MarkupStyle(PdfMarkupKind.strikeOut)),
      ),
    ], key: const ValueKey('highlight colours'));
  }

  /// The magnifier circle of a narrow toolbar: the search field in a popover.
  void _collapsedSearch(BuildContext anchor) {
    _popover?.close();
    _popover = showPopover(
      anchor,
      size: const Size(PreviewMetrics.searchMinWidth + 24, 62),
      builder: (context, handle) =>
          Center(child: _searchField(PreviewMetrics.searchMinWidth)),
    );
    // Once the popover is built, the field takes the keyboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _searchField(double width) {
    final l = AppLocalizations.of(context);
    return SilicaSearchField(
      key: const ValueKey('search field'),
      labels: SearchFieldLabels(
        placeholder: l.searchPlaceholder,
        clear: l.searchClear,
      ),
      style: SearchFieldStyle.toolbar,
      width: width,
      enabled: c.isPdf,
      controller: _search,
      focusNode: _searchFocus,
      onSubmitted: _runSearch,
      onCancel: _closeSearch,
    );
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

    if (key == LogicalKeyboardKey.escape) {
      if (_slideshow) {
        setState(() => _slideshow = false);
      } else if (c.searching) {
        _closeSearch();
      } else if (c.chosenShape != null) {
        c.chooseShape(null);
      } else {
        c.clearSelection();
      }
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final delete = _deleteAction;
      if (delete == null) return KeyEventResult.ignored;
      delete();
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
    } else if (key == LogicalKeyboardKey.space) {
      c.scrollPage(1);
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

  /// The title's second line: the page, "Edited", or the documents of the window.
  String? _subtitle(AppLocalizations l) {
    final doc = c.document;
    final edited = c.edited;
    final String? base = switch (doc) {
      null => null,
      PdfDocument() => l.pageOf(c.current + 1, c.count),
      ImageDocument(:final images) when images.length > 1 => l.documentsTotal(
        images.length,
        images.length,
      ),
      ImageDocument() => null,
    };
    if (!edited) return base;
    return base == null ? l.edited : l.withEdited(base);
  }

  Widget _content(PreviewColors colors, AppLocalizations l) {
    final locked = c.passwordFor;
    if (c.document == null && locked != null) {
      return PasswordView(
        wrong: c.passwordRetry,
        attempt: c.passwordAttempts,
        onPassword: (password) =>
            unawaited(c.openPdf(locked, password: password)),
      );
    }
    if (c.document == null) {
      return ColoredBox(
        key: const ValueKey('empty'),
        color: colors.imageCanvas,
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
    if (c.sidebar == SidebarMode.contactSheet) {
      return ContactSheet(controller: c);
    }
    return Listener(
      // A press in the content takes the focus from the sidebar.
      onPointerDown: (_) => c.focusSidebar(false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: c.isPdf
            ? null
            : (d) => _contextMenu(d.globalPosition),
        child: c.isPdf
            ? PdfView(
                controller: c,
                onContextMenu: (at, annotation) =>
                    _contextMenu(at, annotation: annotation),
                onNote: _openNote,
              )
            : ImageView(controller: c, markup: _markupShown),
      ),
    );
  }

  /// A note's popover: its text, editable, with Done.
  void _openNote(BuildContext anchor, int page, PdfAnnotation note) {
    _popover?.close();
    _popover = showPopover(
      anchor,
      size: PreviewMetrics.notePopover,
      key: const ValueKey('note popover'),
      builder: (context, handle) => NotePopover(
        text: note.contents,
        onDone: (text) {
          handle.close();
          if (text != note.contents) {
            unawaited(c.updateAnnotation(page, note, contents: text));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = PreviewColors.of(context);
    final title = c.image?.name ?? c.document?.title ?? l.appName;
    final band = (_toolbarShown ? toolbarHeight : 0.0);
    final header =
        (_findBar && c.searching ? PreviewMetrics.findBarHeight : 0.0) +
        (_markupShown && c.document != null
            ? PreviewMetrics.markupBarHeight
            : 0.0);
    final top = band + header;
    final shown = Curves.easeInOut.transform(_sidebar.value);
    final sidebarWidth = sidebarWidthOf(c);
    final toolbar = PreviewToolbar(
      key: _titleAnchor,
      controller: c,
      title: title,
      subtitle: _subtitle(l),
      active: widget.active,
      actions: ToolbarActions(
        viewMenu: _viewMenu,
        titlePopover: c.document == null ? null : _openTitlePopover,
        searchField: _searchField,
        collapsedSearch: _collapsedSearch,
        searchCircleKey: _searchCircle,
        highlight: c.document == null ? null : c.toggleHighlighting,
        highlightMenu: _highlightMenu,
        highlighting: c.highlighting,
        markup: c.document == null ? null : _toggleMarkup,
        markupShown: _markupShown,
      ),
    );
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shown > 0)
          ClipRect(
            child: SizedBox(
              width: sidebarWidth * shown,
              child: OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: sidebarWidth,
                maxWidth: sidebarWidth,
                child: _shownMode == SidebarMode.notes && !showsResults(c)
                    ? NotesSidebar(
                        controller: c,
                        top: top,
                        active: widget.active,
                      )
                    : PreviewSidebar(
                        controller: c,
                        active: widget.active,
                        top: top,
                        onPageMenu: _thumbnailMenu,
                      ),
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: ZoomInset(top: top, child: _content(colors, l)),
              ),
              if (shown == 1)
                Positioned(
                  left: 0,
                  top: top,
                  bottom: 0,
                  child: SidebarResizer(controller: c),
                ),
            ],
          ),
        ),
        if (c.inspector && c.document != null)
          Padding(
            padding: EdgeInsets.only(top: top),
            child: Inspector(controller: c),
          ),
      ],
    );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: colors.window,
        child: Stack(
          children: [
            Positioned.fill(
              child: _toolbarShown
                  ? ScrollUnderToolbar(
                      toolbar: toolbar,
                      active: widget.active,
                      scrollPredicate: anyVerticalScrollUnderPredicate,
                      header: header == 0
                          ? null
                          : Column(
                              children: [
                                if (_findBar && c.searching)
                                  FindBar(controller: c, onDone: _closeSearch),
                                if (_markupShown && c.document != null)
                                  MarkupBar(
                                    controller: c,
                                    onAddShape: _addShape,
                                    onAdjustSize: () =>
                                        unawaited(_adjustSize()),
                                    onNote: () => unawaited(_addNote()),
                                  ),
                              ],
                            ),
                      headerHeight: header,
                      body: (context, padding) => body,
                    )
                  : body,
            ),
            if (_slideshow && c.document != null)
              Positioned.fill(
                child: Slideshow(
                  controller: c,
                  onEnd: () {
                    setState(() => _slideshow = false);
                    _focus.requestFocus();
                  },
                ),
              ),
            if (_alert case (final title, final message, final buttons))
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0x33000000),
                  child: Center(
                    child: SizedBox(
                      width: buttons == null
                          ? null
                          : PreviewMetrics.revertAlert.width,
                      child: SilicaAlert(
                        key: const ValueKey('alert'),
                        title: title,
                        message: message,
                        opaque: true,
                        buttons:
                            buttons ??
                            [
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
              ),
          ],
        ),
      ),
    );
  }
}

/// A coloured dot for the highlight menu.
class ColourDot extends StatelessWidget {
  const ColourDot(this.color, {super.key, this.size = 12});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// The first row of an annotation's context menu: the five colours, underline, strikethrough.
class AnnotationStyleRow extends StatelessWidget {
  const AnnotationStyleRow({
    super.key,
    required this.annotation,
    required this.onStyle,
  });
  final PdfAnnotation annotation;
  final ValueChanged<MarkupStyle> onStyle;

  @override
  Widget build(BuildContext context) {
    final colors = PreviewColors.of(context);
    return Row(
      key: const ValueKey('annotation styles'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final colour in HighlightColour.values)
          GestureDetector(
            key: ValueKey('style ${colour.name}'),
            onTap: () => onStyle(MarkupStyle(PdfMarkupKind.highlight, colour)),
            child: ColourDot(colour.color, size: 16),
          ),
        if (annotation.kind != PdfMarkupKind.note) ...[
          GestureDetector(
            onTap: () => onStyle(const MarkupStyle(PdfMarkupKind.underline)),
            child: PreviewSymbol(
              'text-underline',
              size: 16,
              color: colors.text,
              fallback: 'U',
            ),
          ),
          GestureDetector(
            onTap: () => onStyle(const MarkupStyle(PdfMarkupKind.strikeOut)),
            child: PreviewSymbol(
              'text-strikethrough',
              size: 16,
              color: colors.text,
              fallback: 'S',
            ),
          ),
        ],
      ],
    );
  }
}

/// A note's popover (≈ 274 × 154, yellow): its text and Done.
class NotePopover extends StatefulWidget {
  const NotePopover({super.key, required this.text, required this.onDone});
  final String text;
  final ValueChanged<String> onDone;

  @override
  State<NotePopover> createState() => _NotePopoverState();
}

class _NotePopoverState extends State<NotePopover> {
  late final TextEditingController _text = TextEditingController(
    text: widget.text,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: const Color(0xFFFFE97A),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SilicaTextField(
                key: const ValueKey('note text'),
                controller: _text,
                autofocus: true,
                maxLines: null,
                bezel: FieldBezel.square,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: SilicaButton(
                key: const ValueKey('note done'),
                label: l.done,
                onPressed: () => widget.onDone(_text.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A new shape for the current image: centred, a quarter of its shorter side.
MarkupShape newShape(
  ShapeKind kind,
  ImageItem item, {
  String text = '',
  MarkupShape? style,
}) {
  final own = item.content.size;
  final side = math.max(24.0, math.min(own.width, own.height) / 4);
  final centre = own.center(Offset.zero);
  final half = kind == ShapeKind.line || kind == ShapeKind.arrow
      ? Offset(side / 2, 0)
      : Offset(side / 2, side / 2 * (kind == ShapeKind.text ? 0.4 : 1));
  final t = style;
  return MarkupShape(
    kind: kind,
    a: centre - half,
    b: centre + half,
    stroke: t?.stroke ?? const Color(0xFF000000),
    fill: t?.fill,
    lineWidth: t?.lineWidth ?? 3,
    dashed: t?.dashed ?? false,
    shadow: t?.shadow ?? false,
    ends: kind == ShapeKind.arrow && (t == null || t.ends == LineEnds.none)
        ? LineEnds.end
        : (kind == ShapeKind.line || kind == ShapeKind.arrow ? t?.ends : null),
    text: kind == ShapeKind.text ? text : '',
    fontSize: math.max(12, side / 8),
    textColor: t?.textColor ?? const Color(0xFFFF2600),
    bold: t?.bold ?? false,
    italic: t?.italic ?? false,
    underline: t?.underline ?? false,
    align: t?.align ?? TextAlign.left,
  );
}
