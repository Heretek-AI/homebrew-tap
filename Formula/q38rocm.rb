class Q38rocm < Formula
  desc "Qwen 3.8 27B ROCmFP4 Inference Engine on AMD Strix Halo (gfx1151)"
  homepage "https://github.com/julianmb/q38rocm"
  url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1042/rocmfpx-b1042-ubuntu-rocm-gfx1151-q38rocm-x64.zip"
  version "1043"
  sha256 "937154c13f1c05096d409cdaa2c8accabbf527c9da189092f2da0a68e2395c87"
  license "Apache-2.0"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Heretek-AI/ROCmFPX-BUILDER/releases/download/b1042/rocmfpx-b1042-ubuntu-rocm-gfx1151-q38rocm-x64.zip"
      sha256 "937154c13f1c05096d409cdaa2c8accabbf527c9da189092f2da0a68e2395c87"
    end
  end

  def install
    libexec.install Dir["*"]

    %w[llama-server llama-cli llama-quantize llama-bench llama-perplexity].each do |cmd|
      next unless (libexec/cmd).exist?

      chmod 0755, libexec/cmd
      bin.write_exec_script (libexec/cmd)
      (bin/"q38rocm-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{libexec/cmd}" "$@"
      SH
    end

    (bin/"q38rocm").write <<~SH
      #!/bin/bash
      exec "#{libexec}/llama-server" "$@"
    SH
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8000"]
    keep_alive true
    log_path var/"log/q38rocm.log"
    error_log_path var/"log/q38rocm.error.log"
  end

  test do
    if (libexec/"llama-server").exist?
      assert_match(/version:|usage:|llama/i, pipe_output("#{bin}/llama-server --version 2>&1"))
    else
      assert_match(/usage:|llama/i, pipe_output("#{bin}/llama-cli --help 2>&1"))
    end
  end
end
