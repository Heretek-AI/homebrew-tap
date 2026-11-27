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
        self.assertEqual(
            classifier.classify(["xolotl"], "hosted-cuda"), ["cuda-runtime", "xolotl"]
        )
        self.assertEqual(classifier.classify(["xolotl"], "stx-halo"), [])
        self.assertEqual(
            classifier.classify(["lucebox"], "hosted-cuda"), ["cuda-runtime", "lucebox"]
        )
        self.assertEqual(classifier.classify(["lucebox"], "stx-halo"), [])

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


if __name__ == "__main__":
    unittest.main()
