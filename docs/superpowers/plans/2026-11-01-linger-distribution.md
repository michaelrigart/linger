# Linger Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** In progress

**Goal:** Sign Linger with Michael's Personal Team, version releases as `YYYYMMDD-HHMM`,
keep a changelog, test and build in CI, cut releases with one local script, publish a
Homebrew cask, and keep the artwork sources in the repository.

**Architecture:** Build settings carry the signing identity and the version; one script
verifies any built app; a stdlib-only Python tool edits the changelog; a Bash release
script chains build, verify, package, tag, GitHub release and cask update, each publish
step idempotent; CI runs the tests, an ad hoc build and the verifier.

**Tech Stack:** XcodeGen (`project.yml`), `xcodebuild`, `codesign`, Bash, Python 3
(stdlib only, `/usr/bin/python3`), GitHub Actions, `gh`, Homebrew casks, `rsvg-convert`.

**Spec:** `docs/superpowers/specs/2026-11-01-linger-distribution-design.md`

**Branch:** `feat/distribution` from `main` after PR #1 merges; its own draft PR.

## Global Constraints

- Commands run outside any agent sandbox, prefixed with
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` unless `xcode-select -p`
  already points at Xcode (AGENTS.md).
- Team ID `CX4MWR5579`; identity `Apple Development`; manual signing, no provisioning
  profile.
- Ad hoc override for machines without the certificate: `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=`.
- Only entitlement: `com.apple.security.app-sandbox = true`. Hardened Runtime on. Release
  keeps `CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO`.
- Apple silicon only: `ARCHS=arm64`.
- Version `YYYYMMDD-HHMM`, local time, leading zeros, no `v`. `CFBundleShortVersionString`
  is the version; `CFBundleVersion` is its 12 digits. Non-release builds: `dev` and `0`.
- Bundle ID `com.michaelrigart.linger`; release asset `Linger-<version>.zip`; tap
  `michaelrigart/homebrew-tap`, file `Casks/linger.rb`.
- Every GitHub Action pinned to a full commit SHA with the version in a comment.
- Public repository: no machine-specific paths or settings; no public text names a
  specific chat or presence app.
- The release script pushes to `main` only its `Release <version>` commit and the tag,
  and to the tap only `linger <version>`.
- Python is stdlib only; new dev tools go in `mise.toml`.

## Review Focus

1. Resuming a release after a failed step must never pair a cask checksum with bytes
   other than the published asset (Task 5, step 4 test).
2. The changelog date must come from the version, not a second clock read, or a release
   at 23:59 gets the next day's date (Task 2 test `test_date_comes_from_version`).
3. A release with nothing under `Unreleased` must refuse before building (Task 2 test
   `test_release_refuses_empty_unreleased`; Task 5 uses it).
4. Installing the cask over the manually copied `/Applications/Linger.app` fails in
   Homebrew; the README install section says to remove a manual copy first (Task 5).
5. A build on a machine without the certificate must still work with the documented
   override (Task 4 CI proves it).

---

### Task 1: Signing, version settings and the app verifier

**Depends on:** none

**Files:**
- Modify: `project.yml`
- Modify: `Linger/Info.plist` (version keys)
- Create: `scripts/verify-app`
- Create: `scripts/tests/test-verify-app`
- Modify: `AGENTS.md` (Commands: verify; signing rule)

**Interfaces:**
- Produces: `scripts/verify-app [--team <ID>] <Linger.app> [<version>]`, exit 0 on success, non-zero
  with one line per failed check on stderr. Checks: `codesign --verify --strict`;
  entitlements exactly `{com.apple.security.app-sandbox: true}`; `LSUIElement` true;
  bundle ID; when a version is given, `CFBundleShortVersionString == version` and
  `CFBundleVersion == version with '-' removed`; with `--team`, the signature's
  `TeamIdentifier` equals the ID.
- Produces: build settings `MARKETING_VERSION` (default `dev`) and
  `CURRENT_PROJECT_VERSION` (default `0`) feeding the Info.plist.

- [ ] **Step 1: Write the failing verifier test** `scripts/tests/test-verify-app <app>`.
  Every case starts from a fresh copy of the app in its own temp dir, and every negative
  case first asserts that `verify-app <copy>` passes on that copy, so each case fails for
  exactly one reason: (a) `verify-app <copy>` passes; (b) after re-signing the copy ad hoc
  with the sandbox entitlement plus `com.apple.security.network.client`, it fails;
  (c) `verify-app <copy> 20261101-1430` fails on a `dev` build; (d) after re-signing the
  copy ad hoc with exactly `Linger/Linger.entitlements`, `verify-app <copy>` passes and
  `verify-app --team CX4MWR5579 <copy>` fails.
- [ ] **Step 2: Run it against the current build; expect failure** (`verify-app` missing).
- [ ] **Step 3: Implement `scripts/verify-app`** (Bash; `codesign`, `plutil`,
  `/usr/libexec/PlistBuddy`; `set -euo pipefail`).
- [ ] **Step 4: Settings.** In `project.yml` base settings: `DEVELOPMENT_TEAM: CX4MWR5579`,
  `CODE_SIGN_STYLE: Manual`, `CODE_SIGN_IDENTITY: "Apple Development"`,
  `ARCHS: arm64`, `MARKETING_VERSION: dev`, `CURRENT_PROJECT_VERSION: "0"`; remove
  `CODE_SIGN_IDENTITY: "-"`. In `Linger/Info.plist` and `project.yml`'s `info.properties`:
  `CFBundleShortVersionString: $(MARKETING_VERSION)`, `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`.
- [ ] **Step 5: Prove signing without a profile.** Precondition: `security find-identity -v -p codesigning`
  lists the `CX4MWR5579` identity as valid; if not, stop and ask Michael to install Apple's
  WWDR G3 intermediate (spec Prerequisites). Generate and build Release. Expected:
  `codesign -dvv` shows `Authority=Apple Development: …` and `TeamIdentifier=CX4MWR5579`;
  `codesign -d -r-` shows a requirement on `certificate leaf[subject.CN]`, not `cdhash`.
  If `xcodebuild` demands a provisioning profile, stop and report BLOCKED with the exact
  error: the spec sends that case to Michael. Never add a provisioning profile and never
  switch to automatic signing.
- [ ] **Step 6: Run the test** against the Release build (pass), and against an ad hoc
  build made with the override (passes without `--team`).
- [ ] **Step 7: AGENTS.md.** Commands gain `scripts/verify-app`; the signing rule says
  builds are signed with the Personal Team, the grant survives rebuilds, and the
  `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` override builds without the certificate.
  The "every rebuild needs the grant given again" and `tccutil` lines now apply to ad hoc
  builds only; say so.
- [ ] **Step 8: Commit** `Sign with the Personal Team and verify built apps`.

### Task 2: Changelog tool and CHANGELOG.md

**Depends on:** none

**Files:**
- Create: `scripts/changelog.py`
- Create: `scripts/tests/test_changelog.py`
- Create: `CHANGELOG.md`

**Interfaces:**
- Produces: `scripts/changelog.py release <version> --repo <owner/name> [--file CHANGELOG.md]`
  rewrites the file in place; `scripts/changelog.py notes <version> [--file …]` prints
  that version's section body; `scripts/changelog.py check-unreleased [--file …]` exits
  non-zero when `Unreleased` has no entries. Pure functions `release(text, version, repo) -> str`
  and `notes(text, version) -> str`, raising `ValueError` with a one-line message.

- [ ] **Step 1: Write failing tests** in `scripts/tests/test_changelog.py` (unittest), with
  exact strings:
  - `test_release_moves_unreleased_entries`: given `## [Unreleased]\n\n### Added\n\n- X\n`
    and one earlier version `20261101-1430`, `release(text, "20261102-0905", "michaelrigart/linger")`
    yields an empty `## [Unreleased]`, then `## [20261102-0905] - 2026-11-02` holding
    `### Added\n\n- X`, and link lines
    `[Unreleased]: https://github.com/michaelrigart/linger/compare/20261102-0905...HEAD`
    and `[20261102-0905]: https://github.com/michaelrigart/linger/compare/20261101-1430...20261102-0905`.
  - `test_first_release_links_to_its_release`: before any release the file's only link
    line is `[Unreleased]: https://github.com/michaelrigart/linger/commits/main`; after
    `release`, `[Unreleased]` compares `<version>...HEAD` and `[<version>]` is
    `https://github.com/michaelrigart/linger/releases/tag/<version>`.
  - `test_date_comes_from_version`: `20261231-2359` gives `- 2026-12-31`.
  - `test_release_refuses_empty_unreleased`: raises `ValueError("nothing under [Unreleased]")`.
  - `test_release_refuses_existing_version`: raises `ValueError("<version> already released")`.
  - `test_rejects_malformed_version`: `2026-11-02`, `v20261102-0905`, `20261102-905` raise.
  - `test_notes_returns_section_body`: the body between the version heading and the next
    `## `, without the heading.
