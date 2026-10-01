class CiruRocmfpx < Formula
  desc "Low-Bit Quantized ROCm 7 Inference Stack (ROCmFP2..FP8 & DualView)"
  homepage "https://github.com/ciru-ai/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1053/q38rocm-b1053-ubuntu-rocm-gfx1151-x64.zip"
  version "1088"
  sha256 "a774fb8437d89fa9cb60c8bb60beeee2c26fc6c14556e96705df65efc35a88c9"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  option "with-kairic-edge", "Qwen3.8-27B IU4 Kairic Edge certified runtime (Strix Halo)"
  option "with-promptforge", "Qwen3.8-27B ActiveFPX PromptForge certified runtime (Strix Halo)"
  option "with-gfx1150", "Build for AMD Strix Point APU (Radeon 890M / 880M)"
  option "with-gfx120X", "Build for AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)"
  option "with-gfx110X", "Build for AMD RDNA3 GPUs (RX 7900 / 7800, Radeon 780M)"
  option "with-gfx103X", "Build for AMD RDNA2 GPUs / Steam Deck"
  option "with-gfx90a",  "Build for AMD Instinct MI210 / MI250X"
  option "with-gfx908",  "Build for AMD Instinct MI100"

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "kairic-edge"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1006/rocmfpx-b1006-ubuntu-rocm-gfx1151-kairic-edge-x64.zip"
        sha256 "471c83a3055960d689e32491276da88f41acf0d6fba6ae989344562717ccf933"
      elsif build.with? "promptforge"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1007/rocmfpx-b1007-ubuntu-rocm-gfx1151-promptforge-x64.zip"
        sha256 "0eb95a4d84098b5a9bb9e65122c430233a72f27950fee26ec0de79f1c00dfd3b"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "4cf45f08a2847a2dd2f01f71394b15c76d01f5a2e51b04d4ca979714e3172e08"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "4192e89c09761685e233c0601ff15f1ae4f41028b867cdc961f4e1fe7dab59ab"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "948bdd8a5f1c48609ad053bbdf9f3f044a83b1e154e225de36e75f7f091767bc"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "814e503a18fb314c1a04967eda5fdd4e5f854d01838a6e8f4e1cb3e2d4cd8a88"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "4a95bc1c36268694cfc5bd472d414554f2a24316e4ca8ab9e1e214573d0e435f"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1088/rocmfpx-b1088-ubuntu-rocm-gfx908-x64.zip"
        sha256 "023cb4049e552ef36d44af564f6a0836f11481c6ee0b2ce8cdc3378949aa36ad"
      else
        # Default install: Strix Halo gfx1151
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1053/q38rocm-b1053-ubuntu-rocm-gfx1151-x64.zip"
        sha256 "a774fb8437d89fa9cb60c8bb60beeee2c26fc6c14556e96705df65efc35a88c9"
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
      (bin/"ciru-fpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
      (bin/"ciru-rocmfpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
    end

    return unless (base/"llama-server").exist?

    (bin/"ciru-rocmfpx").write <<~SH
      #!/bin/bash
      exec "#{base/"llama-server"}" "$@"
    SH
  end

  def caveats
    <<~EOS
      This formula distributes Ciru-AI ROCmFPX (ciru-ai/ROCmFPX).
      Certified profiles (kairic-edge, promptforge) require sidecar weight files.
      See: https://github.com/ciru-ai/ROCmFPX
    EOS
  end

  service do
    run [opt_bin/"ciru-rocmfpx", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/ciru-rocmfpx.log"
    error_log_path var/"log/ciru-rocmfpx.error.log"
  end

  test do
    if (libexec/"llama-server").exist? || (libexec/"bin"/"llama-server").exist?
      assert_match(/version:|usage:|llama|ciru/i, pipe_output("#{bin}/llama-server --version 2>&1"))
    else
      assert_match(/usage:|llama|ciru/i, pipe_output("#{bin}/llama-cli --help 2>&1"))
    end
  end
end
