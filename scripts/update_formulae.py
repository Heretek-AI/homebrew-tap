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
    content = re.sub(r'version ".*?"', f'version "{version_clean}"', content, count=1)

    # Update asset download URLs and SHAs
    for asset_name, sha in asset_shas.items():
        # Match URL pattern containing download/TAG/...
        # Replace download/[^/]+/asset_name with download/release_tag/asset_name
        pattern = rf'(url "https://github\.com/[^/]+/[^/]+/releases/download/)[^/]+/({re.escape(asset_name)}"\s*\n\s*sha256 ")[a-fA-F0-9]+(")'
        
        def repl(m):
            return f"{m.group(1)}{release_tag}/{m.group(2)}{sha}{m.group(3)}"

        content, count = re.subn(pattern, repl, content)
        if count > 0:
            print(f"[+] Updated {asset_name} -> {sha[:12]}...")

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
