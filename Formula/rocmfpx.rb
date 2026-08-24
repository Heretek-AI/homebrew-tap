class Rocmfpx < Formula
  desc "Low-bit Quantized ROCm 7 Inference Stack (Q2..Q8 ROCMFPX & DualView)"
  homepage "https://github.com/ciru-ai/ROCmFPX"
  version "1005"
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
        sha256 "PLACEHOLDER_FILL_AFTER_FIRST_BUILD"
      elsif build.with? "multi-arch"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1003/rocmfpx-b1003-ubuntu-rocm-multiarch-x64.zip"
        sha256 "b3511f579b968322987ac7a7f4da4945a15ee9e4225a5e621019936d53b70563"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1005/rocmfpx-b1005-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "b787971cdf5cfda8b12cfdff3e39c1ea213f758133619088d8fc5c43751ae6af"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1005/rocmfpx-b1005-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "892d966a691801f60b715d3dd38d5c4c81cefaae7c42e1c9dd52cef28453de6d"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1005/rocmfpx-b1005-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "93af69a287f92f6d1f05396dcd19d8438bc32f7bb22b6e54242a762ba6b9dd57"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1005/rocmfpx-b1005-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "500d75db3abc09e017fde5edc9c70933030c4aa1756a3c6955535e4bcc0ab7f9"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1005/rocmfpx-b1005-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "760991578941d679f12e45cc653a2670572fdc27f1fa3facd7551894851633c2"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1005/rocmfpx-b1005-ubuntu-rocm-gfx908-x64.zip"
        sha256 "8ade9630d8423b624980c2c0c2905143243e2652b3d3cc01eddf1ddbfb4ab937"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1005/rocmfpx-b1005-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "c31d42f4ab7e24f9e24404a8a96d531028226cfd88a9cbe412ff7541650c32b6"
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
