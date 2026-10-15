# Window, toolbar and sidebar

All values *provisional* until PREVIEW-01 (`PreviewMetrics`, `PreviewColors` in
`lib/src/style.dart`).

## Window

| Item | Value | Constant |
| --- | --- | --- |
| Size at launch | 900 × 700 (`--size` of the `.desktop` entry) | `initialWindow` |
| Smallest window | 420 × 300 | `minWindow` |
| A single image opened | the window takes the image's size (rotation included) plus the toolbar, at most 85 % of the screen, at least the smallest window | — |
| Toolbar | 52 pt, unified with the window (full-size content) | silica_ui `toolbarHeight` |

## Toolbar

From the left, after the window buttons (which end at x 80):

| Item | Value | Constant |
| --- | --- | --- |
| Gap after the window buttons | 8 | `toolbarLeadingGap` |
| Sidebar button: one capsule, the sidebar glyph (toggles the sidebar) and a chevron (opens the menu of sidebar kinds and page layouts) | 38 + 22 wide, 38 tall | `sidebarSegment`, `chevronSegment` |
| Gap before the title | 12 | `titleGap` |
| Title (file name) over subtitle | 13 pt semibold, 11 pt regular | `titleSize`, `subtitleSize` |
| Subtitle | PDF "Page n of N"; several images "n of N"; one image its pixel size; while searching "n of N" matches, "Searching…", "Not found" | — |
| Zoom pair (out, in) with a separator | 2 × 38 | `zoomSegment` |
| Rotate (rotates left) | 38 circle | `roundButton` |
| Search (PDF only), replaced by a 200 pt toolbar search field while searching | 38 circle; 200 | `roundButton`, `searchWidth` |
| Gap between groups; right margin | 8; 10 | `toolbarGap`, `toolbarTrailing` |

Not shown, with an issue each: Share, Markup, Highlight, Form filling.

## Sidebar

| Item | Value | Constant |
| --- | --- | --- |
| Width | 168 | `sidebarWidth` |
| Thumbnail, longest side | 112 | `thumbnailSide` |
| Gap between thumbnails | 14 | `thumbnailGap` |
| Label under a thumbnail (page number or file name) | 16 tall, 11 pt | `thumbnailLabel` |
| Backdrop of the current thumbnail | 6 pt radius, 6 pt padding | `selectionRadius` |
| Table of contents row; indent per level | 24; 14 | `contentsRow`, `contentsIndent` |

Several images opened together show the thumbnails at once; a single file opens without the
sidebar.

## Colours

| Item | Light | Dark |
| --- | --- | --- |
| Toolbar band, empty window | `#ffffff` | `#2b2b2b` |
| Canvas around the image or pages | `#e6e6e6` | `#1e1e1e` |
| Sidebar; its edge | `#f2f2f2`; `#d9d9d9` | `#262626`; `#111111` |
| Current thumbnail backdrop (active / inactive) | `#d5d5d5` / `#dcdcdc` | `#464646` / `#3a3a3a` |
| Page shadow | black 20 %, blur 4, 1 down | black 40 % |
| Text selection; search match; current match | `#3d8cff` 40 %; `#ffd60a` 40 %; `#ff9f0a` 67 % | same |
