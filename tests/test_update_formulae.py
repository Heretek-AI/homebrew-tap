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
