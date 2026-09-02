class CachyLlama < Formula
  desc "Persistent KV Cache & MoE Residency LLM Inference Engine"
  homepage "https://github.com/fewtarius/CachyLLama"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1012/cachy-llama-bin-macos-metal-arm64.tar.gz"
  version "1022"
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
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cpu-arm64.tar.gz"
      sha256 "233feea65f09bed4eb4d8af61f480c5f2f67459fb6c2a057686d0b048bb46e2d"
    elsif Hardware::CPU.intel?
      if build.with? "cuda-sm100"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cuda-sm_100-x64.tar.gz"
        sha256 "b5ebad4a3928f180b6c091f07a753468bc1a7888212a0050d2b006be1272fad5"
      elsif build.with? "cuda-sm120"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cuda-sm_120-x64.tar.gz"
        sha256 "a4d0397f6f7e29e940b17dfaf5ed86be9392ccb761097ca9a93fd5d40d5767e2"
      elsif build.with? "cuda-sm90"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cuda-sm_90-x64.tar.gz"
        sha256 "56a52259633ae5fdd230b91092de1837977eec3fdc608fe1d16c393779b0bffd"
      elsif build.with? "cuda-sm89"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cuda-sm_89-x64.tar.gz"
        sha256 "c08831d6fbacd034340cf55474de51cbbceab85c4655899862528cc86707e510"
      elsif build.with? "cuda-sm86"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cuda-sm_86-x64.tar.gz"
        sha256 "e5cdc40d595eb6a8fd7fcd29699b6d6cabbeaf72a1f8ae8bed1720b67e5aab7f"
      elsif build.with? "cuda-sm80"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cuda-sm_80-x64.tar.gz"
        sha256 "6cc028a876fe6747198588ad65d2933adb56c011bf668feb5055e46a8c8bde99"
      elsif build.with? "cuda-sm75"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cuda-sm_75-x64.tar.gz"
        sha256 "4eee88fad0ec0d9c1569a98ad6bbef9dcc152d02f51c98510a122213dc9d9856"
      elsif build.with? "cpu"
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-cpu-x64.tar.gz"
        sha256 "5bccc9f94a5c2ba373c4d50a4feb0d2bc86defab2d69777cf3f7c37bb151dca3"
      else
        url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1022/cachy-llama-bin-ubuntu-vulkan-x64.tar.gz"
        sha256 "6a246060e22a13513325bc7a5a9a3caa71363844839071845e8da72fd587cb17"
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
