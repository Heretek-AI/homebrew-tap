class Ember < Formula
  desc "DeepSeek-V4-Flash C Inference Server for AMD Strix Halo (gfx1151)"
  homepage "https://github.com/otheru-ai/ember"
  url "https://github.com/Heretek-AI/ember-BUILDER/releases/download/b1001/ember-b1001-ubuntu-rocm-gfx1151-x64.zip"
  version "1001"
  sha256 "cc0b345f8d7b4e47a1a95eee00ed84fbc512816d1ebb2d847948aebd7029d5d6"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+)["' >]}i)
  end

  depends_on :linux

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Heretek-AI/ember-BUILDER/releases/download/b1001/ember-b1001-ubuntu-rocm-gfx1151-x64.zip"
      sha256 "cc0b345f8d7b4e47a1a95eee00ed84fbc512816d1ebb2d847948aebd7029d5d6"
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

    %w[ember-dflash ember-token-dump ember-dspark-main-bench ember-dspark-xdna-diff].each do |cmd|
      next unless (base/cmd).exist?

      chmod 0755, base/cmd
      bin.write_exec_script (base/cmd)
    end

    return unless (base/"ember-dflash").exist?

    (bin/"ember").write <<~SH
      #!/bin/bash
      exec "#{base/"ember-dflash"}" "$@"
    SH
    (bin/"ember-server").write <<~SH
      #!/bin/bash
      exec "#{base/"ember-dflash"}" "$@"
    SH
  end

  def caveats
    <<~EOS
      Ember is compiled and optimized for AMD Strix Halo APU (gfx1151 / Radeon 8060S).
      All essential ROCm 7 runtime libraries are bundled via $ORIGIN RPATH.

      Quick Start:
        ember -m /path/to/DeepSeek-V4-Flash.gguf --port 8080 --host 0.0.0.0
    EOS
  end

  service do
    run [opt_bin/"ember-dflash", "-m", "/models/model.gguf", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/ember.log"
    error_log_path var/"log/ember.error.log"
  end

  test do
    if (libexec/"ember-dflash").exist? || (libexec/"bin"/"ember-dflash").exist?
      assert_match "Usage:", pipe_output("#{bin}/ember-dflash --help 2>&1")
    else
      assert_match "Usage:", pipe_output("#{bin}/ember --help 2>&1")
    end
  end
end
