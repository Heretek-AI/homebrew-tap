class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1015/q38rocm-b1015-ubuntu-rocm-gfx1151-x64.zip"
  version "1039"
  sha256 "bf1c622497e48217e0d92d041e4004d77b4f7807bbd2721d050034d66c930331"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1039/kingjones-rocmfpx-b1039-ubuntu-rocm-multiarch-x64.zip"
        sha256 "47809a4df96dd81976b4ef34a879b12452e565aa93738f430c5b95de592a3d10"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1039/kingjones-rocmfpx-b1039-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "3e8bf323c8289110cacba8e886434d99e8541c68c23e8893ab1dc0e74124ef2f"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1039/kingjones-rocmfpx-b1039-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "f24ff3bd69fd4110f878f043b349bd9c5f7702e308f4094caa02ad486b9d095d"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1039/kingjones-rocmfpx-b1039-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "d82603fef2b125f24b5c56a140ee38b61504ef1f8b86372117421179534b25c6"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1039/kingjones-rocmfpx-b1039-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "20d09dc39ffaa5c11a2dad70cef2ce7ca3cb449282911be4b9c8238fab2d4029"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1039/kingjones-rocmfpx-b1039-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "18e464c0a077161b93772ab1f5e12b2aa7d3a92bc7d41e1936f06f13de47720c"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1039/kingjones-rocmfpx-b1039-ubuntu-rocm-gfx908-x64.zip"
        sha256 "443079c66fb9c7a1c9a119d1123773bb204791baa32203606d63956d19b7a844"
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
