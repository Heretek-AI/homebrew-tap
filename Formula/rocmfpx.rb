class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1046/q38rocm-b1046-ubuntu-rocm-gfx1151-x64.zip"
  version "1047"
  sha256 "959c5de6c3a75aabce241fa5f231163945cf5207d9ba8ca3846bccd9ca5f870a"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1047/kingjones-rocmfpx-b1047-ubuntu-rocm-multiarch-x64.zip"
        sha256 "48836dfede9636cf2e7d188859413e46ccdc863154eb73b589f65e94a870b026"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1047/kingjones-rocmfpx-b1047-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "bdf7261d0422f7a2490c861610426efe810d92753c3e08ccb82cbaf996b66ce8"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1047/kingjones-rocmfpx-b1047-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "ee63b35ddcd733737d4edfb483b5ddc30ec1150f0a0f58506fca9414bb312645"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1047/kingjones-rocmfpx-b1047-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "83d753058f4857fd06fbd73dfa3cb08f0582090e7b321731aa4153237aafd0dc"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1047/kingjones-rocmfpx-b1047-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "478f864cd7d5f8492a844e17e6eefc16aae0d5a135488ee3f6802b4e22851608"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1047/kingjones-rocmfpx-b1047-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "974d5b458d889c71eea294d416fcf2a252467add1781d0e4d65a285f62237569"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1047/kingjones-rocmfpx-b1047-ubuntu-rocm-gfx908-x64.zip"
        sha256 "a8a1ef9d31801fc0d5c6a609dedf199e05dc6ed55cc7c290f3634d2947be6980"
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
