# Window, toolbar and sidebar

PREVIEW-01 › Windows and chrome, Sidebar, Motion. Constants: `PreviewMetrics`,
`PreviewColors` in `lib/src/style.dart`; the size of a new window in
`lib/src/model/window_size.dart`.

> **Amalfi (UI 1.0.0).** Behaviour, window sizes and timings below are the measured ones. The
> look and the measures of the chrome (toolbar pieces, sidebars, inspector, colours) are
> Amalfi's, from the kit page `App · Preview` (silica-design) and the Amalfi design notes in
> silica-desktop: a flat 52 pt toolbar of pieces (view 72, zoom 104, highlight 72, buttons 40,
> search 208), nothing scrolls under it; sidebars 160 (200 for search results) with cells 144;
> the inspector 260; find bar and markup strip 36 pt + 1 pt separator; colours from
> `App/Preview/*`. `test/kit_test.dart` checks them. The numbers of the tables below that
> differ are the reference's, kept for the behaviour.

## Window

| Item | Value | Constant |
| --- | --- | --- |
| Smallest window | 708 × 224, images and PDFs alike | `minWindow` |
| An image that fits | 100 %: as wide as the image, image + 52 (toolbar) + 26 + 26 tall; a small image counts as 708 × 224 (200 × 150 opens 708 × 328) | `imageInset` |
| A larger image | fitted in the tallest window, whose bottom stays 40 pt above the screen's edge; 8 pt bands at the sides of the image | `screenBottomGap`, `fittedSideBand` |
| Several images | the 160 pt sidebar beside a content area of at least 708 | — |
| A PDF | as tall as the screen allows; as wide as the sidebar, the widest page at actual size and the 14 pt margins; the page fitted to the width | — |
| Where it opens | the reference: (4, 34), the next one 29 pt further down and right. Silica's compositor places windows (silica-desktop#172) | `windowOrigin`, `windowCascade` |
| The screen | Flutter's display, or the embedder's `outputSize`; neither is reported yet, so a 1440 × 900 screen is assumed. *Provisional* (silica-desktop#171) | `fallbackScreen` |
| Launch size, before a document | 708 × 500 (`--size` of the `.desktop` entry). *Provisional* | `initialWindow` |
| Tabs (a 28 pt bar over the content column) | not in Preview: one window per app in the embedder (#7) | — |

## Toolbar

52 pt, glass: the content scrolls under it (silica_ui `ScrollUnderToolbar`). Capsules are their
segments plus a 1 pt outline on each side (and 1 pt separators between segments where drawn).
At 1200 pt:

| Item | Value | Constant |
| --- | --- | --- |
| View menu button: the sidebar glyph and a chevron; opens the view menu (sidebar kinds, page layouts) | a 50 × 38 capsule centred in a 57 pt slot at x 92 | `viewSlotLeft`, `viewSlot`, `viewButton` |
| Title block | from x 164: the name, 13 pt bold; a 11 pt secondary line: "Page N of M" (PDF), "Edited", "N documents, M pages in all" (several images), "Page N of M — Edited"; a document icon before it and a chevron after it on hover | `titleLeft`, `titleSize`, `subtitleSize` |
| Title popover | 502 × 150 under the title: the name (selected; Return renames the file) and the folder. Tags, the location pop-up and the lock are not in Preview (#16) | `titlePopover` |
| Zoom group | 113 × 38: zoom out, actual size (disabled at 100 %), zoom in | `zoomOutSegment`, `actualSizeSegment`, `zoomInSegment` |
| Highlight group | 76 × 38: highlight (on / off) and the colour menu (yellow, green, blue, pink, purple; underline, strikethrough); disabled for images | `highlightSegment`, `highlightMenuSegment` |
| Rotate | a 38 pt circle (rotates left) | `rotateSegment` |
| Markup | a 40 pt circle; shows the markup toolbar | `markupButton` |
| Inspector | a 38 pt circle | `inspectorSegment` |
| Search field | fills the rest, 273 to 327 wide, 7 pt from the right edge; disabled for images. Narrower: a 38 pt magnifier circle (its field in a popover) and the tools that do not fit in a 38 pt overflow circle with a menu | `searchMinWidth`, `searchMaxWidth`, `roundButton` |
| Gaps | zoom 6, highlight 7, rotate 0, markup 8, inspector 3, right edge 7 | `gapAfter…`, `toolbarTrailing` |
| Not shown | remove background (#19), form filling (#15), share (no share service, #1) | — |

Under the toolbar, inside the glass band: the find bar (36 pt) while a search is shown, and the
markup toolbar (36 pt), shown and hidden at once; the first time on an image shown whole the
window grows by 31 pt.

## Sidebar

| Item | Value | Constant |
| --- | --- | --- |
| Width | 160 by default, 160 to 400 by dragging its edge, a 1 pt divider; 199 while it lists search results | `sidebarWidth`, `sidebarMinWidth`, `sidebarMaxWidth`, `sidebarSearchWidth` |
| Thumbnails | a 105 pt page in a 117 pt cell (6 pt inset), 3 pt, the number 16 pt high: 117 × 174 for A4; 10 pt between cells (184 pitch); the page grows 155 pt for 180 pt of sidebar (260 at 340) | `thumbnail…` |
| The current thumbnail | a rounded rectangle (radius 8) around the cell, `#296ffb` with a white number while the sidebar has the focus, muted otherwise | `thumbnailRadius`, `selection`, `selectionInactive` |
| Several images | one section per file, 5 pt apart, the file's name (middle-truncated) under it | `sectionGap` |
| Table of contents | the document's name 19 pt; entries 40 pt; the disclosure at x 12; 12 pt per level; the chosen entry on a rounded rectangle 10 pt in from the edges: accent with bold white text when focused, `#4a4844` (dark) otherwise | `contents…` |
| Highlights and notes | a 19 pt header; a highlight row 127 pt (page, author, a 3 pt bar of its colour, the marked text), a note row 114 pt | `notesHeader`, `highlightRow`, `noteRow`, `noteBar` |
| Bookmarks | a 30 pt header, rows 85 pt: "Page N" and three lines of the page's text | `bookmarksHeader`, `bookmarkRow` |
| Search results | rows 77 pt: a 40 × 52 page, "Page N", the number of matches, the text around the first one with the match in bold | `resultRow`, `resultThumbnail` |
| Contact sheet | over the whole content: a 28 pt header (disclosure, file name), cells 152 × 216 holding a 120 × 170 page and its number; the chosen page on a gray rounded rectangle, its number in an accent pill | `contact…` |
| PDF page context menu | rotate left / right, delete, insert a blank page, bookmark. *Provisional* (the reference's thumbnail menu was read on images) | — |
| Image thumbnail context menu | close, export as, sort by name, folder, date, size, kind, as opened | — |

Pages are dragged to a new place in the thumbnails (the others make room). Dragging a page into
another window is not possible: one window per app (#7).

## Colours

| Item | Light | Dark |
| --- | --- | --- |
| Around an image | `#ffffff` | `#2f2d2c` |
| Behind PDF pages | `#fcfcfc` | `#2b2927` |
| Page shadow | the gutter darkens to `#f1f1f1` over 14 pt next to the page | barely visible |
| Sidebar (glass over Silica's backdrop) | `#eeedec` | `#2d2a26` |
| Selection, focused | `#296ffb` | `#296ffb` |
| Selection, unfocused | `#9da9c4` | `#3f4b65` |
| Table of contents, unfocused | *provisional* `#dcdcdc` | `#4a4844` |
| Text selection | `#b8d4fd` (behind the glyphs) | same (pages stay light) |
| Current search match | `#ffff3b` | same |
| Other matches | *provisional* `#ffff3b` 40 % | same |
| Markup handles | `#316ec8`, 1 pt white ring | same |
| Sidebar divider | *provisional* `#d9d9d9` | *provisional* `#111111` |

## Motion

| Item | Value | Constant |
| --- | --- | --- |
| Window opening | ≈ 80 ms, the compositor's | — |
| Sidebar | slides out in 220 ms, in in 250 ms, the content reflowing | `sidebarHide`, `sidebarShow` |
| Zoom step | 200 ms; the toolbar's actual size 95 ms | `zoomAnimation`, `actualSizeAnimation` |
| Page Down | at once | — |
| Markup toolbar, crop | at once | — |
| Rotate, flip (images) | ≈ 220 ms, ≈ 185 ms | `rotateAnimation`, `flipAnimation` |
