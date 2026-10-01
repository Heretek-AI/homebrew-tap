class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1053/q38rocm-b1053-ubuntu-rocm-gfx1151-x64.zip"
  version "1088"
  sha256 "a774fb8437d89fa9cb60c8bb60beeee2c26fc6c14556e96705df65efc35a88c9"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-multiarch-x64.zip"
        sha256 "b05f31cfd5ff74b39bd26a069225babc15b22ed9312856a2f71aade985c8551e"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "4cf45f08a2847a2dd2f01f71394b15c76d01f5a2e51b04d4ca979714e3172e08"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "4192e89c09761685e233c0601ff15f1ae4f41028b867cdc961f4e1fe7dab59ab"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "948bdd8a5f1c48609ad053bbdf9f3f044a83b1e154e225de36e75f7f091767bc"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "814e503a18fb314c1a04967eda5fdd4e5f854d01838a6e8f4e1cb3e2d4cd8a88"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "4a95bc1c36268694cfc5bd472d414554f2a24316e4ca8ab9e1e214573d0e435f"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx908-x64.zip"
        sha256 "023cb4049e552ef36d44af564f6a0836f11481c6ee0b2ce8cdc3378949aa36ad"
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
