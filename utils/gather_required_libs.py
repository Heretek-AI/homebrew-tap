#!/usr/bin/env python3
"""
Dynamic Shared Library Resolver for ROCmFPX Binaries.

Runs a compiled binary (e.g. llama-server) and recursively resolves/copies
missing shared library dependencies from the local ROCm installation directory.
"""

import argparse
import os
import shutil
import subprocess


def find_lib_in_rocm(libname: str, rocm_dir: str) -> str:
    """Locate a library file inside the ROCm installation tree."""
    for root, _, files in os.walk(rocm_dir):
        if libname in files:
            return os.path.join(root, libname)
    raise RuntimeError(f"Could not find {libname} in {rocm_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Gather required shared libraries for ROCmFPX binaries"
    )
    parser.add_argument(
        "--rocm-dir",
        default="/opt/rocm",
        help="Path to ROCm installation directory (default: /opt/rocm)",
    )
    parser.add_argument(
        "--dest-dir",
        default=os.path.expanduser("~/ROCmFPX/build/bin"),
        help="Destination directory for binaries and libraries",
    )
    parser.add_argument(
        "--binary",
        default="llama-server",
        help="Binary executable to probe (default: llama-server)",
    )

    args = parser.parse_args()
    rocm_dir = args.rocm_dir
    dest_dir = args.dest_dir
    binary = os.path.join(dest_dir, args.binary)

    if not os.path.exists(binary):
        raise FileNotFoundError(f"Binary not found: {binary}")

    os.makedirs(dest_dir, exist_ok=True)
    result = subprocess.run([binary], capture_output=True, text=True)

    # Iteratively copy missing shared libraries until the loader succeeds
    while "error while loading shared libraries" in result.stderr:
        so_file = result.stderr.split("shared libraries: ")[1].split(": ")[0]
        so_file_path = find_lib_in_rocm(so_file, rocm_dir)
        shutil.copy2(so_file_path, dest_dir)
        print(f"Copied {so_file_path} -> {dest_dir}")
        result = subprocess.run([binary], capture_output=True, text=True)


if __name__ == "__main__":
    main()
