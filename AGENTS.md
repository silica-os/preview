# AGENTS.md

Preview is a Silica app: the rules of `silica-desktop/AGENTS.md` apply (clean-room, assets,
never crash, everything is a command, measured parity, English everywhere). On top of them:

## Clean-room

- Observations of the reference system live in the private repository `silica-reference`
  (`preview.md`, requests PREVIEW-01 and PREVIEW-02), never here. Here only the request codes and
  the measured numbers are cited.
- Interface texts are our own words, in English with translations (`lib/l10n/*.arb`).
  No Apple product names, no texts copied from the reference interface.

## Work

- Plan and bugs: the issues of this repository and the Silica board
  (https://github.com/orgs/silica-os/projects/1).
- Before every commit: `dart format --set-exit-if-changed lib test`,
  `flutter analyze --fatal-infos`, `flutter test`, `tool/check_assets.sh`. One task per commit.
- Every user action is a `preview.*` command, declared once in `lib/src/ui/menus.dart` and
  listed in `docs/spec.md`.
- Values not measured yet are named constants marked *provisional* (`lib/src/style.dart`) and
  listed in `docs/spec/`. When PREVIEW-01/02 arrive, replace them and say where they came from.
- No dead controls: a feature that does not work is not shown, and has an issue.
- `silica_ui` comes from a tag (`ref` in `pubspec.yaml`); widgets other apps need go into
  `silica-ui`.
- The PDF library is behind `lib/src/pdf/backend.dart`; tests use the fake in
  `test/support/fake_pdf.dart`. Tests write their files in temporary directories only.
- Nothing may reach the user's desktop from tests: no dialogs, no programs
  (`lib/src/external.dart`, `startsNothing`).
- Never crash: a damaged image, a broken PDF, a missing library are normal cases with an alert.
