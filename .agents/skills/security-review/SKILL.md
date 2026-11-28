---
name: security-review
description: Perform a structured, evidence-grounded security review (threat model, attack surface mapping, vulnerability verification, and minimal safe patch) on a repository or pull request. Use when auditing auth, parsing, subprocess/shell execution, deserialization, secrets, or CI/supply-chain boundaries.
license: MIT
compatibility: opencode claude codex copilot
metadata:
  audience: maintainers-and-agents
  workflow: security-review
  opencode/slash: "true"
---

# Structured Security Review

Conducts a disciplined, evidence-backed security review modeled on a threat-model-first methodology (scope -> attack surface -> sink/source tracing -> verification -> minimal fix). Never report speculative findings without exact file paths, line numbers, and a concrete exploit precondition.

## When to Use

- Auditing a pull request that touches authentication, authorization, cryptography, secrets, file I/O, network boundaries, subprocesses, or untrusted input parsing
- Running a periodic or pre-release security audit on a Tier 1 repository
- Triaging findings from `Trivy`, `secfoo`, `CodeQL`, or `zizmor`

## Steps

1. **Establish scope and trust boundaries.**
   - Identify the entry points that accept untrusted input (HTTP routes, CLI args, env vars, IPC, file uploads, GitHub Actions event payloads, webhooks).
   - Identify high-value assets (credentials, tokens, filesystem writes, subprocess execution, database queries, CI runner privileges).

2. **Run fast deterministic checks first (if available locally).**
   - Secrets & hygiene: `gitleaks protect --staged --redact --no-banner` (or `gitleaks detect --no-git`).
   - Dependencies & IaC: `trivy fs --scanners vuln,misconfig,secret --severity HIGH,CRITICAL .`
   - GitHub Actions: `actionlint` and `uvx zizmor@1.30.1 --format=plain .`

3. **Trace untrusted sources to dangerous sinks.**
   Check each changed or targeted component for:
   - **Injection:** shell/command (`exec`, `spawn`, `subprocess`, `eval`, template injection in GitHub Actions `run:` blocks), SQL, path traversal (`../`), SSRF, regex DoS.
   - **AuthN/AuthZ:** missing permission checks, IDOR, default-allow fallbacks, weak token comparison, overly broad `GITHUB_TOKEN` permissions.
   - **Secrets & data exposure:** hardcoded keys, secrets logged to stdout/stderr, unredacted error traces, `persist-credentials: true` on untrusted checkouts.
   - **Supply chain & deserialization:** unpinned third-party actions or downloads, unsafe YAML/pickle/JSON deserialization, prototype pollution.

4. **Verify before reporting.**
   - Confirm the code path is actually reachable from an untrusted source (no dead code or test-only fixtures).
   - Document the exact file, symbol, line range, precondition, impact, and severity (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`).
   - Never run destructive exploits or execute untrusted payloads outside an isolated sandbox.

5. **Propose or apply minimal, testable fixes.**
   - Prefer structural fixes (parameterized queries, allowlists, `env:` binding, least-privilege scopes, SHA pinning) over ad-hoc regex sanitization.
   - Add or update a regression test that fails before the fix and passes after it.

## Output Format

For each verified finding, report:

- **Severity & Title:** `[HIGH] Command injection in <file>:<line>`
- **Evidence:** Exact file path, line range, and source-to-sink trace
- **Impact & Precondition:** Who can trigger it and what they gain
- **Fix:** Concrete patch or remediation step + verification test
