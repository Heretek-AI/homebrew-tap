"""Tests for the CI formula classifier."""

from __future__ import annotations

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "classify_changed_formulae",
    REPO_ROOT / "scripts" / "classify_changed_formulae.py",
)
assert SPEC and SPEC.loader
classifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(classifier)


class TestClassifyChangedFormulae(unittest.TestCase):
    def setUp(self) -> None:
        self.original_cwd = Path.cwd()
        self.addCleanup(os.chdir, self.original_cwd)
        os.chdir(REPO_ROOT)

    def test_deleted_formula_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            os.chdir(directory)
            (Path("Formula")).mkdir()
            (Path("Formula") / "added.rb").write_text("class Added < Formula\nend\n")
            diff = "Formula/added.rb\nFormula/removed.rb\n"
            with mock.patch.object(
                classifier.subprocess, "check_output", return_value=diff
            ):
                self.assertEqual(
                    classifier.git_changed_formulae("base", "head"), ["added"]
                )

    def test_missing_formula_is_skipped(self) -> None:
        self.assertEqual(classifier.classify(["missing-formula"], "stx-halo"), [])

    def test_prebuilt_rocm_formulae_route_to_stx_halo(self) -> None:
        for name in ("hipfire", "zinc"):
            self.assertEqual(classifier.classify([name], "stx-halo"), [name])
            self.assertEqual(classifier.classify([name], "hosted-linux"), [])
            self.assertEqual(classifier.classify([name], "hosted-cuda"), [])

    def test_source_rocm_and_cuda_formulae(self) -> None:
        self.assertEqual(
            classifier.classify(["gufo-ds41"], "hosted-rocm"),
            ["rocm-runtime", "gufo-ds41"],
        )
        self.assertEqual(
            classifier.classify(["gufo-ds41"], "stx-halo"),
            ["rocm-runtime", "gufo-ds41"],
        )
        self.assertEqual(classifier.classify(["gufo-ds41"], "hosted-linux"), [])
        self.assertEqual(
            classifier.classify(["rulith-inference"], "stx-halo"),
            ["rocm-runtime", "rulith-inference"],
        )
        self.assertEqual(
            classifier.classify(["strixolotl"], "stx-halo"),
            ["rocm-runtime", "strixolotl"],
        )
        self.assertEqual(
            classifier.classify(["basalt"], "hosted-cuda"), ["cuda-runtime", "basalt"]
        )
        self.assertEqual(classifier.classify(["basalt"], "stx-halo"), [])

    def test_macos_only_formula_is_linux_excluded(self) -> None:
        self.assertEqual(classifier.classify(["uzu"], "hosted-macos"), ["uzu"])
        self.assertEqual(classifier.classify(["uzu"], "hosted-linux"), [])
        self.assertEqual(classifier.classify(["uzu"], "hosted-cuda"), [])
        self.assertEqual(classifier.classify(["uzu"], "stx-halo"), [])

    def test_macos_requirement_not_on_macos_block_alone(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            os.chdir(directory)
            (Path("Formula")).mkdir()
            (Path("Formula") / "portable.rb").write_text(
                "class Portable < Formula\n"
                '  url "https://example.com/portable-1.0.tar.gz"\n'
                "  on_macos do\n"
                '    depends_on "libomp"\n'
                "  end\n"
                "end\n"
            )
            (Path("Formula") / "mac-symbol.rb").write_text(
                "class MacSymbol < Formula\n"
                '  url "https://example.com/macos-1.0.tar.gz"\n'
                "  depends_on :macos\n"
                "end\n"
            )
            (Path("Formula") / "mac-version.rb").write_text(
                "class MacVersion < Formula\n"
                '  url "https://example.com/macos-2.0.tar.gz"\n'
                "  depends_on macos: :tahoe\n"
                "end\n"
            )

            self.assertEqual(
                classifier.classify(["portable"], "hosted-linux"), ["portable"]
            )
            self.assertEqual(classifier.classify(["mac-symbol"], "hosted-linux"), [])
            self.assertEqual(classifier.classify(["mac-version"], "hosted-linux"), [])
            self.assertEqual(
                classifier.classify(["mac-symbol"], "hosted-macos"), ["mac-symbol"]
            )

    def test_hosted_formulae(self) -> None:
        self.assertEqual(classifier.classify(["shimmy"], "hosted-macos"), ["shimmy"])
        self.assertEqual(
            classifier.classify(["stable-diffusion-cpp"], "hosted-linux"),
            ["stable-diffusion-cpp"],
        )
        self.assertEqual(
            classifier.classify(["cuda-runtime"], "hosted-linux"), ["cuda-runtime"]
        )
        self.assertEqual(classifier.classify(["cuda-runtime"], "hosted-cuda"), [])

    def test_skip_bottled_runtime_respects_bottle_block_and_direct_changes(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            os.chdir(directory)
            (Path("Formula")).mkdir()
            (Path("Formula") / "rocm-runtime.rb").write_text(
                "class RocmRuntime < Formula\n"
                '  # ROCM_PATH="#{opt_prefix}"\n'
                "  bottle do\n"
                '    root_url "https://ghcr.io/v2/heretek-ai/tap"\n'
                '    sha256 cellar: :any_skip_relocation, x86_64_linux: "abc123"\n'
                "  end\n"
                "end\n"
            )
            (Path("Formula") / "gufo.rb").write_text(
                "class Gufo < Formula\n"
                '  depends_on "heretek-ai/tap/rocm-runtime"\n'
                "end\n"
            )
            (Path("Formula") / "cuda-runtime.rb").write_text(
                "class CudaRuntime < Formula\n"
                '  url "https://example.com/cuda.tar.xz"\n'
                "end\n"
            )
            (Path("Formula") / "xolotl.rb").write_text(
                "class Xolotl < Formula\n"
                '  depends_on "heretek-ai/tap/cuda-runtime"\n'
                "end\n"
            )

            self.assertTrue(classifier.has_x86_64_linux_bottle("rocm-runtime"))
            self.assertFalse(classifier.has_x86_64_linux_bottle("cuda-runtime"))

            # Unchanged bottled rocm-runtime is skipped when skip_bottled_runtime=True
            self.assertEqual(
                classifier.classify(["gufo"], "hosted-rocm", skip_bottled_runtime=True),
                ["gufo"],
            )
            # Directly changed bottled rocm-runtime is still built
            self.assertEqual(
                classifier.classify(
                    ["rocm-runtime", "gufo"],
                    "hosted-rocm",
                    skip_bottled_runtime=True,
                ),
                ["rocm-runtime", "gufo"],
            )
            self.assertEqual(
                classifier.classify(
                    ["rocm-runtime"], "hosted-rocm", skip_bottled_runtime=True
                ),
                ["rocm-runtime"],
            )

            # Unbottled cuda-runtime is auto-prepended for dependent CUDA formulae
            self.assertEqual(
                classifier.classify(
                    ["xolotl"], "hosted-cuda", skip_bottled_runtime=True
                ),
                ["cuda-runtime", "xolotl"],
            )
            # Standalone cuda-runtime change does not enter hosted-cuda
            self.assertEqual(
                classifier.classify(
                    ["cuda-runtime"], "hosted-cuda", skip_bottled_runtime=True
                ),
                [],
            )

            # Once cuda-runtime has an x86_64_linux bottle, unchanged runtime is skipped
            # unless cuda-runtime itself changed.
            (Path("Formula") / "cuda-runtime.rb").write_text(
                "class CudaRuntime < Formula\n"
                "  bottle do\n"
                '    root_url "https://ghcr.io/v2/heretek-ai/tap"\n'
                '    sha256 cellar: :any_skip_relocation, x86_64_linux: "def456"\n'
                "  end\n"
                "end\n"
            )
            self.assertTrue(classifier.has_x86_64_linux_bottle("cuda-runtime"))
            self.assertEqual(
                classifier.classify(
                    ["xolotl"], "hosted-cuda", skip_bottled_runtime=True
                ),
                ["xolotl"],
            )
            self.assertEqual(
                classifier.classify(
                    ["cuda-runtime", "xolotl"],
                    "hosted-cuda",
                    skip_bottled_runtime=True,
                ),
                ["cuda-runtime", "xolotl"],
            )

    def test_build_matrix_entries_includes_timeout_and_variant(self) -> None:
        entries = classifier.build_matrix_entries(["project-maya", "gufo"], "hosted-rocm")
        self.assertEqual(len(entries), 2)
        by_name = {entry["formula"]: entry for entry in entries}
        self.assertEqual(by_name["project-maya"]["timeout_minutes"], 180)
        self.assertEqual(by_name["project-maya"]["variant"], "rocm")
        self.assertEqual(by_name["gufo"]["timeout_minutes"], 120)
        self.assertEqual(by_name["gufo"]["variant"], "rocm")


if __name__ == "__main__":
    unittest.main()
