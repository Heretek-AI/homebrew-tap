---
name: hygiene-and-workflow-audit
description: Audit tracked files and GitHub Actions workflows for machine-local path leaks, unpinned actions, template injection, excessive permissions, and invalid SKILL.md frontmatter. Use when editing .github/workflows, adding skills, or debugging hygiene CI failures.
license: MIT
compatibility: opencode claude codex copilot
metadata:
  audience: maintainers-and-agents
  workflow: security-hygiene
  opencode/slash: "true"
---

# Hygiene and Workflow Security Audit

Enforces `Heretek-AI` repository hygiene and GitHub Actions supply-chain hardening locally before changes reach CI.

## When to Use

- Creating or modifying `.github/workflows/*.yml`
- Creating or updating `.agents/skills/*/SKILL.md`
- Diagnosing a failure in the `hygiene / No machine-local paths` status check
- Preparing a repository for zero-bypass ruleset enforcement

## Steps

1. **Scan tracked files for machine-local paths.** Run the exact regex enforced by `Heretek-AI/.github/.github/workflows/hygiene.yml`:

   ```bash
   PATTERN='file:///(home|Users|root)/|/(home|Users)/[^/[:space:]"'"'"'`<>]+/(Projects|Documents|Desktop|Downloads|\.gemini|\.claude|\.codex|\.cursor)(/|[^A-Za-z0-9_-]|$)'
   ! git grep -nIE "$PATTERN" -- .
   ```

2. **Enforce GitHub Actions security invariants.** Every workflow under `.github/workflows/` must satisfy:
   - Top-level `permissions: contents: read` (or `permissions: {}` with job-level least-privilege grants).
   - Every third-party or official `uses:` step pinned to a full 40-character commit SHA with a `# vX.Y.Z` version comment.
   - `persist-credentials: false` on every `actions/checkout` step unless the job explicitly pushes git changes.
   - No untrusted context (`github.event.pull_request.title`, `github.event.issue.body`, `github.event.comment.body`, `github.head_ref`) interpolated directly inside `run:` blocks; always bind untrusted values to `env:` variables first.

3. **Run static workflow analyzers (`actionlint` and `zizmor`).**

   ```bash
   actionlint
   uvx zizmor@1.30.1 --format=plain .
   ```

4. **Validate Agent Skills (`SKILL.md`).** In `Heretek-AI/.github` only, validate the canonical `skills/` directory:

   ```bash
   bash scripts/validate-skills.sh
   ```

   In downstream repositories, use their documented skill validation command when available. Fleet sync copies skills into `.agents/skills/` but does not install `scripts/validate-skills.sh`; do not assume that command exists there.

## Gotchas

- `actionlint` skips input validation on SHA-pinned actions; verify action input names against upstream `action.yml` when pinning.
- Never add `pull_request_target` workflows that check out or execute untrusted PR head code.
