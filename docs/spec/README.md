# Preview · public specification

This folder describes how the image and PDF viewer of the reference system (macOS 27) looks and
behaves. Silica follows a clean-room process: observations are made on a real machine and
restated here in our own words, with the numbers that came out of them. The raw material stays
in the private repository `silica-reference` and is not reproduced here.

**Status: measured.** PREVIEW-01 (windows, toolbar, viewing, sidebar, PDF modes, slideshow) and
PREVIEW-02 (markup, PDF features, files, menus) were measured on 2026-10-15 (silica-reference
#101, #102), dark and light. The values live in the named constants of `lib/src/style.dart`.
A value marked *provisional* was not measured (the reference was not observed doing it, or the
measurement did not cover it) and is an estimate.

## Conventions

- **IDs.** `PREVIEW-01` and `PREVIEW-02` name the measurement requests.
- **Units.** Points at 1×. Positions from the top-left corner of the window.
- **Colours.** sRGB hex.
- **Labels.** English, matching `lib/l10n/app_en.arb`. They name controls; they are not
  quotations of the reference interface.

## Files

| File | Covers |
| --- | --- |
| [window.md](window.md) | Window, toolbar, sidebar, colours, motion |
| [viewing.md](viewing.md) | Zoom, page layouts, navigation, search, selection, annotations, markup, slideshow |
| [dialogs.md](dialogs.md) | Password, export, permissions, adjust size, revert, title popover, inspector, alerts |

## Not measured, kept provisional

Native full screen, pinch and smart zoom, signatures, the Open panel, the location browser, the
versions browser, Open With, Show in Finder, instant alpha, remove background, the lasso
selections, the states of form controls, the colours of the highlight menu other than yellow,
the other search matches, the divider of the sidebar.
