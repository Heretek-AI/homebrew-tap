#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Heretek AI
"""
Unit tests for update_formulae.py
"""

import os
import tempfile
import unittest
from pathlib import Path
import sys

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
import update_formulae


SAMPLE_CACHY_FORMULA = """class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1000/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "1000"
  sha256 "50ce560eb3f5649850f9b421211f242cd6cc29ad1fca65d7e31cff778e90f30c"
  license "MIT"

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "rocm-gfx1151"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1000/cachy-llama-b1000-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "0000000000000000000000000000000000000000000000000000000000000000"
      end
    end
  end
end
"""

SAMPLE_Q38ROCM_FORMULA = r"""class Q38rocm < Formula
  desc "Qwen 3.8 27B ROCmFP4 Inference Engine on AMD Strix Halo (gfx1151)"
  homepage "https://github.com/julianmb/q38rocm"
  version "1008"
  license "Apache-2.0"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx1151-q38rocm-x64.zip"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
    end
  end
end
"""

SAMPLE_ROCMFPX_FORMULA = """class Rocmfpx < Formula
  desc "Low-bit Quantized ROCm 7 Inference Stack (Q2..Q8 ROCMFPX & DualView)"
  homepage "https://github.com/ciru-ai/ROCmFPX"
  version "1008"
  license "MIT"

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "q38rocm"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx1151-q38rocm-x64.zip"
        sha256 "0000000000000000000000000000000000000000000000000000000000000000"
      else
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "1111111111111111111111111111111111111111111111111111111111111111"
      end
    end
  end
end
"""


class TestUpdateFormulae(unittest.TestCase):
    def test_update_formula_content(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = Path(tmpdir) / "cachy-llama.rb"
            formula_file.write_text(SAMPLE_CACHY_FORMULA, encoding="utf-8")

            asset_shas = {
                "cachy-llama-bin-macos-metal-arm64.tar.gz": "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899",
                "cachy-llama-b1001-ubuntu-rocm-gfx1151-x64.zip": "11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff",
            }

            # Update to b1001
            changed = update_formulae.update_formula_content(
                str(formula_file),
                "b1001",
                asset_shas,
                dry_run=False,
            )
            self.assertTrue(changed)

            updated_content = formula_file.read_text(encoding="utf-8")
            self.assertIn('version "1001"', updated_content)
            self.assertIn("b1001/cachy-llama-bin-macos-metal-arm64.tar.gz", updated_content)
            self.assertIn('sha256 "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899"', updated_content)

    def test_update_q38rocm_formula(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = Path(tmpdir) / "q38rocm.rb"
            formula_file.write_text(SAMPLE_Q38ROCM_FORMULA, encoding="utf-8")

            asset_shas = {
                "rocmfpx-b1009-ubuntu-rocm-gfx1151-q38rocm-x64.zip": "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
            }

            changed = update_formulae.update_formula_content(
                str(formula_file),
                "b1009",
                asset_shas,
                dry_run=False,
            )
            self.assertTrue(changed)

            updated_content = formula_file.read_text(encoding="utf-8")
            self.assertIn('version "1009"', updated_content)
            self.assertIn("b1009/rocmfpx-b1009-ubuntu-rocm-gfx1151-q38rocm-x64.zip", updated_content)
            self.assertIn('sha256 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"', updated_content)

    def test_update_rocmfpx_with_q38rocm(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = Path(tmpdir) / "rocmfpx.rb"
            formula_file.write_text(SAMPLE_ROCMFPX_FORMULA, encoding="utf-8")

            asset_shas = {
                "rocmfpx-b1009-ubuntu-rocm-gfx1151-q38rocm-x64.zip": "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
                "rocmfpx-b1009-ubuntu-rocm-gfx1151-x64.zip": "cafebeefcafebeefcafebeefcafebeefcafebeefcafebeefcafebeefcafebeef",
            }

            changed = update_formulae.update_formula_content(
                str(formula_file),
                "b1009",
                asset_shas,
                dry_run=False,
            )
            self.assertTrue(changed)

            updated_content = formula_file.read_text(encoding="utf-8")
            self.assertIn('version "1009"', updated_content)
            self.assertIn("b1009/rocmfpx-b1009-ubuntu-rocm-gfx1151-q38rocm-x64.zip", updated_content)
            self.assertIn('sha256 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"', updated_content)
            self.assertIn("b1009/rocmfpx-b1009-ubuntu-rocm-gfx1151-x64.zip", updated_content)
            self.assertIn('sha256 "cafebeefcafebeefcafebeefcafebeefcafebeefcafebeefcafebeefcafebeef"', updated_content)

    def test_no_changes_on_same_content(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = Path(tmpdir) / "cachy-llama.rb"
            formula_file.write_text(SAMPLE_CACHY_FORMULA, encoding="utf-8")

            # Matching tag b1000 and empty asset shas
            changed = update_formulae.update_formula_content(
                str(formula_file),
                "b1000",
                {},
                dry_run=False,
            )
            self.assertFalse(changed)


if __name__ == "__main__":
    unittest.main()
