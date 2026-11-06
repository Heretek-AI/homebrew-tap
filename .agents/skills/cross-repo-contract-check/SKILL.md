---
name: cross-repo-contract-check
description: Verify protocol contracts and version pins across Heretek-AI agent-tooling repositories without sharing runtime source code. Use when updating MCP gateway contracts, OpenCode v2 plugin APIs, or vendored golden fixtures.
license: MIT
compatibility: opencode claude codex copilot
metadata:
  audience: maintainers-and-agents
  workflow: cross-repo
  opencode/slash: "true"
---

# Cross-Repository Contract Verification

Per `Heretek-AI/.github` ADR 0001, repositories in the agent-tooling family (`IUMBTEMS`, `claude-4-opencode`, `scraper-swarm`, `opencode-4-openclaude`, `GDevelop-Unlocked`) never import each other's source code and integrate strictly over versioned protocols and golden fixtures.

## When to Use

- Modifying `/mcp` request/response schemas or `contract/v1/fixtures/` in `Heretek-AI/scraper-swarm`
- Updating the vendored `scraper-swarm` client in `Heretek-AI/IUMBTEMS`
- Bumping `@opencode/plugin` v2 across `Heretek-AI/IUMBTEMS` or `Heretek-AI/claude-4-opencode`

## Steps

1. **Check the governing boundary in `AGENTS.md`.** Confirm that no relative cross-repo filesystem imports or unpublished workspace links are introduced.
2. **Validate golden fixtures against real schemas.**
   - When working in the producer (`Heretek-AI/scraper-swarm`), regenerate or validate `contract/v1/fixtures/` and record the producer commit SHA.
   - When working in the consumer (`Heretek-AI/IUMBTEMS`), vendor the exact fixture files at the recorded commit SHA and run the consumer contract test suite against them.
3. **Apply lockstep or independent release rules.**
   - `IUMBTEMS` packages (`@heretek-ai/epistemic-swarm`, `es-core`, `es-cli`) release in lockstep at identical version numbers.
   - `@opencode/plugin` v2 pins move independently per repository (`package.json` is the source of truth).
4. **Label cross-repo pull requests.** Apply the `cross-repo` label. Reference companion issues and pull requests as `Heretek-AI/<repo>#<number>`. Record commits with the repository name and full commit SHA, as `Heretek-AI/<repo>@<full-commit-sha>`.

## Gotchas

- Breaking changes to an existing contract path (`contract/v1/`) are forbidden; introduce a new contract version directory (`contract/v2/`) and open a tracking issue on the consumer repository.
