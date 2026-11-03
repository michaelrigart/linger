# Linger

Design and behaviour: `docs/superpowers/specs/2026-10-30-linger-design.md`.
Design-record rules (specs, plans, status, commits) are in the global agent instructions.

## Commands

Run all of these outside any agent sandbox. SwiftPM's nested
`sandbox-exec`, the module cache under `/var/folders`, the Xcode build service and the app's
own event and log access all fail inside it. Prefix each with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` unless `xcode-select -p`
already points at Xcode.

- Core tests: `swift test --package-path Packages/LingerCore`
- Generate the project: `mise exec -- xcodegen generate` (`Linger.xcodeproj` is not tracked)
- Build: `xcodebuild -project Linger.xcodeproj -scheme Linger -configuration Debug -derivedDataPath build -quiet build`
- Release build: the same with `-configuration Release`; `scripts/verify-app` accepts only
  Release builds.
- Without the signing certificate (ad hoc): add `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` to
  either build.
- Install: `rm -rf /Applications/Linger.app && ditto build/Build/Products/Debug/Linger.app /Applications/Linger.app`
  (`ditto` merges into an existing bundle and would keep stale files)
- Run: `open /Applications/Linger.app`
- Script tests: `/usr/bin/python3 -m unittest discover -s scripts/tests -p 'test_*.py'` (the
  changelog tool), `scripts/tests/test-release-dry-run` and
  `scripts/tests/test-verify-app <Release Linger.app>` (a Release build made with the default
  version)
- Verify a built app: `scripts/verify-app [--team <ID>] <Linger.app> [<version>]`. It fails on a
  bad signature, entitlements other than exactly `com.apple.security.app-sandbox`, `LSUIElement`
  not true, a wrong bundle identifier or version, or (with `--team`) a different
  `TeamIdentifier`.
- Release: `scripts/release [--dry-run] [--version <YYYYMMDD-HHMM>]`. Michael runs it; an agent
  only with his go-ahead, since it pushes to `main`, tags, creates a GitHub release and pushes
  to the Homebrew tap. `--dry-run` builds, verifies and packages into `build/release/` and
  prints the changelog section; it commits and pushes nothing. `--version` resumes an earlier
  run. Its test, `scripts/tests/test-release-dry-run`, runs the script in temporary clones whose
  `origin` is a local bare repository, with a stub `gh`, so it never reaches GitHub. It builds
  and signs, so it needs the certificate and runs on Michael's Mac, not in CI
- CI builds ad hoc with the override above, so release signing happens only on Michael's Mac
- Artwork sources live in `design/`; `design/render` regenerates every PNG in the asset catalog from
  them. It needs `rsvg-convert` (Homebrew `librsvg`, not in the maintainer's Brewfile)
- Probe (Debug builds only): `build/Build/Products/Debug/Linger.app/Contents/MacOS/Linger -LingerProbe YES -LingerProbeInterval 1 -LingerProbeSeconds 6`,
  then read it with `/usr/bin/log show --last 2m --style compact --predicate 'subsystem == "com.michaelrigart.linger"'`

## Rules an agent gets wrong

- A user-visible change adds an entry to `CHANGELOG.md` under `## [Unreleased]`, in `### Added`,
  `### Changed`, `### Fixed` or `### Removed`. A new `scripts/release` run refuses without one
  (resuming with `--version` does not check), and moves them under the new version.
- `LingerCore` must not import AppKit or SwiftUI. Platform code lives in the app target.
- Linger posts only the zero-distance `mouseMoved` event at the cursor's current position.
  No keyboard, click or scroll events. See the spec's Anti-goals before adding anything.
- The Accessibility (post-event) grant is tied to the code signature. Builds are signed
  with Michael's Personal Team (manual signing, no provisioning profile), whose designated
  requirement names the certificate, so the grant survives rebuilds. Ad hoc builds
  (the override above) have a per-build signature: for those only, every rebuild needs the
  grant given again. The old build's entry stays in the Accessibility list, and macOS won't
  prompt again while it exists. Clear it with `tccutil reset All com.michaelrigart.linger`
  (Michael runs this), or remove and re-add Linger in the list.
- When the grant is given, macOS may record the signature of any copy of Linger that
  Launch Services knows, not the one running. Before granting, rebuild or delete every ad
  hoc copy, including an old Debug build under `build/`. Otherwise Linger stays at
  `needsPermission` and `tccd` logs "Failed to match existing code requirement".
- Check access with `AXIsProcessTrusted()` only. `CGPreflightPostEventAccess()` caches its
  answer for the life of the process, so it misses a grant or a revocation while Linger
  runs, and combining it with the live check lets a stale "granted" mask a revocation.
  `CGRequestPostEventAccess()` is called only for its prompt. The switch in the
  Accessibility list sets exactly the permission `AXIsProcessTrusted()` reads.
- A bare `log` is a zsh builtin. Use `/usr/bin/log`.
- Engine and probe events are logged at notice level, which is persisted, so
  `/usr/bin/log show` reads them without `--info`. Info-level lines are not persisted:
  keep anything that must survive the process at notice or above.
- Launching `Linger.app/Contents/MacOS/Linger` from a terminal makes macOS attribute
  Accessibility to the terminal. Permission readings only count when the app is started with
  `open` or Finder.
- Debug and Release share one sandbox container (same bundle ID), so stored defaults carry
  over between them.
