# Linger

Sandboxed macOS menu bar app (Swift 6, SwiftUI). It keeps Microsoft Teams "active" by
posting a zero-distance mouse event, and steps aside around dusk and dawn so macOS Auto
appearance can switch. Design: `docs/superpowers/specs/2026-10-30-linger-design.md`.
Design-record rules (specs, plans, status, commits) are in the global agent instructions.

## Commands

Run all of these outside the Claude sandbox (`dangerouslyDisableSandbox`). SwiftPM's nested
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
  signed, so every rebuild needs the grant given again.
- A bare `log` is a zsh builtin. Use `/usr/bin/log`.
- Engine and probe events are logged at notice level, which is persisted, so
  `/usr/bin/log show` reads them without `--info`. Info-level lines are not persisted:
  keep anything that must survive the process at notice or above.
