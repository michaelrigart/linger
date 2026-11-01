# Linger distribution — design

**Date:** 2026-11-01
**Owner:** Michael Rigart
**Status:** In progress ([PR #2](https://github.com/michaelrigart/linger/pull/2))

## Why

Linger v1 works, but only as a local build: it is signed ad hoc, so every rebuild needs the
Accessibility permission granted again, and there is no way to install or upgrade it
other than building from source. Michael wants Linger installable with Homebrew, with
releases he can cut in one step, CI on every change, and a signing identity that keeps
the Accessibility grant across rebuilds. The signing setup is the template for his other
macOS tools.

## Goals

- `brew install --cask michaelrigart/tap/linger` installs Linger, and `brew upgrade`
  upgrades it.
- One command on Michael's Mac cuts a release: version, changelog, build, sign, verify,
  package, tag, GitHub release and cask update.
- The Accessibility grant survives rebuilds and upgrades.
- CI tests and builds every pull request and every push to `main`.
- The artwork can be edited and regenerated from sources in the repository.

## Non-goals

- Developer ID signing and notarization. They need the paid Apple Developer Program,
  which Michael declined for now *(Michael's decision)*.
- Mac App Store submission.
- Automatic updates inside the app; Homebrew handles upgrades.
- Signing in CI. A free certificate's private key stays on Michael's Mac.
- Intel Macs. Releases are built for Apple silicon only *(Michael's decision)*.

## Anti-goals

- The cask must not strip the quarantine attribute or otherwise bypass Gatekeeper.
- No certificate, private key or token in the repository or in CI.
- The release script pushes to `main` only its own release commit (the changelog
  section), plus the tag, and only Michael runs it.
- No machine-specific paths or settings in the repository (it is public).
- No public text names a specific chat or presence app *(Michael's request)*.

## Decisions (Michael's)

- **Signing:** a free Personal Team (an Apple ID added in Xcode), which provides an
  "Apple Development" certificate.
- **Versions:** `YYYYMMDD-HHMM` in local time, with leading zeros and no `v` prefix
  (for example `20261101-1430`), as in his other projects.
- **Homebrew:** a cask in his existing tap, `michaelrigart/homebrew-tap`.
- **CI:** yes.
- **Design sources:** kept in this repository.
- **Changelog:** a `CHANGELOG.md` in the format of his other projects (Keep a Changelog,
  with a GitHub compare link per version).
- **Apple silicon only.**

## How it works

### Versions

- The version is the local time when the release script starts, `date +%Y%m%d-%H%M`.
- It is the tag name, the GitHub release title, part of the asset name
  (`Linger-<version>.zip`) and the cask's `version`.
- The app gets it at build time: `MARKETING_VERSION=<version>` becomes
  `CFBundleShortVersionString` (shown in Settings › About), and
  `CURRENT_PROJECT_VERSION=<digits only, YYYYMMDDHHMM>` becomes `CFBundleVersion`, which
  macOS compares as a number.
- Builds outside the release script show `dev` as the version and `0` as the build number.
- The App Store would reject a hyphen in `CFBundleShortVersionString`; that is accepted,
  because the App Store is a non-goal.

### Signing

- `project.yml` sets `DEVELOPMENT_TEAM` to Michael's Personal Team ID, with manual
  signing and the identity `Apple Development`, for Debug and Release. A Team ID is a
  public identifier: it is embedded in every signed build.
- macOS ties the Accessibility grant to the app's designated requirement. With a
  certificate from a team, that requirement names the team and the certificate instead
  of a hash of this exact build, so the grant survives rebuilds and upgrades.
- Hardened Runtime stays on, and Release still injects no base entitlements: the only
  entitlement is `com.apple.security.app-sandbox`.
- Anyone without the certificate (CI, contributors) builds ad hoc by adding
  `CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=` to `xcodebuild`.
- Scripts pick the signing identity by Team ID, not by the bare name `Apple Development`,
  so another team's development certificate on the same Mac is never used.
- Manual signing with this identity and no provisioning profile is the builder's first
  check. If it fails, stop and bring it to Michael: the fallback, automatic signing for a
  free team, embeds a development profile that only runs on Michael's registered Macs
  and expires within days.

### Verifying a built app

One script, `scripts/verify-app <path-to-Linger.app> [<expected-version>]`, used by CI
and by the release script, fails unless:

- the signature verifies (`codesign --verify --strict`);
- the entitlements are exactly `com.apple.security.app-sandbox = true`;
- `LSUIElement` is true and the bundle identifier is `com.michaelrigart.linger`;
- when a version is given, `CFBundleShortVersionString` equals it and `CFBundleVersion`
  equals its digits.

### CI

`.github/workflows/ci.yml`, on pull requests and on pushes to `main`:

- runs on `macos-26` (GitHub has no macOS 27 image) with an Xcode 26 release selected
  explicitly;
- `permissions: contents: read`, and a concurrency group that cancels superseded runs;
- every third-party action pinned to a full commit SHA, with the version in a comment, as
  in Michael's other repositories;
- XcodeGen comes from the repository's `mise.toml` through the mise action;
- steps: `swift test --package-path Packages/LingerCore`, `xcodegen generate`, a Release
  build for Apple silicon signed ad hoc, then `scripts/verify-app` on the product.

This also proves Linger builds with Xcode 26, while Michael builds with Xcode 27.

### Changelog

`CHANGELOG.md` follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), as in
Michael's other projects:

- a short preamble saying versions are `YYYYMMDD-HHMM` release times, not compatibility
  promises;
- `## [Unreleased]` at the top, which every pull request with a user-visible change adds
  to, under `### Added`, `### Changed`, `### Fixed` or `### Removed`;
- one `## [<version>] - <YYYY-MM-DD>` section per release;
- link definitions at the bottom: `[Unreleased]` compares the latest version with
  `HEAD`, each version compares with the one before it, and the first links to its
  release.

The first section records Linger v1 and this distribution work.

### Releasing

`scripts/release`, run by Michael on his Mac:

1. Checks: no local changes, `gh` signed in, and the Apple Development identity for the
   team present in the keychain. A new release must also be on `main`, level with
   `origin/main`, with entries under `## [Unreleased]`. A resumed release (step 2) must be
   on a commit on `origin/main` whose changelog already has the version's section, and if
   the tag exists, on the tagged commit. `--dry-run` skips the branch and `origin/main`
   checks, so a release can be rehearsed from any branch.
2. Computes the version, or takes `--version <version>` to resume an earlier run. When
   resuming, if the tag already exists (locally or on `origin`), both must point at the
   same commit and `HEAD` must be that commit; otherwise the script stops and says which
   commit to check out. A published binary is always built from its tagged commit.
3. For a new release, moves the `Unreleased` entries under `## [<version>] - <date>`,
   updates the link definitions, commits `Release <version>` and pushes it to `main`.
   `--dry-run` prints the section instead of committing.
4. Generates the project and builds Release for Apple silicon (`ARCHS=arm64`), signed
   with the Apple Development identity, with the version settings above.
5. Runs `scripts/verify-app` with the version.
6. Packages `Linger-<version>.zip` with `ditto -c -k --keepParent`.
7. Unless `--dry-run`, publishes in this order, skipping each step that is already done:
   - tags `HEAD` with the version (if the tag doesn't exist yet) and pushes the tag;
   - creates the GitHub release if it doesn't exist, with the version's changelog section
     as its notes;
   - uploads the zip if the release doesn't have it yet. If the release already has a
     `Linger-<version>.zip`, the published asset is kept and the local build is discarded;
   - downloads the published asset and computes its SHA-256. The cask's checksum always
     comes from this download, never from a local file, so it matches what Homebrew
     fetches;
   - clones the tap into a temporary directory, writes `Casks/linger.rb` with the version
     and that checksum, commits `linger <version>` and pushes to the tap's `main`, unless
     the cask already has this version and checksum.

Re-running with `--version` therefore resumes after a failure at any step.

### Homebrew cask

`Casks/linger.rb` in `michaelrigart/homebrew-tap`:

- `version`, `sha256`, and a `url` pointing at the release asset;
- `name`, a generic `desc` and the repository as `homepage`;
- `depends_on macos: ">= :tahoe"` and `depends_on arch: :arm64`;
- `app "Linger.app"`;
- `uninstall quit: "com.michaelrigart.linger"`;
- `zap` removes `~/Library/Containers/com.michaelrigart.linger`;
- `livecheck` on the latest GitHub release;
- `caveats` explaining the two first-run steps below.

Because the app is not notarized, macOS blocks its first launch after a fresh install:
the user opens it once from System Settings › Privacy & Security › "Open Anyway". On
`brew upgrade`, Homebrew carries that approval over when the new app satisfies the old
app's designated requirement, which a stable team signature does, so upgrades should
launch without it. The Accessibility grant survives upgrades for the same reason.

### Design sources

A `design/` folder holds:

- the designer's SVGs from the v2 logo set (the set the committed PNGs come from):
  `app-icon.svg`, `mark.svg`, `mark-on-light.svg`;
- the menu bar sources: the three 2x SVGs (filled, outline, half) and the hand-fitted 1x
  pixel grids;
- `design/render`, which regenerates every PNG in `Linger/Assets.xcassets` from those
  sources. It needs `rsvg-convert` (Homebrew `librsvg`), checks for it, and says so if it
  is missing.

The committed PNGs stay the source of truth for builds; `design/render` is only run when
the artwork changes.

### Documentation

- README: a Homebrew install section (with the two first-run steps) ahead of building
  from source, and the ad hoc signing override for building without the certificate.
- AGENTS.md: the release command, the verify script, the design render script, that CI
  signs ad hoc, and that user-visible changes add a `CHANGELOG.md` entry under
  `Unreleased`.

## Constraints

- Everything from the v1 spec still holds: the sandbox, the single entitlement, Hardened
  Runtime, no network access, XcodeGen through mise.
- Pushes from Michael's Mac use his existing git and `gh` credentials.

## Prerequisites (Michael)

- Add his Apple ID in Xcode › Settings › Accounts and create an Apple Development
  certificate for the Personal Team. The builder reads the Team ID from the keychain.
- The certificate's subject is embedded in every public release. A free team's
  certificate is named after the Apple ID's email, so that email becomes visible in
  every release's signature; Michael accepted this *(Michael's decision, 2026-11-01)*.
- Install Apple's current intermediate certificate (WWDR G3) in the login keychain, which
  `codesign` needs to build the certificate chain.

## Delivery

- A new branch from `main` once PR #1 (Linger v1) is merged, and its own draft pull
  request.

## Acceptance

1. CI passes on the pull request for this work.
2. A Debug or Release build signed with the Personal Team keeps the Accessibility grant
   after a rebuild and reinstall, with no reset.
3. `scripts/release --dry-run` builds, verifies and packages an Apple silicon zip and
   prints the changelog section it would commit.
4. After merging: the first real release creates the tag, the GitHub release with the zip
   and the cask; `brew install --cask michaelrigart/tap/linger` installs it; after
   "Open Anyway" and one Accessibility grant, Linger runs and Settings shows the version.
5. At the second release, `brew upgrade` launches without "Open Anyway" and keeps the
   Accessibility grant. If Homebrew doesn't carry the approval over, the caveats and the
   README say so instead.

## Left to the builder

The scripts' language (shell is fine), the exact Xcode 26 version on the runner, the
pinned action versions, the cask's `caveats` wording, and how the 1x grids are stored
(data file or script), within the constraints above.
