class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1111/q38rocm-b1111-ubuntu-rocm-gfx1151-x64.zip"
  version "1114"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1114/rocmfpx-b1114-ubuntu-rocm-multiarch-x64.zip"
        sha256 "6cbc611c09f7a4c3322ef43bd1016f8ad46380c27de9a588ab8eae8810737c83"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1114/rocmfpx-b1114-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "d059e56eb21dd8633a5ed5c0cc52afc1a61e2a68bed2c7bbc76221ab4866101b"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1114/rocmfpx-b1114-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "269bd57cfd99da44c9128529c924ebd7a1c9f03357cff8d4eb3d454c54532fea"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1114/rocmfpx-b1114-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "d39b8686e9f7fecc93bb9977423e1b9bde9db8fe28fa6d25268d15c0b4d8f7c5"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1114/rocmfpx-b1114-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "acb1a57ebd2ab999b33ca9f7dc8734464ea961449a2a8c5d6ac437dedb017534"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1114/rocmfpx-b1114-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "6b398254e1cbc89191498981a05192c93521c074cb4f7afbc50cd28068fa7d34"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1114/rocmfpx-b1114-ubuntu-rocm-gfx908-x64.zip"
        sha256 "6828ae7c0c0edcd8db7d485130e9b3dbfc36978550ba0c85d4fb188392050aa8"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1111/q38rocm-b1111-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "704c5675b0fa2dcd6f032a83a5aeac76c47f36872715fe19eb432b43be8286e3"
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
