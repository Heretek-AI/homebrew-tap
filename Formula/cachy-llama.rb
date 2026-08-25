class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1010/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "b1011"
  sha256 "a822b245e4b008919dcc95a2bb0f7966dbf8f0f3c6cf08ed43bf90eac2b565d4"
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
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1010/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "68aa2c8e4bfa6acbd8983c061a49015be45092a3d396c4fcb3a991b33ca8d855"
    elsif Hardware::CPU.intel?
      if build.with? "rocm-gfx1151"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1010/cachy-llama-b1001-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx1150"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1010/cachy-llama-b1001-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx120X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1010/cachy-llama-b1001-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx110X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1010/cachy-llama-b1001-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx103X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1010/cachy-llama-b1001-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "rocm-gfx90a"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1010/cachy-llama-b1001-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1010/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "decce55d9bf22b55504f2f4b7d88f8c66261474de354767fe46dd090e45eee56"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1010/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "1e3b24b279634fb1e973f61f53772a517d4fac598e36f2dd94cbf1d8e031680f"
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
