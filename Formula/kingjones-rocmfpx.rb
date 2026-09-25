class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1053/q38rocm-b1053-ubuntu-rocm-gfx1151-x64.zip"
  version "1070"
  sha256 "a774fb8437d89fa9cb60c8bb60beeee2c26fc6c14556e96705df65efc35a88c9"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1070/rocmfpx-b1070-ubuntu-rocm-multiarch-x64.zip"
        sha256 "bd157dd64edf903168273bcddfea0c927aec51a850634985c92633a047cf3cfd"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1070/rocmfpx-b1070-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "79d75a7ef2b7a5a72dfdda8dbe539e7a7b5c87d5a0fa6e6307bcefe9394c749c"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1070/rocmfpx-b1070-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "490418117eca99372d43766eb60722835307831e9245ed691776dbf99bc6fd0b"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1070/rocmfpx-b1070-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "9ee2eb18f4bd7f9522f9f99d68aa80ce5d1c7aeea60493e3a0bf1151e725f27b"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1070/rocmfpx-b1070-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "5214539d278c4ad3d469469ad80d197e6debd62ad2c8a602b4fffadaefc5eceb"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1070/rocmfpx-b1070-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "c1dcb73311862f6390ea06209bb2ede46dd9bbf26a3bd6899876cb3283192b90"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1070/rocmfpx-b1070-ubuntu-rocm-gfx908-x64.zip"
        sha256 "f4b1b8645e0c99e4961ea52d76da959dd75f0b80db6725dc16962d7a83efe9e3"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1053/q38rocm-b1053-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "a774fb8437d89fa9cb60c8bb60beeee2c26fc6c14556e96705df65efc35a88c9"
      end
    end
  end

  def install
    nested = Pathname("bin").directory?
    base = nested ? libexec/"bin" : libexec
    if nested
      (libexec/"bin").install Dir["bin/*"]
      (libexec/".kpack").install Dir[".kpack/*"] if Pathname(".kpack").directory?
    else
      libexec.install Dir["*"]
    end

    %w[llama-server llama-cli llama-quantize llama-bench llama-perplexity].each do |cmd|
      next unless (base/cmd).exist?

      chmod 0755, base/cmd
      bin.write_exec_script (base/cmd)
      (bin/"kingjones-fpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
      (bin/"kingjones-rocmfpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
    end

    return unless (base/"llama-server").exist?

    (bin/"kingjones-rocmfpx").write <<~SH
      #!/bin/bash
      exec "#{base/"llama-server"}" "$@"
    SH
  end

  def caveats
    <<~EOS
      This formula distributes kingjones30 ROCmFPX (kingjones30/ROCmFPX).
      It carries support for 7 extended model architectures:
      mellum, instella, bailing-hybrid, muse-glimmer, qwen4exp, zaya, and cohere2moe.
    EOS
  end

  service do
    run [opt_bin/"kingjones-rocmfpx", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/kingjones-rocmfpx.log"
    error_log_path var/"log/kingjones-rocmfpx.error.log"
  end

  test do
    if (libexec/"llama-server").exist? || (libexec/"bin"/"llama-server").exist?
      assert_match(/version:|usage:|llama/i, pipe_output("#{bin}/llama-server --version 2>&1"))
    else
      assert_match(/usage:|llama/i, pipe_output("#{bin}/llama-cli --help 2>&1"))
    end
  end
end
