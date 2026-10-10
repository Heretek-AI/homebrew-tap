class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1103/q38rocm-b1103-ubuntu-rocm-gfx1151-x64.zip"
  version "1110"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1110/kingjones-rocmfpx-b1110-ubuntu-rocm-multiarch-x64.zip"
        sha256 "28358b8a75611172f3cf7baee0d474687f5d419e84ce70ce76a3e1dd22947d0b"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1110/kingjones-rocmfpx-b1110-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "203529d1ad2a6a963fd8c03c3cd2d9e7bb484920d382c3c8c83e51f596a29fbe"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1110/kingjones-rocmfpx-b1110-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "7d2a1b0c78ea317f3f69ed2402a91654a758d8af66db53a70103e556547bff99"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1110/kingjones-rocmfpx-b1110-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "3573ccc6b26e73da8a8db442f032f3704624d5ad1ec8fea9571a64388aee61b5"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1110/kingjones-rocmfpx-b1110-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "c04757222121f59d0b781f99983910f0ca83d3cb8457b1f6c43c6624a4c8b4fa"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1110/kingjones-rocmfpx-b1110-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "0c1a3de09c2d066d3ff6de8639d01fd471779797f2c99c61bfc72edd8d5b3033"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1110/kingjones-rocmfpx-b1110-ubuntu-rocm-gfx908-x64.zip"
        sha256 "06dd35cb2ce00859d2995e122748d541fe288f5e544e515ea1352c31adf05e45"
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
