class Rocmfpx < Formula
  desc "High-Performance AMD ROCm llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx1151-x64.zip"
  version "1136"
  sha256 "4e6fab169b35d6337b1f7a874fd630dc06c4d98d58ff85ad2bdbcf799f508b2f"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?b?(\d+)["' >]}i)
  end

  option "with-multi-arch", "Single binary for gfx1100 (RX 7900-class) + gfx1151 (Strix Halo)"
  option "with-gfx1150", "Build for AMD Strix Point APU (Radeon 890M / 880M)"
  option "with-gfx120X", "Build for AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)"
  option "with-gfx110X", "Build for AMD RDNA3 GPUs (RX 7900 / 7800, Radeon 780M)"
  option "with-gfx103X", "Build for AMD RDNA2 GPUs / Steam Deck"
  option "with-gfx94X",  "Build for AMD Instinct MI300X / MI300A (gfx942)"
  option "with-gfx90a",  "Build for AMD Instinct MI210 / MI250X"
  option "with-gfx908",  "Build for AMD Instinct MI100"

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "multi-arch"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-multiarch-x64.zip"
        sha256 "4dcca64792e20d4d3d79132da09bb43a3d8ab971c319fbac9661598af85783c8"
      elsif build.with? "gfx1150"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx1150-x64.zip"
        sha256 "30d4da89565d53c98e21c7cf6f28d6151e4c3ec5dbee5e2e08d3815e14363149"
      elsif build.with? "gfx120X"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx120X-x64.zip"
        sha256 "93e82c23131acfbda70be274bf2d5cab7fd394ff8d746d578d3ad72f9ee875f9"
      elsif build.with? "gfx110X"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx110X-x64.zip"
        sha256 "837baab2f58af097ca2050e47307ec8793ed5ae4ad3e269ae721ab9c3904d01d"
      elsif build.with? "gfx103X"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx103X-x64.zip"
        sha256 "aabc20f23c29cf3629431ec49e99f7134cd62850a4257ce9b10626b26b6e72f7"
      elsif build.with? "gfx94X"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx94X-x64.zip"
        sha256 "05c7dceb8339573ba4ae6d4295e8ae4305c7dceb8339573ba4ae6d4295e8ae43"
      elsif build.with? "gfx90a"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx90a-x64.zip"
        sha256 "fc2fcf9b90e021dfef8979568c537fa53b99243da97d5276c97616dd8b5fa3f6"
      elsif build.with? "gfx908"
        url "https://github.com/Heretek-AI/homebrew-tap/releases/download/b1136/rocmfpx-b1136-ubuntu-rocm-gfx908-x64.zip"
        sha256 "2a2ee81b9a0f2119ca293c906e8471495e6386cb421f4eeb8d4b94de0d169f0c"
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
      (bin/"rocmfpx-#{cmd.delete_prefix("llama-")}").write <<~SH
        #!/bin/bash
        exec "#{base/cmd}" "$@"
      SH
    end

    return unless (base/"llama-server").exist?

    (bin/"rocmfpx").write <<~SH
      #!/bin/bash
      exec "#{base/"llama-server"}" "$@"
    SH
  end

  def caveats
    <<~EOS
      This formula distributes canonical upstream ROCmFPX (charlie12345/ROCmFPX)
      with bundled AMD ROCm runtimes (supporting ROCm 7+ and 10.1+).
    EOS
  end

  service do
    run [opt_bin/"llama-server", "--host", "127.0.0.1", "--port", "8080"]
    keep_alive true
    log_path var/"log/rocmfpx.log"
    error_log_path var/"log/rocmfpx.error.log"
  end

  test do
    if (libexec/"llama-server").exist? || (libexec/"bin"/"llama-server").exist?
      assert_match(/version:|usage:|llama/i, pipe_output("#{bin}/llama-server --version 2>&1"))
    else
      assert_match(/usage:|llama/i, pipe_output("#{bin}/llama-cli --help 2>&1"))
    end
  end
end
