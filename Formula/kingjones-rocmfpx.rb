class KingjonesRocmfpx < Formula
  desc "ROCmFPX Inference Stack with 7 Extended Architectures"
  homepage "https://github.com/kingjones30/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1121/q38rocm-b1121-ubuntu-rocm-gfx1151-x64.zip"
  version "1133"
  sha256 "862e80da5c1e2c936b2b8ec2475ed4170eea1d9b9c691328c0c9cc1c1de4217f"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1133/rocmfpx-b1133-ubuntu-rocm-multiarch-x64.zip"
        sha256 "e15371a92de3532de017aee39788a0eacedf889f085cc54370dc1f17908dcdce"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1133/rocmfpx-b1133-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "b86562ee8a1b78f7d564765afce889932d5212679aaaca19680e27f4837bb41b"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1133/rocmfpx-b1133-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "e4fc4fbf93317a8655d861fc7d2eceb9e1280348a1615834d9ff7b61dd590e11"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1133/rocmfpx-b1133-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "c72f98fd62e8d75678585ec0246ea885d41222288b293bd8240f06595bc542d4"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1133/rocmfpx-b1133-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "c933ff85b37a90c8614b558495c6c4197bf76cc23e0a039dc6a98a976c63c7a5"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1133/rocmfpx-b1133-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "5cc7d5e8dd9918832823aedb7ad310f802c737a2a85b8087200ed8fa4c29bb02"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1133/rocmfpx-b1133-ubuntu-rocm-gfx908-x64.zip"
        sha256 "4583708dbf37506deaf96a4fe89e850bb7699047f25699218e108a5e5b7af2f0"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1121/q38rocm-b1121-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "862e80da5c1e2c936b2b8ec2475ed4170eea1d9b9c691328c0c9cc1c1de4217f"
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
