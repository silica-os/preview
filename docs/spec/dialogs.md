# Dialogs, sheets and the inspector

All values *provisional* until PREVIEW-02.

## Open

- File › Open… (⌘O) and the empty window's Open… button ask the desktop portal for the Open
  dialog (several files allowed). Launched without files, or reopened from the Dock with no
  window, Preview shows the Open dialog at once; cancelling it closes the new window and Preview
  keeps running without windows (it does not quit with its last window).
- Images chosen together open in one window; a PDF opens alone. Files that cannot open are
  listed in one alert.

## Export (images)

- File › Export… opens a sheet (360 wide): Format (PNG, JPEG, PDF) and, for JPEG, Quality
  (Least … Best, default 85 %). Save… then asks the portal's Save dialog, with the name of the
  image and the format's extension. The image is written as shown (rotation and flips). JPEG
  puts transparent pixels on white; PDF is one page the size of the image (one pixel per point),
  lossless.

## Password

- A protected PDF opens a sheet asking for its password; a wrong one asks again with a different
  message.

## Go to Page

- ⌥⌘G: a sheet with the page number (1 to the page count).

## Get Info (⌘I)

- A floating panel (280 × 360) at the top right of the window, below the toolbar, movable by its
  title bar: name, kind, file size (decimal units and bytes), and
  - images: dimensions in pixels, colour model (RGB, Gray, CMYK, Indexed, Vector), bits per
    channel, alpha channel, frames for animations, and the EXIF fields Make, Model, Lens, Date
    taken, Exposure, F-number, ISO, Focal length, Flash, Software when present;
  - PDFs: pages, the current page's size in points, version, title, author, subject, creator,
    producer when present.
