class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1042/q38rocm-b1042-ubuntu-rocm-gfx1151-x64.zip"
  version "1043"
  sha256 "44506cf79defcfc20f17c76bd74db89e7491d430c462e201bdbba835b3456e9a"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1043/kingjones-rocmfpx-b1043-ubuntu-rocm-multiarch-x64.zip"
        sha256 "ba57df3a3592c72579c317739f9661bfee35af5303cdc1cb418d45df332f04e0"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1043/kingjones-rocmfpx-b1043-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "691a7dc09edcfc6b3ea39bcf6d0cb9c3e2ef620dc0bde77954e7ab868db5f372"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1043/kingjones-rocmfpx-b1043-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "3c63ffe5e04787cae7f7f072e1c60166a0b07e5764080649b415ae077345873f"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1043/kingjones-rocmfpx-b1043-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "291f532c7c2de8ddbe5392858cc17c6b7432b0b1718e871d39493c8730da4925"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1043/kingjones-rocmfpx-b1043-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "fea3d2e133f16a1dd431be8ba4a1708e7fe55ffd598b70daf097dfc427ae77f1"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1043/kingjones-rocmfpx-b1043-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "36a9bf83028a9957e81af670ea8bd87452734f47a33051c22c66e33c103b6371"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1043/kingjones-rocmfpx-b1043-ubuntu-rocm-gfx908-x64.zip"
        sha256 "f50014d09bdeb46eb0741bfd3b068928975b7a75bebbab0e09cdaf4da2e91053"
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
