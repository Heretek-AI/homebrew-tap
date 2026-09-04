class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "b1027"
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
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "7cc843752b759d4dd253abaf2bdf88a57ae771269acd8c6de4d4f1a26d1dc056"
    elsif Hardware::CPU.intel?
      if build.with? "cuda-sm100"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cuda-sm_100-x64.tar.gz"
        sha256 "75e2614cda1359154887758006c8a8de9af566d98cb3e0c7b60a0fb44cf9069f"
      elsif build.with? "cuda-sm120"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cuda-sm_120-x64.tar.gz"
        sha256 "ea5799be047e9c5dcb1d05f94574b1aa77d2e0478d324bf27a33a779cde0b0af"
      elsif build.with? "cuda-sm90"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cuda-sm_90-x64.tar.gz"
        sha256 "65003150ff8498cc8a707e83e3395c93fe8e2ef8837672c243b03d76126285bd"
      elsif build.with? "cuda-sm89"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cuda-sm_89-x64.tar.gz"
        sha256 "eedb447f56feb7f02f629548092194ab4019b3fc4b2bc6c9f584d329e6fd277b"
      elsif build.with? "cuda-sm86"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cuda-sm_86-x64.tar.gz"
        sha256 "2494c81b9e784509a242e3e95a3842c40f8aa773cdf85c6733f4aa5d8c3aa93c"
      elsif build.with? "cuda-sm80"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cuda-sm_80-x64.tar.gz"
        sha256 "e1ba2adf8193cf7cba4026331d7d7ddeebd17a50fc9b4b9e0374f199aae3ac0c"
      elsif build.with? "cuda-sm75"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cuda-sm_75-x64.tar.gz"
        sha256 "28c126b972a27d3cbc7f3a1dd5b7d598e4fe98d268ef815784bb544ecda20b80"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "9d5c33728c4b8bc1572b1b9686cd4ff31aaed7c01701922c2db21aa754ce6f80"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1026/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "a3a9077b09cd6caa3e29d5a52514773cd7eb553da8a843c9fc90d7dc8921cf14"
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
