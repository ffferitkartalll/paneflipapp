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

## Changes: issue, branch, pull request

Every change to the repository goes through this flow.

1. **Issue first.** Open a GitHub issue assigned to the owner, with the matching label: `bug` for a defect,
   `enhancement` for a feature, `documentation` for docs and rules. Use neutral wording (see Commits).
2. **Branch `issue-<number>`**, created from `main` (`git switch -c issue-<number> main`). One issue, one branch,
   one pull request; a change to these rules gets its own issue.
   Exception: one pull request may close several issues when their changes cannot be separated without a state
   that does not build or does not pass the tests. The branch is named after the first issue, the description has
   one `Closes #<number>` line per issue and says why they travel together.
3. **Pull request** from the branch to `main`. Its description contains `Closes #<number>`, which links it under
   the issue's Development section and closes the issue on merge. The Tests workflow must be green.
4. Commit and push only when the owner asks, and show the commit message first.
5. Explore the code with Graphify (the repository is indexed) and keep the change small with Ponytail.
