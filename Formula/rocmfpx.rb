class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1121/q38rocm-b1121-ubuntu-rocm-gfx1151-x64.zip"
  version "1122"
  sha256 "862e80da5c1e2c936b2b8ec2475ed4170eea1d9b9c691328c0c9cc1c1de4217f"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1122/kingjones-rocmfpx-b1122-ubuntu-rocm-multiarch-x64.zip"
        sha256 "cd292fc797237d1fb973aaa6a285183e0f0c81421ee3d000a540a6c556c1a4f1"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1122/kingjones-rocmfpx-b1122-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "3e692b48575334bf1ac5a4326be6e1d31c96256c7f1213b18bce01f016344dd3"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1122/kingjones-rocmfpx-b1122-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "f7a66e6731d5ddaf3ad9276fc2f6b8bf3149617fa978add480fc420d12c7c598"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1122/kingjones-rocmfpx-b1122-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "1ad0717d39fcd92f6b6f8bd52d5f982469fb188e263c0777e0256dcc786f6415"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1122/kingjones-rocmfpx-b1122-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "e2725571ddb69ebbef30610cbc7171ad92f5b48486962afc2d03f57fee4005af"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1122/kingjones-rocmfpx-b1122-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "b2beb6f81a26eeb3ca85fba54a59eaac654f31c6a7fef22a0bc34469b30a9c85"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1122/kingjones-rocmfpx-b1122-ubuntu-rocm-gfx908-x64.zip"
        sha256 "c9fca02362a3f31965a5d58b6bfb7659d9ed44fa9301243588526f87350b27b0"
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
