class Rocmfpx < Formula
  desc "High-Performance AMD ROCm 7 llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1103/q38rocm-b1103-ubuntu-rocm-gfx1151-x64.zip"
  version "1109"
  sha256 "3f61ab8aba94c10b61e2f20db97a1dc77500a028203ccffee9ca78dfc0b9d387"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1109/rocmfpx-b1109-ubuntu-rocm-multiarch-x64.zip"
        sha256 "bf97cee446312701a974235299eb28cc6ef7f82067e17e2ff0e348e0028da845"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1109/rocmfpx-b1109-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "4d6dccf85c2c94cdccd8c1c63793a06ffc9ba7c1d53190dc4ab9e3669a6ca79d"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1109/rocmfpx-b1109-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "9447e25aa8c6c02cafe5df88054f984a27dee78847c7fb80f2a904f42c2ec5a3"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1109/rocmfpx-b1109-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "181298c7bb32444bc42ccee5105d2b0e319dd92efd24ab94b9b82ecac04ae572"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1109/rocmfpx-b1109-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "14fa82dbb8a9461744b234d9fe2ab72a57de5089e0d244a530f6e114176950c5"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1109/rocmfpx-b1109-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "14b1a2e01e8540ae810ad3c39ab4170a9884f96eab3929b300912338175ff9c8"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1109/rocmfpx-b1109-ubuntu-rocm-gfx908-x64.zip"
        sha256 "5f00ffd17863454e345e34c03d031cfc8991fdd71d96e723268510f8a0fa8231"
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
