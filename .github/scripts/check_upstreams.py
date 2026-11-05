#!/usr/bin/env python3
"""
check_upstreams.py: Change Detection & Dynamic Actions Matrix Builder
Inspects upstream remotes, formula files, and AMD ROCm nightly builds to emit
a precise, deduplicated GitHub Actions execution matrix for Heretek-AI Tap.
"""

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


def get_formula_sha256(formula_name, repo_root):
    formula_path = Path(repo_root) / "Formula" / f"{formula_name}.rb"
    if not formula_path.is_file():
        return None
    with open(formula_path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def fetch_remote_commit(remote_url, branch, retries=3):
    cmd = ["git", "ls-remote", remote_url, f"refs/heads/{branch}"]
    for attempt in range(1, retries + 1):
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20)
            if res.returncode == 0:
                lines = res.stdout.strip().splitlines()
                if lines:
                    sha = lines[0].split()[0]
                    return sha, None
                return None, f"No refs found for refs/heads/{branch}"
            err = res.stderr.strip()
            if attempt == retries:
                return None, err or f"git ls-remote failed with code {res.returncode}"
        except Exception as e:
            if attempt == retries:
                return None, str(e)
        time.sleep(attempt * 1.5)
    return None, "Max retries exceeded"


def fetch_latest_release(repo, token=None, retries=3):
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Heretek-Tap-ChangeGate")
    req.add_header("Accept", "application/vnd.github+json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")

    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                tag = data.get("tag_name")
                return tag, None
        except urllib.error.HTTPError as e:
            if e.code == 404:
                # Fallback to tags endpoint if no releases are published
                tags_url = f"https://api.github.com/repos/{repo}/tags?per_page=1"
                t_req = urllib.request.Request(tags_url)
                t_req.add_header("User-Agent", "Heretek-Tap-ChangeGate")
                t_req.add_header("Accept", "application/vnd.github+json")
                if token:
                    t_req.add_header("Authorization", f"Bearer {token}")
                try:
                    with urllib.request.urlopen(t_req, timeout=15) as t_resp:
                        tags_data = json.loads(t_resp.read().decode("utf-8"))
                        if tags_data and isinstance(tags_data, list):
                            return tags_data[0].get("name"), None
                except Exception as ex:
                    return None, str(ex)
            if attempt == retries:
                return None, f"HTTP {e.code}: {e.reason}"
        except Exception as e:
            if attempt == retries:
                return None, str(e)
        time.sleep(attempt * 1.5)
    return None, "Max retries exceeded"


