// Preview's menus, declared once as data: the titles, the items with their shortcuts, and what
// they do. The same table drives the keyboard shortcuts and, until apps can publish their menus
// to the Silica menu bar (silica-menu-v1, silica-desktop#25), the window's context menu, which
// shows each menu as a submenu. Items that do not apply are disabled, never dead: what Preview
// cannot do yet is not listed at all.

import 'package:flutter/services.dart';
import 'package:silica_ui/silica_ui.dart';

import '../../l10n/app_localizations.dart';
import '../model/viewer.dart';

/// A key combination: ⌘ is the Super (Meta) key or Ctrl, as in the other Silica apps.
class Keys {
  const Keys(
    this.key, {
    this.command = true,
    this.shift = false,
    this.option = false,
  });
  final LogicalKeyboardKey key;
  final bool command;
  final bool shift;
  final bool option;

  bool matches(KeyEvent event, HardwareKeyboard keyboard) {
    if (event.logicalKey != key) return false;
    final cmd = keyboard.isMetaPressed || keyboard.isControlPressed;
    return cmd == command &&
        keyboard.isShiftPressed == shift &&
        keyboard.isAltPressed == option;
  }
}

/// A menu item.
class Command {
  const Command(
    this.id,
    this.label, {
    required this.run,
    this.shortcut,
    this.keys = const [],
    this.enabled = true,
    this.checked = false,
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
  final VoidCallback run;
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
    required this.export,
    required this.goToPage,
    required this.find,
    required this.copy,
  });
  final VoidCallback open;
  final VoidCallback export;
  final VoidCallback goToPage;
  final VoidCallback find;
  final VoidCallback copy;
}

const _up = LogicalKeyboardKey.arrowUp;
const _down = LogicalKeyboardKey.arrowDown;

