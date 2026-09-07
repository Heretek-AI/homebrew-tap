class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1015/q38rocm-b1015-ubuntu-rocm-gfx1151-x64.zip"
  version "1028"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1028/kingjones-rocmfpx-b1028-ubuntu-rocm-multiarch-x64.zip"
        sha256 "79ad3dddf8925ed2c685f56e281f1023ba90a5b0b1ddf09898a59e14acb0947b"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1028/kingjones-rocmfpx-b1028-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "2cec7daf135f53a175950fef04ddcb345cae00e747a7c0dd2b149b2b13d3c8e9"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1028/kingjones-rocmfpx-b1028-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "281f12b4aec52658ad1ffb33ec1afaa7fe0919a2ffb9f9807944c3efac9f2c04"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1028/kingjones-rocmfpx-b1028-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "16fd3b7c92ebc7718c59e78a33044cd611db2833828127ec0830898e8cae2006"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1028/kingjones-rocmfpx-b1028-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "f1fcdd8d10c5832c23689235b1c03193527a10d7e3d47b2f9a5741f0b76c90bf"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1028/kingjones-rocmfpx-b1028-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "877f33ea087f9a8e1c786d21a0e68f7c286ed74f062313a26ebec0a1378184a8"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1028/kingjones-rocmfpx-b1028-ubuntu-rocm-gfx908-x64.zip"
        sha256 "1fa3985a40d32c51af3b4239e5fbb1c9957ac7bca5bf1b92895ec9d0b07a18d7"
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
