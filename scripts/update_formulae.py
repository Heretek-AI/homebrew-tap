#!/usr/bin/env python3
"""
update_formulae.py: Automated updater for Heretek-AI Homebrew Tap Formulae.
Fetches release asset metadata & SHA256 digests from GitHub Releases and updates Formula files.
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
REPOS = {
    "cachyllama": "Heretek-AI/CachyLLama-BUILDER",
    "rocmfpx": "Heretek-AI/ROCmFPX-BUILDER",
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


def update_formula_content(formula_path: str, release_tag: str, asset_shas: dict, dry_run: bool = False) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    with open(formula_path, "r", encoding="utf-8") as f:
        content = f.read()

    original_content = content

    # Clean version string (e.g. b1001 -> 1001 or 1.0.1)
    version_clean = release_tag.lstrip("v").lstrip("b").replace("llama-ai-", "")
    content = re.sub(r'version\s+"[^"]+"', f'version "{version_clean}"', content, count=1)

    # Function to find matching asset in asset_shas
    def find_matching_asset(old_asset_filename: str):
        # 1. Direct match
        if old_asset_filename in asset_shas:
            return old_asset_filename, asset_shas[old_asset_filename]
        
        # 2. Extract architectural suffix (e.g. ubuntu-rocm-gfx1151-x64.zip or macos-metal-arm64.tar.gz)
        # Matches patterns like: cachy-llama-b1000-ubuntu-rocm-gfx1151-x64.zip or rocmfpx-b1000-...
        suffix_match = re.search(r'((?:ubuntu|macos|windows|linux|cpu|metal|vulkan|rocm).*)', old_asset_filename)
        if suffix_match:
            suffix = suffix_match.group(1)
            for asset_name, sha in asset_shas.items():
                if asset_name.endswith(suffix):
                    return asset_name, sha
        
        # 3. Direct suffix match over all keys
        for asset_name, sha in asset_shas.items():
            if asset_name == old_asset_filename or asset_name.endswith(old_asset_filename):
                return asset_name, sha

        return None, None

    # Replace URL lines
    def url_replacer(match):
        prefix = match.group(1)  # https://github.com/.../download/
        old_tag = match.group(2)  # b1000
        old_filename = match.group(3)  # filename

        matched_name, sha = find_matching_asset(old_filename)
        new_filename = matched_name if matched_name else old_filename
        return f'url "{prefix}{release_tag}/{new_filename}"'

    content = re.sub(
        r'url\s+"(https://github\.com/[^/]+/[^/]+/releases/download/)([^/]+)/([^"]+)"',
        url_replacer,
        content
    )

    # Update individual sha256 lines for matched assets
    for asset_name, sha in asset_shas.items():
        # Match URL block for this asset or its suffix followed by sha256
        suffix_match = re.search(r'((?:ubuntu|macos|windows|linux|cpu|metal|vulkan|rocm).*)', asset_name)
        suffix = suffix_match.group(1) if suffix_match else asset_name

        pattern = rf'(url\s+"https://github\.com/[^/]+/[^/]+/releases/download/[^/]+/[^"]*{re.escape(suffix)}"[^\n]*\n(?:\s*version[^\n]*\n)?\s*sha256\s+")[a-fA-F0-9]+(")'
        content = re.sub(pattern, rf'\g<1>{sha}\g<2>', content)

    if content != original_content:
        if dry_run:
            print(f"[DRY-RUN] Formula {formula_path} has updates:")
            print("---")
        else:
            with open(formula_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[✓] Saved updates to {formula_path}")
        return True
    else:
        print(f"[*] No changes needed for {formula_path}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Update Homebrew Tap Formulae with new releases")
    parser.add_argument("--repo", choices=["cachyllama", "rocmfpx", "all"], default="all", help="Target builder repo")
    parser.add_argument("--tag", default="latest", help="Specific release tag or 'latest'")
    parser.add_argument("--token", default=os.environ.get("GITHUB_TOKEN"), help="GitHub API token")
    parser.add_argument("--formula-dir", default=os.path.join(os.path.dirname(__file__), "..", "Formula"), help="Path to Formula directory")
    parser.add_argument("--dry-run", action="store_true", help="Print updates without modifying files")

    args = parser.parse_args()

    targets = ["cachyllama", "rocmfpx"] if args.repo == "all" else [args.repo]

    for target in targets:
        repo_name = REPOS[target]
        print(f"\n[>] Checking releases for {repo_name}...")
        try:
            rel = get_latest_release(repo_name, args.token, args.tag)
        except Exception as e:
            print(f"[-] Failed to fetch release for {repo_name}: {e}")
            continue

        tag_name = rel.get("tag_name", "")
        print(f"[+] Found release: {tag_name} ({rel.get('name', '')})")

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

        formula_file = "cachy-llama.rb" if target == "cachyllama" else "rocmfpx.rb"
        formula_path = os.path.join(args.formula_dir, formula_file)
        update_formula_content(formula_path, tag_name, asset_shas, args.dry_run)


if __name__ == "__main__":
    main()
