# Preview · specification

What the app does and how it behaves. Measurements: `silica-reference` › `preview.md`
(PREVIEW-01, PREVIEW-02; not done yet, every value is *provisional*). Details in
[`spec/`](spec/).

## Files

- Arguments after the bundle (`Exec=… @BUNDLE@ %F`) or `--dart-arg <path>`: the files to open;
  `file://` URIs are accepted, options (`--…`) are ignored.
- Formats: PNG, JPEG, GIF (animated), WebP (animated), BMP through the engine's codecs; TIFF
  through the pure-Dart `image` package; SVG/SVGZ through flutter_svg as vectors; PDF through
  poppler-glib. HEIC is recognised and refused with an alert (no HEVC decoder on Silica OS).
- The format comes from the file's first bytes; the extension only decides between text formats.

## Lifecycle

- A document app: closing the window keeps Preview running without windows
  (`SilicaApp.quitWhenLastWindowCloses = false`); a reopen builds a new window and shows the
  Open dialog.

## Commands

Every action is a command, declared once in `lib/src/ui/menus.dart` with its menu, its shortcut
and its state. Until apps can publish their menus to the Silica menu bar, the same table drives
the keyboard and the window's context menu (one submenu per menu).

| Menu | Command | Shortcut |
| --- | --- | --- |
| File | `preview.open` Open… | ⌘O |
| File | `preview.export` Export… (images) | — |
| Edit | `preview.copy` Copy (selected PDF text) | ⌘C |
| Edit | `preview.select_all` Select All (PDF) | ⌘A |
| Edit | `preview.find` Find… (PDF) | ⌘F |
| Edit | `preview.find_next` / `preview.find_previous` | ⌘G / ⇧⌘G |
| View | `preview.sidebar.none` / `.thumbnails` / `.contents` | ⌥⌘1 / ⌥⌘2 / ⌥⌘3 |
| View | `preview.layout.continuous` / `.single` / `.two` (PDF) | — |
| View | `preview.actual_size`, `preview.zoom_to_fit` | ⌘0, ⌘9 |
| View | `preview.zoom_in`, `preview.zoom_out` | ⌘+ (⌘=), ⌘− |
| Go | `preview.previous`, `preview.next` | ⌥⌘↑, ⌥⌘↓ |
| Go | `preview.first`, `preview.last` (PDF) | Home, End |
| Go | `preview.go_to_page` (PDF) | ⌥⌘G |
| Tools | `preview.rotate_left`, `preview.rotate_right` | ⌘L, ⌘R |
| Tools | `preview.flip_horizontal`, `preview.flip_vertical` (images) | — |
| Tools | `preview.inspector` Show / Hide Inspector | ⌘I |

The app menu (Quit), Close Window, full screen and the Window menu are the shell's.

## Runtime dependencies

| Library | Why | Fedora package |
| --- | --- | --- |
| `libpoppler-glib.so.8` | PDF pages, text, outline, metadata | `poppler-glib` |
| `libcairo.so.2` | the bitmaps poppler draws into | `cairo` |
| `libglib-2.0.so.0`, `libgobject-2.0.so.0` | poppler-glib's types | `glib2` |

All are loaded at run time with FFI: nothing is linked at build time and no binary is shipped.
Without them images work and a PDF shows an alert naming the library. File › Open… and
Export… need xdg-desktop-portal with Silica's FileChooser backend (`silica-portal`).
