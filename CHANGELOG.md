# Changelog

## Unreleased

- Measured against PREVIEW-01 and PREVIEW-02: window sizes, the toolbar's groups and places, the
  sidebar (160–400, thumbnails, contents, highlights and notes, bookmarks, search results,
  contact sheet), zoom steps of actual size, PDF margins and the book layout, colours, motion.
- Editing: PDF highlights, underlines, strikethroughs and notes (poppler); page rotation,
  deletion, blank pages, reordering, bookmarks, keywords and permissions (qpdf); image markup and
  Adjust Size; undo, "Edited", saving on close and ⌘S, Revert.
- The password in the window, the title popover (rename), the find bar, the inspector pane, the
  slideshow, the export sheet with TIFF and transparency, menus and context menus as measured.
- Menus in Silica's menu bar (silica-desktop#175): the app menu, File, Edit, View, Go, Tools,
  Window and Help as measured, with the items Preview cannot do yet shown disabled.
- silica_ui 0.34.0; image 4.12.

## 0.1.0 · 2026-10-15

- First version: images (PNG, JPEG, GIF, WebP, BMP, TIFF, SVG) and PDF documents (poppler-glib
  through FFI); zoom, rotate, flip; thumbnails and table of contents; continuous, single and
  two-page layouts; search, text selection and copy; Get Info with EXIF; export as PNG, JPEG or
  PDF; Open and Save through the desktop portal; English and Italian. Geometry and timing are
  provisional until PREVIEW-01/02 are measured.
