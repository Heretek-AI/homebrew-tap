"""Repository-wide consistency and metadata invariant tests."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
FORMULA_DIR = REPO_ROOT / "Formula"
PINS_PATH = REPO_ROOT / ".github" / "upstream-pins.json"
SPECS_PATH = REPO_ROOT / ".github" / "validation-specs.json"
PORTS_PATH = REPO_ROOT / "scripts" / "port_registry.json"
WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows"


def load_workflow(name: str) -> dict:
    return yaml.safe_load((WORKFLOWS_DIR / name).read_text(encoding="utf-8"))


class TestRepoConsistency(unittest.TestCase):
    def setUp(self) -> None:
        self.formulae = sorted(p.stem for p in FORMULA_DIR.glob("*.rb"))
        self.pins = json.loads(PINS_PATH.read_text(encoding="utf-8"))
        self.specs = json.loads(SPECS_PATH.read_text(encoding="utf-8"))
        self.ports = json.loads(PORTS_PATH.read_text(encoding="utf-8"))

    def test_every_formula_tracked_in_upstream_pins_and_validation_specs(self) -> None:
        pinned = sorted(self.pins.get("packages", {}).keys())
        specced = sorted(self.specs.get("formulas", {}).keys())
        self.assertEqual(
            pinned,
            self.formulae,
            "Formula/*.rb and .github/upstream-pins.json packages must match 1:1",
        )
        self.assertEqual(
            specced,
            self.formulae,
            "Formula/*.rb and .github/validation-specs.json formulas must match 1:1",
        )

    def test_service_ports_are_unique_and_registered(self) -> None:
        services = self.ports.get("services", {})
        seen_ports: dict[int, str] = {}
        for name, cfg in services.items():
            port = int(cfg["port"])
            self.assertNotIn(
                port,
                seen_ports,
                f"Port {port} duplicated between {seen_ports.get(port)} and {name}",
            )
            seen_ports[port] = name

        for name in self.formulae:
            source = (FORMULA_DIR / f"{name}.rb").read_text(encoding="utf-8")
            if re.search(r"^\s*service\s+do\b", source, re.MULTILINE):
                self.assertIn(
                    name,
                    services,
                    f"Formula/{name}.rb defines a service block but is missing from scripts/port_registry.json",
                )

    def test_toolchain_versions_match_dockerfiles_and_runtime_formulae(self) -> None:
        rocm_pin = self.pins["rocm"]["pinned_version"]
        rocm_sha = self.pins["rocm"]["pinned_sha256"]
        cuda_pin = self.pins["cuda"]["pinned_version"]

        rocm_df = (REPO_ROOT / "docker" / "brew-rocm" / "Dockerfile").read_text(
            encoding="utf-8"
        )
        cuda_df = (REPO_ROOT / "docker" / "brew-cuda" / "Dockerfile").read_text(
            encoding="utf-8"
        )
        rocm_rb = (FORMULA_DIR / "rocm-runtime.rb").read_text(encoding="utf-8")

        self.assertIn(f"ARG ROCM_VERSION={rocm_pin}", rocm_df)
        self.assertIn(f"ARG ROCM_SHA256={rocm_sha}", rocm_df)
        self.assertIn(f"nvidia/cuda:{cuda_pin}-devel-ubuntu24.04", cuda_df)
        self.assertIn(rocm_pin, rocm_rb)
        self.assertIn(rocm_sha, rocm_rb)

    def test_workflows_do_not_hardcode_toolchain_image_tags(self) -> None:
        for wf in (REPO_ROOT / ".github" / "workflows").glob("*.yml"):
            text = wf.read_text(encoding="utf-8")
            self.assertNotRegex(
                text,
                r"ghcr\.io/heretek-ai/brew-(?:rocm|cuda):[0-9]",
                f"{wf.name} should resolve toolchain tags from .github/upstream-pins.json",
            )

    def test_rocm_image_keeps_sdk_under_homebrew_prefix(self) -> None:
        dockerfile = (REPO_ROOT / "docker" / "brew-rocm" / "Dockerfile").read_text(
            encoding="utf-8"
        )
        self.assertIn("/home/linuxbrew/.linuxbrew/rocm-sdk", dockerfile)
        self.assertIn("ln -s /home/linuxbrew/.linuxbrew/rocm-sdk /opt/rocm", dockerfile)

    def test_rocm_builds_use_the_prefix_sdk_path(self) -> None:
        workflow = (WORKFLOWS_DIR / "build-rocm.yml").read_text(encoding="utf-8")
        self.assertIn(
            "ROCM_PATH: /home/linuxbrew/.linuxbrew/opt/rocm-sdk",
            workflow,
            "ROCm builds must use a sandbox-visible opt path, not /opt/rocm",
        )
        self.assertIn("Materialize ROCm SDK under Homebrew opt", workflow)
        self.assertIn("cp -al", workflow)
        self.assertNotIn("ROCM_PATH: /opt/rocm", workflow)

    def test_publish_workflow_serializes_pr_pull_runs(self) -> None:
        workflow = load_workflow("publish.yml")
        concurrency = workflow.get("concurrency")
        self.assertIsInstance(
            concurrency,
            dict,
            "publish.yml must define a workflow-level concurrency mapping",
        )
        self.assertEqual(concurrency["group"], "brew-pr-pull")
        self.assertIs(concurrency["cancel-in-progress"], False)

    def test_publish_workflow_skips_closed_pull_requests(self) -> None:
        workflow = load_workflow("publish.yml")
        jobs = workflow["jobs"]
        self.assertIn("preflight", jobs)
        self.assertEqual(
            jobs["preflight"]["outputs"]["open"], "${{ steps.state.outputs.open }}"
        )
        self.assertEqual(jobs["pr-pull"]["needs"], "preflight")
        self.assertEqual(
            jobs["pr-pull"]["if"], "needs.preflight.outputs.open == 'true'"
        )

    def test_auto_publish_leaves_casks_for_manual_merge(self) -> None:
        text = (WORKFLOWS_DIR / "auto-publish.yml").read_text(encoding="utf-8")
        self.assertIn(
            "only changes casks",
            text,
            "cask bumps have no bottle artifacts; auto-publish must not dispatch pr-pull",
        )

    def test_publish_uses_scoped_token_for_github_api(self) -> None:
        text = (WORKFLOWS_DIR / "publish.yml").read_text(encoding="utf-8")
        self.assertIn(
            "HOMEBREW_GITHUB_API_TOKEN: ${{ secrets.GITHUB_TOKEN }}",
            text,
            "brew pr-pull needs actions/checks read; the API token must be GITHUB_TOKEN",
        )
        self.assertIn(
            "token: ${{ steps.app-token.outputs.token || secrets.GITHUB_TOKEN }}",
            text,
            "the App token should still authenticate the setup/git push",
        )

    def test_pins_define_positive_build_timeouts(self) -> None:
        packages = json.loads(PINS_PATH.read_text(encoding="utf-8"))["packages"]
        for name, package in packages.items():
            self.assertIsInstance(
                package.get("timeout_minutes"),
                int,
                f"{name} must define an integer timeout_minutes in upstream-pins.json",
            )
            self.assertGreater(
                package["timeout_minutes"],
                0,
                f"{name} must have a positive timeout_minutes",
            )

    def test_build_workflows_use_pinned_timeouts(self) -> None:
        for name in ("build-hosted.yml", "build-cuda.yml", "build-rocm.yml"):
            workflow_text = (WORKFLOWS_DIR / name).read_text(encoding="utf-8")
            self.assertIn(
                "matrix.item.timeout_minutes",
                workflow_text,
                f"{name} must use matrix.item.timeout_minutes for job timeouts",
            )


if __name__ == "__main__":
    unittest.main()
