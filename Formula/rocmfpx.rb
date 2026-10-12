class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1111/q38rocm-b1111-ubuntu-rocm-gfx1151-x64.zip"
  version "1115"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1115/kingjones-rocmfpx-b1115-ubuntu-rocm-multiarch-x64.zip"
        sha256 "298defe429e3a9e45e287c0fb15b9d64e19a166291062946f39666f853d56183"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1115/kingjones-rocmfpx-b1115-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "d48fd3808f9482fb7a2b6e684c64f9dfe8c8ed38197c7cc28db34d10e476fe71"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1115/kingjones-rocmfpx-b1115-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "3495af5d8303f64519b04604dcd0e610ffed3ceafe9bd3b409521e8857a93299"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1115/kingjones-rocmfpx-b1115-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "ceb37b954afcbc3cc879b819c0d78a3d613f198f3208787479188a03b8abf12d"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1115/kingjones-rocmfpx-b1115-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "b58e4d25fa30c828cfa99ccb1155f44dc25cbb817be94deabe62828a4186de86"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1115/kingjones-rocmfpx-b1115-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "8bf9962d64945733905ee78432c4b34288dee4bc2f1956e0b3db5cdd3ca016a5"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1115/kingjones-rocmfpx-b1115-ubuntu-rocm-gfx908-x64.zip"
        sha256 "63344c6a85f70e679917446d9d32e4630209c5f8bb7e0fcc3fbb613783530910"
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
