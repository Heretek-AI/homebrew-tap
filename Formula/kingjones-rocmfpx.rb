class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx1151-x64.zip"
  version "1026"
  sha256 "a19d3b381ffa4adee820288330ee9cb01a45463624cbf8b9a2cb9b4c678591b6"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-multiarch-x64.zip"
        sha256 "bbb9f0191d87abca2518085e788037ba5ecd55f1d209f33f8d83fe8647177711"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "4a395ee1908f38b0f81e6a99fa607343c0248529d641d51c6d33faa781a49aac"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "780564901dc2ec29e5fe05f4bbdeb9bf5026476f3837e38b3dc1e98728a6fca3"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "afc4ec7896d6f2aff5ecac635bd630ec66aa0aee270f9fe7f3c91e3498f5236e"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "034a7fb6b2a569ad93caa562aca6918d2568f205e904794f475e7a793cefb753"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "e79bde81a7520d1c4b7e9f80b6aa945d49582d1461a8bae7a5d01cc4020de5f9"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx908-x64.zip"
        sha256 "07fa254968a69f9b1c153f7bb9b1a785b3e3c8c412f0de3a77ddd0c53580f02c"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1026/kingjones-rocmfpx-b1026-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "a19d3b381ffa4adee820288330ee9cb01a45463624cbf8b9a2cb9b4c678591b6"
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
