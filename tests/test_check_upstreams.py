import json
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT_PATH = Path(__file__).resolve().parent.parent / ".github" / "scripts" / "check_upstreams.py"
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"


def test_check_upstreams_dry_run():
    cmd = [sys.executable, str(SCRIPT_PATH), "--dry-run"]
    res = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode == 0, f"check_upstreams failed: {res.stderr}"
    assert "Active Jobs Scheduled" in res.stdout or "Total jobs to execute:" in res.stdout
    assert "Excluded" in res.stdout or "SKIPPED" in res.stdout


def test_check_upstreams_custom_ledger(tmp_path):
    test_ledger = {
        "schema_version": 1,
        "rocm": {
            "min_version": "10.1.0",
            "last_build_stamp": "20261105"
        },
        "packages": {
            "testpkg": {
                "formula": "testpkg",
                "remote": "https://github.com/example/testpkg.git",
                "repo": "example/testpkg",
                "branch": "main",
                "track": "commit",
                "variants": {
                    "cpu": {
                        "status": "enabled",
                        "backend": "cpu",
                        "default": True,
                        "runner": "ubuntu-24.04",
                        "bottle_tag": "x86_64_linux",
                        "last_built_commit": "abc1234",
                        "last_rocm_stamp": None
                    },
                    "metal": {
                        "status": "excluded",
                        "reason": "Not supported"
                    }
                }
            }
        }
    }
    ledger_file = tmp_path / "ledger.json"
    ledger_file.write_text(json.dumps(test_ledger), encoding="utf-8")

    # Run with offline fixtures to avoid network calls
    fixtures_dir = tmp_path / "fixtures"
    fixtures_dir.mkdir()
    (fixtures_dir / "testpkg.json").write_text(json.dumps({"target": "abc1234"}), encoding="utf-8")
    (fixtures_dir / "rocm_gfx1151.json").write_text(json.dumps({"build_stamp": "20261105", "filename": "dummy.tar.gz"}), encoding="utf-8")

    cmd = [
        sys.executable, str(SCRIPT_PATH),
        "--ledger", str(ledger_file),
        "--offline-fixtures", str(fixtures_dir),
        "--dry-run"
    ]
    res = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode == 0
    assert "Total jobs to execute: 0" in res.stdout


def test_check_upstreams_detects_update(tmp_path):
    test_ledger = {
        "schema_version": 1,
        "rocm": {
            "min_version": "10.1.0",
            "last_build_stamp": "20261105"
        },
        "packages": {
            "testpkg": {
                "formula": "testpkg",
                "remote": "https://github.com/example/testpkg.git",
                "repo": "example/testpkg",
                "branch": "main",
                "track": "commit",
                "variants": {
                    "cpu": {
                        "status": "enabled",
                        "backend": "cpu",
                        "default": True,
                        "runner": "ubuntu-24.04",
                        "bottle_tag": "x86_64_linux",
                        "last_built_commit": "oldcommit123",
                        "last_rocm_stamp": None
                    }
                }
            }
        }
    }
    ledger_file = tmp_path / "ledger.json"
    ledger_file.write_text(json.dumps(test_ledger), encoding="utf-8")

    fixtures_dir = tmp_path / "fixtures"
    fixtures_dir.mkdir()
    (fixtures_dir / "testpkg.json").write_text(json.dumps({"target": "newcommit456"}), encoding="utf-8")
    (fixtures_dir / "rocm_gfx1151.json").write_text(json.dumps({"build_stamp": "20261105", "filename": "dummy.tar.gz"}), encoding="utf-8")

    cmd = [
        sys.executable, str(SCRIPT_PATH),
        "--ledger", str(ledger_file),
        "--offline-fixtures", str(fixtures_dir),
        "--dry-run"
    ]
    res = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode == 0
    assert "Total jobs to execute: 1" in res.stdout
    assert "upstream-update" in res.stdout
