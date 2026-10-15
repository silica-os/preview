<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/silica-logo-dark.svg">
    <img alt="Silica" src=".github/silica-logo-light.svg" width="200">
  </picture>
</p>

<h1 align="center">Preview</h1>

<p align="center">
  <b>The image and PDF viewer of Silica.</b><br>
  Images and PDF documents, on silica_ui.
</p>

<p align="center">
  <img alt="Flutter: app" src="https://img.shields.io/badge/Flutter-app-02569B?style=flat-square&logo=flutter">
  <img alt="license: MIT / Apache-2.0" src="https://img.shields.io/badge/license-MIT%20%2F%20Apache--2.0-3a3a3a?style=flat-square">
  <img alt="status: alpha" src="https://img.shields.io/badge/status-alpha-8a8a8a?style=flat-square">
</p>

A Flutter app for the [Silica desktop](https://github.com/silica-linux/silica-desktop), built on
[`silica_ui`](https://github.com/silica-linux/silica-ui) like the other Silica apps.
App id `dev.frascella.Preview`, icon `photo-viewer` from silica-icons. In Italian: Anteprima.

- **Images:** PNG, JPEG, GIF (animated), WebP, BMP, TIFF (pure Dart) and SVG (as vectors).
  Zoom (⌘+ ⌘− ⌘0 ⌘9, pinch, ⌘-scroll), rotate (⌘L ⌘R), flip, Get Info with EXIF (⌘I),
  File › Export… as PNG, JPEG (with a quality) or PDF. Several images open in one window
  with thumbnails.
- **PDF:** pages rendered on demand by poppler-glib, continuous scroll, single page, two pages,
  thumbnails and table of contents, search (⌘F), text selection and copy.
- **Files:** from the command line (`Exec=… %F`) and from File › Open… through the desktop
  portal's Open and Save dialogs.

Behaviors and measurements come from observations of macOS 27 in silica-reference (clean-room:
nothing copied, texts and graphics are our own). Until requests PREVIEW-01/02 are measured, every
size and timing is *provisional* (`lib/src/style.dart`, [`docs/spec/`](docs/spec/)). Built with
`cargo xtask bundle <path>` and installed with `cargo xtask install-app <path>` from
silica-desktop.

## Runtime dependencies

- `poppler-glib` and `cairo` (shared libraries, loaded with FFI): PDF documents. Without them
  images still work and a PDF shows an alert naming the missing library.
- The desktop portal with Silica's FileChooser backend: File › Open… and File › Export….

## License

MIT OR Apache-2.0.
