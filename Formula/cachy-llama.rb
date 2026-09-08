class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "1032"
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
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "6c0ad30f5785a28ffb4799d0886fac239701670fa47099e80d780d38ece0248b"
    elsif Hardware::CPU.intel?
      if build.with? "rocm-gfx1151"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-b1032-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "e29b95557649dcc8037bbfe6ae84514a85b410ca7cdc3f39494123fa6396a20d"
      elsif build.with? "rocm-gfx1150"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-b1032-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "71fb836897e142466ae0744681255abbae7448c9f156eb1c745844e26ee7d7d1"
      elsif build.with? "rocm-gfx120X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-b1032-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "2bce379b5f22bdb404e5bfb5d6b9a4c04b1e0681c9d3708e098d30956655d0df"
      elsif build.with? "rocm-gfx110X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-b1032-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "a6d39d949dcd71aa3d4218819fdf8acc9aa8a766ccf8d7fc6850a047d8cd51b6"
      elsif build.with? "rocm-gfx103X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-b1032-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "7d5af13dfde93737a82824cc37a977deb66c071741a78c9f52703ccba2d7d141"
      elsif build.with? "rocm-gfx90a"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-b1032-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "dce0cc96cfb5eae49db6ce4e0f7e0567408c0f51fc27528db2b206b4a2a3b429"
      elsif build.with? "rocm-gfx908"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-b1032-ubuntu-rocm-gfx908-x64.zip"
        sha256 "cf45e155e979a35638aee5e464cfda3cd35103827ca7727adacd920bf0ee5eb1"
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
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "d59a7c3e6d9c69b55fa00aa248f919affbcb0740f735076736a49e22f051627d"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1032/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "dc4de7d1b6635c15115178e1783332b9fd099fd569863390d81e74fd0dbe4f49"
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
