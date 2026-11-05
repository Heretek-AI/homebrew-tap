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

def load_config_from_ledger():
    ledger_path = os.path.join(os.path.dirname(__file__), "..", ".github", "upstream-pins.json")
    if os.path.exists(ledger_path):
        try:
            with open(ledger_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            packages = data.get("packages", {})
            cfg = {}
            for name, pdata in packages.items():
                track = pdata.get("track", "commit")
                if track == "commit":
                    ttype = "upstream_commit"
                elif track == "release":
                    ttype = "upstream_release"
                elif track == "rolling_release":
                    ttype = "rolling_release"
                elif track == "builder":
                    ttype = "builder"
                else:
                    ttype = "upstream_commit"

                entry = {
                    "type": ttype,
                    "repo": pdata.get("repo", name),
                    "branch": pdata.get("branch", "main"),
                    "formulae": [f"{pdata.get('formula', name)}.rb"]
                }
                if name == "rocmfpx":
                    entry["fallback_repo"] = "Heretek-AI/ROCmFPX-BUILDER"
                cfg[name] = entry
            if cfg:
                return cfg
        except Exception:
            pass

    return {
        # Fallback in-repo multi-arch ROCm release tracking
        "rocmfpx": {
            "type": "builder",
            "repo": "Heretek-AI/homebrew-tap",
            "fallback_repo": "Heretek-AI/ROCmFPX-BUILDER",
            "formulae": ["rocmfpx.rb"],
        },
        "shimmy": {
            "type": "upstream_release",
            "repo": "Michael-A-Kuykendall/shimmy",
            "formulae": ["shimmy.rb"],
        },
        "stable-diffusion-cpp": {
            "type": "rolling_release",
            "repo": "leejet/stable-diffusion.cpp",
            "formulae": ["stable-diffusion-cpp.rb"],
        },
        "gufetto": {
            "type": "upstream_commit",
            "repo": "community-token-labs/gufetto",
            "branch": "main",
            "formulae": ["gufetto.rb"],
        },
        "gufo": {
            "type": "upstream_commit",
            "repo": "gufo-org/gufo",
            "branch": "main",
            "formulae": ["gufo.rb"],
        },
        "gufo-franzmoca": {
            "type": "upstream_commit",
            "repo": "franzmoca/gufo",
            "branch": "main",
            "formulae": ["gufo-franzmoca.rb"],
        },
        "strixite": {
            "type": "upstream_commit",
            "repo": "shawnshekari/strixite",
            "branch": "main",
            "formulae": ["strixite.rb"],
        },
        "strata": {
            "type": "upstream_commit",
            "repo": "Niko1221/Strata",
            "branch": "main",
            "formulae": ["strata.rb"],
        },
        "project-maya": {
            "type": "upstream_commit",
            "repo": "mw00/project-maya",
            "branch": "main",
            "formulae": ["project-maya.rb"],
        },
        "kyojin": {
            "type": "upstream_commit",
            "repo": "Yamz-Labs/kyojin",
            "branch": "main",
            "formulae": ["kyojin.rb"],
        },
        "hyperqwen": {
            "type": "upstream_commit",
            "repo": "syv-ai/HyperQwen",
            "branch": "main",
            "formulae": ["hyperqwen.rb"],
        },
    }

CONFIG = load_config_from_ledger()


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


def update_builder_formula_content(formula_path: str, release_tag: str, asset_shas: dict, repo_name: str = None, dry_run: bool = False) -> bool:
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

        suffix_match = re.search(r'(?:^|-)((?:ubuntu|macos|windows|linux|cpu|metal|vulkan|rocm|q38rocm)-.*)', old_asset_filename)
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
        new_prefix = f"https://github.com/{repo_name}/releases/download/" if repo_name else prefix
        return f'url "{new_prefix}{release_tag}/{matched_name}"'

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
            print(f"[OK] Saved updates to {formula_path}")
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
            print(f"[OK] Updated {formula_path} to {tag_name}")
        return True
    else:
        print(f"[*] No changes needed for {formula_path} (already at {tag_name})")
        return False


def update_upstream_commit_formula(formula_path: str, repo: str, branch: str = "main", token: str = None, commit_sha: str = None, sha256_digest: str = None, dry_run: bool = False) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    if not commit_sha:
        commit_data = get_latest_commit(repo, branch, token)
        commit_sha = commit_data.get("sha", "")
        commit_date = commit_data.get("commit", {}).get("committer", {}).get("date", "")[:10].replace("-", ".")
    else:
        commit_date = time.strftime("%Y.%m.%d", time.gmtime())

    if not commit_sha:
        print(f"[-] No commit SHA found for {repo}/{branch}")
        return False

    tarball_url = f"https://github.com/{repo}/archive/{commit_sha}.tar.gz"
    if not sha256_digest:
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
    current_ver_match = re.search(r'version\s+"([^"]+)"', content)
    base_version = "0.0.0"
    if current_ver_match:
        base_version = current_ver_match.group(1).split("-git")[0]
    new_version = f"{base_version}-git{commit_sha[:7]}"

    content = re.sub(
        r'version\s+"[^"]+"',
        f'version "{new_version}"',
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
            print(f"[OK] Updated {formula_path} to commit {commit_sha[:7]} ({commit_date})")
        return True
    else:
        print(f"[*] No changes needed for {formula_path} (already at {commit_sha[:7]})")
        return False


def update_rolling_release_formula(formula_path: str, repo: str, token: str = None, tag: str = "latest", dry_run: bool = False) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    rel = get_latest_release(repo, token, tag)
    tag_name = rel.get("tag_name", "")
    if not tag_name:
        print(f"[-] No release tag found for {repo}")
        return False

    print(f"[+] Found rolling release: {tag_name} ({rel.get('name', '')})")

    version_match = re.search(r'master-(\d+)', tag_name)
    version_str = version_match.group(1) if version_match else tag_name

    asset_map = {}
    for asset in rel.get("assets", []):
        name = asset.get("name", "")
        dl_url = asset.get("browser_download_url", "")
        role = None
        if ("Darwin" in name or "macOS" in name) and "arm64" in name:
            role = "darwin_arm64"
        elif "Linux" in name and "rocm" in name:
            role = "linux_rocm"
        elif "Linux" in name and "vulkan" in name:
            role = "linux_vulkan"
        elif "Linux" in name and not ("rocm" in name or "vulkan" in name) and ("x86_64" in name or "x64" in name):
            role = "linux_cpu"

        if role:
            digest = asset.get("digest")
            if digest and digest.startswith("sha256:"):
                sha = digest.split("sha256:")[1]
            else:
                print(f"[*] Downloading {name} to compute SHA256...")
                try:
                    sha = download_and_compute_sha256(dl_url, token)
                except Exception as ex:
                    print(f"[-] Error downloading {name}: {ex}")
                    continue
            asset_map[role] = {"name": name, "url": dl_url, "sha256": sha}

    with open(formula_path, "r", encoding="utf-8") as f:
        content = f.read()

    original_content = content

    content = re.sub(r'version\s+"[^"]+"', f'version "{version_str}"', content, count=1)

    if "darwin_arm64" in asset_map:
        info = asset_map["darwin_arm64"]
        content = re.sub(
            rf'url\s+"https://github\.com/{re.escape(repo)}/releases/download/[^/]+/sd-master-[^"]+Darwin[^"]+"\s*\n\s*sha256\s+"[a-fA-F0-9]+"',
            f'url "{info["url"]}"\n      sha256 "{info["sha256"]}"',
            content,
        )

    if "linux_rocm" in asset_map:
        info = asset_map["linux_rocm"]
        content = re.sub(
            rf'url\s+"https://github\.com/{re.escape(repo)}/releases/download/[^/]+/sd-master-[^"]+Linux[^"]+rocm[^"]+"\s*\n\s*sha256\s+"[a-fA-F0-9]+"',
            f'url "{info["url"]}"\n        sha256 "{info["sha256"]}"',
            content,
        )

    if "linux_cpu" in asset_map:
        info = asset_map["linux_cpu"]
        content = re.sub(
            rf'url\s+"https://github\.com/{re.escape(repo)}/releases/download/[^/]+/sd-master-[^"]+Linux[^"]+x86_64\.zip"\s*\n\s*sha256\s+"[a-fA-F0-9]+"',
            f'url "{info["url"]}"\n        sha256 "{info["sha256"]}"',
            content,
        )

    if "linux_vulkan" in asset_map:
        info = asset_map["linux_vulkan"]
        content = re.sub(
            rf'url\s+"https://github\.com/{re.escape(repo)}/releases/download/[^/]+/sd-master-[^"]+Linux[^"]+vulkan\.zip"\s*\n\s*sha256\s+"[a-fA-F0-9]+"',
            f'url "{info["url"]}"\n        sha256 "{info["sha256"]}"',
            content,
        )

    if content != original_content:
        if dry_run:
            print(f"[DRY-RUN] Rolling release formula {formula_path} has updates -> tag: {tag_name}")
        else:
            with open(formula_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[OK] Updated {formula_path} to {tag_name}")
        return True
    else:
        print(f"[*] No changes needed for {formula_path} (already at {tag_name})")
        return False


# Backward compatibility alias
update_formula_content = update_builder_formula_content


def main():
    parser = argparse.ArgumentParser(description="Update Homebrew Tap Formulae with new releases and commits")
    parser.add_argument(
        "--repo",
        choices=list(CONFIG.keys()) + ["all"],
        default="all",
        help="Target builder repo or formula key",
    )
    parser.add_argument("--tag", default="latest", help="Specific release tag or 'latest'")
    parser.add_argument("--commit", default=None, help="Explicit target commit SHA for upstream_commit formulae")
    parser.add_argument("--sha256", default=None, help="Precomputed sha256 checksum for the archive")
    parser.add_argument("--token", default=os.environ.get("GITHUB_TOKEN"), help="GitHub API token")
    parser.add_argument("--formula-dir", default=os.path.join(os.path.dirname(__file__), "..", "Formula"), help="Path to Formula directory")
    parser.add_argument("--dry-run", action="store_true", help="Print updates without modifying files")

    args = parser.parse_args()

    targets = list(CONFIG.keys()) if args.repo == "all" else [args.repo]

    updated_targets = []

    for target in targets:
        cfg = CONFIG[target]
        target_type = cfg["type"]
        repo_name = cfg["repo"]
        formula_files = cfg.get("formulae", [])

        print(f"\n[>] Processing {target} ({repo_name}, type: {target_type})...")

        for formula_file in formula_files:
            formula_path = os.path.join(args.formula_dir, formula_file)
            changed = False

            if target_type == "builder":
                rel = None
                try:
                    rel = get_latest_release(repo_name, args.token, args.tag)
                except urllib.error.HTTPError as e:
                    fallback = cfg.get("fallback_repo")
                    if fallback and e.code == 404:
                        print(f"[*] No release found on {repo_name}; checking fallback {fallback}...")
                        try:
                            rel = get_latest_release(fallback, args.token, args.tag)
                        except Exception as e2:
                            print(f"[-] Failed to fetch fallback release for {fallback}: {e2}")
                            continue
                    else:
                        print(f"[-] Failed to fetch release for {repo_name}: {e}")
                        continue
                except Exception as e:
                    fallback = cfg.get("fallback_repo")
                    if fallback:
                        try:
                            rel = get_latest_release(fallback, args.token, args.tag)
                        except Exception as e2:
                            print(f"[-] Failed to fetch fallback release for {fallback}: {e2}")
                            continue
                    else:
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

                changed = update_builder_formula_content(formula_path, tag_name, asset_shas, repo_name=repo_name, dry_run=args.dry_run)

            elif target_type == "upstream_release":
                try:
                    changed = update_upstream_release_formula(formula_path, repo_name, args.token, args.tag, args.dry_run)
                except Exception as e:
                    print(f"[-] Failed to update upstream release formula {formula_file}: {e}")

            elif target_type == "rolling_release":
                try:
                    changed = update_rolling_release_formula(formula_path, repo_name, args.token, args.tag, args.dry_run)
                except Exception as e:
                    print(f"[-] Failed to update rolling release formula {formula_file}: {e}")

            elif target_type == "upstream_commit":
                branch = cfg.get("branch", "main")
                try:
                    changed = update_upstream_commit_formula(
                        formula_path,
                        repo_name,
                        branch=branch,
                        token=args.token,
                        commit_sha=args.commit,
                        sha256_digest=args.sha256,
                        dry_run=args.dry_run
                    )
                except Exception as e:
                    print(f"[-] Failed to update upstream commit formula {formula_file}: {e}")

            if changed and target not in updated_targets:
                updated_targets.append(target)

    if "GITHUB_OUTPUT" in os.environ and os.path.exists(os.environ["GITHUB_OUTPUT"]):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(f"updated_targets={','.join(updated_targets)}\n")
            f.write(f"has_updates={'true' if updated_targets else 'false'}\n")
    print(f"\n[*] Summary: {len(updated_targets)} formula(e) updated: {', '.join(updated_targets) if updated_targets else 'none'}")


if __name__ == "__main__":
    main()
