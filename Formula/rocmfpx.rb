class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1040/q38rocm-b1040-ubuntu-rocm-gfx1151-x64.zip"
  version "1041"
  sha256 "0c2eb1719b978a94f18078742121fa23c7316577010b7aebbcd23d7ca8af0616"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1041/kingjones-rocmfpx-b1041-ubuntu-rocm-multiarch-x64.zip"
        sha256 "bb84de4f100a9bab6a95b81bd328454d95b206f99b739175f8f994d479252eeb"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1041/kingjones-rocmfpx-b1041-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "319db1f8d8757f5357d206f461de63afe3be8339c1f30a33628633846c4caa6c"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1041/kingjones-rocmfpx-b1041-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "6f8c53b604422dd6895710fdbd9f130f76f50fb918470f48819acaf3d1b22ea8"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1041/kingjones-rocmfpx-b1041-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "9b2369bd3f6057b759e3ed2663566b1b76da1a3b1c334bfeae482921db86c936"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1041/kingjones-rocmfpx-b1041-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "2e87cccc4dd0781d4e6721704e303016d69f9913ec3a140c8117bd58d2a4f614"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1041/kingjones-rocmfpx-b1041-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "bfade53df7ed3ad28ac9a2eaf49661faa9b809501aea021842ab7547697580c1"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1041/kingjones-rocmfpx-b1041-ubuntu-rocm-gfx908-x64.zip"
        sha256 "c9c9b22e5b1a5eafd97236d9a5f0f4b64b986262d06547ed2eefcf9640154f64"
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
