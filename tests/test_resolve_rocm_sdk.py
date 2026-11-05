import json
import shutil
import subprocess
import sys
from pathlib import Path
import pytest

SCRIPT_PATH = Path(__file__).resolve().parent.parent / ".github" / "scripts" / "resolve_rocm_sdk.sh"
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"

has_bash = bool(shutil.which("bash")) or bool(shutil.which("wsl"))


def to_wsl_path(p):
    s = str(p).replace("\\", "/")
    if len(s) > 1 and s[1] == ":":
        return f"/mnt/{s[0].lower()}/{s[2:].lstrip('/')}"
    return s


def run_resolve_script(args):
    cmd = ["bash", str(SCRIPT_PATH)] + args
    res = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0 and shutil.which("wsl"):
        wsl_script = to_wsl_path(SCRIPT_PATH)
        wsl_args = [to_wsl_path(a) if (isinstance(a, Path) or ("\\" in str(a) or ":/" in str(a))) else str(a) for a in args]
        res = subprocess.run(["wsl", "bash", wsl_script] + wsl_args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res


@pytest.mark.skipif(not has_bash, reason="bash or wsl is required to execute resolve_rocm_sdk.sh")
def test_resolve_primary_index_latest():
    fixture = FIXTURES_DIR / "rocm_index_primary.html"
    res = run_resolve_script(["--index-file", str(fixture), "--family", "gfx1151", "--resolve-only", "--json"])
    assert res.returncode == 0, f"Script failed: {res.stderr}"
    data = json.loads(res.stdout)
    assert data["filename"] == "therock-dist-linux-gfx1151-10.3.0a20261105.tar.gz"
    assert data["build_stamp"] == "20261105"
    assert data["version"] == "10.3.0a"
    assert "-tests-" not in data["filename"]


@pytest.mark.skipif(not has_bash, reason="bash or wsl is required to execute resolve_rocm_sdk.sh")
def test_resolve_max_version_cap():
    fixture = FIXTURES_DIR / "rocm_index_primary.html"
    res = run_resolve_script(["--index-file", str(fixture), "--family", "gfx1151", "--max-version", "10.1.99", "--resolve-only", "--json"])
    assert res.returncode == 0, f"Script failed: {res.stderr}"
    data = json.loads(res.stdout)
    assert data["filename"] == "therock-dist-linux-gfx1151-10.1.0a20260910.tar.gz"
    assert data["build_stamp"] == "20260910"


@pytest.mark.skipif(not has_bash, reason="bash or wsl is required to execute resolve_rocm_sdk.sh")
def test_resolve_legacy_bkc_channel():
    fixture = FIXTURES_DIR / "rocm_index_legacy.html"
    res = run_resolve_script(["--index-file", str(fixture), "--family", "gfx1151", "--channel", "bkc", "--resolve-only", "--json"])
    assert res.returncode == 0, f"Script failed: {res.stderr}"
    data = json.loads(res.stdout)
    assert "bkc" in data["filename"]
    assert data["filename"] == "therock-dist-linux-gfx1151-10.1.0a20260811+bkc.20260818.tar.gz"
