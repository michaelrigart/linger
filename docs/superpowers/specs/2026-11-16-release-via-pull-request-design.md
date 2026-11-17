# Releasing through a pull request (Linger port) — design

**Date:** 2026-11-16
**Status:** Implemented ([PR #5](https://github.com/michaelrigart/linger/pull/5))
**Canonical:** Muninn's design,
[`docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md`](https://github.com/michaelrigart/muninn/blob/main/docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md)
in `michaelrigart/muninn` (signed off on 2026-11-16 at commit `b87ed19` on its branch
`fix/release-via-pr`). That design governs the release flow. This document lists only what differs
for Linger, and what it brings over.
**Supersedes in part:** the distribution design
(`docs/superpowers/specs/2026-11-01-linger-distribution-design.md`), in the same places the
canonical design supersedes Muninn's: the anti-goal "The release script pushes to `main` only its own
release commit (the changelog section), plus the tag", and step 3 of "Releasing", which pushes the
release commit to `main`. It also supersedes that step's resume checks (step 1), which now follow
the canonical design, together with its new checks that `gh` can merge; and, in step 7, the
keeping of an asset the release already has (one not in state `uploaded` is now deleted and
uploaded again) and the cask update (a cask whose version is newer is left alone).

## What Linger takes

The maintainer decided on 2026-11-16 that all release scripts should resemble each other as much as
possible (the canonical design, "Ports"). Linger takes `scripts/release` and
`scripts/tests/test-release-dry-run` whole from Muninn's implementation of the canonical design,
with the names changed. It does not port the design separately.

The canonical design describes Linger's current script as older than the shared one. It lacks the
following, which come over with the shared script:

- the recovery of an unpushed release commit, which the canonical design turns into landing it
  through its pull request;
- the guard on an untagged resume: HEAD must be the one "Release <version>" commit on origin's
  `main`;
- incomplete release assets: an asset not in state `uploaded` is deleted and uploaded again;
- the tap's downgrade guard: a cask whose version is newer is left alone;
- the test groups and stub support for these (c3's additions, d2, h, i), and the canonical
  design's new cases.

## Differences: names only

| | Muninn | Linger |
|---|---|---|
| Repository | `michaelrigart/muninn` | `michaelrigart/linger` |
| Project, scheme, app | `Muninn.xcodeproj`, `Muninn`, `Muninn.app` | `Linger.xcodeproj`, `Linger`, `Linger.app` |
| Zip | `Muninn-<version>.zip` | `Linger-<version>.zip` |
| Cask template, cask | `scripts/muninn.rb.template`, `Casks/muninn.rb` | `scripts/linger.rb.template`, `Casks/linger.rb` |
| Tap commit | `muninn <version>` | `linger <version>` |
| Temporary folders | `muninn-release.*`, `muninn-release-test.*` | `linger-release.*`, `linger-release-test.*` |
| The test's text from the real changelog, which a section must not contain | "Muninn records calls" | "Linger keeps your Mac active" |

Left out: Muninn's zap cases (`zap_is_settings_only` and the four "a:" cases that use it). Linger's
cask removes its sandbox container and Application Scripts folder, and Linger's test does not check
the zap stanza, as before.

## What the shared script calls, checked against Linger

Recon on 2026-11-16, against Muninn's `main` at `56c3e8b`:

- `scripts/changelog.py` and `scripts/tests/test_changelog.py` are the same as Muninn's apart from
  the name. They need no change.
- `scripts/verify-app` has the interface the script uses, `[--team <ID>] <Linger.app> [<version>]`.
  Its checks are Linger's own (the App Sandbox entitlement, `LSUIElement`, the bundle identifier).
  It needs no change.
- `scripts/linger.rb.template` has the same `@VERSION@` and `@SHA256@` placeholders. It needs no
  change.
- The team (`CX4MWR5579`), `gh`, `mise exec -- xcodegen` and `xcodebuild` are the same.
  `gh auth status --active --hostname github.com --json hosts` works with the maintainer's `gh`
  (2.104.0).
- `michaelrigart/linger` carries the rulesets `protect-main` and `main-merge-owner`.
  `michaelrigart/homebrew-tap` has none, so the cask commit keeps going straight to its `main`.

If Muninn's implementation calls something else that Linger lacks, it comes over too, renamed. The
plan names it.

## Documentation

As in the canonical design, adapted to Linger's files:

- **README, "Releasing":** Linger's section is shorter than Muninn's. It gains the canonical
  content: the release commit goes through a pull request that the script opens and merges as
  admin; `gh` must use a login with the `repo` scope of an admin account; a failed run says where
  it stopped, and `--version` resumes it.
- **`AGENTS.md`:**
  - The Release line says the script pushes a release branch and merges its pull request,
    instead of "pushes to `main`".
  - Linger's `AGENTS.md` has no distribution pointer, so its "Design and behaviour" line gains
    this spec for the release flow.
- **The distribution spec** gains one line under its header, pointing here and at the canonical
  design for the release flow. Its text is not rewritten.
- No `CHANGELOG.md` entry: nothing changes for users.

## Delivery

- Branch `fix/release-via-pr`, with a pull request of its own.
- The port starts from Muninn's commit once its `scripts/release` and test have passed Codex's
  pre-merge review. The plan pins that commit.
- Cross-repository: all five pull requests (Muninn, Hulder, Linger, Tafl, Skald) are opened before
  any is merged, and Muninn's is merged first. Skald was added by the maintainer on 2026-11-16
  (canonical design, "Ports", at Muninn `a539742`).

## Acceptance

1. `scripts/tests/test-release-dry-run` passes on the maintainer's Mac, every case.
2. `scripts/release --dry-run` passes there and creates nothing on git or GitHub.
3. With the names normalised, `scripts/release` is identical to Muninn's, and
   `scripts/tests/test-release-dry-run` is identical except for the zap cases.
4. CI passes on the pull request.
5. After the merge, the maintainer's next real release lands, tags and publishes in one run. It
   ends on `main`, level with origin, with no `release/<version>` left.
