import json
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parent.parent / ".github" / "scripts" / "validate_bottle.py"
SPECS_PATH = Path(__file__).resolve().parent.parent / ".github" / "validation-specs.json"


def test_validate_bottle_success(tmp_path):
    # Create mock keg
    keg = tmp_path / "keg"
    bin_dir = keg / "bin"
    bin_dir.mkdir(parents=True)

    dummy_bin = bin_dir / "gufo"
    dummy_bin.write_text("#!/usr/bin/env bash\necho 'gufo version 0.28.1'\necho 'No device found (hipErrorNoDevice)'\n", encoding="utf-8")
    dummy_bin.chmod(0o755)

    out_file = tmp_path / "proof.json"
    cmd = [
        sys.executable, str(SCRIPT_PATH),
        "--keg", str(keg),
        "--formula", "gufo",
        "--variant", "rocm",
        "--spec", str(SPECS_PATH),
        "--tiers", "1,2",
        "--hardware", "absent",
        "--out", str(out_file)
    ]
    res = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode == 0, f"validate_bottle failed: {res.stderr}"

    assert out_file.is_file()
    data = json.loads(out_file.read_text(encoding="utf-8"))
    assert data["formula"] == "gufo"
    assert data["variant"] == "rocm"
    assert "proof_sha256" in data
    assert len(data["proof_sha256"]) == 64
    assert data["overall_status"] in ("PASSED", "PASSED_HW_ABSENT")


def test_validate_bottle_crash_fails(tmp_path):
    keg = tmp_path / "keg"
    bin_dir = keg / "bin"
    bin_dir.mkdir(parents=True)

    # Crashing binary with exit code 139 (SIGSEGV)
    crash_bin = bin_dir / "gufo"
    crash_bin.write_text("#!/usr/bin/env bash\nexit 139\n", encoding="utf-8")
    crash_bin.chmod(0o755)

    out_file = tmp_path / "proof.json"
    cmd = [
        sys.executable, str(SCRIPT_PATH),
        "--keg", str(keg),
        "--formula", "gufo",
        "--variant", "rocm",
        "--spec", str(SPECS_PATH),
        "--tiers", "2",
        "--hardware", "absent",
        "--out", str(out_file)
    ]
    res = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    assert res.returncode != 0
    data = json.loads(out_file.read_text(encoding="utf-8"))
    assert data["overall_status"] == "FAILED"
