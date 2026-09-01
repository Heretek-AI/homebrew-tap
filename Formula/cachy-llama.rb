class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "1021"
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
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "e7884bd62584468e8a3dde2cf266663d5447cf1867bfdb88a0bcbef4c94d2647"
    elsif Hardware::CPU.intel?
      if build.with? "cuda-sm100"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cuda-sm_100-x64.tar.gz"
        sha256 "cb95bb80104fe066f3c7f535d8425d373aeca3f7dc29214bb0c3c169259bce93"
      elsif build.with? "cuda-sm120"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cuda-sm_120-x64.tar.gz"
        sha256 "efffe147ae865e4747ca97205a9b089d6cc8c18c9b32c82d2a0606cbca3ed0d5"
      elsif build.with? "cuda-sm90"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cuda-sm_90-x64.tar.gz"
        sha256 "da7349a077973400751088d417d31f674d0cd04f2b35e9d4f4dc0de80a1f327d"
      elsif build.with? "cuda-sm89"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cuda-sm_89-x64.tar.gz"
        sha256 "ba96e200e7521aef34c688077afe24251c64af0b3c0852e4345d283bcddb404d"
      elsif build.with? "cuda-sm86"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cuda-sm_86-x64.tar.gz"
        sha256 "27b26005e157e9220891b7048484b330354088b17511afe2428dcc8394457460"
      elsif build.with? "cuda-sm80"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cuda-sm_80-x64.tar.gz"
        sha256 "32ef2a8ce4693dbb0e609f844cc052ffdfe1f00139f2097a91f0f0b3186aa86a"
      elsif build.with? "cuda-sm75"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cuda-sm_75-x64.tar.gz"
        sha256 "0fe348158159912fb50cd1ea5964f9c6ba5b41cc66ed23a51ed0f8f4abec3b41"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "d48f9a4dd8fe6043449d95805cebbac8574f1cfd7f8fddfa12ad9bbf43a593e6"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "ae47aeb76466d30abfa0163739cf2dd640f76f19da172b788152477d5a6f32a9"
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
