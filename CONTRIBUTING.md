# Contributing

This tap packages accelerator-focused inference runtimes. Changes land through pull requests and must keep the pinned formula set reproducible, bottleable, and auditable.

## Branch and pull-request flow

1. Start from the latest `main` and create a short, descriptive branch, for example `formula/gufo-0.9.1` or `docs/service-ports`.
2. Keep one logical change per pull request. Formula version bumps include the formula and the matching [`.github/upstream-pins.json`](.github/upstream-pins.json) entry in the same commit.
3. Do not push directly to `main`. Bottles are published to GHCR from green pull requests: the `brew auto-publish` workflow dispatches `brew pr-pull` for same-repository PRs labelled `autobump`, while human PRs are published by a maintainer.
4. Open the pull request with the repository template and complete every applicable verification item. A passing pull request must be green in `Lint and Test` (`lint-and-test.yml`) and every applicable independent bottle builder (`build-hosted.yml`, `build-cuda.yml`, `build-rocm.yml`) before review.
5. Publish with the `publish` workflow (`brew pr-pull`) or locally with `brew pr-pull --workflows=build-hosted.yml,build-cuda.yml,build-rocm.yml --tap=heretek-ai/tap --head-sha=<reviewed-head-sha> <pr-number>`. The `--head-sha` pin prevents publishing a moving branch. You can also trigger a single-formula build via `build-formula.yml` or bootstrap unbottled formulae via `backfill-bottles.yml`.

Do not commit local scratch clones, review checkouts, or nested repositories. Every entry must be a regular file or directory in this repository, never a gitlink (mode `160000`).

## Publishing backfilled bottles

`backfill-bottles.yml` only dispatches ordinary `workflow_dispatch` builds. Those builds upload bottle artifacts, but no `brew pr-pull` run ever consumes them, so the artifacts are not published automatically.

1. Dispatch **Backfill Bottles** with a group (`runtimes`, `hosted`, `cuda`, `rocm`) and a batch size, then wait for the dispatched `Build Hosted Bottles` / `Build CUDA Bottles` / `Build ROCm Bottles` runs to finish. The backfill run itself does not upload bottles.
2. Copy the run ID of a completed builder run from its Actions URL (`.../actions/runs/<run_id>`). Repeat the next step for every builder run that produced bottles.
3. Dispatch **Publish Backfilled Bottles** (`publish-bottles.yml`) with that `run_id`. `root_url` defaults to `https://ghcr.io/v2/heretek-ai/tap`; leave it unchanged for this tap.
4. Review the pull request labelled `bottle-bootstrap`. It contains only the `bottle do` blocks and manifest digests written by `brew pr-upload`; the archives are already in GHCR. Merge it manually once checks pass.

This is the only path that persists bottle artifacts from `workflow_dispatch` builds. The PR is not labelled `autobump`, so `brew auto-publish` does not dispatch `brew pr-pull` for it. If the App variables are unset, the workflow falls back to `GITHUB_TOKEN`, which cannot trigger pull-request workflows for the PR it opens; configure `APP_ID` and `APP_PRIVATE_KEY` or re-run checks manually.

## Formula conventions

- **Bottleable defaults.** The default install path must be non-interactive and reproducible so `brew test-bot` can build a bottle. Prefer the pinned upstream prebuilt archive where one exists; use a source build only for a documented target gap (for example `basalt` on arm64), and pin every source URL with a `sha256`.
- **No new options unless necessary.** Every option expands the build/test matrix and the set of artifacts users can install. Use the upstream default when it is usable, and document any option in the formula, the README option map, and the ledger variant policy.
- **Keg-only runtimes and collision avoidance.** Runtime libraries, private Python virtualenvs, kernel packs, and support binaries belong under `libexec` or a versioned formula prefix. Do not link generic command names (`llama-server`, `daemon`, `python`, and similar) into `PATH`; install the tap-specific wrapper name instead. Declare conflicting runtimes keg-only where Homebrew requires it.
- **Unique service ports.** Every `service do` block must bind loopback and use a port from [`scripts/port_registry.json`](scripts/port_registry.json). Add or change the registry entry, the formula service block, the formula caveats, and the generated README table together. The tap reserves `18000-18099`; `shimmy` keeps `11434` and `hyperqwen` keeps `18020`. If an upstream binary exposes no host or port control, keep the documented command, record the limitation in the registry notes, and do not invent flags.
- **Caveats and log paths.** Put service logs under `var/log/<formula>.log`, document required external runtimes and one-time setup in `caveats`, and keep the caveat text aligned with the README. Do not hide a required manual step in a service block.
- **Ledger and README stay in sync.** A formula change that alters the pinned revision, options, commands, or service behavior must update the README and the matching `.github/upstream-pins.json` entry in the same pull request.
- **Do not edit `.github/workflows/ocr.yml`.** That workflow is intentionally managed outside formula and documentation changes.

## Local verification

Run these before opening a pull request, from the repository root:

```bash
brew style Formula/ Casks/ cmd/
brew audit --strict --tap=heretek-ai/tap
brew audit --cask --strict --tap=heretek-ai/tap
python3 scripts/generate_readme.py --check
./scripts/test_local_tap.sh
python3 -m unittest discover -s tests/ -v
pytest tests/ -q
```

`./scripts/test_local_tap.sh` syncs only tracked tap paths (including `cmd/` and `Brewfiles/`) into Homebrew's tap directory, runs `brew style` on formulae, casks, and commands, runs the strict audits, verifies the generated README, and executes both Python suites. It never copies or deletes untracked workspace directories.

## YAML, actionlint, and shellcheck

Workflow and action changes must be valid YAML and must pass `actionlint` before review:

```bash
actionlint .github/workflows/*.yml
```

Shell scripts under `.github/scripts/` and `scripts/test_local_tap.sh` must pass ShellCheck with no new findings:

```bash
shellcheck .github/scripts/*.sh scripts/test_local_tap.sh
```

Keep workflow permissions minimal, pin every third-party action to a full commit SHA with a version comment, and do not add secrets to pull-request workflows.

## Self-hosted runner security

Never run untrusted fork code on self-hosted hardware. The self-hosted runners in this repository have access to maintainer machines and must be limited to trusted branches, maintainer-authored pull requests, or explicitly approved runs. Do not use `pull_request_target` to check out and execute code from an untrusted fork, do not expose secrets to self-hosted jobs triggered by forks, and do not add a self-hosted runner label to a workflow that can be reached by an external contributor without maintainer approval. Use GitHub-hosted runners for untrusted pull-request validation.

The ROCm `stx-halo` job is additionally gated by the repository variable `STX_HALO_ENABLED=true` and the protected GitHub environment `stx-halo`. A required reviewer must approve the deployment before any job step runs on the physical machine. Leave the variable unset while the runner is offline; the job is skipped instead of remaining queued.

## Reporting problems

Open an issue with the formula or cask name, the exact `brew` command, the output of `brew config`, and whether the failure is at install, test, or service start. Include the relevant log from `$(brew --prefix)/var/log/` for service failures.
