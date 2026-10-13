# PaneFlip repository

One repository, one folder per platform. All current work is in `macos/`.

- Platform code stays inside its platform folder; never share source files between platforms.
- The macOS rules are mandatory for anything under `macos/`:

@macos/CLAUDE.md

## Commits

- Never add a `Co-Authored-By` line, a "Generated with" line or any other AI attribution to a commit message,
  pull request description or file header.
- Commit or push only when the owner asks for it.
- Do not put the names of other applications (the owner's other apps, apps studied for reference, apps used
  as examples) in code, comments, tests, docs or commit messages. Use neutral names.
  The one exception is data: `macos/Sources/PaneFlip/Resources/AppGlyphs.json` maps bundle identifiers to glyphs.

## Changes: edit on main, test, owner tests, issue, branch, pull request

Every change to the repository (a bug, an enhancement, documentation: no difference) goes through this flow.

1. **Edit on `main`, locally.** Make the change in the working tree of `main`. Never commit on `main`.
2. **Test it.** Run the tests that fit the change on this machine: `swift test` (`PaneFlipCoreTests`) and
   `xcodebuild … test` (`PaneFlipTests`).
3. **The owner tests it** on their own machine. Nothing is opened, committed, pushed or merged before the owner
   has tested the change and said it is fine.
4. **Issues, once the owner's test is clean.** Open one issue, or several when the requested changes are
   separate. Each is assigned to the owner and has every label that fits: `bug` for a defect, `enhancement` for a
   feature, `documentation` for docs and rules (several when it is more than one, for example `enhancement` and
   `documentation`). Use neutral wording (see Commits).
5. **Branch, commit, pull request.** Move the changes, still uncommitted, to a new branch from `main`:
   `issue-<number>` for one issue, `issue-<number1>-<number2>-<number3>` for several
   (`git switch -c …`). Commit (the owner has seen the message first), push and open the pull request to `main`
   with the same assignee and labels as its issue(s). Its description has one `Closes #<number>` line per issue,
   which links it under each issue's Development section and closes them on merge; with several issues it also
   says why they travel together.
6. **CI and merge.** The owner watches the Tests workflow and says when it is done; only then the pull request is
   merged (`gh pr merge <number> --squash --delete-branch`). Before merging, check that the branch is not behind
   `main` (`gh pr view <number> --json mergeStateStatus`; `BEHIND` means: update the branch and wait for the Tests
   workflow again). Branch protection is not available for this private repository on the current plan, so this
   check is done by hand.

Alongside: explore the code with Graphify (the repository is indexed), keep the change small with Ponytail, and
check it with the Ponytail audit before reporting it as done. Commit and push only when the owner asks. A change to
these rules goes through the same flow with its own issue.
