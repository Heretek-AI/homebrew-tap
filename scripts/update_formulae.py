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
import time
import urllib.error
import urllib.request
from typing import Dict, Optional, Tuple

GITHUB_API_BASE = "https://api.github.com/repos"


def load_config_from_ledger():
    ledger_path = os.path.join(
        os.path.dirname(__file__), "..", ".github", "upstream-pins.json"
    )
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
                    "formulae": [f"{pdata.get('formula', name)}.rb"],
                }
                cfg[name] = entry
            if cfg:
                return cfg
        except Exception:
            pass

    return {
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
        "gufo": {
            "type": "upstream_commit",
            "repo": "gufo-org/gufo",
            "branch": "main",
            "formulae": ["gufo.rb"],
        },
        "gufo-ds41": {
            "type": "upstream_release",
            "repo": "franzmoca/ds41-gufo-extension",
            "formulae": ["gufo-ds41.rb"],
        },
        "rulith-inference": {
            "type": "upstream_commit",
            "repo": "rulith-dev/llama.cpp",
            "branch": "rulith",
            "formulae": ["rulith-inference.rb"],
        },
        "strixite": {
            "type": "upstream_commit",
            "repo": "shawnshekari/strixite",
            "branch": "main",
            "formulae": ["strixite.rb"],
        },
        "strixolotl": {
            "type": "upstream_commit",
            "repo": "snowsh1ne/strixolotl",
            "branch": "main",
            "formulae": ["strixolotl.rb"],
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

# Per-formula release-asset families. Prefixes are intentionally formula
# specific: rocmfpx must never accept kingjones-rocmfpx or q38rocm assets.
ASSET_RULES: Dict[str, Dict[str, Tuple[str, ...]]] = {
    "rocmfpx.rb": {
        "prefixes": ("rocmfpx-",),
        "excludes": ("-q38rocm", "-kairic-edge", "-promptforge"),
    },
}

_ARCHIVE_SUFFIX_RE = re.compile(r"\.(?:zip|tar\.gz|tar\.xz|tgz)$", re.IGNORECASE)
_RELEASE_TAG_PATTERNS = (
    re.compile(r"(?:^|-)llama-ai-b\d+(?=-|$)", re.IGNORECASE),
    re.compile(r"(?:^|-)b\d+(?=-|$)", re.IGNORECASE),
    re.compile(r"(?:^|-)master-\d+-[0-9a-f]{7,40}(?=-|$)", re.IGNORECASE),
)
_PREFIX_TOKENS = tuple(
    sorted(
        (
            "kingjones-rocmfpx",
            "ciru-rocmfpx",
            "stable-diffusion",
            "cachy-llama",
            "engramhalo",
            "q38rocm",
            "llama-ai",
            "rocmfpx",
            "ember",
            "bin",
            "sd",
        ),
        key=len,
        reverse=True,
    )
)

_RELEASE_URL_PAIR_RE = re.compile(
    r'(?P<url_prefix>url\s+"https://github\.com/[^/"]+/[^/"]+/releases/download/)'
    r'(?P<tag>[^/"]+)/(?P<filename>[^"]+)"\n'
    r'(?P<extra>(?:[ \t]*version\s+"[^"]+"\n)?)'
    r'(?P<sha_indent>[ \t]*)sha256\s+"(?P<sha>[0-9a-fA-F]{64})"'
)


def get_asset_rules(formula_path: str) -> Dict[str, Tuple[str, ...]]:
    return ASSET_RULES.get(os.path.basename(formula_path), {})


def is_asset_allowed(asset_name: str, rules: Dict[str, Tuple[str, ...]]) -> bool:
    if ".bottle." in asset_name or asset_name.endswith(".bottle.json"):
        return False

    if any(asset_name.startswith(prefix) for prefix in rules.get("prefixes", ())):
        return not any(marker in asset_name for marker in rules.get("excludes", ()))

    legacy_prefixes = rules.get("legacy_prefixes", ())
    legacy_markers = rules.get("legacy_markers", ())
    return bool(
        legacy_prefixes
        and legacy_markers
        and any(asset_name.startswith(prefix) for prefix in legacy_prefixes)
        and any(marker in asset_name for marker in legacy_markers)
    )


def asset_role(filename: str) -> str:
    """Return a tag-independent role such as ubuntu-rocm-gfx1151-x64."""
    name = _ARCHIVE_SUFFIX_RE.sub("", filename)
    name = re.sub(r"^sd-master-[0-9a-f]+-bin-", "", name, flags=re.IGNORECASE)

    for pattern in _RELEASE_TAG_PATTERNS:
        name = pattern.sub("", name)

    for token in _PREFIX_TOKENS:
        name = re.sub(
            rf"(?:^|-){re.escape(token)}(?=-|$)", "", name, flags=re.IGNORECASE
        )

    name = re.sub(r"(?:^|-)q38rocm(?=-|$)", "", name, flags=re.IGNORECASE)
    return re.sub(r"-{2,}", "-", name).strip("-").lower()


def sd_asset_role(filename: str) -> Optional[str]:
    name = filename.lower()
    if "darwin" in name or "macos" in name:
        return "darwin-arm64" if "arm64" in name else "darwin-x86_64"
    if "linux" not in name:
        return None
    if "rocm" in name:
        return "linux-rocm"
    if "vulkan" in name:
        return "linux-vulkan"
    if "x86_64" in name or "x64" in name:
        return "linux-cpu"
    return None


def find_matching_asset(
    old_filename: str,
    asset_shas: Dict[str, str],
    rules: Dict[str, Tuple[str, ...]],
    role_function=asset_role,
) -> Tuple[Optional[str], Optional[str]]:
    allowed = {
        name: sha for name, sha in asset_shas.items() if is_asset_allowed(name, rules)
    }
    if old_filename in allowed:
        return old_filename, allowed[old_filename]

    old_role = role_function(old_filename)
    if not old_role:
        return None, None

    matches = [
        (name, sha) for name, sha in allowed.items() if role_function(name) == old_role
    ]
    if not matches:
        return None, None

    if len(matches) > 1:
        for prefix in (*rules.get("prefixes", ()), *rules.get("legacy_prefixes", ())):
            if not old_filename.startswith(prefix):
                continue
            same_family = [match for match in matches if match[0].startswith(prefix)]
            if same_family:
                matches = same_family
            break

    return matches[0]


def _release_version(release_tag: str) -> str:
    version = release_tag.lstrip("v").removeprefix("llama-ai-")
    version = version.removeprefix("b")
    return version.replace("master-", "")


def find_latest_release_with_assets(
    repo: str,
    formula_path: str,
    token: Optional[str] = None,
    max_pages: int = 3,
) -> Optional[dict]:
    """Find the newest release that actually contains assets for this formula."""
    rules = get_asset_rules(formula_path)

    for page in range(1, max_pages + 1):
        url = f"{GITHUB_API_BASE}/{repo}/releases?per_page=100&page={page}"
        releases = fetch_json(url, token)
        if not isinstance(releases, list) or not releases:
            break

        for release in releases:
            if release.get("draft") or release.get("prerelease"):
                continue
            if any(
                is_asset_allowed(asset.get("name", ""), rules)
                for asset in release.get("assets", [])
            ):
                return release

    return None


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


def update_builder_formula_content(
    formula_path: str,
    release_tag: str,
    asset_shas: Dict[str, str],
    repo_name: str = None,
    dry_run: bool = False,
    asset_rules: Dict[str, Tuple[str, ...]] = None,
) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    with open(formula_path, "r", encoding="utf-8") as f:
        content = f.read()

    rules = asset_rules or get_asset_rules(formula_path)
    matched_count = 0

    def url_replacer(match: re.Match) -> str:
        nonlocal matched_count
        old_filename = match.group("filename")
        matched_name, sha = find_matching_asset(old_filename, asset_shas, rules)
        if not matched_name:
            print(f"[*] No matching asset for {old_filename}; keeping existing URL")
            return match.group(0)

        matched_count += 1
        prefix = (
            f"https://github.com/{repo_name}/releases/download/"
            if repo_name
            else match.group("url_prefix").split('"', 1)[1]
        )
        return (
            f'url "{prefix}{release_tag}/{matched_name}"\n'
            f"{match.group('extra')}"
            f'{match.group("sha_indent")}sha256 "{sha}"'
        )

    updated_content = _RELEASE_URL_PAIR_RE.sub(url_replacer, content)

    if matched_count == 0:
        print(f"[*] No matching assets for {formula_path}; version left unchanged")
        return False

    version = _release_version(release_tag)
    updated_content = re.sub(
        r'version\s+"[^"]+"',
        f'version "{version}"',
        updated_content,
        count=1,
    )

    if updated_content == content:
        print(f"[*] No changes needed for {formula_path}")
        return False

    if dry_run:
        print(f"[DRY-RUN] Formula {formula_path} has updates for {release_tag}")
    else:
        with open(formula_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
        print(f"[OK] Saved updates to {formula_path} ({release_tag})")
    return True


def update_upstream_release_formula(
    formula_path: str,
    repo: str,
    token: str = None,
    tag: str = "latest",
    dry_run: bool = False,
) -> bool:
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

    # Replace the tag-archive URL together with the sha256 that immediately
    # follows it. Rewriting the first sha256 in the file independently would
    # corrupt formulae whose first checksum belongs to a different URL (e.g.
    # gufo-ds41, whose main archive is pinned to a commit while the tag archive
    # belongs to a resource block).
    url_and_sha = re.compile(
        r'(url\s+")https://github\.com/[^/]+/[^/]+/archive/refs/tags/[^"]+("\s*\n\s*sha256\s+")[a-fA-F0-9]+(")'
    )
    content, replacements = url_and_sha.subn(
        lambda m: f"{m.group(1)}{tarball_url}{m.group(2)}{sha256_digest}{m.group(3)}",
        content,
        count=1,
    )

    if content != original_content:
        if dry_run:
            print(
                f"[DRY-RUN] Upstream release formula {formula_path} has updates -> tag: {tag_name}, sha256: {sha256_digest}"
            )
        else:
            with open(formula_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"[OK] Updated {formula_path} to {tag_name}")
        return True
    else:
        print(f"[*] No changes needed for {formula_path} (already at {tag_name})")
        return False


def update_upstream_commit_formula(
    formula_path: str,
    repo: str,
    branch: str = "main",
    token: str = None,
    commit_sha: str = None,
    sha256_digest: str = None,
    dry_run: bool = False,
) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    if not commit_sha:
        commit_data = get_latest_commit(repo, branch, token)
        commit_sha = commit_data.get("sha", "")
        commit_date = (
            commit_data.get("commit", {})
            .get("committer", {})
            .get("date", "")[:10]
            .replace("-", ".")
        )
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
            print(
                f"[DRY-RUN] Upstream commit formula {formula_path} has updates -> commit: {commit_sha[:7]} ({commit_date}), sha256: {sha256_digest}"
            )
        else:
            with open(formula_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(
                f"[OK] Updated {formula_path} to commit {commit_sha[:7]} ({commit_date})"
            )
        return True
    else:
        print(f"[*] No changes needed for {formula_path} (already at {commit_sha[:7]})")
        return False


def update_rolling_release_formula(
    formula_path: str,
    repo: str,
    token: str = None,
    tag: str = "latest",
    dry_run: bool = False,
) -> bool:
    if not os.path.exists(formula_path):
        print(f"[-] Formula not found: {formula_path}")
        return False

    rel = get_latest_release(repo, token, tag)
    tag_name = rel.get("tag_name", "")
    if not tag_name:
        print(f"[-] No release tag found for {repo}")
        return False

    print(f"[+] Found rolling release: {tag_name} ({rel.get('name', '')})")

    version_match = re.search(r"master-(\d+)", tag_name)
    version_str = version_match.group(1) if version_match else tag_name

    asset_map: Dict[str, Tuple[str, str]] = {}
    for asset in rel.get("assets", []):
        name = asset.get("name", "")
        role = sd_asset_role(name)
        if not role or role in asset_map:
            continue

        digest = asset.get("digest")
        if digest and digest.startswith("sha256:"):
            sha = digest.split("sha256:", 1)[1]
        else:
            print(f"[*] Downloading {name} to compute SHA256...")
            try:
                sha = download_and_compute_sha256(
                    asset.get("browser_download_url"), token
                )
            except Exception as ex:
                print(f"[-] Error downloading {name}: {ex}")
                continue
        asset_map[role] = (name, sha)

    with open(formula_path, "r", encoding="utf-8") as f:
        content = f.read()

    matched_count = 0

    def url_replacer(match: re.Match) -> str:
        nonlocal matched_count
        role = sd_asset_role(match.group("filename"))
        if role is None or role not in asset_map:
            print(
                f"[*] No matching asset for {match.group('filename')}; keeping existing URL"
            )
            return match.group(0)

        matched_count += 1
        name, sha = asset_map[role]
        return (
            f'url "https://github.com/{repo}/releases/download/{tag_name}/{name}"\n'
            f"{match.group('extra')}"
            f'{match.group("sha_indent")}sha256 "{sha}"'
        )

    updated_content = _RELEASE_URL_PAIR_RE.sub(url_replacer, content)

    if matched_count == 0:
        print(f"[*] No matching assets for {formula_path}; version left unchanged")
        return False

    updated_content = re.sub(
        r'version\s+"[^"]+"',
        f'version "{version_str}"',
        updated_content,
        count=1,
    )

    if updated_content == content:
        print(f"[*] No changes needed for {formula_path} (already at {tag_name})")
        return False

    if dry_run:
        print(f"[DRY-RUN] Rolling release formula {formula_path} -> tag: {tag_name}")
    else:
        with open(formula_path, "w", encoding="utf-8") as f:
            f.write(updated_content)
        print(f"[OK] Updated {formula_path} to {tag_name}")
    return True


# Backward compatibility alias
update_formula_content = update_builder_formula_content


def _resolve_builder_release(cfg, formula_path, token, tag):
    repo = cfg["repo"]

    if tag == "latest":
        try:
            release = find_latest_release_with_assets(repo, formula_path, token)
        except Exception as e:
            print(f"[-] Failed to fetch release for {repo}: {e}")
            return None, None

        if release:
            return release, repo
        return None, None

    try:
        release = get_latest_release(repo, token, tag)
    except Exception as e:
        print(f"[-] Failed to fetch release for {repo}: {e}")
        return None, None

    if release:
        return release, repo

    return None, None


def _release_asset_shas(release, token):
    asset_shas = {}
    for asset in release.get("assets", []):
        name = asset.get("name")
        if not name:
            continue
        digest = asset.get("digest")
        if digest and digest.startswith("sha256:"):
            asset_shas[name] = digest.split("sha256:", 1)[1]
            continue

        download_url = asset.get("browser_download_url")
        print(f"[*] Downloading {name} to compute SHA256...")
        try:
            asset_shas[name] = download_and_compute_sha256(download_url, token)
        except Exception as ex:
            print(f"[-] Error downloading {name}: {ex}")
    return asset_shas


def main():
    parser = argparse.ArgumentParser(
        description="Update Homebrew Tap Formulae with new releases and commits"
    )
    parser.add_argument(
        "--repo",
        choices=list(CONFIG.keys()) + ["all"],
        default="all",
        help="Target builder repo or formula key",
    )
    parser.add_argument(
        "--tag", default="latest", help="Specific release tag or 'latest'"
    )
    parser.add_argument(
        "--commit",
        default=None,
        help="Explicit target commit SHA for upstream_commit formulae",
    )
    parser.add_argument(
        "--sha256", default=None, help="Precomputed sha256 checksum for the archive"
    )
    parser.add_argument(
        "--token", default=os.environ.get("GITHUB_TOKEN"), help="GitHub API token"
    )
    parser.add_argument(
        "--formula-dir",
        default=os.path.join(os.path.dirname(__file__), "..", "Formula"),
        help="Path to Formula directory",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Print updates without modifying files"
    )
    parser.add_argument(
        "--builders-only",
        action="store_true",
        help="Only process multi-asset BUILDER targets",
    )
    parser.add_argument(
        "--skip-upstream-releases",
        action="store_true",
        help="Skip upstream release-tag formulae that are handled by brew bump",
    )

    args = parser.parse_args()

    targets = list(CONFIG.keys()) if args.repo == "all" else [args.repo]
    if args.builders_only:
        targets = [target for target in targets if CONFIG[target]["type"] == "builder"]
    if args.skip_upstream_releases:
        targets = [
            target for target in targets if CONFIG[target]["type"] != "upstream_release"
        ]

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
                release, release_repo = _resolve_builder_release(
                    cfg, formula_path, args.token, args.tag
                )
                if not release:
                    print(f"[*] No release with matching assets for {formula_file}")
                    continue

                tag_name = release.get("tag_name", "")
                print(
                    f"[+] Found builder release: {tag_name} ({release.get('name', '')})"
                )
                changed = update_builder_formula_content(
                    formula_path,
                    tag_name,
                    _release_asset_shas(release, args.token),
                    repo_name=release_repo,
                    dry_run=args.dry_run,
                )

            elif target_type == "upstream_release":
                try:
                    changed = update_upstream_release_formula(
                        formula_path, repo_name, args.token, args.tag, args.dry_run
                    )
                except Exception as e:
                    print(
                        f"[-] Failed to update upstream release formula {formula_file}: {e}"
                    )

            elif target_type == "rolling_release":
                try:
                    changed = update_rolling_release_formula(
                        formula_path, repo_name, args.token, args.tag, args.dry_run
                    )
                except Exception as e:
                    print(
                        f"[-] Failed to update rolling release formula {formula_file}: {e}"
                    )

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
                        dry_run=args.dry_run,
                    )
                except Exception as e:
                    print(
                        f"[-] Failed to update upstream commit formula {formula_file}: {e}"
                    )

            if changed and target not in updated_targets:
                updated_targets.append(target)

    if "GITHUB_OUTPUT" in os.environ and os.path.exists(os.environ["GITHUB_OUTPUT"]):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as f:
            f.write(f"updated_targets={','.join(updated_targets)}\n")
            f.write(f"has_updates={'true' if updated_targets else 'false'}\n")
    print(
        f"\n[*] Summary: {len(updated_targets)} formula(e) updated: "
        f"{', '.join(updated_targets) if updated_targets else 'none'}"
    )


if __name__ == "__main__":
    main()
