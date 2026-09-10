class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "1034"
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
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "0b84817bcf2fb5a70dfd198eacb1f25c03705abc118d56f9785c76e3adfa12f2"
    elsif Hardware::CPU.intel?
      if build.with? "rocm-gfx1151"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-b1034-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "4280895b183801b815a2aa2dd0e4ef4d111102d98ec6b774c4dc88f4d1155fce"
      elsif build.with? "rocm-gfx1150"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-b1034-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "08f344a4301e572e02b1cef4f49762d6cf72b5aecccc3492fbcc004dd9bb0bad"
      elsif build.with? "rocm-gfx120X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-b1034-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "0bde78f29d135c5bbb792a83495d80615b1203d7c22ed382b3a2ccdbb461ac75"
      elsif build.with? "rocm-gfx110X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-b1034-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "5d22ec870e4ff526e16f83aa45ca2c5277ab91ae876499f4bec80b7d2ec50331"
      elsif build.with? "rocm-gfx103X"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-b1034-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "c0fbfd7fce8624e2a8302eb515385d0b89947e1ffa1ca67b2e5d546879c9ed0e"
      elsif build.with? "rocm-gfx90a"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-b1034-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "4e9c76968279205eed53b8880a34fac06341853e6cd3c161a5ad035c2217c48f"
      elsif build.with? "rocm-gfx908"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-b1034-ubuntu-rocm-gfx908-x64.zip"
        sha256 "3ae39af26ee17c9a033100aee5dd02d6ee0c750c01cf078d75e773f649f7d941"
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
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "cbca981d4c57deb8f6ab2fe734a56ea437b9afc8a093cc164b91b3191b34eac9"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1034/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "4850c1b4d2385e8fa2e21193612b2b46f11c59394e9a06f76545838f19a4b401"
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
