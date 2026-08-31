#!/usr/bin/env python3
"""
update_formulae.py: Automated updater for Heretek-AI Homebrew Tap Formulae.
Supports:
1. Multi-asset BUILDER releases (CachyLLama, ROCmFPX, Ember, etc.)
2. Upstream GitHub Releases with semantic tags (Shimmy, etc.)
3. Upstream rolling branch commits (Prima.cpp, etc.)
"""

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.request

GITHUB_API_BASE = "https://api.github.com/repos"

CONFIG = {
    # BUILDER multi-asset releases
    "cachyllama": {
        "type": "builder",
        "repo": "Heretek-AI/CachyLLama-BUILDER",
        "formulae": ["cachy-llama.rb", "llama-ai.rb"],
    },
    "rocmfpx": {
        "type": "builder",
        "repo": "Heretek-AI/ROCmFPX-BUILDER",
        "formulae": ["rocmfpx.rb"],
    },
    "ciru-rocmfpx": {
        "type": "builder",
        "repo": "Heretek-AI/ROCmFPX-BUILDER",
        "formulae": ["ciru-rocmfpx.rb"],
    },
    "q38rocm": {
        "type": "builder",
        "repo": "Heretek-AI/ROCmFPX-BUILDER",
        "formulae": ["q38rocm.rb"],
    },
    "ember": {
        "type": "builder",
        "repo": "Heretek-AI/ember-BUILDER",
        "formulae": ["ember.rb"],
    },

    # Upstream source release tracking
    "shimmy": {
        "type": "upstream_release",
        "repo": "Michael-A-Kuykendall/shimmy",
        "formulae": ["shimmy.rb"],
    },

    # Upstream rolling commit tracking
    "prima-cpp": {
        "type": "upstream_commit",
        "repo": "OpenCPIL/prima.cpp",
        "branch": "main",
        "formulae": ["prima-cpp.rb"],
    },
}


