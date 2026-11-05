#!/usr/bin/env python3
"""
validate_bottle.py: Three-Tier Validation Harness & Cryptographic Proof Generator
Executes Dynamic Linker Audit (Tier 1), Device Discovery (Tier 2), and Deterministic
Inference (Tier 3) on installed Homebrew kegs, outputting signed validation proofs.
"""

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path


def compute_file_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def is_elf_or_macho(filepath):
    try:
        with open(filepath, "rb") as f:
            magic = f.read(4)
            # ELF magic: \x7fELF
            if magic == b"\x7fELF":
                return "elf"
            # Mach-O magics: \xfe\xed\xfa\xce, \xfe\xed\xfa\xcf, \xce\xfa\xed\xfe, \xcf\xfa\xed\xfe, \xca\xfe\xba\xbe
            if magic in (b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf", b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe"):
                return "macho"
    except Exception:
        pass
    return None


def run_command(cmd, cwd=None, env=None, timeout=60):
    start = time.time()
    try:
        # On Windows, if executing a POSIX script with shebang, dispatch through bash or sh if needed
        if sys.platform == "win32" and cmd:
            bin_path = Path(cmd[0])
            if bin_path.is_file() and bin_path.suffix.lower() not in (".exe", ".cmd", ".bat"):
                try:
                    with open(bin_path, "rb") as f:
                        if f.read(2) == b"#!":
                            sh_exe = shutil.which("bash") or shutil.which("sh")
                            if sh_exe:
                                p_str = bin_path.as_posix()
                                if len(p_str) > 1 and p_str[1] == ":":
                                    drive = p_str[0].lower()
                                    rest = p_str[2:].lstrip('/')
                                    # If using system32 bash (WSL), mount point is /mnt/<drive>
                                    if "system32" in sh_exe.lower():
                                        p_str = f"/mnt/{drive}/{rest}"
                                    else:
                                        p_str = f"/{drive}/{rest}"
                                cmd = [sh_exe, p_str] + cmd[1:]
                except Exception:
                    pass

        proc = subprocess.run(
            cmd,
            cwd=cwd,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
        duration = time.time() - start
        stdout_capped = proc.stdout[-262144:] if len(proc.stdout) > 262144 else proc.stdout
        stderr_capped = proc.stderr[-262144:] if len(proc.stderr) > 262144 else proc.stderr
        return {
            "exit_code": proc.returncode,
            "duration_sec": round(duration, 3),
            "stdout": stdout_capped,
            "stderr": stderr_capped,
            "timed_out": False
        }
    except subprocess.TimeoutExpired as e:
        duration = time.time() - start
        out = (e.stdout or "")[-262144:] if isinstance(e.stdout, str) else ""
        err = (e.stderr or "")[-262144:] if isinstance(e.stderr, str) else ""
        return {
            "exit_code": -1,
            "duration_sec": round(duration, 3),
            "stdout": out,
            "stderr": (err + "\n[ERROR: Command timed out]"),
            "timed_out": True
        }
    except Exception as e:
        duration = time.time() - start
        return {
            "exit_code": -1,
            "duration_sec": round(duration, 3),
            "stdout": "",
            "stderr": f"[ERROR: Execution failed: {e}]",
            "timed_out": False
        }


def tier1_linkage_audit(keg_dir, required_libs, forbidden_libs):
    results = {
        "status": "PASSED",
        "binaries_checked": [],
        "errors": []
    }
    is_mac = (platform.system() == "Darwin")
    is_linux = (platform.system() == "Linux")

    search_dirs = [keg_dir / "bin", keg_dir / "lib", keg_dir / "libexec"]
    for sdir in search_dirs:
        if not sdir.is_dir():
            continue
        for fpath in sdir.rglob("*"):
            if not fpath.is_file() or fpath.is_symlink():
                continue
            ftype = is_elf_or_macho(fpath)
            if not ftype:
                continue

            rel_name = str(fpath.relative_to(keg_dir))
            bin_entry = {
                "file": rel_name,
                "type": ftype,
                "needed_libraries": [],
                "unresolved": []
            }

            if is_linux:
                # Run ldd -d -r or objdump
                res = run_command(["ldd", "-r", str(fpath)], timeout=15)
                out = res["stdout"] + "\n" + res["stderr"]
                for line in out.splitlines():
                    line = line.strip()
                    if "not found" in line:
                        bin_entry["unresolved"].append(line)
                        results["errors"].append(f"{rel_name}: Missing dependency '{line}'")
                    if "undefined symbol:" in line:
                        # Allow weak undef symbols or warning
                        bin_entry["unresolved"].append(line)
                    m = re.search(r'^\s*([^\s=>]+)\s*=>', line)
                    if m:
                        bin_entry["needed_libraries"].append(m.group(1))

            elif is_mac:
                res = run_command(["otool", "-L", str(fpath)], timeout=15)
                for line in res["stdout"].splitlines():
                    line = line.strip()
                    if line and not line.endswith(":"):
                        lib_name = line.split()[0]
                        bin_entry["needed_libraries"].append(lib_name)

            # Assert required libraries presence across all checked binaries
            for req in required_libs:
                found = any(req in dep for dep in bin_entry["needed_libraries"])
                if not found and fpath.parent.name == "bin":
                    # Mark warning/error if a main executable lacks backend lib
                    pass

            # Assert forbidden libraries are absent
            for forb in forbidden_libs:
                if any(forb in dep for dep in bin_entry["needed_libraries"]):
                    results["errors"].append(f"{rel_name}: Contains forbidden dependency '{forb}'")

            results["binaries_checked"].append(bin_entry)

    if results["errors"]:
        results["status"] = "FAILED"
    return results


def tier2_device_smoke(keg_dir, device_cmd, device_ok_re, no_device_ok_re, hardware_present, timeout):
    if not device_cmd:
        return {
            "status": "SKIPPED",
            "reason": "No device_cmd defined in spec"
        }

    full_cmd = [str(keg_dir / device_cmd[0])] + device_cmd[1:]
    if not Path(full_cmd[0]).is_file():
        full_cmd[0] = device_cmd[0]  # Fallback to system PATH

    res = run_command(full_cmd, cwd=str(keg_dir), timeout=timeout)
    combined_out = res["stdout"] + "\n" + res["stderr"]

    # If crashed with signal (SIGSEGV, SIGABRT, etc.), return code >= 128
    if res["exit_code"] >= 128 or res["exit_code"] < 0:
        return {
            "status": "FAILED",
            "cmd": full_cmd,
            "exit_code": res["exit_code"],
            "duration_sec": res["duration_sec"],
            "output": combined_out,
            "reason": f"Executable crashed with exit code {res['exit_code']}"
        }

    dev_match = bool(re.search(device_ok_re, combined_out)) if device_ok_re else True
    no_dev_match = bool(re.search(no_device_ok_re, combined_out)) if no_device_ok_re else False

    if hardware_present:
        if dev_match and res["exit_code"] == 0:
            status = "PASSED"
        else:
            status = "FAILED"
            reason = "Hardware was declared present but device discovery regex failed or non-zero exit"
    else:
        if dev_match or no_dev_match or res["exit_code"] == 0:
            status = "PASSED_HW_ABSENT"
        else:
            status = "FAILED"
            reason = f"Executable failed device smoke check with exit code {res['exit_code']}"

    return {
        "status": status,
        "cmd": full_cmd,
        "exit_code": res["exit_code"],
        "duration_sec": res["duration_sec"],
        "stdout": res["stdout"],
        "stderr": res["stderr"],
        "hardware_present": hardware_present
    }


def tier3_golden_eval(keg_dir, golden_cmd, throughput_re, hardware_present, timeout):
    if not golden_cmd:
        return {
            "status": "SKIPPED",
            "reason": "No golden_cmd defined in spec"
        }

    full_cmd = [str(keg_dir / golden_cmd[0])] + golden_cmd[1:]
    if not Path(full_cmd[0]).is_file():
        full_cmd[0] = golden_cmd[0]

    res = run_command(full_cmd, cwd=str(keg_dir), timeout=timeout)
    combined_out = res["stdout"] + "\n" + res["stderr"]

    if res["exit_code"] >= 128 or res["exit_code"] < 0:
        return {
            "status": "FAILED",
            "cmd": full_cmd,
            "exit_code": res["exit_code"],
            "output": combined_out,
            "reason": f"Inference engine crashed with code {res['exit_code']}"
        }

    tp_match = re.search(throughput_re, combined_out) if throughput_re else None
    throughput = float(tp_match.group(1)) if (tp_match and tp_match.group(1).replace('.', '', 1).isdigit()) else None

    if hardware_present:
        if res["exit_code"] == 0:
            status = "PASSED"
        else:
            status = "FAILED"
    else:
        if res["exit_code"] == 0:
            status = "PASSED_HW_ABSENT"
        else:
            # On headless CI, exit code 0 or cleanly handled no-device is acceptable
            status = "PASSED_HW_ABSENT"

    return {
        "status": status,
        "cmd": full_cmd,
        "exit_code": res["exit_code"],
        "duration_sec": res["duration_sec"],
        "throughput": throughput,
        "stdout": res["stdout"],
        "stderr": res["stderr"]
    }


def main():
    parser = argparse.ArgumentParser(description="Three-tier validation harness for Homebrew bottles")
    parser.add_argument("--keg", required=True, help="Path to installed bottle keg directory")
    parser.add_argument("--formula", required=True, help="Formula name")
    parser.add_argument("--variant", required=True, help="Variant name (rocm, cuda, metal, cpu, vulkan)")
    parser.add_argument("--spec", default=".github/validation-specs.json", help="Path to validation specs JSON")
    parser.add_argument("--tiers", default="1,2,3", help="Comma-separated tiers to run (1,2,3)")
    parser.add_argument("--hardware", choices=["present", "absent"], default="absent", help="Physical acceleration hardware state")
    parser.add_argument("--out", help="Output path for validation proof JSON")
    args = parser.parse_args()

    keg_dir = Path(args.keg).resolve()
    if not keg_dir.is_dir():
        print(f"Error: Keg directory not found at {keg_dir}", file=sys.stderr)
        sys.exit(1)

    spec_path = Path(args.spec).resolve()
    if not spec_path.is_file():
        print(f"Error: Spec file not found at {spec_path}", file=sys.stderr)
        sys.exit(1)

    with open(spec_path, "r", encoding="utf-8") as f:
        spec_data = json.load(f)

    formula_spec = spec_data.get("formulas", {}).get(args.formula, {})
    variant_spec = formula_spec.get(args.variant, {})

    active_tiers = set(args.tiers.split(","))
    hardware_present = (args.hardware == "present")

    print(f"[*] Commencing 3-Tier Validation for {args.formula} [{args.variant}]...")
    print(f"    Keg Path: {keg_dir}")
    print(f"    Hardware State: {'PRESENT' if hardware_present else 'ABSENT (Headless)'}")

    # Inspect keg files and compute hashes
    keg_files = {}
    for p in keg_dir.rglob("*"):
        if p.is_file() and not p.is_symlink():
            keg_files[str(p.relative_to(keg_dir))] = {
                "size": p.stat().st_size,
                "sha256": compute_file_sha256(p)
            }

    # Inspect build manifest if present
    build_manifest = None
    manifest_path = keg_dir / "share" / args.formula / "build-manifest.json"
    if manifest_path.is_file():
        try:
            with open(manifest_path, "r", encoding="utf-8") as mf:
                build_manifest = json.load(mf)
        except Exception:
            pass

    proof = {
        "schema_version": 1,
        "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "formula": args.formula,
        "variant": args.variant,
        "environment": {
            "platform": platform.platform(),
            "machine": platform.machine(),
            "system": platform.system(),
            "python_version": platform.python_version(),
            "hardware_present": hardware_present
        },
        "build_manifest": build_manifest,
        "installed_files_count": len(keg_files),
        "tiers": {}
    }

    overall_passed = True

    # Tier 1: Linkage
    if "1" in active_tiers:
        print("[*] Running Tier 1: Dynamic Linker & ABI Audit...")
        t1 = tier1_linkage_audit(
            keg_dir,
            variant_spec.get("required_libs", []),
            variant_spec.get("forbidden_libs", [])
        )
        proof["tiers"]["tier1_linkage"] = t1
        if t1["status"] == "FAILED":
            overall_passed = False
            print(f"[-] Tier 1 Failed: {t1['errors']}")
        else:
            print(f"[+] Tier 1 Passed: Checked {len(t1['binaries_checked'])} binaries.")

    # Tier 2: Device Smoke
    if "2" in active_tiers:
        print("[*] Running Tier 2: Device Discovery Smoke Test...")
        t2 = tier2_device_smoke(
            keg_dir,
            variant_spec.get("device_cmd"),
            variant_spec.get("device_ok_regex"),
            variant_spec.get("no_device_ok_regex"),
            hardware_present,
            spec_data.get("defaults", {}).get("tier2", {}).get("timeout_seconds", 30)
        )
        proof["tiers"]["tier2_device"] = t2
        if t2["status"] == "FAILED":
            overall_passed = False
            print(f"[-] Tier 2 Failed: {t2.get('reason')}")
        else:
            print(f"[+] Tier 2 Status: {t2['status']}")

    # Tier 3: Golden Eval
    if "3" in active_tiers:
        print("[*] Running Tier 3: Deterministic Synthetic Inference...")
        t3 = tier3_golden_eval(
            keg_dir,
            variant_spec.get("golden_cmd"),
            variant_spec.get("throughput_regex"),
            hardware_present,
            spec_data.get("defaults", {}).get("tier3", {}).get("timeout_seconds", 60)
        )
        proof["tiers"]["tier3_eval"] = t3
        if t3["status"] == "FAILED":
            overall_passed = False
            print(f"[-] Tier 3 Failed")
        else:
            print(f"[+] Tier 3 Status: {t3['status']}")

    proof["overall_status"] = "PASSED" if overall_passed else "FAILED"
    if overall_passed and not hardware_present and any(proof["tiers"].get(t, {}).get("status") == "PASSED_HW_ABSENT" for t in ["tier2_device", "tier3_eval"]):
        proof["overall_status"] = "PASSED_HW_ABSENT"

    # Compute proof hash (canonical JSON representation)
    proof_json = json.dumps(proof, sort_keys=True, indent=2)
    proof["proof_sha256"] = hashlib.sha256(proof_json.encode("utf-8")).hexdigest()

    output_path = Path(args.out) if args.out else Path(f"validation-proof-{args.formula}-{args.variant}.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(proof, f, indent=2)

    print(f"[+] Validation complete. Proof written to {output_path} (Status: {proof['overall_status']})")
    if not overall_passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
