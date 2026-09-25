class CiruRocmfpx < Formula
  desc "Low-Bit Quantized ROCm 7 Inference Stack (ROCmFP2..FP8 & DualView)"
  homepage "https://github.com/ciru-ai/ROCmFPX"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1053/q38rocm-b1053-ubuntu-rocm-gfx1151-x64.zip"
  version "1071"
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
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1071/kingjones-rocmfpx-b1071-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "66edfb5e91c0b885bfafb269786f62b144ab8abf9289969bbb3547608d46d214"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1071/kingjones-rocmfpx-b1071-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "16fab550d55eda7557243f1241ae00953c1dd2a5de9043f682fade67c9f0bea5"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1071/kingjones-rocmfpx-b1071-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "a224404c91ffc1a9732bcc26592bbe87a2adfea195d8b773b18bead2b22c210f"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1071/kingjones-rocmfpx-b1071-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "b91ba117a4e68d986d847dcb6932fe309603f17be034d5370ff19de4003d5504"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1071/kingjones-rocmfpx-b1071-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "635e11f3588c9694cd54af8eac65d2c5dd37847b19a76fa5652b3d105b728106"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1071/kingjones-rocmfpx-b1071-ubuntu-rocm-gfx908-x64.zip"
        sha256 "2b66ceb70d7d93916af96ab3099a07a0e652678cb57e2e5e31e79afd372cf7dd"
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
