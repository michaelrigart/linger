# Releasing through a pull request (Linger port) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: run this plan with the `plan-run` skill. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Status:** Implemented ([PR #5](https://github.com/michaelrigart/linger/pull/5)); completed, do not run again

**Goal:** Linger's `scripts/release` cuts a release through a pull request, with the script and its
test taken whole from Muninn's implementation, renamed.

**Architecture:** No design of its own. Muninn's reviewed `scripts/release` and
`scripts/tests/test-release-dry-run` are copied over, renamed by a fixed substitution, and the zap
cases are removed from the test. The docs gain the canonical release flow.

**Tech Stack:** Bash, `gh`, git, `xcodebuild`, `mise exec -- xcodegen`.

**Spec:** `docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md`, which names the
canonical design: Muninn's
[`docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md`](https://github.com/michaelrigart/muninn/blob/main/docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md).

## Global Constraints

- **Source:** Muninn's branch `fix/release-via-pr` in `~/Code/Netronix/muninn-fix-release-via-pr`,
  at the commit that passed Codex's pre-merge review there (receipt `xr-1794908533-fc04b075`,
  Muninn's suite 475/475): `ee810a9aa04404599715aac48158e2a2d20f5059`. The port was first made
  from `092d5f8d2d083a789b2f5545543febbd68b14878` (receipt `xr-1794905228-ba53f276`); the newer
  commit changed only the test's isolation and one README sentence. Every `<SOURCE>` in the tasks
  means this commit. If Muninn's session sends a newer commit, the pin changes in a plan commit
  and the difference is ported.
- The rename is exactly this `sed`, in this order, applied to both files:
  `sed -e 's/muninn/linger/g' -e 's/Muninn/Linger/g' -e 's/Linger records calls/Linger keeps your Mac active/g'`.
  If the source test no longer contains "Muninn records calls", stop and report: the spec names
  that text.
- Left out: Muninn's `zap_is_settings_only` function and every case that calls it (the four "a:"
  cases), with the fixture files only they use. Nothing else in the test or script differs.
- `scripts/changelog.py`, `scripts/tests/test_changelog.py`, `scripts/verify-app` and
  `scripts/linger.rb.template` do not change (spec, recon at Muninn `56c3e8b`).
- No `CHANGELOG.md` entry.
- Every script run that builds goes outside the agent sandbox, with
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, and needs the signing certificate.
- `scripts/release` itself runs only as `--dry-run`. A real release is Michael's.
- Cross-repository (canonical design, "Ports", as amended at Muninn `a539742`): the five pull
  requests (Muninn, Hulder, Linger, Tafl, Skald) are opened before any is merged; Muninn's merges
  first. This PR is opened and left as a draft; it is never merged here.

## Review Focus

1. **A Muninn name left behind** (a URL, bundle identifier, path or message): Task 1 Step 6 requires
   `rg -i muninn` over both files to print nothing.
2. **A shared-script call Linger lacks** (a helper or a `changelog.py` subcommand added on Muninn's
   branch): Task 1 Step 2 diffs every other file the source commit changed under `scripts/` and
   checks every path the ported script calls.
3. **The maintainer's real `gh` cannot merge**: in an agent shell `gh` uses `GH_TOKEN` with no
   readable scopes, which the new check refuses. Task 3 Step 3 runs the dry run and expects the
   note, not a refusal; the report tells Michael to check `gh auth status` in his release shell.
4. **Linger's real cask in the tap**: the downgrade guard reads `  version "<v>"` with two spaces;
   `scripts/linger.rb.template` writes exactly that. Task 1's test covers it through the stub tap.
5. **A dry run of a new release with an empty `## [Unreleased]`** refuses "nothing to release"; the
   real changelog's is empty today, so Task 3 Step 3 runs it in a scratch clone with an entry.

---

### Task 1: Port the release script and its test

**Depends on:** none (needs the pinned **Source**)

**Files:**
- Modify: `scripts/release` (replaced by the renamed source)
- Modify: `scripts/tests/test-release-dry-run` (replaced by the renamed source, zap cases removed)

**Interfaces:**
- Consumes: Muninn's `scripts/release` and `scripts/tests/test-release-dry-run` at **Source**.
- Produces: the ported script's usage, `scripts/release [--dry-run] [--version <YYYYMMDD-HHMM>]`,
  unchanged; Task 2 documents it.

- [ ] **Step 1: Check the source is the pinned, reviewed commit**

Run: `git -C ~/Code/Netronix/muninn-fix-release-via-pr cat-file -e <SOURCE>^{commit}`
Expected: exit 0.

- [ ] **Step 2: Check what else the source changed under `scripts/`**

Run: `git -C ~/Code/Netronix/muninn-fix-release-via-pr diff --stat 56c3e8b <SOURCE> -- scripts`
Expected: only `scripts/release` and `scripts/tests/test-release-dry-run`. Any other file is a
helper the shared script needs: stop and report it, with the diff, so the plan can name it.

- [ ] **Step 3: Port the test first**

