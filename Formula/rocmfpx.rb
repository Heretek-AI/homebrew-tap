class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1111/q38rocm-b1111-ubuntu-rocm-gfx1151-x64.zip"
  version "1112"
  sha256 "704c5675b0fa2dcd6f032a83a5aeac76c47f36872715fe19eb432b43be8286e3"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1112/kingjones-rocmfpx-b1112-ubuntu-rocm-multiarch-x64.zip"
        sha256 "fd72efe549f4ce912becbbba02ae2eae80fe12a823c69268d482c5ea137b84a9"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1112/kingjones-rocmfpx-b1112-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "6057f0884ea5e97b868bf8bd8779c552b7e19203af68d1543b641325ed4fcebb"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1112/kingjones-rocmfpx-b1112-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "3ad80a14444b1a5416fc91f962c982f7626f920f6ac440399e20170e617931fb"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1112/kingjones-rocmfpx-b1112-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "94c6d854bd9ce2dfb409f3875f0e3487772f13f470fb841a05f5e06c034ded3b"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1112/kingjones-rocmfpx-b1112-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "9bfdbeb0180cd28e99061d2c5e472a6795c7da07b26607c57c80205767fdd274"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1112/kingjones-rocmfpx-b1112-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "1ec7d99e4dd3273add760dab1b905cb5994de7350357e72cb6017a291014f61b"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1112/kingjones-rocmfpx-b1112-ubuntu-rocm-gfx908-x64.zip"
        sha256 "6ce345c7a79fba4a7c7246e25b11b2f28bf3e2f0268955428c191cd4b989365d"
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
