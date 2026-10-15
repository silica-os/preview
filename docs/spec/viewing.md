# Viewing and editing

PREVIEW-01 › Viewing, PDF display modes, Navigation, Slideshow; PREVIEW-02 › Markup, PDF
features.

## Zoom

| Item | Value | Constant |
| --- | --- | --- |
| Steps (zoom in / out, ⌘+ / ⌘−, the toolbar) | 0.05, 0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.75, 1, 1.5, 2, 3, 4, 6, 8, 10, 15, 20, 30 × actual size; 5 % to 3000 % | `zoomSteps`, `minZoom`, `maxZoom` |
| Actual size | images: a pixel per point; PDFs: the physical size on the display (the display's pixels per inch / 72; until the system tells the display's size Preview uses 72) | `pdfPointsPerInch` |
| PDF stops | the fitted width (continuous) or the fitted page is a stop between the steps | — |
| Fit (⌘9) | the default for PDFs and for images larger than the window; it holds while the window is resized | — |
| Animation | 200 ms per step, the toolbar's actual size 95 ms | `zoomAnimation`, `actualSizeAnimation` |
| ⌘-scroll, pinch | the factor e^(−dy / 200), the gesture's scale, at the pointer. *Provisional* (pinch and smart zoom were not measured) | `scrollZoomPoints` |

No zoom percentage field. Images smaller than the window sit in its middle.

## Page layouts (PDF)

- **Continuous Scroll** (⌘1, default): one column, 14 pt from the content's edges, 17 pt
  between pages; the current page is the one a third of the way down the window.
- **Single Page** (⌘2): one page, fitted and centred; a scroll that cannot move the page turns
  it.
- **Two Pages** (⌘3): a book. The first page alone, then 2–3, 4–5…; the two pages of a spread
  touch, with a faint shade at the spine.
- Page Down (⇟) moves a screen at once (no animation) in the continuous layout, a page or spread
  in the others.

## Navigation

| Action | Keys |
| --- | --- |
| Page up / down | ⇞ / ⇟, Space |
| Previous / next page or image | ⌥↑ / ⌥↓, ← / → |
| Previous / next document (several images) | ⌥⇞ / ⌥⇟ |
| First / last | Home / End |
| Go to Page… | ⌥⌘G |
| Back / Forward (the pages jumped from: thumbnails, contents, results, Go to Page) | ⌘[ / ⌘] |

## Search (PDF)

- The toolbar's field; Return searches (again: the next match, ⇧Return the previous). Matching
  ignores case and common accents; a space matches any run of white space.
- The sidebar lists the pages with matches (by number of matches or by page) and widens to
  199 pt; the 36 pt find bar shows the order toggles, "Found on N pages", previous / next and Done
  (50 × 26), which ends the search. The current match is filled `#ffff3b`.
- ⌘E searches the selected text.

## Text selection (PDF)

- Dragging over a page selects its text (light blue `#b8d4fd` behind the glyphs); ⌘A selects
  every page's text; ⌘C copies it, pages separated by a line break. A selection stays on the page
  where the drag started (#10).

## Annotations (PDF)

- The toolbar's highlight button turns highlighting on: a selection is marked when the drag
  ends; with text already selected it is marked at once. Its menu chooses yellow (`#f5d164` on
  white), green, blue, pink, purple (*provisional* colours), underline or strikethrough.
- Tools › Annotate: highlight, underline, strikethrough the selection (⌃⌘H, ⌃⌘U, ⌃⌘S); a note
  (⌃⌘N), a 22 pt icon whose popover (≈ 274 × 154, yellow) holds its text and Done.
- A click chooses an annotation (drawn darker); its context menu has the five colours, underline
  and strikethrough, remove, and add a note.
- Annotations are written into the PDF by poppler-glib when it is saved. Not on blank pages
  added in Preview, nor in a PDF whose permissions forbid them.

## Pages (PDF)

- Rotate (the toolbar, ⌘L, ⌘R) turns the current page (both pages of a spread); Edit › Delete
  (with the focus in the sidebar) removes it; Edit › Insert › Blank Page adds one of its size after
  it; a thumbnail dragged to another place moves its page; ⌘D bookmarks it. All are written
  with qpdf on save; bookmarks are kept in the page (`/SilicaBookmark`).

## Markup (images)

- The markup toolbar (⇧⌘A or the toolbar's markup circle): a 36 pt strip, centred, in groups:
  Shapes ▾ (110 × 218: line, arrow, rectangle, rounded rectangle, oval, speech balloon, star,
  polygon), Text, Adjust Size | Shape Style ▾ (120 × 417: six widths, dashes, line ends, shadow),
  Border Colour ▾ and Fill Colour ▾ (270 × 300: a bright row and a 12 × 10 grid with "none"),
  Text Style ▾ (289 × 138: colour, size, bold / italic / underline, alignment). For a PDF: Note.
- A new shape goes in the middle, chosen: a 3 pt black border, no fill; a text box says "Text" in
  red. Handles are 10 pt circles `#316ec8` with a white ring at the corners and the middles of the
  sides (a line's ends; a text box's sides). Dragging a shape moves it, a handle resizes it; a
  double click edits a text box; ⌫ removes the chosen shape.
- The six line widths 1, 2, 3, 5, 8, 12 and the colours of the grid are *provisional*.
- Not in Preview yet: the selection tools and crop (#10), instant alpha, sketch, sign, adjust
  colour, image description, the loupe and the mask (#12), redaction, shapes and text on PDFs
  (#13).

## Rotation and flips (images)

- Rotate Left / Right (⌘L, ⌘R, the toolbar) and Flip Horizontal / Vertical turn the image,
  animated (≈ 220 ms, ≈ 185 ms), and are written into the file when it is saved.

## Slideshow

- View › Slideshow (⇧⌘F): the pages or images on black, fitted (a spread in the two-page
  layout). Moving the pointer shows the HUD (287 × 74, 32 pt from the bottom, radius 8): previous,
  play / pause, next, close (61 × 52 each). Playing, the next page comes about every 5 s with a
  dissolve (*provisional* length 500 ms); previous and next cut. Esc ends it.
- The reference fills the display; Silica's embedder cannot ask for a full-screen window yet, so
  the slideshow covers the window (silica-desktop#173).