def resolve_rocm_metadata(repo_root, family="gfx1151", min_version="10.1.0", max_version="", offline_dir=None):
    if offline_dir:
        meta_file = Path(offline_dir) / f"rocm_{family}.json"
        if meta_file.is_file():
            return load_json(meta_file)

    # Native Python resolution for high speed, reliability, and cross-platform execution
    index_urls = [
        "https://nightly.repo.amd.com/rocm/core/tarball/",
        "https://rocm.nightlies.amd.com/tarball-multi-arch/"
    ]
    index_content = None
    resolved_index_url = None

    for url in index_urls:
        req = urllib.request.Request(url, headers={"User-Agent": "Heretek-Tap-ChangeGate"})
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                content = resp.read().decode("utf-8")
                if content:
                    index_content = content
                    resolved_index_url = url
                    break
        except Exception:
            continue

    if not index_content:
        return None

    # Parse files list
    file_names = []
    m = re.search(r'const\s+files\s*=\s*(\[.*?\])\s*;', index_content, re.DOTALL)
    if m:
        try:
            entries = json.loads(m.group(1))
            file_names = [e.get("name", "") for e in entries if isinstance(e, dict)]
        except Exception:
            pass

    if not file_names:
        file_names = list(set(re.findall(r'therock-dist-linux-[A-Za-z0-9_.\-+]+?\.tar\.gz', index_content)))

    pattern = re.compile(
        r'^therock-dist-linux-' + re.escape(family) +
        r'-(\d+)\.(\d+)\.(\d+)(a|rc)(\d{8})(?:\+bkc\.(\d{8}))?\.tar\.gz$'
    )

    def parse_semver(v_str):
        parts = [int(p) for p in re.findall(r'\d+', v_str)]
        while len(parts) < 3:
            parts.append(0)
        return tuple(parts[:3])

    min_semver = parse_semver(min_version)
    max_semver = parse_semver(max_version) if max_version else None

    candidates = []
    for name in file_names:
        if "-tests-" in name:
            continue
        mat = pattern.match(name)
        if not mat:
            continue

        maj, minor, patch, stage, stamp, bkc_stamp = mat.groups()
        semver = (int(maj), int(minor), int(patch))

        if semver < min_semver:
            continue
        if max_semver and semver > max_semver:
            continue

        stage_rank = 0 if stage == "a" else 1
        sort_key = (semver[0], semver[1], semver[2], stage_rank, int(stamp), int(bkc_stamp or 0))

        candidates.append({
            "name": name,
            "version": f"{maj}.{minor}.{patch}{stage}",
            "build_stamp": stamp,
            "sort_key": sort_key
        })

    if not candidates:
        return None

    candidates.sort(key=lambda x: x["sort_key"])
    winner = candidates[-1]

    tarball_name = winner["name"]
    download_url = f"{resolved_index_url.rstrip('/')}/{tarball_name}"
    etag = ""
    size = 0
    last_mod = ""

    # Query HEAD for ETag and size
    try:
        h_req = urllib.request.Request(download_url, method="HEAD", headers={"User-Agent": "Heretek-Tap-ChangeGate"})
        with urllib.request.urlopen(h_req, timeout=10) as h_resp:
            etag = h_resp.headers.get("ETag", "").strip('"')
            size_val = h_resp.headers.get("Content-Length", "0")
            size = int(size_val) if size_val.isdigit() else 0
            last_mod = h_resp.headers.get("Last-Modified", "")
    except Exception:
        pass

    return {
        "index_url": resolved_index_url,
        "family": family,
        "filename": tarball_name,
        "url": download_url,
        "version": winner["version"],
        "build_stamp": winner["build_stamp"],
        "etag": etag,
        "size": size,
        "last_modified": last_mod
    }


