class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1012/q38rocm-b1012-ubuntu-rocm-gfx1151-x64.zip"
  version "1014"
  sha256 "a36582326c7e17b8103b359ffee1a2d6bf483f1141edb18863748d1b61e1803f"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1014/rocmfpx-b1014-ubuntu-rocm-multiarch-x64.zip"
        sha256 "071c77dbb70ba9302ea8bb0335a23268195898986e20fd38947df25f14d084f6"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1014/rocmfpx-b1014-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "e76f7e68bd16721c6fea094ef6d81154d530d16d798c949fb3be618e4062d489"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1014/rocmfpx-b1014-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "66e30b69812c682c2c2b6314b5faeab77aa0841faf100af7da97b72be2d1bc8d"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1014/rocmfpx-b1014-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "937362b2bc3c2b9b4e3d3ab8b605a23640963fb8393e570e667a5d794b4a82b8"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1014/rocmfpx-b1014-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "8c5dffd58d10ca66d1f99de3abf7510ccdd7765a6f9aee2ea76f7bb7c9d4cadd"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1014/rocmfpx-b1014-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "48f4c8e3f150c204aeb06241cfeaf95c11d07df4166895bde8cc64f8187167b3"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1014/rocmfpx-b1014-ubuntu-rocm-gfx908-x64.zip"
        sha256 "bceabe6e21c4ca58408e4729b4048ab5d514ff287bc5f9a2ad363f26b7252aa2"
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
