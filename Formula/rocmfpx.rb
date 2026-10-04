class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1093/q38rocm-b1093-ubuntu-rocm-gfx1151-x64.zip"
  version "1097"
  sha256 "097996125f04be7f38bf5e84f548c747b15504a3c371c24b0083b57a1f91f2b4"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1097/kingjones-rocmfpx-b1097-ubuntu-rocm-multiarch-x64.zip"
        sha256 "fbc1f7c05413be020745a37882d4012456e04084c6478c77b2b1e703876edbed"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1097/kingjones-rocmfpx-b1097-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "fb6f8a98d08d66d1d627f6cb405733cf0659eabd9038e009776715b4e8bd8746"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1097/kingjones-rocmfpx-b1097-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "b8971082d5929261beb306281a380cd6931c3e56d1ce6505d321639dcb9466cd"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1097/kingjones-rocmfpx-b1097-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "0367ded9f1a4482863878d4003fcd7fcf27e3fed52a677c70891eba949385c50"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1097/kingjones-rocmfpx-b1097-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "77e9bc40d8d64a7b4bcf047d51eaa41c40840f78c76a1319943f6251cf32fe28"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1097/kingjones-rocmfpx-b1097-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "58eeed655ed3864ce9c3b98b343cfaf64e973855460743dba3699ec4d4690e7b"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1097/kingjones-rocmfpx-b1097-ubuntu-rocm-gfx908-x64.zip"
        sha256 "2e2583bb0ec145fcc249c02f079a03610327b8136b4575dda843c3b297109f3e"
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
