class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "1024"
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
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "4474de140f9bf3e80324f32d486b7ac17dc310e2ee79614a014f6b5eed023bbd"
    elsif Hardware::CPU.intel?
      if build.with? "cuda-sm100"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cuda-sm_100-x64.tar.gz"
        sha256 "eb8c62a620f42695463d1b62bd9c665db00f9f54eb6407c717c82c2646855430"
      elsif build.with? "cuda-sm120"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cuda-sm_120-x64.tar.gz"
        sha256 "4e94a45ca1484ca5bc7cc0c9fa91fbaf50559a0417d73123e68e72e161a58fd0"
      elsif build.with? "cuda-sm90"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cuda-sm_90-x64.tar.gz"
        sha256 "c9249d5674ba3e0a07be6da01b306954acea7ee400dca392fd0eaa2b4e62a023"
      elsif build.with? "cuda-sm89"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cuda-sm_89-x64.tar.gz"
        sha256 "846e76387c417df5b10c74071a46c7f3a208c084e6862e456503866dd64ab969"
      elsif build.with? "cuda-sm86"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cuda-sm_86-x64.tar.gz"
        sha256 "7b307962089fb877b5243f9733f205f53b188afc83fe2b84ebd448b5f0f189c8"
      elsif build.with? "cuda-sm80"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cuda-sm_80-x64.tar.gz"
        sha256 "437d83cbd8e56d9918b45538a9289ca13bd2a063f503d9afedaaba43884ed850"
      elsif build.with? "cuda-sm75"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cuda-sm_75-x64.tar.gz"
        sha256 "7e20a5a5d71bdcda8cd00c797d93ae5da4588f8f61d04a8b85172ba732975ad9"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "7ef46c3997de8e1f10535d1d164f7cfeabee9dd42b3e878134645073b18cb12e"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1024/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "2460f7a8a18b761e8364e91a6336f4e6e9302c6b40e9e763d0c48a7042aff3a8"
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
