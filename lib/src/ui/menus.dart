// Preview's menus (PREVIEW-02 › Menus), declared once as data: the titles, the items with their
// shortcuts, and what they do. The same table drives the keyboard shortcuts and, until apps can
// publish their menus to the Silica menu bar (silica-menu-v1, silica-desktop#25), the window's
// context menu, which ends with each menu as a submenu. Items that do not apply are disabled,
// never dead: what Preview cannot do is not listed at all.

import 'package:flutter/services.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/markup.dart';
import '../model/viewer.dart';
import '../pdf/backend.dart';

/// A key combination: ⌘ is the Super (Meta) key or Ctrl, as in the other Silica apps; ⌃⌘
/// ([control]) needs both.
class Keys {
  const Keys(
    this.key, {
    this.command = true,
    this.shift = false,
    this.option = false,
    this.control = false,
  });
  final LogicalKeyboardKey key;
  final bool command;
  final bool shift;
  final bool option;
  final bool control;

  bool matches(KeyEvent event, HardwareKeyboard keyboard) {
    if (event.logicalKey != key) return false;
    final meta = keyboard.isMetaPressed;
    final ctrl = keyboard.isControlPressed;
    final cmd = control ? meta && ctrl : (meta || ctrl) && !(meta && ctrl);
    return cmd == (command || control) &&
        keyboard.isShiftPressed == shift &&
        keyboard.isAltPressed == option;
  }
}

/// A menu item.
class Command {
  const Command(
    this.id,
    this.label, {
    this.run,
    this.shortcut,
    this.keys = const [],
    this.enabled = true,
    this.checked = false,
    this.submenu,
  });

  /// `preview.*`, the command's name (docs/spec.md).
  final String id;
  final String label;

  /// The shortcut as shown, with the modifier symbols.
  final String? shortcut;

  /// The keys that run it (several: ⌘+ and ⌘=).
  final List<Keys> keys;
  final bool enabled;
  final bool checked;
  final VoidCallback? run;

  /// The items of a submenu (null entries: separators).
  final List<Command?>? submenu;
}

/// A menu: its title and its items (null: a separator).
class AppMenu {
  const AppMenu(this.id, this.title, this.items);
  final String id;
  final String title;
  final List<Command?> items;
}

/// What the menus need from the window besides the controller.
class WindowActions {
  const WindowActions({
    required this.open,
    required this.close,
    required this.save,
    required this.rename,
    required this.revert,
    required this.export,
    required this.exportPdf,
    required this.permissions,
    required this.goToPage,
    required this.find,
    required this.findSelection,
    required this.copy,
    required this.delete,
    required this.markup,
    required this.markupShown,
    required this.toolbar,
    required this.toolbarShown,
    required this.slideshow,
    required this.adjustSize,
    required this.addShape,
    required this.addNote,
    required this.canWritePdf,
  });
  final VoidCallback open;
  final VoidCallback close;
  final VoidCallback save;
  final VoidCallback rename;
  final VoidCallback revert;
  final VoidCallback export;
  final VoidCallback exportPdf;
  final VoidCallback permissions;
  final VoidCallback goToPage;
  final VoidCallback find;
  final VoidCallback findSelection;
  final VoidCallback copy;

  /// Deletes what is chosen (a shape, an annotation, a page), null when nothing is.
  final VoidCallback? delete;
  final VoidCallback markup;
  final bool markupShown;
  final VoidCallback toolbar;
  final bool toolbarShown;
  final VoidCallback slideshow;
  final VoidCallback adjustSize;
  final void Function(ShapeKind kind) addShape;
  final VoidCallback addNote;

  /// qpdf is there: pages, bookmarks and permissions can be written.
  final bool canWritePdf;
}

const _up = LogicalKeyboardKey.arrowUp;
const _down = LogicalKeyboardKey.arrowDown;
const _pageUp = LogicalKeyboardKey.pageUp;
const _pageDown = LogicalKeyboardKey.pageDown;