- [ ] **Step 2: Run** `/usr/bin/python3 -m unittest discover -s scripts/tests -p 'test_*.py'`;
  expect failures (module missing).
- [ ] **Step 3: Implement `scripts/changelog.py`** (stdlib only; version regex
  `^\d{8}-\d{4}$`; date = `YYYY-MM-DD` from the version's first 8 digits).
- [ ] **Step 4: Run the tests; expect all pass.**
- [ ] **Step 5: Write `CHANGELOG.md`:** title, a preamble saying versions are
  `YYYYMMDD-HHMM` release times in the maintainer's local time, not compatibility
  promises, and that the format follows Keep a Changelog 1.1.0; `## [Unreleased]` with
  `### Added` entries for Linger v1 (keeps the Mac active while you're away, steps aside
  for light/dark switching, pause, lock detection, login item, settings) and for this
  work (Homebrew cask, signed builds), and the link line
  `[Unreleased]: https://github.com/michaelrigart/linger/commits/main`. No chat app names.
- [ ] **Step 6: Commit** `Add a changelog and the tool that cuts its releases`.

### Task 3: Design sources and the render script

**Depends on:** Task 1 (both edit `AGENTS.md`, and Task 1's build reads the asset catalog
this task rewrites)

**Files:**
- Create: `design/app-icon.svg`, `design/mark.svg`, `design/mark-on-light.svg`
  (copied from `.superpowers/distribution/design-sources/`)
- Create: `design/menubar/filled.svg`, `outline.svg`, `half.svg`, `design/menubar/pixel1x.py`
  (copied from `.superpowers/distribution/design-sources/menubar/`)
- Create: `design/render`
- Modify: the PNGs in `Linger/Assets.xcassets` only if Step 3 shows a pixel difference
- Modify: `AGENTS.md` (one line: how to regenerate artwork)

**Interfaces:**
- Produces: `design/render` regenerates every PNG in `Linger/Assets.xcassets`: the 2x
  menu bar PNGs with `rsvg-convert -w 36 -h 36`, the 1x ones with `design/menubar/pixel1x.py`,
  and the app icon set from `design/app-icon.svg` at each size in its `Contents.json`.
  Exits with "needs rsvg-convert (Homebrew librsvg)" when it is missing.

- [ ] **Step 1: Copy the sources;** change `pixel1x.py` to take the output directory and
  write `LingerMenuBar@1x.png`, `LingerMenuBarOutline@1x.png`, `LingerMenuBarHalf@1x.png`
  into the matching imagesets.
- [ ] **Step 2: Write `design/render`** (Bash).
- [ ] **Step 3: Verify reproduction.** Run it, then for every changed PNG compare pixels
  with the committed one (`magick compare -metric AE <old> <new> null:`, run once by the
  implementer). Expected: `0` for all six menu bar PNGs; for the app icon set, a
  difference small enough to be invisible (report the AE values). Commit the rendered
  PNGs so the committed files equal the script's output from now on.
- [ ] **Step 4: AGENTS.md** gains: artwork sources live in `design/`; regenerate with
  `design/render`, which needs `rsvg-convert` (Homebrew `librsvg`, not in the
  maintainer's Brewfile).
- [ ] **Step 5: Commit** `Keep the artwork sources and a render script in design/`.

### Task 4: CI

**Depends on:** Task 1, Task 2

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `mise.toml` (add `actionlint`)

**Interfaces:**
- Consumes: `scripts/verify-app`, `scripts/tests/test-verify-app`,
  `scripts/tests/test_changelog.py`.

- [ ] **Step 1: Add `actionlint` to `mise.toml`** (pinned version) for local workflow checks.
- [ ] **Step 2: Write `.github/workflows/ci.yml`:** triggers `pull_request` and `push` to
  `main`; `permissions: contents: read`; concurrency group `ci-${{ github.ref }}` with
  `cancel-in-progress: true`; one job on `macos-26` that selects the newest Xcode 26 on
  the image explicitly (`sudo xcode-select -s /Applications/Xcode_26.<n>.app`, version
  read from the runner image's documentation at implementation time), checks out with
  `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`, installs mise
  tools with `jdx/mise-action` pinned to a commit, then runs: the changelog tests,
  `swift test --package-path Packages/LingerCore`, `mise exec -- xcodegen generate`,
  `xcodebuild … -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build`,
  `scripts/verify-app build/Build/Products/Release/Linger.app`, and
  `scripts/tests/test-verify-app` on that app.
- [ ] **Step 3: Run** `mise exec -- actionlint`; expected: no output.
- [ ] **Step 4: Commit** `Run tests and an ad hoc Release build in CI`. The workflow's
  first real run is on the pull request (acceptance 1).

### Task 5: Release script, cask and install docs

**Depends on:** Task 1, Task 2, Task 3 (`AGENTS.md`, and its build reads the asset catalog)

**Files:**
- Create: `scripts/release`
- Create: `scripts/linger.rb.template`
- Create: `scripts/tests/test-release-dry-run`
- Modify: `README.md` (Install with Homebrew; first-run steps; build-from-source override;
  releasing pointer), `AGENTS.md` (release command; changelog rule)

**Interfaces:**
- Consumes: `scripts/verify-app`, `scripts/changelog.py` (Tasks 1–2).
- Produces: `scripts/release [--dry-run] [--version <YYYYMMDD-HHMM>]`.

- [ ] **Step 1: Write `scripts/linger.rb.template`** with placeholders `@VERSION@` and
  `@SHA256@`: `url "https://github.com/michaelrigart/linger/releases/download/#{version}/Linger-#{version}.zip"`,
  `name "Linger"`, a generic `desc` (keeps your Mac active without blocking light/dark
  switching; Homebrew's 80-character limit), `homepage "https://github.com/michaelrigart/linger"`,
  `livecheck` (`url :url`, `strategy :github_latest`, regex for `\d{8}-\d{4}`),
  `depends_on macos: ">= :tahoe"`, `depends_on arch: :arm64`, `app "Linger.app"`,
  `uninstall quit: "com.michaelrigart.linger"`,
  `zap trash: "~/Library/Containers/com.michaelrigart.linger"`, and `caveats` naming the
  two first-run steps ("Open Anyway" once after the first install; Accessibility once).
- [ ] **Step 2: Write the failing test** `scripts/tests/test-release-dry-run`: runs
  `scripts/release --dry-run` on a temp clone of the repo; asserts exit 0, a
  `Linger-<version>.zip` whose app passes `verify-app --team CX4MWR5579 <app> <version>`,
  the printed changelog section, a rendered cask that passes `brew style --cask`, and no
  new tag, release or commit (`git tag`, `git log` unchanged). The test never touches
  GitHub: the temp clone's `origin` is a local bare repository and `gh` on `PATH` is a
  stub. It needs the signing certificate, so it runs on Michael's Mac, not in CI.
- [ ] **Step 3: Implement `scripts/release`** (Bash, `set -euo pipefail`) as the spec's
  steps 1–7, in this order: checks; version (`date +%Y%m%d-%H%M`, or `--version`);
  changelog commit and push (new releases only; `changelog.py check-unreleased` first);
  build with `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`, `ARCHS=arm64`;
  `verify-app --team CX4MWR5579 <app> <version>`; `ditto -c -k --keepParent` into
  `build/release/Linger-<version>.zip`. `--dry-run` then renders the cask from the template
  with the local zip's checksum to `build/release/linger.rb`, for checking only, and stops.
  Otherwise: tag
  and push; `gh release create <version> --notes-file <changelog.py notes>` if missing;
  `gh release upload` only if the asset is missing; `gh release download` the asset into
  a temp dir and `shasum -a 256` it; clone the tap with `gh repo clone` into a temp dir,
  render the template, skip if unchanged, else commit `linger <version>` and push.
- [ ] **Step 4: Resume-safety test** (extend the test file, same kind of local `origin`
  and stubbed `gh`, including the tap clone; each scenario gets its own fresh temp clone,
  bare origin and stub state): with the stub that reports an existing release *with* the
  asset, `--version <v>` must hash the downloaded asset (the stub serves a fixture zip)
  and never upload; with the tag pointing at a different commit than `HEAD`, the script
  must stop before building.
- [ ] **Step 5: Run the tests; expect pass.**
- [ ] **Step 6: Docs.** README: a new "Install" section before "Build and install"
  (`brew install --cask michaelrigart/tap/linger`; remove any manually copied
  `/Applications/Linger.app` first; "Open Anyway" once after the first install; grant
  Accessibility once; upgrades should keep both, per the spec); the build-from-source section notes the
  `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` override and that ad hoc builds need the
  Accessibility grant again after each rebuild. AGENTS.md: `scripts/release` (Michael
  runs it; agents only with his go-ahead, since it pushes to `main`); "user-visible
  changes add a `CHANGELOG.md` entry under `Unreleased`"; and CI builds ad hoc with the
  override, so release signing happens only on Michael's Mac.
- [ ] **Step 7: Commit** `Add the release script and the Homebrew cask template`.

### Task 6: Acceptance before merge

**Depends on:** Tasks 1–5

**Files:** none (results go in the PR description)

- [ ] **Step 1:** CI passes on the pull request (acceptance 1).
- [ ] **Step 2:** Michael installs a Personal-Team-signed build, grants Accessibility,
  then installs a rebuilt one: Linger stays active with no reset (acceptance 2). Read
  `status:` lines in Linger's log as in the v1 acceptance.
- [ ] **Step 3:** `scripts/release --dry-run` passes on the branch (acceptance 3).
- [ ] **Step 4:** Set the spec's and this plan's Status to `Implemented` citing the PR in
  the final pre-merge commit.

After merge, Michael runs `scripts/release` for the first release (acceptance 4:
`brew install --cask michaelrigart/tap/linger`, "Open Anyway", one Accessibility grant,
Settings shows the version). Acceptance 5 (upgrade keeps both approvals) is checked at
the second release and recorded in the README or caveats if it fails.
