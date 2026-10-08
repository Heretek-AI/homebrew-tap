class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1103/q38rocm-b1103-ubuntu-rocm-gfx1151-x64.zip"
  version "1104"
  sha256 "3f61ab8aba94c10b61e2f20db97a1dc77500a028203ccffee9ca78dfc0b9d387"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1104/kingjones-rocmfpx-b1104-ubuntu-rocm-multiarch-x64.zip"
        sha256 "d9fd1e8ea19d3494d24b2d183eb4b73cb22eb65113bc3f6ae1bc75d1a160e46e"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1104/kingjones-rocmfpx-b1104-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "eff45edf5bbeb63900e07349165fd56e6ab05d7e1f733f369be006a5a8ea6505"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1104/kingjones-rocmfpx-b1104-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "b5621c9eeda5ba651e5c76a6f9fa27af3c9d70bf78a6498200e4ca74ec0764fb"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1104/kingjones-rocmfpx-b1104-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "f45337f6c7263c871f473d74c7dfca801032efe3a843bc9dcef57daaa09f9e38"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1104/kingjones-rocmfpx-b1104-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "f21cf7f9252a4326304290a94891421eb3f74d947ffdb02367eab91c75f6edbd"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1104/kingjones-rocmfpx-b1104-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "9da95015617653f33b091790b52602ce9ae61258074414508fae122348564828"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1104/kingjones-rocmfpx-b1104-ubuntu-rocm-gfx908-x64.zip"
        sha256 "d045fb5bcac8a95df1b0e8bae429929efb45db29c22cc7503c8464145a12e427"
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