List<AppMenu> previewMenus(
  AppLocalizations l,
  ViewerController c,
  WindowActions a,
) {
  final open = c.document != null;
  final pdf = c.isPdf;
  final image = c.image;
  final editableImage = image != null && image.writable;
  final pages = pdf && a.canWritePdf;
  final textMarkup = pdf && c.canCopy && c.canAnnotate;
  Command shape(String id, String label, ShapeKind kind, [Keys? keys]) =>
      Command(
        'preview.annotate.$id',
        label,
        shortcut: keys == null ? null : '⌃⌘${keys.key.keyLabel}',
        keys: [?keys],
        enabled: editableImage,
        run: () => a.addShape(kind),
      );
  Command markText(String id, String label, PdfMarkupKind kind, Keys keys) =>
      Command(
        'preview.annotate.$id',
        label,
        shortcut: '⌃⌘${keys.key.keyLabel}',
        keys: [keys],
        enabled: textMarkup,
        run: () => c.markSelection(style: MarkupStyle(kind)),
      );
  return [
    AppMenu('file', l.menuFile, [
      Command(
        'preview.open',
        l.open,
        shortcut: '⌘O',
        keys: const [Keys(LogicalKeyboardKey.keyO)],
        run: a.open,
      ),
      null,
      Command(
        'preview.close',
        l.closeWindow,
        shortcut: '⌘W',
        keys: const [Keys(LogicalKeyboardKey.keyW)],
        run: a.close,
      ),
      Command(
        'preview.save',
        l.saveCommand,
        shortcut: '⌘S',
        keys: const [Keys(LogicalKeyboardKey.keyS)],
        enabled: c.canSave,
        run: a.save,
      ),
      Command('preview.rename', l.renameCommand, enabled: open, run: a.rename),
      Command(
        'preview.revert_menu',
        l.revertTo,
        enabled: c.canRevert,
        submenu: [
          Command(
            'preview.revert',
            l.lastOpened,
            enabled: c.canRevert,
            run: a.revert,
          ),
        ],
      ),
      if (pdf) ...[
        null,
        Command(
          'preview.permissions',
          l.editPermissions,
          enabled: a.canWritePdf,
          run: a.permissions,
        ),
      ],
      null,
      Command('preview.export', l.export, enabled: open, run: a.export),
      Command(
        'preview.export_pdf',
        l.exportAsPdf,
        enabled: image != null,
        run: a.exportPdf,
      ),
    ]),
    AppMenu('edit', l.menuEdit, [
      Command(
        'preview.undo',
        l.undo,
        shortcut: '⌘Z',
        keys: const [Keys(LogicalKeyboardKey.keyZ)],
        enabled: c.history.canUndo,
        run: c.undo,
      ),
      Command(
        'preview.redo',
        l.redo,
        shortcut: '⇧⌘Z',
        keys: const [Keys(LogicalKeyboardKey.keyZ, shift: true)],
        enabled: c.history.canRedo,
        run: c.redo,
      ),
      null,
      Command(
        'preview.copy',
        l.copy,
        shortcut: '⌘C',
        keys: const [Keys(LogicalKeyboardKey.keyC)],
        enabled: c.canCopy,
        run: a.copy,
      ),
      Command(
        'preview.delete',
        l.delete,
        enabled: a.delete != null,
        run: a.delete,
      ),
      Command(
        'preview.select_all',
        l.selectAll,
        shortcut: '⌘A',
        keys: const [Keys(LogicalKeyboardKey.keyA)],
        enabled: pdf,
        run: c.selectAll,
      ),
      if (pdf) ...[
        null,
        Command(
          'preview.insert',
          l.insert,
          enabled: pages,
          submenu: [
            Command(
              'preview.insert_blank',
              l.blankPage,
              enabled: pages,
              run: c.insertBlankPage,
            ),
          ],
        ),
      ],
      null,
      Command(
        'preview.find_menu',
        l.findMenu,
        enabled: pdf,
        submenu: [
          Command(
            'preview.find',
            l.find,
            shortcut: '⌘F',
            keys: const [Keys(LogicalKeyboardKey.keyF)],
            enabled: pdf,
            run: a.find,
          ),
          Command(
            'preview.find_next',
            l.findNext,
            shortcut: '⌘G',
            keys: const [Keys(LogicalKeyboardKey.keyG)],
            enabled: c.matches.isNotEmpty,
            run: c.findNext,
          ),
          Command(
            'preview.find_previous',
            l.findPrevious,
            shortcut: '⇧⌘G',
            keys: const [Keys(LogicalKeyboardKey.keyG, shift: true)],
            enabled: c.matches.isNotEmpty,
            run: c.findPrevious,
          ),
          Command(
            'preview.find_selection',
            l.useSelectionForFind,
            shortcut: '⌘E',
            keys: const [Keys(LogicalKeyboardKey.keyE)],
            enabled: c.canCopy,
            run: a.findSelection,
          ),
        ],
      ),
    ]),
    AppMenu('view', l.menuView, [
      for (final (mode, label, digit) in [
        (SidebarMode.none, l.hideSidebar, LogicalKeyboardKey.digit1),
        (SidebarMode.thumbnails, l.thumbnails, LogicalKeyboardKey.digit2),
        (SidebarMode.contents, l.tableOfContents, LogicalKeyboardKey.digit3),
        (SidebarMode.notes, l.highlightsAndNotes, LogicalKeyboardKey.digit4),
        (SidebarMode.bookmarks, l.bookmarks, LogicalKeyboardKey.digit5),
        (SidebarMode.contactSheet, l.contactSheet, LogicalKeyboardKey.digit6),
      ])
        Command(
          'preview.sidebar.${mode.name}',
          label,
          shortcut: '⌥⌘${digit.keyLabel}',
          keys: [Keys(digit, option: true)],
          enabled: c.canShowSidebar(mode),
          checked: open && c.sidebar == mode,
          run: () => c.setSidebar(mode),
        ),
      null,
      for (final (layout, label, digit) in [
        (PageLayout.continuous, l.continuousScroll, LogicalKeyboardKey.digit1),
        (PageLayout.single, l.singlePage, LogicalKeyboardKey.digit2),
        (PageLayout.two, l.twoPages, LogicalKeyboardKey.digit3),
      ])
        Command(
          'preview.layout.${layout.name}',
          label,
          shortcut: '⌘${digit.keyLabel}',
          keys: [Keys(digit)],
          enabled: pdf,
          checked: pdf && c.layout == layout,
          run: () => c.setLayout(layout),
        ),
      null,
      Command(
        'preview.actual_size',
        l.actualSize,
        shortcut: '⌘0',
        keys: const [Keys(LogicalKeyboardKey.digit0)],
        enabled: open && !c.atActualSize,
        run: c.actualSize,
      ),
      Command(
        'preview.zoom_to_fit',
        l.zoomToFit,
        shortcut: '⌘9',
        keys: const [Keys(LogicalKeyboardKey.digit9)],
        enabled: open,
        checked: open && c.zoomMode != ZoomMode.manual,
        run: c.zoomToFit,
      ),
      Command(
        'preview.zoom_in',
        l.zoomIn,
        shortcut: '⌘+',
        keys: const [
          Keys(LogicalKeyboardKey.equal),
          Keys(LogicalKeyboardKey.equal, shift: true),
          Keys(LogicalKeyboardKey.add),
          Keys(LogicalKeyboardKey.numpadAdd),
        ],
        enabled: c.canZoomIn,
        run: c.zoomIn,
      ),
      Command(
        'preview.zoom_out',
        l.zoomOut,
        shortcut: '⌘−',
        keys: const [
          Keys(LogicalKeyboardKey.minus),
          Keys(LogicalKeyboardKey.numpadSubtract),
        ],
        enabled: c.canZoomOut,
        run: c.zoomOut,
      ),
      null,
      Command(
        'preview.markup',
        a.markupShown ? l.hideMarkupToolbar : l.showMarkupToolbar,
        shortcut: '⇧⌘A',
        keys: const [Keys(LogicalKeyboardKey.keyA, shift: true)],
        enabled: open,
        run: a.markup,
      ),
      null,
      Command(
        'preview.toolbar',
        a.toolbarShown ? l.hideToolbar : l.showToolbar,
        shortcut: '⌥⌘T',
        keys: const [Keys(LogicalKeyboardKey.keyT, option: true)],
        run: a.toolbar,
      ),
      null,
      Command(
        'preview.slideshow',
        l.slideshow,
        shortcut: '⇧⌘F',
        keys: const [Keys(LogicalKeyboardKey.keyF, shift: true)],
        enabled: open,
        run: a.slideshow,
      ),
    ]),
    AppMenu('go', l.menuGo, [
      Command(
        'preview.page_up',
        l.pageUp,
        shortcut: '⇞',
        keys: const [Keys(_pageUp, command: false)],
        enabled: pdf,
        run: () => c.scrollPage(-1),
      ),
      Command(
        'preview.page_down',
        l.pageDown,
        shortcut: '⇟',
        keys: const [Keys(_pageDown, command: false)],
        enabled: pdf,
        run: () => c.scrollPage(1),
      ),
      Command(
        'preview.previous_document',
        l.previousDocument,
        shortcut: '⌥⇞',
        keys: const [Keys(_pageUp, command: false, option: true)],
        enabled: c.several && c.canGoBack,
        run: c.previous,
      ),
      Command(
        'preview.next_document',
        l.nextDocument,
        shortcut: '⌥⇟',
        keys: const [Keys(_pageDown, command: false, option: true)],
        enabled: c.several && c.canGoForward,
        run: c.next,
      ),
      Command(
        'preview.previous',
        l.previousItem,
        shortcut: '⌥↑',
        keys: const [Keys(_up, command: false, option: true)],
        enabled: c.canGoBack,
        run: c.previous,
      ),
      Command(
        'preview.next',
        l.nextItem,
        shortcut: '⌥↓',
        keys: const [Keys(_down, command: false, option: true)],
        enabled: c.canGoForward,
        run: c.next,
      ),
      Command(
        'preview.go_to_page',
        l.goToPage,
        shortcut: '⌥⌘G',
        keys: const [Keys(LogicalKeyboardKey.keyG, option: true)],
        enabled: pdf && c.count > 1,
        run: a.goToPage,
      ),
      null,
      Command(
        'preview.back',
        l.back,
        shortcut: '⌘[',
        keys: const [Keys(LogicalKeyboardKey.bracketLeft)],
        enabled: c.canGoBackInHistory,
        run: c.back,
      ),
      Command(
        'preview.forward',
        l.forward,
        shortcut: '⌘]',
        keys: const [Keys(LogicalKeyboardKey.bracketRight)],
        enabled: c.canGoForwardInHistory,
        run: c.forward,
      ),
    ]),
    AppMenu('tools', l.menuTools, [
      Command(
        'preview.inspector',
        c.inspector ? l.hideInspector : l.showInspector,
        shortcut: '⌘I',
        keys: const [Keys(LogicalKeyboardKey.keyI)],
        enabled: open,
        run: c.toggleInspector,
      ),
      null,
      Command(
        'preview.adjust_size',
        l.adjustSize,
        enabled: editableImage,
        run: a.adjustSize,
      ),
      null,
      Command(
        'preview.annotate',
        l.annotate,
        enabled: open,
        submenu: [
          if (pdf) ...[
            markText(
              'highlight',
              l.highlightText,
              PdfMarkupKind.highlight,
              const Keys(LogicalKeyboardKey.keyH, control: true),
            ),
            markText(
              'underline',
              l.underlineText,
              PdfMarkupKind.underline,
              const Keys(LogicalKeyboardKey.keyU, control: true),
            ),
            markText(
              'strikethrough',
              l.strikethroughText,
              PdfMarkupKind.strikeOut,
              const Keys(LogicalKeyboardKey.keyS, control: true),
            ),
            null,
            Command(
              'preview.annotate.note',
              l.note,
              shortcut: '⌃⌘N',
              keys: const [Keys(LogicalKeyboardKey.keyN, control: true)],
              enabled: c.canAnnotate,
              run: a.addNote,
            ),
          ] else ...[
            shape(
              'rectangle',
              l.shapeRectangle,
              ShapeKind.rectangle,
              const Keys(LogicalKeyboardKey.keyR, control: true),
            ),
            shape(
              'oval',
              l.shapeOval,
              ShapeKind.oval,
              const Keys(LogicalKeyboardKey.keyO, control: true),
            ),
            shape(
              'line',
              l.shapeLine,
              ShapeKind.line,
              const Keys(LogicalKeyboardKey.keyI, control: true),
            ),
            shape(
              'arrow',
              l.shapeArrow,
              ShapeKind.arrow,
              const Keys(LogicalKeyboardKey.keyA, control: true),
            ),
            shape('polygon', l.shapePolygon, ShapeKind.polygon),
            shape('star', l.shapeStar, ShapeKind.star),
            null,
            shape(
              'text',
              l.shapeText,
              ShapeKind.text,
              const Keys(LogicalKeyboardKey.keyT, control: true),
            ),
            shape('bubble', l.shapeBubble, ShapeKind.speechBubble),
          ],
        ],
      ),
      if (pdf) ...[
        null,
        Command(
          'preview.bookmark',
          c.currentBookmarked ? l.removeBookmark : l.addBookmark,
          shortcut: '⌘D',
          keys: const [Keys(LogicalKeyboardKey.keyD)],
          enabled: a.canWritePdf && c.count > 0,
          run: c.toggleBookmark,
        ),
      ],
      null,
      Command(
        'preview.rotate_left',
        l.rotateLeft,
        shortcut: '⌘L',
        keys: const [Keys(LogicalKeyboardKey.keyL)],
        enabled: c.canRotate && (!pdf || a.canWritePdf),
        run: c.rotateLeft,
      ),
      Command(
        'preview.rotate_right',
        l.rotateRight,
        shortcut: '⌘R',
        keys: const [Keys(LogicalKeyboardKey.keyR)],
        enabled: c.canRotate && (!pdf || a.canWritePdf),
        run: c.rotateRight,
      ),
      Command(
        'preview.flip_horizontal',
        l.flipHorizontal,
        enabled: c.canFlip,
        run: c.flipHorizontal,
      ),
      Command(
        'preview.flip_vertical',
        l.flipVertical,
        enabled: c.canFlip,
        run: c.flipVertical,
      ),
    ]),
  ];
}

