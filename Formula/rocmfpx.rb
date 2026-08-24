class Rocmfpx < Formula
  desc "Low-bit Quantized ROCm 7 Inference Stack (Q2..Q8 ROCMFPX & DualView)"
  homepage "https://github.com/ciru-ai/ROCmFPX"
  version "1008"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  # Certified model-specific profiles (server-only builds; accelerated routes
  # are qualified on gfx1151, other families fall back to standard paths)
  option "with-kairic-edge", "Qwen3.8-27B IU4 Kairic Edge certified runtime (Strix Halo)"
  option "with-promptforge", "Qwen3.8-27B ActiveFPX PromptForge certified runtime (Strix Halo)"
  option "with-multi-arch", "Single binary for gfx1100 (RX 7900-class) + gfx1151 (Strix Halo)"
  option "with-gfx1150", "Build for AMD Strix Point APU (Radeon 890M / 880M)"
  option "with-gfx120X", "Build for AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)"
  option "with-gfx110X", "Build for AMD RDNA3 GPUs (RX 7900 / 7800, Radeon 780M)"
  option "with-gfx103X", "Build for AMD RDNA2 GPUs / Steam Deck"
  option "with-gfx90a",  "Build for AMD Instinct MI210 / MI250X"
  option "with-gfx908",  "Build for AMD Instinct MI100"

  depends_on :linux

  # NOTE: --with-multi-arch is built on demand, not by the nightly matrix, so its
  # asset only exists under the tag it was dispatched from. The auto-bump script
  # leaves URLs untouched when the newest release lacks a matching asset.
  on_linux do
    if Hardware::CPU.intel?
      if build.with? "kairic-edge"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1006/rocmfpx-b1006-ubuntu-rocm-gfx1151-kairic-edge-x64.zip"
        sha256 "471c83a3055960d689e32491276da88f41acf0d6fba6ae989344562717ccf933"
      elsif build.with? "promptforge"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1007/rocmfpx-b1007-ubuntu-rocm-gfx1151-promptforge-x64.zip"
        sha256 "0eb95a4d84098b5a9bb9e65122c430233a72f27950fee26ec0de79f1c00dfd3b"
      elsif build.with? "multi-arch"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-multiarch-x64.zip"
        sha256 "15f33327f4e7c9ba64f4ec7c6c1bb998e2dbc961834c59a4903df574b645992a"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "dc8896da5a752469efb3c00aaa35b857eb49154c4295d1dcc9ef6286ad51c69f"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "1bcad9f0078ecaf43149d1db88bfdcb5f881fe966edd081521d697b374714c79"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "cd149b586aa4a33b81b927a179a34707fbd4d3c6ba9a94788518fb9489912955"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "9a50cb44476a66e22eed1d32b506de5f02a8203c84dc9776b9ccfd76a9e78fa9"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "4708e624606ea009b9e2e4ac1cf7c4adefe23ef6de95a5e24225b33fb00e2589"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx908-x64.zip"
        sha256 "e61e1aef65af71871ac5e3a507191f620576a97ba7ab8171f09a6f0fff56344a"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1008/rocmfpx-b1008-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "0c9912fb447355f882c962504ccf74e357095af4bdd4155005f51a973c456864"
      end
    end
  end

  def install
    # Multi-arch (--with-multi-arch) archives nest binaries under bin/ with a
    # sibling .kpack/ directory of GPU kernel packs; rocm_kpack resolves each
    # library's embedded "../.kpack/<name>_@GFXARCH@.kpack" relative to itself,
    # so that geometry must survive installation. Older per-target archives are
    # flat and keep their previous layout.
    nested = Pathname("bin").directory?
    base = nested ? libexec/"bin" : libexec
    if nested
      (libexec/"bin").install Dir["bin/*"]
      (libexec/".kpack").install Dir[".kpack/*"]
    else
      libexec.install Dir["*"]
    end

    %w[llama-server llama-cli llama-quantize llama-bench llama-perplexity].each do |cmd|
      next unless (base/cmd).exist?

      bin.write_exec_script (base/cmd)
      (bin/"rocmfpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
    end
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/rocmfpx.log"
    error_log_path var/"log/rocmfpx.error.log"
  end

  test do
    # Certified profiles (kairic-edge, promptforge) ship only llama-server
    if (libexec/"llama-server").exist? || (libexec/"bin"/"llama-server").exist?
      assert_match "llama", shell_output("#{bin}/llama-server --version 2>&1")
    else
      assert_match "llama", shell_output("#{bin}/llama-cli --help 2>&1")
    end
  end
end
