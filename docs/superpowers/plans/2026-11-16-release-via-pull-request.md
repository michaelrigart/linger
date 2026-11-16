# Releasing through a pull request (Linger port) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: run this plan with the `plan-run` skill. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Status:** Approved

**Goal:** Linger's `scripts/release` cuts a release through a pull request, with the script and its
test taken whole from Muninn's implementation, renamed.

**Architecture:** No design of its own. Muninn's reviewed `scripts/release` and
`scripts/tests/test-release-dry-run` are copied over, renamed by a fixed substitution, and the zap
cases are removed from the test. The docs gain the canonical release flow.

**Tech Stack:** Bash, `gh`, git, `xcodebuild`, `mise exec -- xcodegen`.

**Spec:** `docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md`, which names the
canonical design: Muninn's
[`docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md`](https://github.com/michaelrigart/muninn/blob/main/docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md).

**Source:** Muninn's branch `fix/release-via-pr` in `~/Code/Netronix/muninn-fix-release-via-pr`,
at the commit `muninn-fix-release-via-pr-71` reports as having passed Codex's pre-merge review:
`<SOURCE>`. Execution does not start until this line names that commit; the pin lands in its own
plan commit.

## Global Constraints

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

Write `scripts/tests/test-release-dry-run` from the source's file through the Global Constraints
`sed`, then delete `zap_is_settings_only` and every line that exists only for its four "a:" cases.
Keep the file executable.

- [ ] **Step 4: Run it against Linger's old script to see it fail**

Run (outside the sandbox): `scripts/tests/test-release-dry-run`
Expected: exits non-zero, with failures in the pull-request cases (no `gh pr` calls), the
incomplete-asset case (d2) and the downgrade guard (c3). Record the failing case count in the
task report.

- [ ] **Step 5: Port the script**

Write `scripts/release` from the source's file through the same `sed`. Keep it executable.

- [ ] **Step 6: Check the port is the source, renamed**

Run, with `$SRC` the source checkout at `<SOURCE>` and each source file passed through the same
`sed` into `$TMPDIR`:
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
- Consumes: Task 1's script behaviour, as the canonical design's "Design" describes it.

- [ ] **Step 1: README, "Releasing"**

Keep the two existing sentences and add, in the README's register: the release commit goes on
`release/<version>` and through a pull request that the script opens, checks and merges as admin;
`gh` must use a login with the `repo` scope of an admin account (`gh auth login`, with `GH_TOKEN`
unset); a failed run says where it stopped, and `scripts/release --version <version>` resumes it.

- [ ] **Step 2: `AGENTS.md`**

- Line 3 gains: `Release flow: docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md.`
- The Release line's "since it pushes to `main`, tags," becomes "since it pushes a release
  branch, merges its pull request as admin, tags,". "it commits and pushes nothing" becomes "it
  commits, branches, pushes and merges nothing". "with a stub `gh`" becomes "with a stub `gh`
  that keeps their pull requests".

- [ ] **Step 3: Distribution spec pointer**

Under the header's Status line, add one line: the release flow is now governed by
`docs/superpowers/specs/2026-11-16-release-via-pull-request-design.md` and the canonical design it
names (forge link). No other text changes.

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
Expected: exit 0; a note that the token cannot merge (Review Focus 3); last line
"Dry run: nothing committed, branched, pushed, merged, tagged or published."; afterwards
`git ls-remote origin 'refs/heads/release/*'` prints nothing, `gh pr list --repo michaelrigart/linger --state all --head release/<version>`
prints nothing, and the clone's HEAD and branch are unchanged. The clone's removal goes in the
final report as a command.

## Finishing

Push `fix/release-via-pr`, open a draft pull request into `main` (the `merge-request` skill), set
the spec's and this plan's Status to `In progress` with its reference, and run Codex's pre-merge
review. CI must pass on the pull request (spec acceptance 4).