def fetch_json(url: str, token: str = None) -> dict:
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Homebrew-Tap-Updater")
    req.add_header("Accept", "application/vnd.github+json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def download_and_compute_sha256(url: str, token: str = None) -> str:
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Homebrew-Tap-Updater")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    hasher = hashlib.sha256()
    with urllib.request.urlopen(req) as resp:
        while chunk := resp.read(65536):
            hasher.update(chunk)
    return hasher.hexdigest()


def get_latest_release(repo: str, token: str = None, tag: str = None) -> dict:
    if tag and tag != "latest":
        url = f"{GITHUB_API_BASE}/{repo}/releases/tags/{tag}"
    else:
        url = f"{GITHUB_API_BASE}/{repo}/releases/latest"
    return fetch_json(url, token)


def get_latest_commit(repo: str, branch: str = "main", token: str = None) -> dict:
    url = f"{GITHUB_API_BASE}/{repo}/commits/{branch}"
    return fetch_json(url, token)


def update_builder_formula_content(formula_path: str, release_tag: str, asset_shas: dict, dry_run: bool = False) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    with open(formula_path, "r", encoding="utf-8") as f:
        content = f.read()

    original_content = content

    version_clean = release_tag.lstrip("v").lstrip("b").replace("llama-ai-", "")
    content = re.sub(r'version\s+"[^"]+"', f'version "{version_clean}"', content, count=1)

    def find_matching_asset(old_asset_filename: str):
        if old_asset_filename in asset_shas:
            return old_asset_filename, asset_shas[old_asset_filename]

        stripped = None
        if re.match(r'^[A-Za-z0-9._-]+?-b\d+', old_asset_filename):
            stripped = re.sub(r'-b\d+', f'-{release_tag}', old_asset_filename, count=1)
        if stripped and stripped in asset_shas:
            return stripped, asset_shas[stripped]

        prefix_match = re.match(r'^([a-zA-Z0-9._-]+?)-b\d+', old_asset_filename)
        expected_prefix = prefix_match.group(1) if prefix_match else ""

        suffix_match = re.search(r'(?:^|-)((?:ubuntu|macos|windows|linux|cpu|metal|vulkan|q38rocm)-.*)', old_asset_filename)
        if suffix_match:
            suffix = suffix_match.group(1)
            for asset_name, sha in asset_shas.items():
                if expected_prefix and asset_name.startswith(expected_prefix) and asset_name.endswith(suffix):
                    return asset_name, sha
            for asset_name, sha in asset_shas.items():
                if asset_name.endswith(suffix):
                    return asset_name, sha

        for asset_name, sha in asset_shas.items():
            if asset_name == old_asset_filename or asset_name.endswith(old_asset_filename):
                return asset_name, sha

        return None, None

    def url_replacer(match):
        prefix = match.group(1)
        old_tag = match.group(2)
        old_filename = match.group(3)

        matched_name, sha = find_matching_asset(old_filename)
        if not matched_name:
            print(f"[*] No matching asset for {old_filename}; keeping {old_tag} URL")
            return match.group(0)
        return f'url "{prefix}{release_tag}/{matched_name}"'

    content = re.sub(
        r'url\s+"(https://github\.com/[^/]+/[^/]+/releases/download/)([^/]+)/([^"]+)"',
        url_replacer,
        content,
    )

    for asset_name, sha in asset_shas.items():
        suffix_match = re.search(r'((?:ubuntu|macos|windows|linux|cpu|metal|vulkan|rocm|q38rocm).*)', asset_name)
        suffix = suffix_match.group(1) if suffix_match else asset_name

        pattern = rf'(url\s+"https://github\.com/[^/]+/[^/]+/releases/download/[^/]+/[^"]*{re.escape(suffix)}"[^\n]*\n(?:\s*version[^\n]*\n)?\s*sha256\s+")[a-fA-F0-9]+(")'
        content = re.sub(pattern, rf'\g<1>{sha}\g<2>', content)

    if content != original_content:
        if dry_run:
            print(f"[DRY-RUN] Formula {formula_path} has updates:")
        else:
            with open(formula_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[✓] Saved updates to {formula_path}")
        return True
    else:
        print(f"[*] No changes needed for {formula_path}")
        return False


def update_upstream_release_formula(formula_path: str, repo: str, token: str = None, tag: str = "latest", dry_run: bool = False) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    rel = get_latest_release(repo, token, tag)
    tag_name = rel.get("tag_name", "")
    if not tag_name:
        print(f"[-] No release tag found for {repo}")
        return False

    tarball_url = f"https://github.com/{repo}/archive/refs/tags/{tag_name}.tar.gz"
    print(f"[*] Computing SHA256 for upstream release {tag_name} ({tarball_url})...")
    sha256_digest = download_and_compute_sha256(tarball_url, token)

    with open(formula_path, "r", encoding="utf-8") as f:
        content = f.read()

    original_content = content

    # Replace URL and SHA256
    content = re.sub(
        r'url\s+"https://github\.com/[^/]+/[^/]+/archive/refs/tags/[^"]+"',
        f'url "{tarball_url}"',
        content,
    )
    content = re.sub(
        r'sha256\s+"[a-fA-F0-9]+"',
        f'sha256 "{sha256_digest}"',
        content,
        count=1,
    )

    if content != original_content:
        if dry_run:
            print(f"[DRY-RUN] Upstream release formula {formula_path} has updates -> tag: {tag_name}, sha256: {sha256_digest}")
        else:
            with open(formula_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[✓] Updated {formula_path} to {tag_name}")
        return True
    else:
        print(f"[*] No changes needed for {formula_path} (already at {tag_name})")
        return False


def update_upstream_commit_formula(formula_path: str, repo: str, branch: str = "main", token: str = None, dry_run: bool = False) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    commit_data = get_latest_commit(repo, branch, token)
    commit_sha = commit_data.get("sha", "")
    commit_date = commit_data.get("commit", {}).get("committer", {}).get("date", "")[:10].replace("-", ".")
    if not commit_sha:
        print(f"[-] No commit SHA found for {repo}/{branch}")
        return False

    tarball_url = f"https://github.com/{repo}/archive/{commit_sha}.tar.gz"
    print(f"[*] Computing SHA256 for commit {commit_sha[:7]} ({tarball_url})...")
    sha256_digest = download_and_compute_sha256(tarball_url, token)

    with open(formula_path, "r", encoding="utf-8") as f:
        content = f.read()

    original_content = content

    content = re.sub(
        r'url\s+"https://github\.com/[^/]+/[^/]+/archive/[a-fA-F0-9]+\.tar\.gz"',
        f'url "{tarball_url}"',
        content,
    )
    content = re.sub(
        r'version\s+"[^"]+"',
        f'version "{commit_date}"',
        content,
        count=1,
    )
    content = re.sub(
        r'sha256\s+"[a-fA-F0-9]+"',
        f'sha256 "{sha256_digest}"',
        content,
        count=1,
    )

    if content != original_content:
        if dry_run:
            print(f"[DRY-RUN] Upstream commit formula {formula_path} has updates -> commit: {commit_sha[:7]} ({commit_date}), sha256: {sha256_digest}")
        else:
            with open(formula_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[✓] Updated {formula_path} to commit {commit_sha[:7]} ({commit_date})")
        return True
    else:
        print(f"[*] No changes needed for {formula_path} (already at {commit_sha[:7]})")
        return False


def main():
    parser = argparse.ArgumentParser(description="Update Homebrew Tap Formulae with new releases and commits")
    parser.add_argument(
        "--repo",
        choices=list(CONFIG.keys()) + ["all"],
        default="all",
        help="Target builder repo or formula key",
    )
    parser.add_argument("--tag", default="latest", help="Specific release tag or 'latest'")
    parser.add_argument("--token", default=os.environ.get("GITHUB_TOKEN"), help="GitHub API token")
    parser.add_argument("--formula-dir", default=os.path.join(os.path.dirname(__file__), "..", "Formula"), help="Path to Formula directory")
    parser.add_argument("--dry-run", action="store_true", help="Print updates without modifying files")

    args = parser.parse_args()

    targets = list(CONFIG.keys()) if args.repo == "all" else [args.repo]

    for target in targets:
        cfg = CONFIG[target]
        target_type = cfg["type"]
        repo_name = cfg["repo"]
        formula_files = cfg.get("formulae", [])

        print(f"\n[>] Processing {target} ({repo_name}, type: {target_type})...")

        for formula_file in formula_files:
            formula_path = os.path.join(args.formula_dir, formula_file)

            if target_type == "builder":
                try:
                    rel = get_latest_release(repo_name, args.token, args.tag)
                except Exception as e:
                    print(f"[-] Failed to fetch release for {repo_name}: {e}")
                    continue

                tag_name = rel.get("tag_name", "")
                print(f"[+] Found builder release: {tag_name} ({rel.get('name', '')})")

                asset_shas = {}
                for asset in rel.get("assets", []):
                    name = asset.get("name")
                    digest = asset.get("digest")
                    if digest and digest.startswith("sha256:"):
                        sha = digest.split("sha256:")[1]
                    else:
                        download_url = asset.get("browser_download_url")
                        print(f"[*] Downloading {name} to compute SHA256...")
                        try:
                            sha = download_and_compute_sha256(download_url, args.token)
                        except Exception as ex:
                            print(f"[-] Error downloading {name}: {ex}")
                            continue
                    asset_shas[name] = sha

                update_builder_formula_content(formula_path, tag_name, asset_shas, args.dry_run)

            elif target_type == "upstream_release":
                try:
                    update_upstream_release_formula(formula_path, repo_name, args.token, args.tag, args.dry_run)
                except Exception as e:
                    print(f"[-] Failed to update upstream release formula {formula_file}: {e}")

            elif target_type == "upstream_commit":
                branch = cfg.get("branch", "main")
                try:
                    update_upstream_commit_formula(formula_path, repo_name, branch, args.token, args.dry_run)
                except Exception as e:
                    print(f"[-] Failed to update upstream commit formula {formula_file}: {e}")


if __name__ == "__main__":
    main()
