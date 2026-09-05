class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "1029"
  sha256 "d1eaf38f50bf04426c5f583d25967b1b8fe1731a9fc1d8e6c4db1e7a07b2541b"
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
  option "with-rocm-gfx908",  "Install ROCm build optimized for AMD Instinct MI100"
  option "with-cuda-sm100",   "Install CUDA build for NVIDIA Blackwell (SM100)"
  option "with-cuda-sm120",   "Install CUDA build for NVIDIA Blackwell RTX 50-series (SM120)"
  option "with-cuda-sm90",    "Install CUDA build for NVIDIA Hopper (H100/H200, SM90)"
  option "with-cuda-sm89",    "Install CUDA build for NVIDIA Ada Lovelace (RTX 4090/4080, SM89)"
  option "with-cuda-sm86",    "Install CUDA build for NVIDIA Ampere (RTX 3090/3080/A6000, SM86)"
  option "with-cuda-sm80",    "Install CUDA build for NVIDIA Ampere Data Center (A100, SM80)"
  option "with-cuda-sm75",    "Install CUDA build for NVIDIA Turing (RTX 2080/T4, SM75)"
  option "with-cpu",          "Install CPU-only baseline build"

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "a0c79e2f83a7c08d96bf765b88eef49edcba531c5f6e2bb3b7c08034f31b8cc4"
    elsif Hardware::CPU.intel?
      if build.with? "rocm-gfx1151"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-b1029-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "83bd02fe822c8acbc303addc040987cf8b9c8dc41726b02abcf598f3a84f122a"
      elsif build.with? "rocm-gfx1150"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-b1029-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "34acd857a0ed8cb05f5e692105bdc027dd6dc84418f2bc523be4db0cdbd30595"
      elsif build.with? "rocm-gfx120X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-b1029-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "a7d9c1493534011238f95874dc5566529e5596da51ab11a45284b5f969e4724f"
      elsif build.with? "rocm-gfx110X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-b1029-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "8833dff2bc21aa113d9a5b686ca85d399d4e1ce9471b5e7b2549bb864c309373"
      elsif build.with? "rocm-gfx103X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-b1029-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "6a48b39d411f83c17f10120a0d76ee90ac278dbbf161ecf2b0c8ebbc73e9f3fe"
      elsif build.with? "rocm-gfx90a"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-b1029-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "fed0b49c7d1257717984342346073a1efadde0339ed98a76fdf108990a69d5bc"
      elsif build.with? "rocm-gfx908"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-b1029-ubuntu-rocm-gfx908-x64.zip"
        sha256 "8fcdb4ea2763cf72b59d35e79039745ac99437d3941a1d28c74619f567b71c8b"
      elsif build.with? "cuda-sm100"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cuda-sm_100-x64.tar.gz"
        sha256 "8a89faa2f6f795cea91d03621b7e3b9ae6f82490d8bb9ee2cf2e0427c32d01b9"
      elsif build.with? "cuda-sm120"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cuda-sm_120-x64.tar.gz"
        sha256 "f8bf19212301e6f582aab1a28f9b5982f6327b0e568a879416f0ac4614ff089f"
      elsif build.with? "cuda-sm90"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cuda-sm_90-x64.tar.gz"
        sha256 "ba26e71dd54309289f998ba8c2112abd3a6ce50b2abb1322dfc2fcd85fdfd3ee"
      elsif build.with? "cuda-sm89"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cuda-sm_89-x64.tar.gz"
        sha256 "c2a67e3b780312cebd2c18b5dd56b323b29557dc266cc18c12b5acfd6a7cb3a0"
      elsif build.with? "cuda-sm86"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cuda-sm_86-x64.tar.gz"
        sha256 "498f219cd27910aa8d2ec6484f0c0fc6e07d8ffdfdfb85b3dcc7604b53a82789"
      elsif build.with? "cuda-sm80"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cuda-sm_80-x64.tar.gz"
        sha256 "c9387462c62363ec2e487b87db610eeeac8dde685ff9fd72f0c26defef9edb81"
      elsif build.with? "cuda-sm75"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cuda-sm_75-x64.tar.gz"
        sha256 "9909dee6d16e1176eaa2d99bb53e87b1e6a20721c9399ebc4c7d5ec7ced1a7f0"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "39e1f4e9b6e2d31772dc179a883276ba41b6a72cbea5a8f6da03d2b12a4102b5"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1029/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "80bca77e84e8c0e54692acad1fa96fe45656d1d7dc8645b6d010c2a1e6d5c962"
      end
    end
  end

  def install
    libexec.install Dir["*"]

    # Wrap executables so that $ORIGIN RPATH dynamic libraries inside libexec are discovered cleanly
    %w[llama-cli llama-server llama-quantize llama-bench llama-perplexity].each do |cmd|
      next unless (libexec/cmd).exist?

      chmod 0755, libexec/cmd
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
    assert_match "llama", pipe_output("#{bin}/llama-cli --help 2>&1")
  end
end
