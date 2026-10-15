# Dialogs, sheets, popovers and the inspector

PREVIEW-02 › PDF features, Files; PREVIEW-01 › Title bar and toolbar.

## Open

- File › Open… (⌘O) and the empty window's Open… button ask the desktop portal for the Open
  dialog (several files allowed). Launched without files, or reopened from the Dock with no
  window, Preview shows the Open dialog at once; cancelling it closes the new window and Preview
  keeps running without windows. The reference's own Open panel and location browser were not
  measured.
- Images chosen together open in one window; a PDF opens alone. Files that cannot open are
  listed in one alert.

## Password

- A locked PDF asks for its password inside the window, in place of the pages: a lock glyph
  (58 × 45), a bold line saying the document is locked, a smaller line asking for the password,
  and a secure field (242 × 24) with the keyboard. A wrong password empties the field and changes
  the second line; there is no shake. The right one opens the document at once.

## Title popover

- 502 × 150 under the title: the name (selected without its extension; Return renames the file,
  as does closing the popover) and the folder. The reference also offers tags, a location
  pop-up that moves the file and a lock: not in Preview (#16).

## Export

- File › Export…: a sheet 406 pt wide. The format: JPEG, PDF, PNG, TIFF (the reference also has
  HEIC, JPEG 2000 and OpenEXR, which have no encoder in Silica, #14). JPEG: the quality slider
  (182 pt, Least … Best, 0.85 by default). PNG: "keep transparency", only for an image with
  transparent pixels (on by default). PDF: Permissions… (as Edit Permissions). The size of the
  result, live. Cancel and Save (81 × 26); Save then asks the portal's Save dialog for the name
  and the folder.
- The image is written as shown (turned, flipped, resized, with its markup). A PDF document
  exports as PDF: a copy with its changes and the chosen permissions. File › Export as PDF…
  (images) opens the sheet on PDF.
- Not in Preview: the TIFF compression and OpenEXR depth pop-ups, the PDF filters, PDF/A and
  linearization (#14). A PDF document exports as PDF only (#6).

## Edit Permissions (PDF)

- A sheet 339 × 487: ask for a password to open the document (and the same again); the five
  permissions (printing, copying, inserting / deleting / rotating pages, annotating, filling
  forms); the owner password (and again), needed to restrict anything. Apply writes them on save
  (AES-256 with qpdf). Mismatched passwords are said under the fields.

## Adjust Size (images)

- A sheet 417 × 414 centred on the window: Fit into (Custom, or a preset), width and height
  (106 × 26) linked while keeping proportions, the unit (pixels, percent, inches, cm, mm,
  points), the resolution (72 pixels/inch), and the resulting size (percentage, file size before
  and after, estimated). Cancel and OK (71 × 26). The presets are *provisional*; resampling is
  always on (Preview does not write a resolution).

## Revert

- File › Revert To › Last Opened…: an alert (292 wide): Cancel and Revert. The file goes back to
  how it was opened. The reference's versions browser is not in Preview.

## Inspector (⌘I, the toolbar)

- A 270 pt pane on the right of the window, under the toolbar. A segmented control at its top
  with four tabs; it remembers the last one:
  - General: name, kind, file size (decimal units and bytes), modified; images: dimensions,
    colour model, depth, alpha, frames; PDFs: pages, page size, version, title, author, subject,
    creator, producer.
  - More Info: sections that fold (General, EXIF), values on the right.
  - Keywords: a PDF's keywords, added with the field and +, removed with −; "No Keywords" when
    empty; read-only for images.
  - Annotations: page, kind, author, date.
- Rows sit in 250 pt rounded group boxes, 37 pt apart.

## Not in Preview

- Print (#5), share (#1), Duplicate, Move To, Insert › Page from File (#17), Open With, Show in
  Finder, the versions browser (not measured).
