class Rocmfpx < Formula
  desc "Low-bit Quantized ROCm 7 Inference Stack (Q2..Q8 ROCMFPX & DualView)"
  homepage "https://github.com/ciru-ai/ROCmFPX"
  version "1.0.0"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  option "with-gfx1150", "Build for AMD Strix Point APU (Radeon 890M / 880M)"
  option "with-gfx120X", "Build for AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)"
  option "with-gfx110X", "Build for AMD RDNA3 GPUs (RX 7900 / 7800, Radeon 780M)"
  option "with-gfx103X", "Build for AMD RDNA2 GPUs / Steam Deck"
  option "with-gfx90a",  "Build for AMD Instinct MI210 / MI250X"
  option "with-gfx908",  "Build for AMD Instinct MI100"

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1001/rocmfpx-b1001-ubuntu-rocm-gfx1150-x64.zip"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1001/rocmfpx-b1001-ubuntu-rocm-gfx120X-x64.zip"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1001/rocmfpx-b1001-ubuntu-rocm-gfx110X-x64.zip"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1001/rocmfpx-b1001-ubuntu-rocm-gfx103X-x64.zip"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1001/rocmfpx-b1001-ubuntu-rocm-gfx90a-x64.zip"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1001/rocmfpx-b1001-ubuntu-rocm-gfx908-x64.zip"
      else
        # Default: AMD Strix Halo (gfx1151)
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1001/rocmfpx-b1001-ubuntu-rocm-gfx1151-x64.zip"
      end
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
  end

  def install
    libexec.install Dir["*"]

    %w[llama-server llama-cli llama-quantize llama-bench llama-perplexity].each do |cmd|
      if File.exist?(libexec/cmd)
        (bin/cmd).write_exec_script libexec/cmd
        (bin/"rocmfpx-#{cmd.sub("llama-", "")}").write_exec_script libexec/cmd
      end
    end
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/rocmfpx.log"
    error_log_path var/"log/rocmfpx.error.log"
  end

  test do
    assert_match "usage:", shell_output("#{bin}/llama-cli --help 2>&1")
  end
end
