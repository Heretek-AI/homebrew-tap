class Rocmfpx < Formula
  desc "High-Performance AMD ROCm llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-gfx1151-x64.zip"
  version "1135"
  sha256 "8b14756b4302e052721d27a9bc6cbc5c76171e0b6dbcafe6cbb0093bce57b42f"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?b?(\d+)["' >]}i)
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
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-multiarch-x64.zip"
        sha256 "d929677c9338e10b876ae87e3924be6b4cac96aba3c862e6fd6dfa5bcc2432b7"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "2b5001c38dcbd455c595c3eb14a13776bdaf9a3f968e9af5eac09c1792bd0628"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "dd472af68e839dd619d7dcf9b99a3122addde8adedf05fc20be26f52c6918e3e"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "e2a00e7b6d8d9a6a513e58accd77b7e499df713de3f0678ba36b43522a3f88a7"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "7b8044c32f5d4026692bf9f0d28d308cd1d8b6ec1caccbf2b964124c7045473a"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "3245723cdff58f0394de29e45956c6726eb59b1a006c781905860c4868de983b"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1135/rocmfpx-b1135-ubuntu-rocm-gfx908-x64.zip"
        sha256 "bdf3f637bef1994585ec4e4b7a33b6b3ced861aa2a6b13e1732c41c41770f77c"
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
      This formula distributes canonical upstream ROCmFPX (charlie12345/ROCmFPX)
      with bundled AMD ROCm runtimes (supporting ROCm 7+ and 10.1+).
    EOS
  end

  service do
    run [opt_bin/"llama-server", "--host", "127.0.0.1", "--port", "8080"]
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
