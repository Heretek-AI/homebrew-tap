class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1015/q38rocm-b1015-ubuntu-rocm-gfx1151-x64.zip"
  version "1031"
  sha256 "bf1c622497e48217e0d92d041e4004d77b4f7807bbd2721d050034d66c930331"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  option "with-multi-arch", "Single binary for gfx1100 (RX 7900-class) + gfx1151 (Strix Halo)"
  option "with-gfx1150", "Build for AMD Strix Point APU (Radeon 890M / 880M)"
  option "with-gfx120X", "Build for AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)"
  option "with-gfx110X", "Build for AMD RDNA3 GPUs (RX 7900 / 7800, Radeon 780M)"
  option "with-gfx103X", "Build for AMD RDNA2 GPUs / Steam Deck"
  option "with-gfx90a",  "Build for AMD Instinct MI210 / MI250X"
  option "with-gfx908",  "Build for AMD Instinct MI100"

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "multi-arch"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1031/kingjones-rocmfpx-b1031-ubuntu-rocm-multiarch-x64.zip"
        sha256 "5f48f8df9610c373d636917aea227334b1ac4081c60c909bc61112508e4ee54f"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1031/kingjones-rocmfpx-b1031-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "258c44b976d726b63df85048f78fd1b6706454ac01b5ff0e0fe24fa9bd37effd"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1031/kingjones-rocmfpx-b1031-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "33fbdcebf58a4677c2d17647ae8bccafc20848fdf86fc713a161e89e84a97ecf"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1031/kingjones-rocmfpx-b1031-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "f06dd6d61a191cfe200c74764bcc54765bf54d31979bd57d05f7035d6235082f"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1031/kingjones-rocmfpx-b1031-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "079b836baa285f94f937fbe1e30bbf3f2c8b2b534e7b4a972512b104c55bf569"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1031/kingjones-rocmfpx-b1031-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "45dbb66a9d64b7dddd5f33bdd7c3683d9048a06dfb7d06975938f453b6f0bd81"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1031/kingjones-rocmfpx-b1031-ubuntu-rocm-gfx908-x64.zip"
        sha256 "32cb09cb7c51a7ddad96c91b5e4f0b337d8149606fee90e852300cfeaa722bf3"
      end
    end
  end

  def install
    nested = Pathname("bin").directory?
    base = nested ? libexec/"bin" : libexec
    if nested
      (libexec/"bin").install Dir["bin/*"]
      (libexec/".kpack").install Dir[".kpack/*"]
    else
      libexec.install Dir["*"]
    end

    %w[llama-server llama-cli llama-quantize llama-bench llama-perplexity].each do |cmd|
      next unless (base/cmd).exist?

      chmod 0755, base/cmd
      bin.write_exec_script (base/cmd)
      (bin/"rocmfpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
    end

    return unless (base/"llama-server").exist?

    (bin/"rocmfpx").write <<~SH
      #!/bin/bash
      exec "#{base/"llama-server"}" "$@"
    SH
  end

  def caveats
    <<~EOS
      This formula distributes canonical upstream ROCmFPX (charlie12345/ROCmFPX).
      For Ciru's specialized research fork (DualView Q7, PromptForge, Kairic Edge),
      install:
        brew install ciru-rocmfpx
    EOS
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/rocmfpx.log"
    error_log_path var/"log/rocmfpx.error.log"
  end

  test do
    if (libexec/"llama-server").exist? || (libexec/"bin"/"llama-server").exist?
      assert_match(/version:|usage:|llama/i, pipe_output("#{bin}/llama-server --version 2>&1"))
    else
      assert_match(/usage:|llama/i, pipe_output("#{bin}/llama-cli --help 2>&1"))
    end
  end
end
