class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx1151-x64.zip"
  version "1025"
  sha256 "30ca02329116170f1ac9cc5f28532c0a11bd016796521a069390b1cf9f11ff46"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-multiarch-x64.zip"
        sha256 "c4780c0b16d07cebe8d7e850e1307d5db06bf94ccce2b7f4aab9e90e1f1b3b01"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "0f2a11c7c17d853307d14624c33ad9452e07dd35d4fee7a82e9023a388c59e5e"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "e26c524dd305906f506de59282ae6ad85b1c7f644e053b5aeb3c6be21f6a614b"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "e7e90338cdb850f8fa5198640dd5890b76ee17f6ad9d183f09027002e10e57bb"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "9bfe1983dab16c763a1ae3e9d46efcc49dac58f9024752999253d2ecaf3079eb"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "c111d4be48228d4ead1ed26e754f1daca0793b8570306516c7a97ecf3719ec69"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx908-x64.zip"
        sha256 "564f7fbcd8e5517af891bbad2569c2f2434086a2dadc485da8862e6bf0ba6d8f"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1025/rocmfpx-b1025-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "30ca02329116170f1ac9cc5f28532c0a11bd016796521a069390b1cf9f11ff46"
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
