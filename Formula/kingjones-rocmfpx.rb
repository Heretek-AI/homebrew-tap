class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx1151-x64.zip"
  version "1034"
  sha256 "d0806237c3a19280371cc78605702ed2fc132190e661b285d221e8f923fd22f3"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-multiarch-x64.zip"
        sha256 "37dabda7d65f3b34f09bebf77a3872031c7e274396851e3573b8ff3876e51311"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "5bfc6bfe0453e062f61b76102fe1b321cc8c698f2df959147aeff1f898ddd5d6"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "7e60dfbaaef557377d353a26ea0db79ca8d833f7c94957fa9ca01607e2609081"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "0310a6562297f2bc8d4661e43a3f17cb1dcf470af8314a0e4bc8955d5dd78744"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "02f0bb863645d95a47d3d72bbffcb1a5f52a13f0e665c238fcd302095614847b"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "49e427527d1f1f8eae2bbd24403d4f3931a25786e74cfae0ded0caff0523e089"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx908-x64.zip"
        sha256 "cf0817d2358d39d33804c37c944ebaf700f5d97799c180ef7888ec376d6446c5"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1034/kingjones-rocmfpx-b1034-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "d0806237c3a19280371cc78605702ed2fc132190e661b285d221e8f923fd22f3"
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
