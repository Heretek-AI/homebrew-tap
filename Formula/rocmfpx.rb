class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1093/q38rocm-b1093-ubuntu-rocm-gfx1151-x64.zip"
  version "1102"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1102/kingjones-rocmfpx-b1102-ubuntu-rocm-multiarch-x64.zip"
        sha256 "806db948df47781d8066d21228ba363f8a50bb4e5291cde36a3d82dc78720583"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1102/kingjones-rocmfpx-b1102-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "efc10a3ae96dcaf5a160e39535f0d08ae081a81618e7d92139cb605b6e42c4ea"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1102/kingjones-rocmfpx-b1102-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "187e294022b7478c3ad734c811e4b6c2d90ff7885c35b9d076b251d9c5c88889"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1102/kingjones-rocmfpx-b1102-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "a7903d6b47aa4f4ac3ffeb95c78e81bfe5fb5015830c7b2f964f01496f9e207d"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1102/kingjones-rocmfpx-b1102-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "93b65c058265790d692ed4a4dc013d030aae13e414becfe7538781258a588c7c"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1102/kingjones-rocmfpx-b1102-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "099ef566d6d8b3a52963a21a4a9c573c2078c05fb1141a7a2b52e1e3c9ce7c53"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1102/kingjones-rocmfpx-b1102-ubuntu-rocm-gfx908-x64.zip"
        sha256 "7bcac8a51133022b33420490eaf2d6b35ba475587826908a9d171365731c713d"
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
