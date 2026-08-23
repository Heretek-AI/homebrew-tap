class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "b1009"
  sha256 "b997e1924dbc643b8dc38b13b191ca75944a3924eb672abc8778f1c1f4c5bc77"
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

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "44a9bd545500ec27df151c535993cd746cfdb56e509728ccf5d0bb1545a8813f"
    elsif Hardware::CPU.intel?
      if build.with? "rocm-gfx1151"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-b1001-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx1150"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-b1001-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx120X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-b1001-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx110X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-b1001-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx103X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-b1001-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx90a"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-b1001-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "af6ef0f5ab39f1992544ab5da2b73706e56ae2c7153505911cd35b2594ff938d"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1009/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "06179a2789be63ea19296199cd767b0d51ee53bb2e7668f4d0dfd1f5b60b0a0e"
      end
    end
  end

  def install
    libexec.install Dir["*"]

    # Wrap executables so that $ORIGIN RPATH dynamic libraries inside libexec are discovered cleanly
    %w[llama-cli llama-server llama-quantize llama-bench llama-perplexity].each do |cmd|
      next unless (libexec/cmd).exist?

      bin.write_exec_script (libexec/cmd)
      (bin/"cachy-#{cmd}").write <<~SH
        #!/bin/bash
        exec "#{libexec/cmd}" "$@"
      SH
    end
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/cachy-llama.log"
    error_log_path var/"log/cachy-llama.error.log"
  end

  test do
    assert_match "llama", shell_output("#{bin}/llama-cli --help 2>&1")
  end
end
