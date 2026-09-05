class Engramhalo < Formula
  desc "Tuned llama.cpp for Qwen 3.8 Flash-Next on AMD Strix Halo (gfx1151)"
  homepage "https://github.com/Aristo94/EngramHalo.cpp"
  url "https://github.com/Heretek-AI/EngramHalo-BUILDER/releases/download/b1000/engramhalo-b1000-ubuntu-rocm-gfx1151-x64.zip"
  version "1000"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Heretek-AI/EngramHalo-BUILDER/releases/download/b1000/engramhalo-b1000-ubuntu-rocm-gfx1151-x64.zip"
      sha256 "0000000000000000000000000000000000000000000000000000000000000000"
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
      (bin/"engramhalo-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
    end

    return unless (base/"llama-server").exist?

    (bin/"engramhalo").write <<~SH
      #!/bin/bash
      exec "#{base/"llama-server"}" "$@"
    SH
  end

  def caveats
    <<~EOS
      EngramHalo.cpp is tuned for Qwen 3.8 Flash-Next on AMD Strix Halo (gfx1151).
      Features true QSA sparse gather, MTP draft head, and NVMe/SSD engram table streaming.
      All essential ROCm 7 runtime libraries are bundled via $ORIGIN RPATH.

      Quick Start:
        engramhalo -m /path/to/Qwen3.8-Flash-Next-ROCmFP4.gguf \\
          --spec-draft /path/to/mtp-sidecar.gguf --spec-draft-p-min 0.75 -lm mmap
    EOS
  end

  service do
    run [opt_bin/"llama-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/engramhalo.log"
    error_log_path var/"log/engramhalo.error.log"
  end

  test do
    if (libexec/"llama-server").exist? || (libexec/"bin"/"llama-server").exist?
      assert_match(/version:|usage:|llama/i, pipe_output("#{bin}/llama-server --version 2>&1"))
    else
      assert_match(/usage:|llama/i, pipe_output("#{bin}/llama-cli --help 2>&1"))
    end
  end
end
