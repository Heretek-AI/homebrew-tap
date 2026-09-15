class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1046/q38rocm-b1046-ubuntu-rocm-gfx1151-x64.zip"
  version "1046"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1045/kingjones-rocmfpx-b1045-ubuntu-rocm-multiarch-x64.zip"
        sha256 "bb96081bce7a2f0aa1aead6556cd61e0cb2f02bd8a373b79bed5791382a388ce"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1045/kingjones-rocmfpx-b1045-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "332aabf6cbd598281dd6a6d2763db575f59d54b36eb619cac16f4f452609eda9"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1045/kingjones-rocmfpx-b1045-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "e5df732953d9dd011d6ddfe8f9c721d1604564df3aa3814f9ed5399b2a658267"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1045/kingjones-rocmfpx-b1045-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "4e37213203a921f7f89d09364952477ae2eb7889f175cdc45b9bb009cd3ccd64"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1045/kingjones-rocmfpx-b1045-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "dc3bc5e6abecae14728c2aa373b86516c2ad572a6e2965a552be1c24e345f364"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1045/kingjones-rocmfpx-b1045-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "1a3fac8e2adebd764adb769d3647a49d2d6d0229771558f8051b5497eace2ec6"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1045/kingjones-rocmfpx-b1045-ubuntu-rocm-gfx908-x64.zip"
        sha256 "3b62e3db87cd3634e66119a8184c7c2f77769643c8c015bc4524967de7164bbd"
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
