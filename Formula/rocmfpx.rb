class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  version "1011"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-multiarch-x64.zip"
        sha256 "7a02b638b7425b5e59168e5ac135e3ffb72f845d336243b84cce05cdda0afe4b"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "54e1224b6e2a18ab2677f6249060e7d238484d71d92f8084e1c5710ef4de66d4"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "6f66ab76d9c7cb780dee21d3c07a24db9bec909bc39850a3f609e778d681825b"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "072bc97e22c4c0cd7a0e0c14100fc9db21e68f90a6c5c60a44e0c2e4b059e26a"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "877be672f7267fb8ceb09b97f63876c2867ceabf9db04152729c30ae2b3a229e"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "6703cff5fcedaa8e7a2f3702bb68d4f9ff91d395f9968e87a4baa5ed29462611"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-gfx908-x64.zip"
        sha256 "5ffc9eb70c029d5ba434b3fea115ac73506e7fa0da683dfb7578d9a755f32bd5"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1011/rocmfpx-b1011-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "69762f1a7ca4835edbbd3f9febb41695926a6f1113f882dbc92ccc8a8c796fd6"
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
      assert_match "version:", shell_output("#{bin}/llama-server --version 2>&1")
    else
      assert_match "usage", shell_output("#{bin}/llama-cli --help 2>&1")
    end
  end
end
