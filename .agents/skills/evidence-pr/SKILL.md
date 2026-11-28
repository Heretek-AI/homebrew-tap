---
name: evidence-pr
description: Prepare and verify an evidence-backed pull request following Heretek-AI conventions. Use whenever staging changes, running pre-PR verification, writing a pull request body, or checking CI status after a push.
license: MIT
compatibility: opencode claude codex copilot
metadata:
  audience: maintainers-and-agents
  workflow: github-pr
  opencode/slash: "true"
---

# Evidence-Backed Pull Request Workflow

Every pull request in a `Heretek-AI` repository must prove its claims with executed command output and explicitly state what was not run.

## When to Use

- Preparing a branch to open or update a pull request
- Writing or updating a pull request description
- Verifying that a push passes all required status checks

## Steps

1. **Work on a topic branch.** Confirm you are not on `main`:

   ```bash
   git branch --show-current
   ```

2. **Stage explicit repo-relative paths.** Never run `git add .` or `git add -A`. Verify staged files contain no machine-local paths or untracked scratch files:

   ```bash
   git status --short
   git diff --cached --stat
   ```

   Scan the staged blobs using the repository's no-local-paths pattern (not just the working files):

   ```bash
   PATTERN='file:///(home|Users|root)/|/(home|Users)/[^/[:space:]"'"'"'`<>]+/(Projects|Documents|Desktop|Downloads|\.gemini|\.claude|\.codex|\.cursor)(/|[^A-Za-z0-9_-]|$)'
   if git grep --cached -nIE "$PATTERN" -- .; then
     echo "ERROR: Machine-local paths found in staged content." >&2
     exit 1
   else
     scan_status=$?
     [ "$scan_status" -eq 1 ] || exit "$scan_status"
   fi
   ```

   Resolve any matches or scan errors before claiming the no-local-paths invariant is verified.

3. **Run local pre-commit and test gates.** Execute Lefthook and the repository's canonical test command, capturing the exact output:

   ```bash
   lefthook run pre-commit
   ```

4. **Draft the PR body using executed evidence.** Populate all three required sections from `.github/pull_request_template.md`:
   - `## What and why`: Concise summary of the behavior change and motivation.
   - `## Evidence`: Exact commands executed and their trimmed verbatim stdout/stderr. Explicitly list any check or integration that was **not** run and why.
   - `## Linked issues`: Closing or tracking references (`Closes #123` or `Part of Heretek-AI/<repo>#45`).

5. **Sign off commits and verify CI after push.** Organization governance requires commit sign-off (`git commit --signoff`). After pushing, inspect every triggered workflow run:

   ```bash
   gh pr checks --watch
   ```

## Gotchas

- Never claim a test passed without executing it in the current working tree.
- Never reference another repository by local filesystem path (`../other-repo` or `/Users/...`); always use `Heretek-AI/<repo>`.
- Merging to `main` and cutting releases are human maintainer actions unless explicitly delegated.
