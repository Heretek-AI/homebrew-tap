"""Checks for the backfilled bottle publishing workflow."""

from __future__ import annotations

from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_PATH = REPO_ROOT / ".github" / "workflows" / "publish-bottles.yml"
GHCR_ROOT_URL = "https://ghcr.io/v2/heretek-ai/tap"


def _load_workflow() -> dict:
    workflow = yaml.safe_load(WORKFLOW_PATH.read_text(encoding="utf-8"))
    assert isinstance(workflow, dict)
    # PyYAML resolves the unquoted YAML 1.1 key `on` to boolean True.
    if True in workflow and "on" not in workflow:
        workflow["on"] = workflow.pop(True)
    return workflow


def test_publish_bottles_workflow_is_valid_yaml() -> None:
    workflow = _load_workflow()
    assert workflow["name"] == "Publish Backfilled Bottles"
    assert workflow["permissions"] == {}


def test_workflow_dispatch_requires_run_id() -> None:
    trigger = _load_workflow()["on"]
    assert set(trigger) == {"workflow_dispatch"}

    inputs = trigger["workflow_dispatch"]["inputs"]
    assert inputs["run_id"]["required"] is True
    assert inputs["run_id"]["type"] == "string"
    assert inputs["root_url"]["default"] == GHCR_ROOT_URL


def test_concurrency_is_scoped_to_the_source_run() -> None:
    assert _load_workflow()["concurrency"] == {
        "group": "publish-bottles-${{ inputs.run_id }}",
        "cancel-in-progress": False,
    }


def test_publish_job_uploads_bottles_to_ghcr() -> None:
    job = _load_workflow()["jobs"]["publish"]
    assert job["runs-on"] == "ubuntu-latest"
    assert job["timeout-minutes"] == 30
    assert job["permissions"]["packages"] == "write"

    upload_steps = [
        step
        for step in job["steps"]
        if "brew pr-upload --root-url" in step.get("run", "")
    ]
    assert len(upload_steps) == 1
    assert '--root-url="${ROOT_URL}"' in upload_steps[0]["run"]
    assert job["env"]["ROOT_URL"] == "${{ inputs.root_url }}"


def test_app_token_does_not_request_missing_packages_permission() -> None:
    text = WORKFLOW_PATH.read_text(encoding="utf-8")
    assert "permission-packages" not in text
    assert "HOMEBREW_GITHUB_PACKAGES_TOKEN: ${{ secrets.GITHUB_TOKEN }}" in text


def test_source_run_is_validated_before_download() -> None:
    job = _load_workflow()["jobs"]["publish"]
    validation_steps = [
        step for step in job["steps"] if step.get("name") == "Validate source run"
    ]
    assert len(validation_steps) == 1

    script = validation_steps[0]["run"]
    for expected in (
        "Build Hosted Bottles",
        "Build CUDA Bottles",
        "Build ROCm Bottles",
        "head_repository.full_name",
        "autobump/*",
        "bump-*",
    ):
        assert expected in script
