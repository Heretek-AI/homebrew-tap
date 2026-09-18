class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1046/q38rocm-b1046-ubuntu-rocm-gfx1151-x64.zip"
  version "1052"
  sha256 "959c5de6c3a75aabce241fa5f231163945cf5207d9ba8ca3846bccd9ca5f870a"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  option "with-multi-arch", "Single binary for gfx1100 (RX 7900-class) + gfx1151 (Strix Halo)"
  option "with-gfx1150", "Build for AMD Strix Point APU (Radeon 890M / 880M)"
  option "with-gfx120X", "Build for AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)"
  option "with-gfx110X", "Build for AMD RDNA3 GPUs (RX 7900 / 7800, Radeon 780M)"
  option "with-gfx103X", "Build for AMD RDNA2 GPUs / Steam Deck"
  option "with-gfx90a",  "Build for AMD Instinct MI210 / MI250X"
  option "with-gfx908",  "Build for AMD Instinct MI100"

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "multi-arch"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1052/kingjones-rocmfpx-b1052-ubuntu-rocm-multiarch-x64.zip"
        sha256 "a0798fb91c5f929deef2b0ae7da0b0255262af06b88c862bd06c9563b6950047"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1052/kingjones-rocmfpx-b1052-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "9e702353344ee64abec5905f16bdc7fcc6cbb669d116a7ae9e8683ef02646248"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1052/kingjones-rocmfpx-b1052-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "e12277a75a6c1a70742093ba9296a17e7a9678b8018b608c63bd4cd33887f5c8"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1052/kingjones-rocmfpx-b1052-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "d5b42187beaa9b2f816800aa3800c4c670c9a7d106687493bda3c685462931d4"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1052/kingjones-rocmfpx-b1052-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "1bdf2ab41a9c00ce6033b7d64cc876942b9251f4fb958c976f9fa3c221e6e059"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1052/kingjones-rocmfpx-b1052-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "5fc3ed7ba6755e1a4934c36bdc873c25363af95dc02455b14f6aee0274ff4fe9"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1052/kingjones-rocmfpx-b1052-ubuntu-rocm-gfx908-x64.zip"
        sha256 "79af566cd4f4d7532cffa8eaf6b153ce2b13d3706be8510cff8715af669cd9f3"
      end
    end
  end

  def install
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

      chmod 0755, base/cmd
      bin.write_exec_script (base/cmd)
      (bin/"rocmfpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
    end

    return unless (base/"llama-server").exist?

    (bin/"rocmfpx").write <<~SH
      #!/bin/bash
      exec "#{base/"llama-server"}" "$@"
    SH
  end

  def caveats
    <<~EOS
      This formula distributes canonical upstream ROCmFPX (charlie12345/ROCmFPX).
      For Ciru's specialized research fork (DualView Q7, PromptForge, Kairic Edge),
      install:
        brew install ciru-rocmfpx
    EOS
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/rocmfpx.log"
    error_log_path var/"log/rocmfpx.error.log"
  end

  test do
    if (libexec/"llama-server").exist? || (libexec/"bin"/"llama-server").exist?
      assert_match(/version:|usage:|llama/i, pipe_output("#{bin}/llama-server --version 2>&1"))
    else
      assert_match(/usage:|llama/i, pipe_output("#{bin}/llama-cli --help 2>&1"))
    end
  end
end
