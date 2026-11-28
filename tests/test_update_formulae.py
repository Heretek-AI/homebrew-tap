#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Heretek AI
"""
Unit tests for update_formulae.py on the latest-main formula set.
"""

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))
import update_formulae
from update_formulae import (
    asset_role,
    find_latest_release_with_assets,
    find_matching_asset,
    is_asset_allowed,
    sd_asset_role,
)


SAMPLE_ROCMFPX_FORMULA = """class Rocmfpx < Formula
  desc "High-Performance AMD ROCm llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx1151-x64.zip"
  version "1136"
  sha256 "4e6fab169b35d6337b1f7a874fd630dc06c4d98d58ff85ad2bdbcf799f508b2f"
  license "MIT"

  on_linux do
    if build.with? "multi-arch"
      url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-multiarch-x64.zip"
      sha256 "4dcca64792e20d4d3d79132da09bb43a3d8ab971c319fbac9661598af85783c8"
    elsif build.with? "gfx1150"
      url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx1150-x64.zip"
      sha256 "30d4da89565d53c98e21c7cf6f28d6151e4c3ec5dbee5e2e08d3815e14363149"
    end
  end
end
"""

SAMPLE_SD_FORMULA = """class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
  version "975"
  sha256 "703f547a0bbe254979940ec6142a87b4af6acbc01d34e37358f4feabb430a225"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Darwin-macOS-26.6.2-arm64.zip"
      sha256 "2edf5a21c4b73f448c3a02c87925283b77aa94f1859c0d8e649134da68b40813"
    end
  end

  on_linux do
    if build.with? "rocm"
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Linux-Ubuntu-24.04-x86_64-rocm-10.1.0.zip"
      sha256 "b0deb148e8f0c05c75b5c8b54876ff97f819e80f57fcf1398ebb5dbb727c7a16"
    elsif build.with? "cpu"
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Linux-Ubuntu-24.04-x86_64.zip"
      sha256 "23757b2d46edd68ec59ad252e6e3d6c1854ab01d6be5d47a06e0bc751c2eee2a"
    end
  end
end
"""


