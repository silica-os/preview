# Preview · public specification

This folder describes how the image and PDF viewer of the reference system (macOS 27) looks and
behaves. Silica follows a clean-room process: observations are made on a real machine and
restated here in our own words, with the numbers that came out of them. The raw material stays
in the private repository `silica-reference` and is not reproduced here.

**Status: nothing is measured yet.** The measurement requests PREVIEW-01 (window, toolbar,
sidebar, zoom) and PREVIEW-02 (sheets, inspector, search, text selection) are queued
(silica-reference #101, #102). Every value below is *provisional*: an estimate written down so
that the code has one place to change, the named constants of `lib/src/style.dart`.

## Conventions

- **IDs.** `PREVIEW-01` and `PREVIEW-02` name the measurement requests. A row says which one
  will replace it.
- **Units.** Points at 1×. Positions from the top-left corner of the window.
- **Colours.** sRGB hex.
- **Status.** *provisional*: an estimate, to be replaced by a measurement.
- **Labels.** English, matching `lib/l10n/app_en.arb`. They name controls; they are not
  quotations of the reference interface.

## Files

| File | Covers |
| --- | --- |
| [window.md](window.md) | Window, toolbar, sidebar, colours |
| [viewing.md](viewing.md) | Zoom, page layouts, rotation, navigation, search, selection |
| [dialogs.md](dialogs.md) | Open, export, password, go to page, Get Info, alerts |
