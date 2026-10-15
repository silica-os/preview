# Preview · specification

What the app does and how it behaves. Measurements: `silica-reference` › `preview-app.md`
(PREVIEW-01 windows, viewing, sidebar, PDF modes; PREVIEW-02 markup, PDF features, files,
menus; measured 2026-10-15). What was not measured is marked *provisional*. Details in
[`spec/`](spec/).

## Files

- Arguments after the bundle (`Exec=… @BUNDLE@ %F`) or `--dart-arg <path>`: the files to open;
  `file://` URIs are accepted, options (`--…`) are ignored.
- Formats: PNG, JPEG, GIF, WebP, BMP through the engine's codecs; TIFF through the pure-Dart
  `image` package (the first page, #18); SVG/SVGZ through flutter_svg as vectors; PDF through poppler-glib. HEIC is
  recognised and refused with an alert (no HEVC decoder on Silica OS).
- The format comes from the file's first bytes; the extension only decides between text formats.
- **Differences kept on purpose.** The reference does not open SVG files and shows an animated
  GIF's frames as pages without playing it; Preview opens SVG as vectors and plays animations.
  Both are extras that cost nothing to the measured behaviour.

## Editing and saving

- Every change to a document is one step of Undo (⌘Z) and Redo (⇧⌘Z). While changes are not in
  the file the title's second line says "Edited" (after "Page N of M —" for a PDF); there is no
  mark in the close button. Undoing back to the file's state clears it.
- Changes are written when the window closes (nothing is asked), when another file is opened in
  the window, and with File › Save (⌘S). Before the first write the file is copied aside
  (`$XDG_CACHE_HOME/preview`), and File › Revert To › Last Opened… puts it back after an alert
  (292 × 170); the copies go when the window closes.
- Images are written in their own format (PNG, JPEG keeping its EXIF, TIFF, BMP, a single-frame
  GIF, WebP): turned, flipped, resized and with their markup. Other formats (SVG, animations)
  turn and flip for viewing only, which is not a change.
- PDFs: annotations are written by poppler-glib; pages (order, rotation, blank pages, deletions),
  bookmarks (a `/SilicaBookmark` key in the page), keywords and permissions by qpdf. Without qpdf,
  page edits, bookmarks and permissions are not offered.

## Lifecycle

- A document app: closing the window keeps Preview running without windows
  (`SilicaApp.quitWhenLastWindowCloses = false`); a reopen builds a new window and shows the
  Open dialog.

## Commands

Every action is a command, declared once in `lib/src/ui/menus.dart` with its menu, its shortcut
and its state. The same table is published to Silica's menu bar (`SilicaMenuBar`, silica-menu-v1:
the app menu, File, Edit, View, Go, Tools, Window, Help; checkmarks and enabled states follow
the document), drives the keyboard (the window binds ⌘ and Ctrl itself) and the window's context
menu (the reference's context items first, then one submenu per menu). The bar also shows, disabled, the
items of the reference that Preview cannot do yet (listed below); the context menu leaves them out. The menus follow the reference's (PREVIEW-02 › Menus, read through
accessibility), keeping the items Preview can do.

| Menu | Command | Shortcut |
| --- | --- | --- |
| File | `preview.open` Open… | ⌘O |
| File | `preview.close` Close Window | ⌘W |
| File | `preview.save` Save | ⌘S |
| File | `preview.rename` Rename… (the title popover) | — |
| File | `preview.revert` Revert To › Last Opened… | — |
| File | `preview.permissions` Edit Permissions… (PDF) | — |
| File | `preview.export` Export…, `preview.export_pdf` Export as PDF… (images) | — |
| Edit | `preview.undo`, `preview.redo` | ⌘Z, ⇧⌘Z |
| Edit | `preview.copy` Copy (selected PDF text) | ⌘C |
| Edit | `preview.delete` Delete (the chosen shape, annotation, or page in the sidebar) | ⌫ |
| Edit | `preview.select_all` Select All (PDF) | ⌘A |
| Edit | `preview.insert_blank` Insert › Blank Page (PDF) | — |
| Edit | `preview.find`, `preview.find_next`, `preview.find_previous`, `preview.find_selection` | ⌘F, ⌘G, ⇧⌘G, ⌘E |
| View | `preview.sidebar.none` / `.thumbnails` / `.contents` / `.notes` / `.bookmarks` / `.contactSheet` | ⌥⌘1 … ⌥⌘6 |
| View | `preview.layout.continuous` / `.single` / `.two` (PDF) | ⌘1, ⌘2, ⌘3 |
| View | `preview.actual_size`, `preview.zoom_to_fit` | ⌘0, ⌘9 |
| View | `preview.zoom_in`, `preview.zoom_out` | ⌘+ (⌘=), ⌘− |
| View | `preview.markup` Show / Hide Markup Toolbar | ⇧⌘A |
| View | `preview.toolbar` Show / Hide Toolbar | ⌥⌘T |
| View | `preview.slideshow` Slideshow | ⇧⌘F |
| Go | `preview.page_up`, `preview.page_down` | ⇞, ⇟ |
| Go | `preview.previous_document`, `preview.next_document` (several images) | ⌥⇞, ⌥⇟ |
| Go | `preview.previous`, `preview.next` (page or image) | ⌥↑, ⌥↓ |
| Go | `preview.go_to_page` (PDF) | ⌥⌘G |
| Go | `preview.back`, `preview.forward` (pages jumped from) | ⌘[, ⌘] |
| Tools | `preview.inspector` Show / Hide Inspector | ⌘I |
| Tools | `preview.adjust_size` Adjust Size… (images) | — |
| Tools | `preview.annotate.*`: highlight, underline, strikethrough text, note (PDF); rectangle, oval, line, arrow, polygon, star, text box, speech balloon (images) | ⌃⌘H, ⌃⌘U, ⌃⌘S, ⌃⌘N; ⌃⌘R, ⌃⌘O, ⌃⌘I, ⌃⌘A, ⌃⌘T |
| Tools | `preview.bookmark` Add / Remove Bookmark (PDF) | ⌘D |
| Tools | `preview.rotate_left`, `preview.rotate_right` | ⌘L, ⌘R |
| Tools | `preview.flip_horizontal`, `preview.flip_vertical` (images) | — |

⌃⌘ is Ctrl together with Super. The app menu (Services, Hide, Quit), full screen and the Window menu are the
shell's. Shown disabled in the bar: print (#5), share (#1), Open Recent, Duplicate, Move To, Insert › Page
from File (#17), the selection tools and crop (#10), the loupe, signatures, adjust colour (#12),
form filling (#15), remove background (#19), import from devices, writing tools, colour
proofing, 3D.

## Runtime dependencies

| Library | Why | Fedora package |
| --- | --- | --- |
| `libpoppler-glib.so.8` | PDF pages, text, outline, metadata, annotations | `poppler-glib` |
| `libcairo.so.2` | the bitmaps poppler draws into | `cairo` |
| `libglib-2.0.so.0`, `libgobject-2.0.so.0` | poppler-glib's types | `glib2` |
| `libqpdf.so.30` (or `.29`) | rewriting PDFs: page order, rotation, blank pages, bookmarks, keywords, encryption | `qpdf-libs` |

All are loaded at run time with FFI: nothing is linked at build time and no binary is shipped.
Without poppler images work and a PDF shows an alert naming the library; without qpdf PDFs are
still annotated and saved, and the page, bookmark and permission commands are not offered.
File › Open… and Export… need xdg-desktop-portal with Silica's FileChooser backend
(`silica-portal`).
