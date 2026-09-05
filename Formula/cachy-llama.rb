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

  option "with-cuda-sm100", "Install CUDA build for NVIDIA Blackwell (SM100)"
  option "with-cuda-sm120", "Install CUDA build for NVIDIA Blackwell RTX 50-series (SM120)"
  option "with-cuda-sm90",  "Install CUDA build for NVIDIA Hopper (H100/H200, SM90)"
  option "with-cuda-sm89",  "Install CUDA build for NVIDIA Ada Lovelace (RTX 4090/4080, SM89)"
  option "with-cuda-sm86",  "Install CUDA build for NVIDIA Ampere (RTX 3090/3080/A6000, SM86)"
  option "with-cuda-sm80",  "Install CUDA build for NVIDIA Ampere Data Center (A100, SM80)"
  option "with-cuda-sm75",  "Install CUDA build for NVIDIA Turing (RTX 2080/T4, SM75)"
  option "with-cpu", "Install CPU-only baseline build"

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "a0c79e2f83a7c08d96bf765b88eef49edcba531c5f6e2bb3b7c08034f31b8cc4"
    elsif Hardware::CPU.intel?
      if build.with? "cuda-sm100"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cuda-sm_100-x64.tar.gz"
        sha256 "8a89faa2f6f795cea91d03621b7e3b9ae6f82490d8bb9ee2cf2e0427c32d01b9"
      elsif build.with? "cuda-sm120"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cuda-sm_120-x64.tar.gz"
        sha256 "f8bf19212301e6f582aab1a28f9b5982f6327b0e568a879416f0ac4614ff089f"
      elsif build.with? "cuda-sm90"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cuda-sm_90-x64.tar.gz"
        sha256 "ba26e71dd54309289f998ba8c2112abd3a6ce50b2abb1322dfc2fcd85fdfd3ee"
      elsif build.with? "cuda-sm89"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cuda-sm_89-x64.tar.gz"
        sha256 "c2a67e3b780312cebd2c18b5dd56b323b29557dc266cc18c12b5acfd6a7cb3a0"
      elsif build.with? "cuda-sm86"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cuda-sm_86-x64.tar.gz"
        sha256 "498f219cd27910aa8d2ec6484f0c0fc6e07d8ffdfdfb85b3dcc7604b53a82789"
      elsif build.with? "cuda-sm80"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cuda-sm_80-x64.tar.gz"
        sha256 "c9387462c62363ec2e487b87db610eeeac8dde685ff9fd72f0c26defef9edb81"
      elsif build.with? "cuda-sm75"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cuda-sm_75-x64.tar.gz"
        sha256 "9909dee6d16e1176eaa2d99bb53e87b1e6a20721c9399ebc4c7d5ec7ced1a7f0"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "39e1f4e9b6e2d31772dc179a883276ba41b6a72cbea5a8f6da03d2b12a4102b5"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1028/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
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
