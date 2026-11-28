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


def test_validate_bottle_strixolotl_hardware_present_and_absent(tmp_path):
    # Hardware present mock: strata-device --list-devices and --selftest succeed.
    keg_present = tmp_path / "keg_present"
    libexec_bin = keg_present / "libexec" / "bin"
    libexec_bin.mkdir(parents=True)
    device_bin = libexec_bin / "strata-device"
    device_bin.write_text(
        "#!/usr/bin/env bash\n"
        "if [[ \"${1:-}\" == \"--list-devices\" ]]; then\n"
        "  echo 'device 0: AMD Radeon Graphics'\n"
        "  echo '  arch gfx1151, 128.0 GiB, wave32'\n"
        "  exit 0\n"
        "elif [[ \"${1:-}\" == \"--selftest\" ]]; then\n"
        "  echo 'device 0: AMD Radeon Graphics'\n"
        "  echo '  HIP arch            gfx1151 wave32 (compiled for gfx1151)'\n"
        "  echo 'strata-device selftest OK'\n"
        "  exit 0\n"
        "fi\n"
        "exit 2\n",
        encoding="utf-8",
    )
    device_bin.chmod(0o755)

    out_present = tmp_path / "proof_present.json"
    res_present = subprocess.run(
        [
            sys.executable, str(SCRIPT_PATH),
            "--keg", str(keg_present),
            "--formula", "strixolotl",
            "--variant", "rocm",
            "--spec", str(SPECS_PATH),
            "--tiers", "2,3",
            "--hardware", "present",
            "--out", str(out_present),
        ],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    assert res_present.returncode == 0, res_present.stderr
    data_present = json.loads(out_present.read_text(encoding="utf-8"))
    assert data_present["overall_status"] == "PASSED"
    assert data_present["tiers"]["tier2_device"]["status"] == "PASSED"
    assert data_present["tiers"]["tier3_eval"]["status"] == "PASSED"

    # Hardware absent mock: --list-devices exits 0 with "(no GPU device)", --selftest exits 1.
    keg_absent = tmp_path / "keg_absent"
    libexec_bin_absent = keg_absent / "libexec" / "bin"
    libexec_bin_absent.mkdir(parents=True)
    device_bin_absent = libexec_bin_absent / "strata-device"
    device_bin_absent.write_text(
        "#!/usr/bin/env bash\n"
        "if [[ \"${1:-}\" == \"--list-devices\" ]]; then\n"
        "  echo '(no GPU device)'\n"
        "  exit 0\n"
        "elif [[ \"${1:-}\" == \"--selftest\" ]]; then\n"
        "  echo 'strata-device: no HIP device' >&2\n"
        "  exit 1\n"
        "fi\n"
        "exit 2\n",
        encoding="utf-8",
    )
    device_bin_absent.chmod(0o755)

    out_absent = tmp_path / "proof_absent.json"
    res_absent = subprocess.run(
        [
            sys.executable, str(SCRIPT_PATH),
            "--keg", str(keg_absent),
            "--formula", "strixolotl",
            "--variant", "rocm",
            "--spec", str(SPECS_PATH),
            "--tiers", "2,3",
            "--hardware", "absent",
            "--out", str(out_absent),
        ],
        stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    assert res_absent.returncode == 0, res_absent.stderr
    data_absent = json.loads(out_absent.read_text(encoding="utf-8"))
    assert data_absent["overall_status"] == "PASSED_HW_ABSENT"
    assert data_absent["tiers"]["tier2_device"]["status"] == "PASSED_HW_ABSENT"
    assert data_absent["tiers"]["tier3_eval"]["status"] == "PASSED_HW_ABSENT"