Write `scripts/tests/test-release-dry-run` from
`git -C ~/Code/Netronix/muninn-fix-release-via-pr show <SOURCE>:scripts/tests/test-release-dry-run`
(never the checkout's working tree, which may have moved on) through the Global Constraints
`sed`, then delete `zap_is_settings_only` and every line that exists only for its four "a:" cases.
Keep the file executable.

- [ ] **Step 4: Run it against Linger's old script to see it fail**

Run (outside the sandbox): `scripts/tests/test-release-dry-run`
Expected: exits non-zero, with failures in the pull-request cases (no `gh pr` calls), the
incomplete-asset case (d2) and the downgrade guard (c3). Record the failing case count in the
task report.

- [ ] **Step 5: Port the script**

Write `scripts/release` from
`git -C ~/Code/Netronix/muninn-fix-release-via-pr show <SOURCE>:scripts/release` through the same
`sed`. Keep it executable.

- [ ] **Step 6: Check the port is the source, renamed**

Run, with each source file taken by `git show <SOURCE>:<path>` as in Steps 3 and 5 and passed
through the same `sed` into `$TMPDIR`:
`diff "$TMPDIR/release" scripts/release` and `diff "$TMPDIR/test-release-dry-run" scripts/tests/test-release-dry-run`,
then `rg -i muninn scripts/release scripts/tests/test-release-dry-run`.
Expected: the script diff is empty; the test diff is only deleted lines, all of them the zap
function and its cases; `rg` prints nothing.

- [ ] **Step 7: Run the test to see it pass**

Run (outside the sandbox): `scripts/tests/test-release-dry-run`
Expected: exit 0, every case passing; record passed/total.

- [ ] **Step 8: Commit**

```bash
git add scripts/release scripts/tests/test-release-dry-run
git commit -m "Release through a pull request, as Muninn's script does"
```

The body names the source commit.

### Task 2: Document the release flow

**Depends on:** Task 1

**Files:**
- Modify: `README.md` ("Releasing", lines 90-93)
- Modify: `AGENTS.md` (line 3, "Design and behaviour"; the Release line, 32-)
- Modify: `docs/superpowers/specs/2026-11-01-linger-distribution-design.md` (header)

**Interfaces:**
- Consumes: Muninn's wording at `<SOURCE>` (`git -C ~/Code/Netronix/muninn-fix-release-via-pr diff 56c3e8b <SOURCE> -- README.md AGENTS.md docs/superpowers/specs/2026-11-03-muninn-distribution-design.md`),
  names mapped. The text below is that wording fitted to Linger's files; use it as written.

- [ ] **Step 1: README, "Releasing"**

The section becomes (the last sentence is Linger's own and stays):

```markdown
The maintainer cuts a release with `scripts/release`. It needs the signing certificate, so
it runs on the maintainer's Mac, not in CI. It sets the version (the time it starts,
`YYYYMMDD-HHMM`) and moves the `Unreleased` entries of `CHANGELOG.md` into that version, in a
commit on `release/<version>`. It opens a pull request for that commit, checks that it changes
only `CHANGELOG.md` and merges it as admin. Then it builds, signs, runs `scripts/verify-app` and
packages `Linger-<version>.zip`; only then does it tag the release commit, publish the GitHub
release and update the cask. It never pushes `main`. A finished release returns to `main`, level
with origin, and deletes `release/<version>` locally and on origin; if it cannot, it says what is
left and how to finish. `gh` must use a login with the `repo` (or `public_repo`) scope on an
admin account; the script refuses to start otherwise. A run that fails part way leaves you on the
release branch, and `scripts/release --version <version>` resumes it. `scripts/release --dry-run`
creates nothing: no branch, commit, pull request, tag or release. It builds, verifies and
packages, and prints the changelog section. `CHANGELOG.md` lists what each release changed.
```

- [ ] **Step 2: `AGENTS.md`**

- After line 3 ("Design and behaviour: …"), add the line
  ``Release flow: `docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md`.``
- In the Release line, "since it pushes to `main`, tags, creates a GitHub release and pushes to
  the Homebrew tap." becomes "since it pushes a release branch and merges its pull request (never
  `main`), tags, creates a GitHub release and pushes to the Homebrew tap. It needs a `gh` login
  that can merge as admin." "it commits and pushes nothing" becomes "it creates nothing: no
  branch, commit, pull request, tag or release".

- [ ] **Step 3: Distribution spec pointer**

Under the header's Status line, add:

```markdown
**Release flow:** superseded in part on 2026-11-16 by
docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md (the release commit lands
through a pull request).
```

No other text changes.

- [ ] **Step 4: Check and commit**

Run: `git diff --stat` — expected: the three files only.

```bash
git add README.md AGENTS.md docs/superpowers/specs/2026-11-01-linger-distribution-design.md
git commit -m "Document releasing through a pull request"
```

### Task 3: Verify the branch

**Depends on:** Task 2

No code. Every command runs outside the sandbox. Report passed/total for each.

- [ ] **Step 1: Unchanged suites**

Run: `swift test --package-path Packages/LingerCore`,
`/usr/bin/python3 -m unittest discover -s scripts/tests -p 'test_*.py'`.
Expected: all pass.

- [ ] **Step 2: Release build and its checks**

Run the Release build from `AGENTS.md` (signed, default version), then
`scripts/tests/test-verify-app build/dd.noindex/Build/Products/Release/Linger.app` and
`scripts/tests/test-release-dry-run`.
Expected: both exit 0.

- [ ] **Step 3: A real dry run creates nothing**

In a scratch clone `$TMPDIR/linger-dry-run` of this branch, with `origin` set to
`git@github.com:michaelrigart/linger.git` and `mise trust` run in it, commit one `### Fixed`
entry under `## [Unreleased]`, then run `scripts/release --dry-run`.
Expected: exit 0; a note that `gh`'s token cannot merge, not a refusal (an agent shell's
`GH_TOKEN` has no scopes `gh` can read); last line
"Dry run: nothing committed, branched, pushed, merged, tagged or published."; afterwards
`git ls-remote origin 'refs/heads/release/*'` prints nothing, `gh pr list --repo michaelrigart/linger --state all --head release/<version>`
prints nothing, and the clone's HEAD and branch are unchanged. The clone's removal goes in the
final report as a command.

## Finishing

Push `fix/release-via-pr`, open a draft pull request into `main` (the `merge-request` skill), set
the spec's and this plan's Status to `In progress` with its reference, and run Codex's pre-merge
review. CI must pass on the pull request (spec acceptance 4).
