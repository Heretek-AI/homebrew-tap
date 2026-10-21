---
name: adversarial-claim-check
description: Stress-test repository claims, version pins, packaging artifacts, and security invariants in a disposable git worktree before release or audit sign-off. Use when cutting a release, auditing shipped work, or proving an [S] invariant is guarded by tests.
license: MIT
compatibility: opencode claude codex copilot
metadata:
  audience: maintainers-and-agents
  workflow: audit-verification
  opencode/slash: "true"
---

# Adversarial Claim & Release Verification

Proves that a repository's claims, dependency pins, and security invariants hold against real tools and sabotage testing in an isolated worktree without dirtying the working checkout.

## When to Use

- Verifying a repository before cutting a tagged release or publishing to npm/GHCR
- Auditing an issue labeled `audit` or `security`
- Confirming that a new test genuinely catches a broken invariant (sabotage check)

## Steps

1. **Create an isolated disposable worktree.** Never mutate the primary checkout for destructive or sabotage experiments:

   ```bash
   AUDIT_TMP="$(mktemp -d -t heretek-check-XXXXXX)"
   trap 'git worktree remove --force "$AUDIT_TMP/wt" || :; rm -rf "$AUDIT_TMP"' EXIT
   git worktree add --detach "$AUDIT_TMP/wt" HEAD
   ```

2. **Verify package & lockfile truth.**
   - **Bun / Node**: Run `npm pack --dry-run` (or `bun pm pack --dry-run`) inside `"$AUDIT_TMP/wt"` and confirm every entry point (`main`, `exports`, `bin`, `files`) resolves to a built file that exists.
   - **Python (`uv`)**: Run `uv lock --check` and confirm `[tool.uv] exclude-newer = "7 days"` is respected.
   - **GitHub Actions (remote actions)**: Confirm each remote action `uses: owner/repo[/path]@ref` is pinned to a full 40-character commit SHA. Exclude local action paths (`./.github/actions/...`) and Docker references (`docker://...`) from this SHA check.
   - **GitHub Actions (reusable workflows)**: Separately confirm each remote workflow `uses: owner/repo/.github/workflows/file.yml@ref` is pinned to a full 40-character commit SHA. Exclude local workflow paths (`./.github/workflows/...`).

3. **Sabotage critical invariants.** For each security or correctness invariant changed in the PR:
   - Introduce a 1-line break in `"$AUDIT_TMP/wt"`.
   - Run the test suite in `"$AUDIT_TMP/wt"` and confirm it exits non-zero.
   - Restore the file with `git -C "$AUDIT_TMP/wt" checkout -- .`.

4. **Confirm clean working tree.** Verify `git status --porcelain` on the main checkout is empty after cleanup.

## Gotchas

- A test that passes when the production guard is commented out is a lie; fix the test before merging.