/// Runs the enabled command whose keys match `event`; true if one did.
bool runShortcut(
  List<AppMenu> menus,
  KeyEvent event,
  HardwareKeyboard keyboard,
) {
  bool walk(List<Command?> items) {
    for (final command in items) {
      if (command == null || !command.enabled) continue;
      if (command.run != null &&
          command.keys.any((k) => k.matches(event, keyboard))) {
        command.run!();
        return true;
      }
      if (command.submenu case final sub? when walk(sub)) return true;
    }
    return false;
  }

  for (final menu in menus) {
    if (walk(menu.items)) return true;
  }
  return false;
}

/// Commands as menu entries.
List<MenuEntry> commandEntries(List<Command?> items) => [
  for (final command in items)
    if (command == null)
      const MenuDivider()
    else
      MenuAction(
        command.label,
        shortcut: command.shortcut,
        enabled: command.enabled,
        checked: command.checked,
        onSelected: command.run,
        submenu: command.submenu == null
            ? null
            : commandEntries(command.submenu!),
      ),
];

/// The menus as context menu entries: one submenu per menu.
List<MenuEntry> menuEntries(List<AppMenu> menus) => [
  for (final menu in menus)
    MenuAction(menu.title, submenu: commandEntries(menu.items)),
];

/// Finds a command by id (tests).
Command? findCommand(List<AppMenu> menus, String id) {
  Command? walk(List<Command?> items) {
    for (final command in items) {
      if (command == null) continue;
      if (command.id == id) return command;
      if (command.submenu case final sub?) {
        final found = walk(sub);
        if (found != null) return found;
      }
    }
    return null;
  }

  for (final menu in menus) {
    final found = walk(menu.items);
    if (found != null) return found;
  }
  return null;
}
