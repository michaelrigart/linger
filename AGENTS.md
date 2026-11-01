# Linger

Design and behaviour: `docs/superpowers/specs/2026-10-30-linger-design.md`.
Design-record rules (specs, plans, status, commits) are in the global agent instructions.

## Commands

Run all of these outside any agent sandbox. SwiftPM's nested
`sandbox-exec`, the module cache under `/var/folders`, the Xcode build service and the app's
own event and log access all fail inside it. Prefix each with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; `xcode-select` points at the
Command Line Tools.

- Core tests: `swift test --package-path Packages/LingerCore`
- Generate the project: `mise exec -- xcodegen generate` (`Linger.xcodeproj` is not tracked)
- Build: `xcodebuild -project Linger.xcodeproj -scheme Linger -configuration Debug -derivedDataPath build -quiet build`
- Probe (Debug builds only): `build/Build/Products/Debug/Linger.app/Contents/MacOS/Linger -LingerProbe YES -LingerProbeInterval 1 -LingerProbeSeconds 6`,
  then read it with `/usr/bin/log show --last 2m --style compact --predicate 'subsystem == "com.michaelrigart.linger"'`

## Rules an agent gets wrong

- `LingerCore` must not import AppKit or SwiftUI. Platform code lives in the app target.
- Linger posts only the zero-distance `mouseMoved` event at the cursor's current position.
  No keyboard, click or scroll events. See the spec's Anti-goals before adding anything.
- The Accessibility (post-event) grant is tied to the code signature. Builds are ad-hoc
  signed, so every rebuild needs the grant given again. The old build's entry stays in
  the Accessibility list, and macOS won't prompt again while it exists. Clear it with
  `tccutil reset PostEvent com.michaelrigart.linger` (Michael runs this), or remove and
  re-add Linger in the list.
- `CGPreflightPostEventAccess()` caches its answer for the life of the process, so on its
  own it never sees a grant made while Linger runs. `AXIsProcessTrusted()` checks live,
  and the switch in the Accessibility list sets exactly that permission.
- A bare `log` is a zsh builtin. Use `/usr/bin/log`.
- Engine and probe events are logged at notice level, which is persisted, so
  `/usr/bin/log show` reads them without `--info`. Info-level lines are not persisted:
  keep anything that must survive the process at notice or above.
- Launching `Linger.app/Contents/MacOS/Linger` from a terminal makes macOS attribute
  Accessibility to the terminal. Permission readings only count when the app is started with
  `open` or Finder.
- Debug and Release share one sandbox container (same bundle ID), so stored defaults carry
  over between them.
