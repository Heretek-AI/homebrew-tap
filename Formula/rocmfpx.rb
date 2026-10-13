class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1111/q38rocm-b1111-ubuntu-rocm-gfx1151-x64.zip"
  version "1118"
  sha256 "704c5675b0fa2dcd6f032a83a5aeac76c47f36872715fe19eb432b43be8286e3"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1118/kingjones-rocmfpx-b1118-ubuntu-rocm-multiarch-x64.zip"
        sha256 "20b80020b161a4371f37c66718f77437309208f4f67ba88de2baf9293b7754eb"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1118/kingjones-rocmfpx-b1118-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "8a38049e94daec4b8f73ff2ac940c6f378f6f270a1d98a5f2d5d66eebc7c0906"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1118/kingjones-rocmfpx-b1118-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "146a9ffcad306a990f7ff5940ff58cbd85b7586180d74c034451fd0a34cf4bd9"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1118/kingjones-rocmfpx-b1118-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "6291daadd5d9b412478d16eab9492cbb3a3ebe569586a7eaa2cb40f47a1c89e9"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1118/kingjones-rocmfpx-b1118-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "04c7bef7b2e211d2c12ec93758720947716a2a4fff5d99913e23ed1ae07458ee"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1118/kingjones-rocmfpx-b1118-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "86cb59aaf9f7ac9f8490ea77a471a82459cb8fd03fc85e124b75262103e0d522"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1118/kingjones-rocmfpx-b1118-ubuntu-rocm-gfx908-x64.zip"
        sha256 "ef63fc82c5260018f2adfef795180375615939db5d0ca39615e989fb9051081d"
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
