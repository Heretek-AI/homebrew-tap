#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Heretek AI
"""Regenerate the generated tables in README.md from live Homebrew metadata.

The readme is split into marker-delimited blocks. Only the content between a
matching pair of markers is replaced; every other byte of README.md is kept.

Data sources:

* ``Formula/*.rb`` and ``Casks/*.rb`` decide which items belong to the tap.
  Formula source is also scanned for ``gfx`` targets and CUDA architecture
  hints that ``brew info`` does not expose.
* ``brew info --json=v2 heretek-ai/tap/<formula>`` supplies the formula
  description, homepage, dependencies, options, requirements and version.
* ``brew info --cask --json=v2 heretek-ai/tap/<cask>`` supplies the cask
  description, homepage, and platform requirements.
* ``.github/validation-specs.json`` supplies backend coverage hints for each
  formula (``rocm``, ``cuda``, ``metal``, ``vulkan`` and ``cpu`` keys).
* ``.github/upstream-pins.json`` supplies enabled hardware variants, their
  ``default`` backend selection, and their ``amdgpu_targets`` values for the
  hardware matrix.
* ``scripts/port_registry.json`` supplies the service port table.

The installed Homebrew on the development machines used for this tap does not
support ``brew info --tap``. This script therefore iterates ``Formula/*.rb``
and queries each fully-qualified name individually. Run it after syncing the
tap into Homebrew's tap directory (``scripts/test_local_tap.sh`` does this), so
that ``brew info`` reads the current checkout rather than a stale tap copy.

Usage:

    python3 scripts/generate_readme.py            # write README.md
    python3 scripts/generate_readme.py --write    # write README.md
    python3 scripts/generate_readme.py --check    # fail if README.md is stale
    python3 scripts/generate_readme.py --readme /path/to/README.md

The script resolves the repository root from ``__file__`` and works from any
working directory. Output is deterministic: catalogues are sorted by name,
column order is fixed, whitespace is collapsed, ``|`` is escaped in table
cells, and no timestamps are emitted.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

TAP = "heretek-ai/tap"
TAP_PREFIX = f"{TAP}/"
REPO_ROOT = Path(__file__).resolve().parent.parent
FORMULA_DIR = REPO_ROOT / "Formula"
CASK_DIR = REPO_ROOT / "Casks"
README_PATH = REPO_ROOT / "README.md"
PINS_PATH = REPO_ROOT / ".github" / "upstream-pins.json"
VALIDATION_PATH = REPO_ROOT / ".github" / "validation-specs.json"
PORT_REGISTRY_PATH = REPO_ROOT / "scripts" / "port_registry.json"

BLOCK_IDS = (
    "formula-catalog",
    "cask-catalog",
    "port-registry",
    "hardware-matrix",
)

BACKEND_ORDER = ("ROCm", "CUDA", "Metal", "Vulkan", "SYCL", "CPU")
BACKEND_LABELS = {
    "rocm": "ROCm",
    "cuda": "CUDA",
    "metal": "Metal",
    "vulkan": "Vulkan",
    "sycl": "SYCL",
    "cpu": "CPU",
}
RUNTIME_FORMULAE = {"rocm-runtime", "cuda-runtime"}

HARDWARE_ROWS = (
    ("AMD Strix Halo (`gfx1151`)", "rocm-runtime"),
    ("AMD RDNA3 (`gfx1100` family)", "rocm-runtime"),
    ("AMD RDNA4 (`gfx1200` family)", "rocm-runtime"),
    ("NVIDIA Blackwell (CUDA `sm_120`/`sm_121`)", "cuda-runtime"),
    ("NVIDIA CUDA (`sm_80`-`sm_90`)", "cuda-runtime"),
    ("Apple Silicon (macOS)", None),
    ("CPU / Vulkan fallback", None),
)


class GenerateError(RuntimeError):
    """A recoverable generator error with a user-facing message."""


def find_brew() -> Path:
    """Return the brew executable, preferring the active Homebrew prefix."""
    candidates: list[Path] = []
    prefix = os.environ.get("HOMEBREW_PREFIX")
    if prefix:
        candidates.append(Path(prefix) / "bin" / "brew")
    candidates.extend(
        [
            Path("/home/linuxbrew/.linuxbrew/bin/brew"),
            Path("/opt/homebrew/bin/brew"),
            Path("/usr/local/bin/brew"),
        ]
    )
    found = shutil.which("brew")
    if found:
        candidates.append(Path(found))

    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate
    raise GenerateError(
        "Homebrew was not found. Install brew or set HOMEBREW_PREFIX before "
        "running this generator."
    )


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise GenerateError(f"required metadata file is missing: {path}") from exc
    except json.JSONDecodeError as exc:
        raise GenerateError(f"invalid JSON in {path}: {exc}") from exc


def formula_names() -> list[str]:
    names = sorted(path.stem for path in FORMULA_DIR.glob("*.rb"))
    if not names:
        raise GenerateError(f"no Formula/*.rb files found under {FORMULA_DIR}")
    return names


def cask_names() -> list[str]:
    return sorted(path.stem for path in CASK_DIR.glob("*.rb"))


def brew_info_json(brew: Path, name: str, cask: bool = False) -> dict:
    command = [str(brew), "info"]
    if cask:
        command.append("--cask")
    command.extend(["--json=v2", f"{TAP}/{name}"])

    environment = os.environ.copy()
    environment.update(
        {
            "HOMEBREW_NO_ANALYTICS": "1",
            "HOMEBREW_NO_AUTO_UPDATE": "1",
            "HOMEBREW_NO_ENV_HINTS": "1",
        }
    )
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        env=environment,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise GenerateError(
            f"`{' '.join(command)}` failed (exit {result.returncode}):\n{detail}"
        )
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise GenerateError(
            f"`{' '.join(command)}` did not return JSON: {exc}"
        ) from exc


def find_item(document: dict, key: str, name: str) -> dict:
    for item in document.get(key, []):
        if item.get("name") == name or item.get("token") == name:
            return item
        if item.get("full_name") == f"{TAP}/{name}":
            return item
        if item.get("full_token") == f"{TAP}/{name}":
            return item
    raise GenerateError(f"brew info did not return {key[:-1]} `{TAP}/{name}`")


def load_formulae(brew: Path) -> list[dict]:
    records = []
    for name in formula_names():
        item = find_item(brew_info_json(brew, name), "formulae", name)
        source_path = FORMULA_DIR / f"{name}.rb"
        records.append(
            {
                "name": name,
                "full_name": f"{TAP}/{name}",
                "desc": item.get("desc") or "",
                "homepage": item.get("homepage") or "",
                "dependencies": item.get("dependencies") or [],
                "options": [
                    option.get("option", "") for option in item.get("options", [])
                ],
                "requirements": item.get("requirements") or [],
                "source": source_path.read_text(encoding="utf-8", errors="replace"),
            }
        )
    return records


def load_casks(brew: Path) -> list[dict]:
    records = []
    for name in cask_names():
        item = find_item(brew_info_json(brew, name, cask=True), "casks", name)
        records.append(
            {
                "name": name,
                "full_name": f"{TAP}/{name}",
                "desc": item.get("desc") or "",
                "homepage": item.get("homepage") or "",
                "depends_on": item.get("depends_on") or {},
            }
        )
    return records


def collapse(text: str) -> str:
    return " ".join(str(text).split())


def table_cell(text: str) -> str:
    return collapse(text).replace("|", r"\|")


def upstream_label(url: str) -> str:
    if not url:
        return "—"
    parsed = urlparse(url)
    host = parsed.netloc.removeprefix("www.")
    path = parsed.path.strip("/").removesuffix(".git")
    if host == "github.com" and path:
        return path
    if path:
        return f"{host}/{path}"
    return host


def upstream_link(url: str) -> str:
    label = upstream_label(url)
    if not url:
        return label
    return f"[{label}]({url})"


def formula_anchor(name: str) -> str:
    return f"[`{name}`](#{name})"


def requirement_names(formula: dict) -> set[str]:
    return {requirement.get("name") for requirement in formula["requirements"]}


def requirement_values(formula: dict, name: str) -> set[str]:
    values = set()
    for requirement in formula["requirements"]:
        if requirement.get("name") == name and requirement.get("version"):
            values.add(str(requirement["version"]))
    return values


def formula_platforms(formula: dict) -> list[str]:
    names = requirement_names(formula)
    has_linux = "linux" in names
    has_macos = "macos" in names
    if has_linux and has_macos:
        return ["Linux", "macOS"]
    if has_linux:
        return ["Linux"]
    if has_macos:
        return ["macOS"]
    # These formulae select per-platform artefacts with on_linux/on_macos and
    # therefore declare no OS requirement in their active brew info spec.
    return ["Linux", "macOS"]


def enabled_backends(formula: dict, pins: dict, validation: dict) -> set[str]:
    name = formula["name"]
    backends: set[str] = set()

    for dependency in formula["dependencies"]:
        dependency = str(dependency).lower()
        if "rocm-runtime" in dependency:
            backends.add("ROCm")
        if "cuda-runtime" in dependency:
            backends.add("CUDA")

    for key in validation.get("formulas", {}).get(name, {}):
        if key in BACKEND_LABELS:
            backends.add(BACKEND_LABELS[key])

    package = pins.get("packages", {}).get(name, {})
    for variant in package.get("variants", {}).values():
        if variant.get("status") != "enabled":
            continue
        backend = variant.get("backend")
        if backend in BACKEND_LABELS:
            backends.add(BACKEND_LABELS[backend])

    for option in formula["options"]:
        if option == "--with-rocm":
            backends.add("ROCm")
        elif option == "--with-cuda":
            backends.add("CUDA")
        elif option == "--with-vulkan":
            backends.add("Vulkan")
        elif option == "--with-sycl":
            backends.add("SYCL")
        elif option == "--with-cpu":
            backends.add("CPU")

    return backends


def platform_summary(formula: dict, pins: dict, validation: dict) -> str:
    name = formula["name"]
    if name == "rocm-runtime":
        return "Linux x86_64, ROCm runtime"
    if name == "cuda-runtime":
        return "Linux x86_64 + arm64, CUDA runtime"

    platforms = formula_platforms(formula)
    label = " + ".join(platforms)

    if platforms == ["Linux"] and requirement_values(formula, "arch") == {"x86_64"}:
        label += " x86_64"

    backends = enabled_backends(formula, pins, validation)
    ordered = [backend for backend in BACKEND_ORDER if backend in backends]
    if ordered:
        label += f", {'/'.join(ordered)}"
    return label


def formula_catalog_table(formulae: list[dict], pins: dict, validation: dict) -> str:
    lines = [
        "| Formula | Upstream | Purpose | Platforms / backends |",
        "| :--- | :--- | :--- | :--- |",
    ]
    for formula in sorted(formulae, key=lambda item: item["name"]):
        lines.append(
            "| "
            + " | ".join(
                [
                    formula_anchor(formula["name"]),
                    upstream_link(formula["homepage"]),
                    table_cell(formula["desc"]) or "—",
                    table_cell(platform_summary(formula, pins, validation)),
                ]
            )
            + " |"
        )
    return "\n".join(lines)


def cask_platforms(cask: dict) -> str:
    depends_on = cask.get("depends_on") or {}
    macos = depends_on.get("macos") or {}
    version = ""
    if isinstance(macos, dict):
        for operator, values in macos.items():
            if not values:
                continue
            first = values[0]
            if operator == ">=":
                version = f" {first}+"
            elif operator == ">":
                version = f" >{first}"
            elif operator == "==":
                version = f" {first}"
            break

    arch_specs = depends_on.get("arch") or []
    arch_types = {spec.get("type") for spec in arch_specs if isinstance(spec, dict)}
    if arch_types == {"arm"}:
        arch = "Apple Silicon"
    elif arch_types == {"intel"}:
        arch = "Intel"
    else:
        arch = "Apple Silicon and Intel"

    return f"macOS{version}, {arch}"


def cask_catalog_table(casks: list[dict]) -> str:
    lines = [
        "| Cask | Upstream | Purpose | Platforms |",
        "| :--- | :--- | :--- | :--- |",
    ]
    for cask in sorted(casks, key=lambda item: item["name"]):
        lines.append(
            "| "
            + " | ".join(
                [
                    formula_anchor(cask["name"]),
                    upstream_link(cask["homepage"]),
                    table_cell(cask["desc"]) or "—",
                    table_cell(cask_platforms(cask)),
                ]
            )
            + " |"
        )
    return "\n".join(lines)


def port_registry_table(registry: dict) -> str:
    bind_host = registry.get("bind_host", "127.0.0.1")
    rows = []
    for name, service in registry.get("services", {}).items():
        port = int(service["port"])
        notes = collapse(service.get("notes", ""))
        # zinc is the documented exception: upstream always binds 0.0.0.0 and
        # exposes no --host flag, so the registry records that in its notes.
        host = (
            "0.0.0.0" if re.search(r"always binds\s+0\.0\.0\.0", notes) else bind_host
        )
        rows.append((port, name, service.get("executable", ""), host, notes))

    def sort_key(row: tuple) -> tuple:
        port = row[0]
        in_reserved_range = 18000 <= port <= 18099
        return (0 if in_reserved_range else 1, port, row[1])

    lines = [
        "| Formula | Service executable | Default endpoint | Notes |",
        "| :--- | :--- | :--- | :--- |",
    ]
    for port, name, executable, host, notes in sorted(rows, key=sort_key):
        lines.append(
            "| "
            + " | ".join(
                [
                    formula_anchor(name),
                    f"`{table_cell(executable)}`",
                    f"`{host}:{port}`",
                    table_cell(notes) or "—",
                ]
            )
            + " |"
        )
    return "\n".join(lines)


def split_targets(value: str) -> set[str]:
    return {
        target.lower() for target in re.split(r"[;,\s]+", str(value or "")) if target
    }


def formula_targets(formula: dict, pins: dict) -> set[str]:
    name = formula["name"]
    targets: set[str] = set()

    package = pins.get("packages", {}).get(name, {})
    for variant in package.get("variants", {}).values():
        if variant.get("status") == "enabled" and variant.get("backend") == "rocm":
            targets |= split_targets(variant.get("amdgpu_targets", ""))

    targets |= {
        target.lower() for target in re.findall(r"gfx[0-9a-zA-Z]+", formula["source"])
    }
    return targets


def formula_cuda_arches(formula: dict) -> set[int]:
    source = formula["source"]
    arches = {
        int(match)
        for match in re.findall(r"(?:sm_|compute_)(\d+)", source, flags=re.IGNORECASE)
    }

    for match in re.findall(r"CMAKE_CUDA_ARCHITECTURES[=\s\"']+([0-9;\.]+)", source):
        for token in re.split(r"[;\.]+", match):
            if token:
                arches.add(int(token))

    # Arch lists are often held in a variable (e.g. cuda_archs) so the ci-fast
    # mode can swap in a single arch; parse the full semicolon-separated list
    # and drop CMake's -real/-virtual suffixes.
    for match in re.findall(
        r"[\"']([0-9]+(?:-(?:real|virtual))?(?:;[0-9]+(?:-(?:real|virtual))?)+)[\"']",
        source,
    ):
        for token in match.split(";"):
            token = re.sub(r"-(?:real|virtual)$", "", token)
            if token.isdigit():
                arches.add(int(token))

    for match in re.findall(
        r"TORCH_CUDA_ARCH_LIST[^=]*=\s*[\"']([^\"']+)[\"']", source
    ):
        for token in re.split(r"[;\s]+", match):
            if re.fullmatch(r"\d+\.\d+", token):
                major, minor = token.split(".")
                arches.add(int(major) * 10 + int(minor))

    return arches


def hardware_membership(formula: dict, pins: dict, validation: dict) -> dict[str, bool]:
    targets = formula_targets(formula, pins)
    backends = enabled_backends(formula, pins, validation)
    cuda_arches = formula_cuda_arches(formula)
    text = f"{formula['desc']}\n{formula['source']}".lower()

    supports_blackwell = "CUDA" in backends and (
        "blackwell" in text or bool(cuda_arches & {120, 121})
    )
    supports_cuda_8_9 = "CUDA" in backends and any(
        80 <= arch <= 90 for arch in cuda_arches
    )

    return {
        "strix-halo": "gfx1151" in targets,
        "rdna3": any(target.startswith("gfx110") for target in targets),
        "rdna4": any(target.startswith("gfx120") for target in targets),
        "blackwell": supports_blackwell,
        "cuda-8-9": supports_cuda_8_9,
        "apple-silicon": "macOS" in formula_platforms(formula),
        "cpu-vulkan": bool(backends & {"CPU", "Vulkan"})
        and "Linux" in formula_platforms(formula),
    }


def default_backends(formula: dict, pins: dict) -> set[str]:
    name = formula["name"]
    package = pins.get("packages", {}).get(name, {})
    defaults = {
        BACKEND_LABELS[variant.get("backend")]
        for variant in package.get("variants", {}).values()
        if variant.get("status") == "enabled"
        and variant.get("default") is True
        and variant.get("backend") in BACKEND_LABELS
    }
    if defaults:
        return defaults

    dependencies = " ".join(
        str(dependency).lower() for dependency in formula["dependencies"]
    )
    if "rocm-runtime" in dependencies:
        defaults.add("ROCm")
    if "cuda-runtime" in dependencies:
        defaults.add("CUDA")
    return defaults


def matrix_install_args(formula: dict, row_key: str, pins: dict) -> list[str]:
    name = formula["name"]
    options = set(formula["options"])
    defaults = default_backends(formula, pins)

    if row_key in {"strix-halo", "rdna3", "rdna4"}:
        if "--with-rocm" in options and "ROCm" not in defaults:
            return ["--with-rocm"]
        if row_key == "rdna3" and name == "hipfire" and "--with-gfx1100" in options:
            return ["--with-gfx1100"]
        if row_key == "rdna4" and name == "hipfire" and "--with-gfx1201" in options:
            return ["--with-gfx1201"]
        if row_key == "rdna4" and name == "kyojin" and "--with-rdna4" in options:
            return ["--with-rdna4"]
    elif row_key in {"blackwell", "cuda-8-9"}:
        if "--with-cuda" in options and "CUDA" not in defaults:
            return ["--with-cuda"]
    elif row_key == "cpu-vulkan":
        if name == "zinc" and "--with-vulkan" in options:
            return ["--with-vulkan"]

    return []


def hardware_matrix_table(formulae: list[dict], pins: dict, validation: dict) -> str:
    membership = {
        formula["name"]: hardware_membership(formula, pins, validation)
        for formula in formulae
        if formula["name"] not in RUNTIME_FORMULAE
    }
    formula_by_name = {formula["name"]: formula for formula in formulae}

    lines = [
        "| Hardware family | Recommended formulae / install commands |",
        "| :--- | :--- |",
    ]
    for label, runtime in HARDWARE_ROWS:
        if label.startswith("AMD Strix"):
            row_key = "strix-halo"
        elif label.startswith("AMD RDNA3"):
            row_key = "rdna3"
        elif label.startswith("AMD RDNA4"):
            row_key = "rdna4"
        elif label.startswith("NVIDIA Blackwell"):
            row_key = "blackwell"
        elif label.startswith("NVIDIA CUDA"):
            row_key = "cuda-8-9"
        elif label.startswith("Apple Silicon"):
            row_key = "apple-silicon"
        else:
            row_key = "cpu-vulkan"

        names = sorted(name for name, matches in membership.items() if matches[row_key])
        lines_for_row = []
        if runtime:
            lines_for_row.append(f"Runtime: `brew install {TAP_PREFIX}{runtime}`")
        else:
            lines_for_row.append("Runtime: none")
        for name in names:
            arguments = matrix_install_args(formula_by_name[name], row_key, pins)
            command = " ".join(["brew", "install", *arguments, f"{TAP_PREFIX}{name}"])
            lines_for_row.append(f"`{command}`")
        if not names:
            lines_for_row.append("No formula metadata matched this row.")
        lines.append(f"| {label} | {'<br>'.join(lines_for_row)} |")
    return "\n".join(lines)


def build_blocks(
    brew: Path, pins: dict, validation: dict, registry: dict
) -> dict[str, str]:
    formulae = load_formulae(brew)
    casks = load_casks(brew)
    return {
        "formula-catalog": formula_catalog_table(formulae, pins, validation),
        "cask-catalog": cask_catalog_table(casks),
        "port-registry": port_registry_table(registry),
        "hardware-matrix": hardware_matrix_table(formulae, pins, validation),
    }


def marker_pair(block_id: str) -> tuple[str, str]:
    return (
        f"<!-- BEGIN GENERATED: {block_id} -->",
        f"<!-- END GENERATED: {block_id} -->",
    )


def block_pattern(block_id: str) -> re.Pattern:
    begin, end = marker_pair(block_id)
    return re.compile(re.escape(begin) + r"(.*?)" + re.escape(end), re.DOTALL)


def replace_block(text: str, block_id: str, content: str) -> str:
    begin, end = marker_pair(block_id)
    if text.count(begin) != 1 or text.count(end) != 1:
        raise GenerateError(
            f"README.md must contain exactly one pair of `{begin}` / `{end}` markers"
        )
    pattern = block_pattern(block_id)
    replacement = f"{begin}\n{content.rstrip()}\n{end}"
    return pattern.sub(lambda _match: replacement, text, count=1)


def rendered_readme(text: str, blocks: dict[str, str]) -> str:
    result = text
    for block_id in BLOCK_IDS:
        result = replace_block(result, block_id, blocks[block_id])
    return result


def stale_blocks(text: str, blocks: dict[str, str]) -> list[str]:
    stale = []
    for block_id in BLOCK_IDS:
        pattern = block_pattern(block_id)
        match = pattern.search(text)
        if match is None:
            raise GenerateError(
                f"README.md is missing the generated block `{block_id}`; "
                f"expected `{marker_pair(block_id)[0]}` and `{marker_pair(block_id)[1]}`"
            )
        if match.group(1).strip() != blocks[block_id].strip():
            stale.append(block_id)
    return stale


def resolve_readme(path: Path | None) -> Path:
    if path is None:
        return README_PATH
    return path if path.is_absolute() else REPO_ROOT / path


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Regenerate the marker-delimited tables in README.md from live "
            "Homebrew metadata."
        )
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--write",
        action="store_true",
        help="write README.md (the default)",
    )
    mode.add_argument(
        "--check",
        action="store_true",
        help="exit 1 if README.md differs from freshly generated output",
    )
    parser.add_argument(
        "--readme",
        type=Path,
        help="README path to update; relative paths are resolved from the repo root",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    readme_path = resolve_readme(args.readme)
    if not readme_path.is_file():
        print(f"error: README not found: {readme_path}", file=sys.stderr)
        return 1

    try:
        brew = find_brew()
        pins = load_json(PINS_PATH)
        validation = load_json(VALIDATION_PATH)
        registry = load_json(PORT_REGISTRY_PATH)
        blocks = build_blocks(brew, pins, validation, registry)
        original = readme_path.read_text(encoding="utf-8")
        updated = rendered_readme(original, blocks)

        if args.check:
            if updated != original:
                stale = stale_blocks(original, blocks)
                if not stale:
                    stale = ["README structure"]
                print(f"README is stale: {', '.join(stale)}", file=sys.stderr)
                print("run scripts/generate_readme.py", file=sys.stderr)
                return 1
            print("README is up to date.")
            return 0

        if updated == original:
            print("README is already up to date.")
            return 0

        readme_path.write_text(updated, encoding="utf-8")
        print(f"Updated {readme_path}")
        return 0
    except GenerateError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