class TestUpdateFormulae(unittest.TestCase):
    def _write_formula(self, tmpdir: str, name: str, content: str) -> Path:
        formula_file = Path(tmpdir) / name
        formula_file.write_text(content, encoding="utf-8")
        return formula_file

    def test_update_rocmfpx_formula(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(
                tmpdir, "rocmfpx.rb", SAMPLE_ROCMFPX_FORMULA
            )

            asset_shas = {
                "rocmfpx-b1137-ubuntu-rocm-gfx1151-x64.zip": "e" * 64,
                "rocmfpx-b1137-ubuntu-rocm-multiarch-x64.zip": "f" * 64,
                "rocmfpx-b1137-ubuntu-rocm-gfx1150-x64.zip": "a" * 64,
            }

            changed = update_formulae.update_builder_formula_content(
                str(formula_file),
                "b1137",
                asset_shas,
                repo_name="Heretek-AI/homebrew-tap",
                dry_run=False,
            )
            self.assertTrue(changed)

            updated_content = formula_file.read_text(encoding="utf-8")
            self.assertIn('version "1137"', updated_content)
            self.assertIn(
                "b1137/rocmfpx-b1137-ubuntu-rocm-gfx1151-x64.zip", updated_content
            )
            self.assertIn(f'sha256 "{"e" * 64}"', updated_content)
            self.assertIn(
                "b1137/rocmfpx-b1137-ubuntu-rocm-multiarch-x64.zip", updated_content
            )
            self.assertIn(f'sha256 "{"f" * 64}"', updated_content)
            self.assertIn(
                "b1137/rocmfpx-b1137-ubuntu-rocm-gfx1150-x64.zip", updated_content
            )
            self.assertIn(f'sha256 "{"a" * 64}"', updated_content)

    def test_version_not_bumped_without_matching_assets(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(
                tmpdir, "rocmfpx.rb", SAMPLE_ROCMFPX_FORMULA
            )
            original = formula_file.read_text(encoding="utf-8")

            changed = update_formulae.update_builder_formula_content(
                str(formula_file),
                "b9999",
                {},
                dry_run=False,
            )

            self.assertFalse(changed)
            self.assertEqual(formula_file.read_text(encoding="utf-8"), original)

    def test_kingjones_assets_never_update_rocmfpx(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(
                tmpdir, "rocmfpx.rb", SAMPLE_ROCMFPX_FORMULA
            )
            original = formula_file.read_text(encoding="utf-8")

            asset_shas = {
                "kingjones-rocmfpx-b1134-ubuntu-rocm-gfx1151-x64.zip": "3" * 64,
            }

            changed = update_formulae.update_builder_formula_content(
                str(formula_file),
                "b1134",
                asset_shas,
                dry_run=False,
            )

            self.assertFalse(changed)
            self.assertEqual(formula_file.read_text(encoding="utf-8"), original)

    def test_q38_and_profile_assets_rejected(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(
                tmpdir, "rocmfpx.rb", SAMPLE_ROCMFPX_FORMULA
            )
            original = formula_file.read_text(encoding="utf-8")

            asset_shas = {
                "rocmfpx-b1132-ubuntu-rocm-gfx1151-q38rocm-x64.zip": "3" * 64,
                "rocmfpx-b1006-ubuntu-rocm-gfx1151-kairic-edge-x64.zip": "4" * 64,
                "rocmfpx-b1007-ubuntu-rocm-gfx1151-promptforge-x64.zip": "5" * 64,
            }

            changed = update_formulae.update_builder_formula_content(
                str(formula_file),
                "b1132",
                asset_shas,
                dry_run=False,
            )

            self.assertFalse(changed)
            self.assertEqual(formula_file.read_text(encoding="utf-8"), original)

    def test_update_sd_formula(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(
                tmpdir, "stable-diffusion-cpp.rb", SAMPLE_SD_FORMULA
            )

            fake_release = {
                "tag_name": "master-1141-e637c7b",
                "name": "master-1141-e637c7b",
                "assets": [
                    {
                        "name": "sd-master-e637c7b-bin-Darwin-macOS-26.7.2-arm64.zip",
                        "browser_download_url": "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Darwin-macOS-26.7.2-arm64.zip",
                        "digest": "sha256:" + "1" * 64,
                    },
                    {
                        "name": "sd-master-e637c7b-bin-Linux-Ubuntu-24.04-x86_64-rocm-10.1.0.zip",
                        "browser_download_url": "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-24.04-x86_64-rocm-10.1.0.zip",
                        "digest": "sha256:" + "2" * 64,
                    },
                    {
                        "name": "sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64.zip",
                        "browser_download_url": "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64.zip",
                        "digest": "sha256:" + "3" * 64,
                    },
                    {
                        "name": "sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64-vulkan.zip",
                        "browser_download_url": "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64-vulkan.zip",
                        "digest": "sha256:" + "4" * 64,
                    },
                ],
            }

            with patch("update_formulae.get_latest_release", return_value=fake_release):
                changed = update_formulae.update_rolling_release_formula(
                    str(formula_file),
                    "leejet/stable-diffusion.cpp",
                    dry_run=False,
                )

            self.assertTrue(changed)

            updated_content = formula_file.read_text(encoding="utf-8")
            self.assertIn('version "1141"', updated_content)
            self.assertIn(
                "master-1141-e637c7b/sd-master-e637c7b-bin-Darwin-macOS-26.7.2-arm64.zip",
                updated_content,
            )
            self.assertIn(f'sha256 "{"1" * 64}"', updated_content)
            self.assertIn(
                "master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-24.04-x86_64-rocm-10.1.0.zip",
                updated_content,
            )
            self.assertIn(f'sha256 "{"2" * 64}"', updated_content)
            self.assertIn(
                "master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64.zip",
                updated_content,
            )
            self.assertIn(f'sha256 "{"3" * 64}"', updated_content)
            self.assertIn(
                "master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64-vulkan.zip",
                updated_content,
            )
            self.assertIn(f'sha256 "{"4" * 64}"', updated_content)

    def test_sd_no_version_bump_without_matching_assets(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(
                tmpdir, "stable-diffusion-cpp.rb", SAMPLE_SD_FORMULA
            )
            original = formula_file.read_text(encoding="utf-8")

            fake_release = {
                "tag_name": "master-1142-deadbee",
                "name": "master-1142-deadbee",
                "assets": [
                    {
                        "name": "sd-master-deadbee-bin-win-cpu-x64.zip",
                        "browser_download_url": "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1142-deadbee/sd-master-deadbee-bin-win-cpu-x64.zip",
                        "digest": "sha256:" + "9" * 64,
                    },
                ],
            }

            with patch("update_formulae.get_latest_release", return_value=fake_release):
                changed = update_formulae.update_rolling_release_formula(
                    str(formula_file),
                    "leejet/stable-diffusion.cpp",
                    dry_run=False,
                )

            self.assertFalse(changed)
            self.assertEqual(formula_file.read_text(encoding="utf-8"), original)

    def test_no_changes_on_same_content(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(
                tmpdir, "rocmfpx.rb", SAMPLE_ROCMFPX_FORMULA
            )

            changed = update_formulae.update_builder_formula_content(
                str(formula_file),
                "b1136",
                {},
                dry_run=False,
            )
            self.assertFalse(changed)

    def test_asset_roles_are_tag_independent(self):
        self.assertEqual(
            asset_role("rocmfpx-b1136-ubuntu-rocm-gfx1151-x64.zip"),
            asset_role("rocmfpx-b1137-ubuntu-rocm-gfx1151-x64.zip"),
        )
        self.assertEqual(
            asset_role("rocmfpx-b1132-ubuntu-rocm-gfx1151-q38rocm-x64.zip"),
            asset_role("q38rocm-b1132-ubuntu-rocm-gfx1151-x64.zip"),
        )
        self.assertEqual(
            sd_asset_role("sd-master-0000000-bin-Darwin-macOS-26.5.2-arm64.zip"),
            sd_asset_role("sd-master-6b3edaa-bin-Darwin-macOS-26.7.2-arm64.zip"),
        )

    def test_find_matching_asset_respects_rules(self):
        rules = update_formulae.get_asset_rules("rocmfpx.rb")
        asset_shas = {
            "rocmfpx-b1137-ubuntu-rocm-gfx1151-x64.zip": "aaaa",
            "kingjones-rocmfpx-b1134-ubuntu-rocm-gfx1151-x64.zip": "bbbb",
        }

        matched = find_matching_asset(
            "rocmfpx-b1136-ubuntu-rocm-gfx1151-x64.zip",
            asset_shas,
            rules,
        )
        self.assertEqual(matched, ("rocmfpx-b1137-ubuntu-rocm-gfx1151-x64.zip", "aaaa"))
        self.assertFalse(
            is_asset_allowed(
                "kingjones-rocmfpx-b1134-ubuntu-rocm-gfx1151-x64.zip", rules
            )
        )
        self.assertFalse(
            is_asset_allowed("rocmfpx-b1132-ubuntu-rocm-gfx1151-q38rocm-x64.zip", rules)
        )

    def test_find_latest_release_with_assets_skips_nightly_releases(self):
        releases = [
            {
                "tag_name": "nightly-20261126",
                "draft": False,
                "prerelease": False,
                "assets": [{"name": "shimmy-2.6.5.x86_64_linux.bottle.1.tar.gz"}],
            },
            {
                "tag_name": "b1136",
                "draft": False,
                "prerelease": False,
                "assets": [{"name": "rocmfpx-b1136-ubuntu-rocm-gfx1151-x64.zip"}],
            },
        ]

        with patch("update_formulae.fetch_json", side_effect=[releases, []]):
            release = find_latest_release_with_assets(
                "Heretek-AI/homebrew-tap",
                "rocmfpx.rb",
            )

        self.assertIsNotNone(release)
        self.assertEqual(release["tag_name"], "b1136")

    def test_config_has_no_builder_fallback_repo(self):
        config = update_formulae.load_config_from_ledger()
        for name, entry in config.items():
            self.assertNotIn(
                "fallback_repo", entry, f"{name} still defines fallback_repo"
            )

        with patch("update_formulae.os.path.exists", return_value=False):
            fallback_config = update_formulae.load_config_from_ledger()
        for name, entry in fallback_config.items():
            self.assertNotIn(
                "fallback_repo", entry, f"{name} still defines fallback_repo"
            )

    def test_update_multi_asset_release_formula(self):
        sample_colibri = """class Colibri < Formula
  homepage "https://github.com/JustVugg/colibri"
  on_macos do
    url "https://github.com/JustVugg/colibri/releases/download/v2.2.0/colibri-v2.2.0-macos-arm64.tar.gz"
    sha256 "0000000000000000000000000000000000000000000000000000000000000001"
  end
  on_linux do
    url "https://github.com/JustVugg/colibri/releases/download/v2.2.0/colibri-v2.2.0-linux-x86_64.tar.gz"
    sha256 "0000000000000000000000000000000000000000000000000000000000000002"
  end
end
"""
        fake_release = {
            "tag_name": "v2.3.0",
            "assets": [
                {
                    "name": "colibri-v2.3.0-macos-arm64.tar.gz",
                    "browser_download_url": "https://example.com/mac",
                    "digest": "sha256:" + "a" * 64,
                },
                {
                    "name": "colibri-v2.3.0-linux-x86_64.tar.gz",
                    "browser_download_url": "https://example.com/lin",
                    "digest": "sha256:" + "b" * 64,
                },
            ],
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            formula_file = self._write_formula(tmpdir, "colibri.rb", sample_colibri)
            with patch("update_formulae.get_latest_release", return_value=fake_release):
                changed = update_formulae.update_multi_asset_release_formula(
                    str(formula_file),
                    "JustVugg/colibri",
                    dry_run=False,
                )
            self.assertTrue(changed)
            updated = formula_file.read_text(encoding="utf-8")
            self.assertIn("v2.3.0/colibri-v2.3.0-macos-arm64.tar.gz", updated)
            self.assertIn("a" * 64, updated)
            self.assertIn("v2.3.0/colibri-v2.3.0-linux-x86_64.tar.gz", updated)
            self.assertIn("b" * 64, updated)


if __name__ == "__main__":
    unittest.main()
