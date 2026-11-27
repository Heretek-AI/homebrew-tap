#!/usr/bin/env python3
"""Classify changed tap formulae for the CI runner that can build them.

The tap has three build classes:

* ``hosted-linux`` / ``hosted-macos``: CPU, Metal, Vulkan and prebuilt
  formulae that need no GPU toolchain.
* ``hosted-cuda``: CUDA formulae that only need ``nvcc`` (no GPU at build
  time), built in the ``brew-cuda`` toolchain image.
* ``stx-halo``: ROCm source builds and hardware validation on the trusted
  self-hosted ``stx-halo`` runner.

The script intentionally uses the formula source text and git diff rather
than Homebrew internals so it can run before ``brew test-bot --only-setup``.
It prints a comma-separated list suitable for
``brew test-bot --testing-formulae`` and writes ``formulae=<list>`` to
``$GITHUB_OUTPUT`` when that variable is set.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
from pathlib import Path

FORMULA_DIR = Path("Formula")

ROCM_MARKERS = (
    "heretek-ai/tap/rocm-runtime",
    "HOMEBREW_ROCM_PATH",
    "hipcc",
    "CMAKE_HIP_ARCHITECTURES",
    "GGML_HIP=ON",
    "ROCM_PATH",
)
CUDA_MARKERS = (
    "heretek-ai/tap/cuda-runtime",
    "HOMEBREW_CUDA_PATH",
    "nvcc",
    "CMAKE_CUDA_ARCHITECTURES",
    "CUDAToolkit_ROOT",
)
# Linux-only formulae that install prebuilt ROCm artifacts and therefore have
# no ROCm SDK markers in their source. They still belong to the trusted
# self-hosted ROCm bottle/validation job.
PREBUILT_ROCM_FORMULAE = frozenset({"hipfire", "zinc"})
# Formulae that contain both backend markers but build CUDA by default.
CUDA_DEFAULT_FORMULAE = frozenset({"lucebox"})
# Runtime-only formula that downloads prebuilt CUDA libraries and needs no
# toolkit, so it can be bottled on ordinary hosted Linux.
HOSTED_LINUX_FORMULAE = frozenset({"cuda-runtime"})


def git_changed_formulae(base: str, head: str) -> list[str]:
    """Return formula names touched between *base* and *head*."""
    try:
        output = subprocess.check_output(
            ["git", "diff", "--name-only", f"{base}...{head}", "--", "Formula/"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        output = subprocess.check_output(
            ["git", "diff", "--name-only", base, head, "--", "Formula/"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    names = []
    for line in output.splitlines():
        path = Path(line)
        if path.parent != FORMULA_DIR or path.suffix != ".rb":
            continue
        # Deleted formulae appear in the diff but cannot be read or built.
        if (FORMULA_DIR / path.name).is_file():
            names.append(path.stem)
    return sorted(set(names))


def all_formulae() -> list[str]:
    return sorted(path.stem for path in FORMULA_DIR.glob("*.rb"))


def read_formula(name: str) -> str:
    return (FORMULA_DIR / f"{name}.rb").read_text(encoding="utf-8")


def is_linux_only(source: str) -> bool:
    """Best-effort check for a formula that cannot build on macOS."""
    if "OS.mac?" in source or "on_macos do" in source:
        return False
    return re.search(r"^\s*depends_on :linux\b", source, re.MULTILINE) is not None


def is_macos_only(source: str) -> bool:
    """Best-effort check for a formula that cannot build on Linux.

    Only an unconditional macOS requirement makes a formula macOS-only.
    A bare ``on_macos`` block is not enough: portable formulae use those
    blocks for macOS-only dependencies while keeping a shared Linux URL.
    """
    if (
        "OS.linux?" in source
        or "on_linux do" in source
        or re.search(r"^\s*depends_on :linux\b", source, re.MULTILINE)
    ):
        return False
    return (
        re.search(r"^\s*depends_on\s+(?::macos\b|macos\s*:)", source, re.MULTILINE)
        is not None
    )


def is_rocm(source: str) -> bool:
    return any(marker in source for marker in ROCM_MARKERS)


def is_cuda(source: str) -> bool:
    return any(marker in source for marker in CUDA_MARKERS)


def classify(names: list[str], runner: str) -> list[str]:
    selected = []
    for name in names:
        if not (FORMULA_DIR / f"{name}.rb").is_file():
            continue

        source = read_formula(name)
        rocm = is_rocm(source)
        cuda = is_cuda(source)
        prebuilt_rocm = name in PREBUILT_ROCM_FORMULAE
        cuda_default = name in CUDA_DEFAULT_FORMULAE
        macos_only = is_macos_only(source)
        if runner in ("hosted-rocm", "stx-halo"):
            keep = (rocm or prebuilt_rocm) and not cuda_default and not macos_only
        elif runner == "hosted-cuda":
            keep = not macos_only and (
                cuda_default
                or (
                    cuda
                    and not rocm
                    and not prebuilt_rocm
                    and name not in HOSTED_LINUX_FORMULAE
                )
            )
        elif runner == "hosted-macos":
            keep = (
                not is_linux_only(source)
                and not rocm
                and not cuda
                and not prebuilt_rocm
            )
        elif runner == "hosted-linux":
            keep = not macos_only and (
                name in HOSTED_LINUX_FORMULAE
                or (not rocm and not cuda and not prebuilt_rocm)
            )
        else:
            raise SystemExit(f"unknown runner class: {runner}")
        if keep:
            selected.append(name)

    runtime = {
        "hosted-cuda": "cuda-runtime",
        "hosted-rocm": "rocm-runtime",
        "stx-halo": "rocm-runtime",
    }.get(runner)
    if runtime and any(
        f"heretek-ai/tap/{runtime}" in read_formula(name) for name in selected
    ):
        selected = [runtime] + [name for name in selected if name != runtime]
    return selected


def emit(names: list[str]) -> None:
    value = ",".join(names)
    print(value)
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as handle:
            handle.write(f"formulae={value}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--runner",
        required=True,
        choices=["hosted-linux", "hosted-macos", "hosted-cuda", "hosted-rocm", "stx-halo"],
    )
    parser.add_argument("--base", help="Base revision for the diff")
    parser.add_argument("--head", default="HEAD", help="Head revision (default: HEAD)")
    parser.add_argument("--formulae", help="Explicit comma-separated formula list")
    parser.add_argument("--all", action="store_true", help="Classify every formula")
    args = parser.parse_args()

    if args.formulae:
        names = sorted(
            {name.strip() for name in args.formulae.split(",") if name.strip()}
        )
    elif args.all:
        names = all_formulae()
    else:
        if not args.base:
            parser.error("--base is required unless --all or --formulae is used")
        names = git_changed_formulae(args.base, args.head)

    emit(classify(names, args.runner))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
