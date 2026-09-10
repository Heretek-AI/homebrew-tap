class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx1151-x64.zip"
  version "1036"
  sha256 "a7e5034ba2dcb40aa8cd9651de687eb54ef0484ffc8812dab0ca504fa2e72d74"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-multiarch-x64.zip"
        sha256 "3a0379e1a2a5ace1b6fac6475b472f6a7899461fdf9723f0f92e48c8b4066bf3"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "a7a3e993cb05be672230c6fa498e54220e827bf72fb06d70a434b2047c51945a"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "194df9ab5ecefe0f3ba8d2a9d09a0842a08a3e7e83bb22ab7f9dc33f6aedafd2"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "417f2e82abebd679bc5470c00164d2415a27d7510cb4c8cd65834a24325fec93"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "08554391ab35d50cc333b008be6e32fe851a5545f32551ebd64a8318b2b3c19e"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "c377f31a7e7ea0750f567dbde415db8b8116a8bf04a152205b0137e595c1f580"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx908-x64.zip"
        sha256 "ceff412146db82e57591f08c7549c450d8e0e203cae66af450b911515aded001"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1036/kingjones-rocmfpx-b1036-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "a7e5034ba2dcb40aa8cd9651de687eb54ef0484ffc8812dab0ca504fa2e72d74"
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