List<AppMenu> previewMenus(
  AppLocalizations l,
  ViewerController c,
  WindowActions actions,
) {
  final open = c.document != null;
  final pdf = c.isPdf;
  return [
    AppMenu('file', l.menuFile, [
      Command(
        'preview.open',
        l.open,
        shortcut: '⌘O',
        keys: const [Keys(LogicalKeyboardKey.keyO)],
        run: actions.open,
      ),
      null,
      Command(
        'preview.export',
        l.export,
        enabled: c.image != null,
        run: actions.export,
      ),
    ]),
    AppMenu('edit', l.menuEdit, [
      Command(
        'preview.copy',
        l.copy,
        shortcut: '⌘C',
        keys: const [Keys(LogicalKeyboardKey.keyC)],
        enabled: c.canCopy,
        run: actions.copy,
      ),
      Command(
        'preview.select_all',
        l.selectAll,
        shortcut: '⌘A',
        keys: const [Keys(LogicalKeyboardKey.keyA)],
        enabled: pdf,
        run: c.selectAll,
      ),
      null,
      Command(
        'preview.find',
        l.find,
        shortcut: '⌘F',
        keys: const [Keys(LogicalKeyboardKey.keyF)],
        enabled: pdf,
        run: actions.find,
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
    ]),
    AppMenu('view', l.menuView, [
      Command(
        'preview.sidebar.none',
        l.hideSidebar,
        shortcut: '⌥⌘1',
        keys: const [Keys(LogicalKeyboardKey.digit1, option: true)],
        enabled: open,
        checked: open && c.sidebar == SidebarMode.none,
        run: () => c.setSidebar(SidebarMode.none),
      ),
      Command(
        'preview.sidebar.thumbnails',
        l.thumbnails,
        shortcut: '⌥⌘2',
        keys: const [Keys(LogicalKeyboardKey.digit2, option: true)],
        enabled: open,
        checked: c.sidebar == SidebarMode.thumbnails,
        run: () => c.setSidebar(SidebarMode.thumbnails),
      ),
      Command(
        'preview.sidebar.contents',
        l.tableOfContents,
        shortcut: '⌥⌘3',
        keys: const [Keys(LogicalKeyboardKey.digit3, option: true)],
        enabled: c.hasOutline,
        checked: c.sidebar == SidebarMode.contents,
        run: () => c.setSidebar(SidebarMode.contents),
      ),
      if (pdf) ...[
        null,
        for (final (layout, label) in [
          (PageLayout.continuous, l.continuousScroll),
          (PageLayout.single, l.singlePage),
          (PageLayout.two, l.twoPages),
        ])
          Command(
            'preview.layout.${layout.name}',
            label,
            checked: c.layout == layout,
            run: () => c.setLayout(layout),
          ),
      ],
      null,
      Command(
        'preview.actual_size',
        l.actualSize,
        shortcut: '⌘0',
        keys: const [Keys(LogicalKeyboardKey.digit0)],
        enabled: open,
        run: c.actualSize,
      ),
      Command(
        'preview.zoom_to_fit',
        l.zoomToFit,
        shortcut: '⌘9',
        keys: const [Keys(LogicalKeyboardKey.digit9)],
        enabled: open,
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
    ]),
    AppMenu('go', l.menuGo, [
      Command(
        'preview.previous',
        pdf ? l.previousPage : l.previousImage,
        shortcut: '⌥⌘↑',
        keys: const [Keys(_up, option: true)],
        enabled: c.canGoBack,
        run: c.previous,
      ),
      Command(
        'preview.next',
        pdf ? l.nextPage : l.nextImage,
        shortcut: '⌥⌘↓',
        keys: const [Keys(_down, option: true)],
        enabled: c.canGoForward,
        run: c.next,
      ),
      if (pdf) ...[
        null,
        Command(
          'preview.first',
          l.firstPage,
          enabled: c.canGoBack,
          run: c.first,
        ),
        Command(
          'preview.last',
          l.lastPage,
          enabled: c.canGoForward,
          run: c.last,
        ),
        Command(
          'preview.go_to_page',
          l.goToPage,
          shortcut: '⌥⌘G',
          keys: const [Keys(LogicalKeyboardKey.keyG, option: true)],
          enabled: c.count > 1,
          run: actions.goToPage,
        ),
      ],
    ]),
    AppMenu('tools', l.menuTools, [
      Command(
        'preview.rotate_left',
        l.rotateLeft,
        shortcut: '⌘L',
        keys: const [Keys(LogicalKeyboardKey.keyL)],
        enabled: c.canRotate,
        run: c.rotateLeft,
      ),
      Command(
        'preview.rotate_right',
        l.rotateRight,
        shortcut: '⌘R',
        keys: const [Keys(LogicalKeyboardKey.keyR)],
        enabled: c.canRotate,
        run: c.rotateRight,
      ),
      if (!pdf) ...[
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
      ],
      null,
      Command(
        'preview.inspector',
        c.inspector ? l.hideInspector : l.showInspector,
        shortcut: '⌘I',
        keys: const [Keys(LogicalKeyboardKey.keyI)],
        enabled: open,
        run: c.toggleInspector,
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
  for (final menu in menus) {
    for (final command in menu.items) {
      if (command == null || !command.enabled) continue;
      if (command.keys.any((k) => k.matches(event, keyboard))) {
        command.run();
        return true;
      }
    }
  }
  return false;
}

/// The menus as context menu entries: one submenu per menu.
List<MenuEntry> menuEntries(List<AppMenu> menus) => [
  for (final menu in menus)
    MenuAction(
      menu.title,
      submenu: [
        for (final command in menu.items)
          if (command == null)
            const MenuDivider()
          else
            MenuAction(
              command.label,
              shortcut: command.shortcut,
              enabled: command.enabled,
              checked: command.checked,
              onSelected: command.run,
            ),
      ],
    ),
];

/// Finds a command by id (tests).
Command? findCommand(List<AppMenu> menus, String id) {
  for (final menu in menus) {
    for (final command in menu.items) {
      if (command?.id == id) return command;
    }
  }
  return null;
}
