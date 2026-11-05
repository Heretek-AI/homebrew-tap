import json
import subprocess
import sys
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parent.parent / ".github" / "scripts" / "finalize_run.py"


def test_finalize_run_synchronization(tmp_path):
    test_ledger = {
        "schema_version": 1,
        "rocm": {
            "last_build_stamp": None,
            "last_index_url": None
        },
        "packages": {
            "gufo": {
                "formula": "gufo",
                "variants": {
                    "rocm": {
                        "backend": "rocm",
                        "last_built_commit": "old_commit",
                        "last_rocm_stamp": None,
                        "last_success_at": None
                    }
                }
            }
        }
    }
    ledger_file = tmp_path / "upstream-pins.json"
    ledger_file.write_text(json.dumps(test_ledger), encoding="utf-8")

    proofs_dir = tmp_path / "proofs"
    proofs_dir.mkdir()
    proof_data = {
        "formula": "gufo",
        "variant": "rocm",
        "overall_status": "PASSED",
        "target_commit": "new_commit_789",
        "proof_sha256": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
    }
    (proofs_dir / "validation-proof-gufo-rocm.json").write_text(json.dumps(proof_data), encoding="utf-8")

    cmd = [
        sys.executable, str(SCRIPT_PATH),
        "--ledger", str(ledger_file),
        "--proofs-dir", str(proofs_dir),
        "--rocm-stamp", "20261105",
        "--rocm-index", "https://nightly.repo.amd.com/rocm/core/tarball/"
    ]
    res = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode == 0, f"finalize_run failed: {res.stderr}"
    assert "1 Passed" in res.stdout

    updated_ledger = json.loads(ledger_file.read_text(encoding="utf-8"))
    assert updated_ledger["rocm"]["last_build_stamp"] == "20261105"
    assert updated_ledger["rocm"]["last_index_url"] == "https://nightly.repo.amd.com/rocm/core/tarball/"
    gufo_var = updated_ledger["packages"]["gufo"]["variants"]["rocm"]
    assert gufo_var["last_built_commit"] == "new_commit_789"
    assert gufo_var["last_rocm_stamp"] == "20261105"
    assert gufo_var["last_success_at"] is not None
