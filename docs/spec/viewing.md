# Viewing

All values *provisional* until PREVIEW-01/02.

## Zoom

| Item | Value | Constant |
| --- | --- | --- |
| An image opens at its size, or fitted when larger than the window | — | `ZoomMode.auto` |
| A PDF opens fitted to the width of its widest page (continuous) | — | `ZoomMode.fitWidth` |
| Zoom In / Zoom Out (⌘+ / ⌘−, toolbar) | × or ÷ 1.25 | `zoomStep` |
| Limits | 5 % to 3200 % | `minZoom`, `maxZoom` |
| ⌘-scroll (or Ctrl-scroll) | factor e^(−dy / 200) at the pointer | `scrollZoomPoints` |
| Pinch | the gesture's scale, at the pointer | — |
| Actual Size (⌘0) | 100 %: one image pixel or one PDF point per point | — |
| Zoom to Fit (⌘9) | the whole image or page (spread) in the window; the page width in the continuous layout | — |
| Margin around PDF pages; gap between pages | 12; 10 | `pageMargin`, `pageGap` |
| Margin around an image | 0 | `imageMargin` |
| Image pixels drawn as squares from | 300 % | — |

The point under the pointer (or the centre for the keyboard and buttons) stays in place while
zooming.

## Rendering PDF pages

- Pages are rendered by poppler-glib in a worker isolate, one at a time, the most recent request
  first; the scale is rounded up to quarter-octave steps (2^(n/4) pixels per point) so small zoom
  changes reuse a bitmap; while the right bitmap renders the nearest one is shown scaled.
- Bitmaps are kept up to 256 MB, least recently used out (`pageCacheBytes`); a page is never
  rendered beyond 8192 pixels per side (`maxPagePixels`).

## Page layouts (PDF)

- **Continuous Scroll** (default): all pages in a column, scrolling; the current page is the one
  a third of the way down the window.
- **Single Page**: one page; ← → (and ↑ ↓, Page Up/Down, Space) change page.
- **Two Pages**: pages side by side, 1–2, 3–4…; the arrows move by a spread.

## Navigation

| Action | Keys |
| --- | --- |
| Previous / next page or image | ⌥⌘↑ / ⌥⌘↓, ← / → |
| First / last | Home / End, Go › First Page / Last Page |
| Go to Page… | ⌥⌘G |
| Scroll (continuous) | ↑ ↓ 40 pt; Page Up / Page Down / Space 90 % of the window |

## Rotation and flips

- Rotate Left (⌘L, the toolbar button) and Rotate Right (⌘R) turn the current image, or every
  page of a PDF, by a quarter turn. Flip Horizontal / Flip Vertical mirror the current image
  (images only). The file is not changed; Export… writes the image as shown.

## Search (PDF)

- ⌘F opens the toolbar search field; typing searches after 250 ms, every page in order. Matching
  ignores case and common accents; a space matches any run of white space (line breaks too).
- All matches are highlighted, the current one stronger; Return or ⌘G goes to the next one,
  ⇧Return or ⇧⌘G to the previous one, wrapping around; Esc closes the search.

## Text selection (PDF)

- Dragging over a page selects its text from the character under the press to the one under the
  pointer (lines in reading order); a click clears the selection. Select All (⌘A) selects the
  text of every page. Copy (⌘C) puts the text on the clipboard, pages separated by a line break.
- A selection stays on the page where the drag started.