def main():
    parser = argparse.ArgumentParser(description="Check upstream changes & build matrix")
    parser.add_argument("--ledger", default=".github/upstream-pins.json", help="Path to upstream ledger JSON")
    parser.add_argument("--repo-root", default=".", help="Root of homebrew-tap repository")
    parser.add_argument("--force", default="", help="Comma-separated formula names to force build, or 'all'")
    parser.add_argument("--dry-run", action="store_true", help="Print summary without writing outputs")
    parser.add_argument("--offline-fixtures", help="Directory with offline JSON fixtures for testing")
    parser.add_argument("--token", default=os.getenv("GITHUB_TOKEN"), help="GitHub API Token")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    ledger_path = repo_root / args.ledger
    if not ledger_path.is_file():
        print(f"Error: Ledger file not found at {ledger_path}", file=sys.stderr)
        sys.exit(1)

    ledger = load_json(ledger_path)
    rocm_cfg = ledger.get("rocm", {})
    min_rocm_ver = rocm_cfg.get("min_version", "10.1.0")
    max_rocm_ver = rocm_cfg.get("max_version") or ""
    packages = ledger.get("packages", {})

    print(f"[*] Querying AMD ROCm nightly toolchain metadata (min_version={min_rocm_ver})...")
    rocm_meta_gfx1151 = resolve_rocm_metadata(
        repo_root, family="gfx1151", min_version=min_rocm_ver, max_version=max_rocm_ver, offline_dir=args.offline_fixtures
    )
    current_rocm_stamp = rocm_meta_gfx1151.get("build_stamp") if rocm_meta_gfx1151 else None
    current_rocm_etag = rocm_meta_gfx1151.get("etag") if rocm_meta_gfx1151 else None
    current_rocm_filename = rocm_meta_gfx1151.get("filename") if rocm_meta_gfx1151 else None
    current_rocm_index = rocm_meta_gfx1151.get("index_url") if rocm_meta_gfx1151 else None

    print(f"    Resolved ROCm nightly build stamp: {current_rocm_stamp} ({current_rocm_filename})")

    # Inspect upstreams in parallel
    print(f"[*] Checking {len(packages)} tracked packages for upstream changes...")
    upstream_results = {}

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        future_to_pkg = {}
        for pkg_name, pkg_info in packages.items():
            track_type = pkg_info.get("track", "commit")
            if args.offline_fixtures:
                fixture_file = Path(args.offline_fixtures) / f"{pkg_name}.json"
                if fixture_file.is_file():
                    data = load_json(fixture_file)
                    upstream_results[pkg_name] = (data.get("target"), None)
                    continue

            if track_type == "commit":
                future = executor.submit(fetch_remote_commit, pkg_info["remote"], pkg_info["branch"])
            elif track_type in ("release", "rolling_release", "builder"):
                future = executor.submit(fetch_latest_release, pkg_info["repo"], args.token)
            else:
                future = executor.submit(fetch_remote_commit, pkg_info["remote"], pkg_info.get("branch", "main"))
            future_to_pkg[future] = pkg_name

        for future in concurrent.futures.as_completed(future_to_pkg):
            pkg_name = future_to_pkg[future]
            target_val, err = future.result()
            upstream_results[pkg_name] = (target_val, err)

    matrix_includes = []
    hw_matrix_includes = []
    changed_formulas = set()
    rocmfpx_needed = False
    audit_table = []

    force_all = (args.force == "all")
    forced_set = set(re.split(r"[,\s]+", args.force.strip())) if args.force and not force_all else set()

    for pkg_name, pkg_info in packages.items():
        formula = pkg_info.get("formula", pkg_name)
        variants = pkg_info.get("variants", {})
        current_formula_sha = get_formula_sha256(formula, repo_root)
        formula_changed = (current_formula_sha and current_formula_sha != pkg_info.get("formula_sha256"))

        target_ref, err = upstream_results.get(pkg_name, (None, "Unknown error"))
        if err:
            print(f"[-] Warning: Failed to query {pkg_name}: {err}", file=sys.stderr)

        for var_name, var_info in variants.items():
            status = var_info.get("status", "enabled")
            if status != "enabled":
                audit_table.append({
                    "formula": formula,
                    "variant": var_name,
                    "status": "excluded",
                    "reason": var_info.get("reason", "Disabled in ledger"),
                    "action": "SKIPPED"
                })
                continue

            backend = var_info.get("backend", "cpu")
            last_commit = var_info.get("last_built_commit")
            last_rocm_stamp = var_info.get("last_rocm_stamp")

            reasons = []
            if force_all or formula in forced_set or f"{formula}:{var_name}" in forced_set:
                reasons.append("forced")
            if target_ref and target_ref != last_commit:
                reasons.append(f"upstream-update({last_commit[:7] if last_commit else 'none'}->{target_ref[:7]})")
            if backend == "rocm" and current_rocm_stamp and current_rocm_stamp != last_rocm_stamp:
                reasons.append(f"rocm-bump({last_rocm_stamp or 'none'}->{current_rocm_stamp})")
            if formula_changed:
                reasons.append("formula-rb-edited")

            if reasons:
                changed_formulas.add(formula)
                if formula == "rocmfpx":
                    rocmfpx_needed = True

                matrix_entry = {
                    "formula": formula,
                    "package": pkg_name,
                    "variant": var_name,
                    "backend": backend,
                    "default": var_info.get("default", False),
                    "runner": var_info.get("runner", "ubuntu-24.04"),
                    "bottle_tag": var_info.get("bottle_tag", "x86_64_linux"),
                    "brew_flags": var_info.get("brew_flags", ""),
                    "amdgpu_targets": var_info.get("amdgpu_targets", ""),
                    "rocm_family": var_info.get("rocm_family", "gfx1151"),
                    "cuda_version": var_info.get("cuda_version", "12.8"),
                    "hw_validate": var_info.get("hw_validate", False),
                    "target_commit": target_ref or last_commit or "HEAD",
                    "target_rocm_stamp": current_rocm_stamp or "",
                    "target_rocm_filename": current_rocm_filename or "",
                    "target_rocm_etag": current_rocm_etag or "",
                    "reasons": reasons
                }
                matrix_includes.append(matrix_entry)

                if var_info.get("hw_validate", False) and backend == "rocm":
                    hw_matrix_includes.append({
                        "formula": formula,
                        "variant": var_name,
                        "target_commit": target_ref or last_commit or "HEAD"
                    })

                audit_table.append({
                    "formula": formula,
                    "variant": var_name,
                    "status": "DIRTY",
                    "reason": ", ".join(reasons),
                    "action": "BUILD"
                })
            else:
                audit_table.append({
                    "formula": formula,
                    "variant": var_name,
                    "status": "UP-TO-DATE",
                    "reason": f"commit={last_commit[:7] if last_commit else 'none'}",
                    "action": "NO-OP"
                })

    has_work = len(matrix_includes) > 0
    matrix_output = {"include": matrix_includes}
    hw_matrix_output = {"include": hw_matrix_includes}

    print("\n" + "=" * 80)
    print(f"{'FORMULA':<22} {'VARIANT':<10} {'STATUS':<12} {'ACTION':<8} {'REASONS / DETAILS'}")
    print("-" * 80)
    for row in audit_table:
        print(f"{row['formula']:<22} {row['variant']:<10} {row['status']:<12} {row['action']:<8} {row['reason']}")
    print("=" * 80)
    print(f"Total jobs to execute: {len(matrix_includes)} | ROCmFPX builder needed: {rocmfpx_needed}")

    # Generate step summary markdown
    summary_lines = [
        "### Heretek-AI Tap Nightly Matrix Change Gate",
        f"- **Resolved ROCm Nightly**: `{current_rocm_filename or 'N/A'}` (Stamp: `{current_rocm_stamp or 'N/A'}`)",
        f"- **Active Jobs Scheduled**: `{len(matrix_includes)}`",
        f"- **ROCmFPX Re-build Required**: `{rocmfpx_needed}`",
        "",
        "| Formula | Variant | Status | Action | Reasons / Details |",
        "| :--- | :--- | :--- | :--- | :--- |"
    ]
    for row in audit_table:
        status_badge = "🟢 Up-to-date" if row['status'] == "UP-TO-DATE" else ("🔴 Rebuild" if row['status'] == "DIRTY" else "⚪ Excluded")
        summary_lines.append(f"| `{row['formula']}` | `{row['variant']}` | {status_badge} | **{row['action']}** | {row['reason']} |")
    summary_md = "\n".join(summary_lines)

    step_summary_path = os.getenv("GITHUB_STEP_SUMMARY")
    if step_summary_path and not args.dry_run:
        with open(step_summary_path, "a", encoding="utf-8") as f:
            f.write(summary_md + "\n")

    github_output_path = os.getenv("GITHUB_OUTPUT")
    if github_output_path and not args.dry_run:
        with open(github_output_path, "a", encoding="utf-8") as f:
            f.write(f"has_work={'true' if has_work else 'false'}\n")
            f.write(f"rocmfpx_needed={'true' if rocmfpx_needed else 'false'}\n")
            f.write(f"changed_formulas={','.join(sorted(changed_formulas))}\n")
            f.write(f"matrix={json.dumps(matrix_output)}\n")
            f.write(f"hw_matrix={json.dumps(hw_matrix_output)}\n")
            f.write(f"rocm_stamp={current_rocm_stamp or ''}\n")
            f.write(f"rocm_filename={current_rocm_filename or ''}\n")
            f.write(f"rocm_etag={current_rocm_etag or ''}\n")
            f.write(f"rocm_index={current_rocm_index or ''}\n")

    if args.dry_run:
        print("\n[DRY RUN] Generated Matrix:")
        print(json.dumps(matrix_output, indent=2))


if __name__ == "__main__":
    main()
