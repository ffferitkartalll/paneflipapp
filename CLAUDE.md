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

## Changes: edit on main, test, issue, branch, pull request

Every change to the repository goes through this flow.

1. **Edit on `main`, locally.** Make the change in the working tree of `main` and build and test it on this
   machine (`swift test`, `xcodebuild … test`). Never commit on `main`.
2. **Issue, once everything passes.** Open a GitHub issue assigned to the owner, with every label that fits:
   `bug` for a defect, `enhancement` for a feature, `documentation` for docs and rules (several when it is more
   than one, for example `enhancement` and `documentation`). Use neutral wording (see Commits).
3. **Branch `issue-<number>`**, created from `main` with the changes still uncommitted
   (`git switch -c issue-<number>`). One issue, one branch, one pull request; a change to these rules gets its
   own issue.
   Exception: one pull request may close several issues when their changes cannot be separated without a state
   that does not build or does not pass the tests. The branch is named after the first issue, the description has
   one `Closes #<number>` line per issue and says why they travel together.
4. **Pull request** from the branch to `main`, with the same assignee and labels as the issue. Its description
   contains `Closes #<number>`, which links it under the issue's Development section and closes the issue on
   merge. The Tests workflow must be green.
   Before merging, check that the branch is not behind `main` (`gh pr view <number> --json mergeStateStatus`;
   `BEHIND` means: update the branch and wait for the Tests workflow again). Branch protection is not available
   for this private repository on the current plan, so this check is done by hand.
5. Commit and push only when the owner asks, and show the commit message first.
6. Explore the code with Graphify (the repository is indexed), keep the change small with Ponytail, and check
   it with the Ponytail audit before reporting it as done.
