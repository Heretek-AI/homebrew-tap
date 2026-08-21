class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  version "1.0.0"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  option "with-rocm-gfx1151", "Install ROCm build optimized for AMD Strix Halo (Radeon 8060S / 128GB)"
  option "with-rocm-gfx1150", "Install ROCm build optimized for AMD Strix Point (Radeon 890M / 880M)"
  option "with-rocm-gfx120X", "Install ROCm build optimized for AMD RDNA4 GPUs (RX 9070 XT / 9070)"
  option "with-rocm-gfx110X", "Install ROCm build optimized for AMD RDNA3 GPUs (RX 7900 / 7800, Radeon 780M)"
  option "with-rocm-gfx103X", "Install ROCm build optimized for AMD RDNA2 GPUs / Steam Deck"
  option "with-rocm-gfx90a",  "Install ROCm build optimized for AMD Instinct MI210 / MI250X"
  option "with-cpu",          "Install CPU-only baseline build"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-bin-macos-metal-arm64.tar.gz"
      sha256 "50ce560eb3f5649850f9b421211f242cd6cc29ad1fca65d7e31cff778e90f30c"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    elsif Hardware::CPU.intel?
      if build.with? "rocm-gfx1151"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-b1001-ubuntu-rocm-gfx1151-x64.zip"
      elsif build.with? "rocm-gfx1150"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-b1001-ubuntu-rocm-gfx1150-x64.zip"
      elsif build.with? "rocm-gfx120X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-b1001-ubuntu-rocm-gfx120X-x64.zip"
      elsif build.with? "rocm-gfx110X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-b1001-ubuntu-rocm-gfx110X-x64.zip"
      elsif build.with? "rocm-gfx103X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-b1001-ubuntu-rocm-gfx103X-x64.zip"
      elsif build.with? "rocm-gfx90a"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-b1001-ubuntu-rocm-gfx90a-x64.zip"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
      end
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
  end

  def install
    libexec.install Dir["*"]

    # Wrap executables so that $ORIGIN RPATH dynamic libraries inside libexec are discovered cleanly
    %w[llama-cli llama-server llama-quantize llama-bench llama-perplexity].each do |cmd|
      if File.exist?(libexec/cmd)
        (bin/cmd).write_exec_script libexec/cmd
        (bin/"cachy-#{cmd}").write_exec_script libexec/cmd
      end
    end
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/cachy-llama.log"
    error_log_path var/"log/cachy-llama.error.log"
  end

  test do
    assert_match "usage:", shell_output("#{bin}/llama-cli --help 2>&1")
  end
end
