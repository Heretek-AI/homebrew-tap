class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1046/q38rocm-b1046-ubuntu-rocm-gfx1151-x64.zip"
  version "1050"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1050/kingjones-rocmfpx-b1050-ubuntu-rocm-multiarch-x64.zip"
        sha256 "9a2f86d4e6b8b16c8c79125bebc3384215b311b5a4a6324a6a4cfba79c9d7ba7"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1050/kingjones-rocmfpx-b1050-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "3330e2f9e74cf6bc1a630fc97e94eca7010027228bf31f9c24dde204cc071b35"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1050/kingjones-rocmfpx-b1050-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "a932079ab556df6cd3d9f202c8f34d542ff04d8728e1453baa26ebec7994b321"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1050/kingjones-rocmfpx-b1050-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "1e3a4df3702c963a41be9f52be98025d8d51a7d404bb7fec710a3ab17d49dd29"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1050/kingjones-rocmfpx-b1050-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "ea03c989adf136da143c03b58e8901cdc928c889dceaf95a5a0f248f5fc86717"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1050/kingjones-rocmfpx-b1050-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "c752c2b019e591b76eeefc8c520b5b12afbb7b2ef961eaef05786f5da53df1ef"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1050/kingjones-rocmfpx-b1050-ubuntu-rocm-gfx908-x64.zip"
        sha256 "19bed8a6897749fbeeffe23326bfa10fb1cacecb52ac3aace363ab3fb7b1d1f3"
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
