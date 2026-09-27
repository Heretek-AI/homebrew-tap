class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1053/q38rocm-b1053-ubuntu-rocm-gfx1151-x64.zip"
  version "1076"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1076/rocmfpx-b1076-ubuntu-rocm-multiarch-x64.zip"
        sha256 "70d9bbd8c9d8e2aa734cf4b6d507a6c85fbb122129ae151c7ee5f87e9ff4c2a9"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1076/rocmfpx-b1076-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "54aeed09d4c325d49a7e58a56faf979a44032e703c1c998fd965844a2ef2cbef"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1076/rocmfpx-b1076-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "d9982518ce04794f1454ae41aba1ef7637609dc039d42fab3dd7b9be89beeca0"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1076/rocmfpx-b1076-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "dbeec4f9dfda1e39a28de414feca7088c0ab74b81af755be4a29c2ead8a07bca"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1076/rocmfpx-b1076-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "20e5f829935d32e71b6eaef810bea82185f6ecb93137bd35e6e762704c4b1fcb"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1076/rocmfpx-b1076-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "57f4e57d023dc019952c9cb01fc0a1010b74b7f85e2b972986bf1c7a8092bf26"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1076/rocmfpx-b1076-ubuntu-rocm-gfx908-x64.zip"
        sha256 "f58b9c049f906014264983d9214e0fe5fbb93fdb8e026eb2b114ac21e518ad96"
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
