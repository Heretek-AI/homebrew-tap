class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1093/q38rocm-b1093-ubuntu-rocm-gfx1151-x64.zip"
  version "1099"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1099/kingjones-rocmfpx-b1099-ubuntu-rocm-multiarch-x64.zip"
        sha256 "c3b3a534865da80f10ab66ce03549b13674186c258e00441cc5ec72d72a303d5"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1099/kingjones-rocmfpx-b1099-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "060f929832ed8cf2c8bc5eaea76f0fb103ca968d67e919260b8c697a6327e868"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1099/kingjones-rocmfpx-b1099-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "f00e8afbc708ef6958c193c811863b29445a9665bfcdd44b0d0e6a0fccad7119"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1099/kingjones-rocmfpx-b1099-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "5ae6a228b18fc39519d87f0f1aba81570857715a310052d438050f35d2ee5b1a"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1099/kingjones-rocmfpx-b1099-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "21a6ca5a747428d492f3ed297fa4b83685a98f144c00295a337ce53fef22f8f6"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1099/kingjones-rocmfpx-b1099-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "df6f7912bed6f2bff32736f8798f1e59e9d2bc1f7f41f6826e2adbd3a8d41e48"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1099/kingjones-rocmfpx-b1099-ubuntu-rocm-gfx908-x64.zip"
        sha256 "2f6e6dfa43996893c548047e36134fe0ba06f5cd262b3e75e19e07e39ca9141e"
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
