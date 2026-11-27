class Colibri < Formula
  desc "Run large MoE models locally with a tiny C engine"
  homepage "https://github.com/JustVugg/colibri"
  url "https://github.com/JustVugg/colibri/releases/download/v2.2.0/colibri-v2.2.0-macos-arm64.tar.gz"
  sha256 "6fce6e344131e527f904d012e2701044345e615be5a2ca3611f6b2f905d864d9"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "python@3.12"

  on_macos do
    depends_on arch: :arm64
    depends_on "libomp"
    depends_on macos: :tahoe
  end

  on_linux do
    on_intel do
      url "https://github.com/JustVugg/colibri/releases/download/v2.2.0/colibri-v2.2.0-linux-x86_64.tar.gz"
      sha256 "b1e2bc8a650b2b216e17357614cfcb4355a83fb9d3077d61f8e1d63beea14d72"
    end

    on_arm do
      url "https://github.com/JustVugg/colibri/releases/download/v2.2.0/colibri-v2.2.0-linux-aarch64.tar.gz"
      sha256 "1e340e5bda50863303e7d2b3e2cd530f48926967c1bb390049c2df4dd43af602"
    end
  end

  def install
    libexec.install Dir["*"]

    python = formula_opt_bin("python@3.12")/"python3.12"
    (bin/"coli").write <<~SH
      #!/usr/bin/env bash
      exec "#{python}" "#{libexec}/coli" "$@"
    SH
    chmod 0755, bin/"coli"

    variant = if OS.mac?
      "metal"
    elsif Hardware::CPU.arm?
      "cpu"
    else
      "cpu-vulkan"
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant: variant,
      version: version,
      arch:    Hardware::CPU.arch.to_s,
      python:  python.to_s,
    )
  end

  def caveats
    <<~EOS
      Colibri installs the `coli` launcher and its per-family engine binaries
      under #{opt_libexec}. The launcher runs on the formula's Python 3.12.
      On first use it can download a model pack and prepare it for the current
      machine:
        coli setup
        coli info --model /path/to/model

      The Linux builds include CPU and Vulkan engines. The macOS build requires
      macOS 26 (Tahoe) or newer, libomp, and uses Metal on Apple Silicon.
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    if OS.linux?
      out = shell_output("ldd #{libexec}/colibri 2>&1")
      refute_match(/not found/, out)
      tui_out = shell_output("ldd #{libexec}/colibri-tui 2>&1")
      refute_match(/not found/, tui_out)
    elsif OS.mac?
      out = shell_output("otool -L #{libexec}/colibri 2>&1")
      refute_match(/not found/, out)
      assert_match(/libomp\.dylib/, out)
    end

    # 2. CLI Introspection
    assert_match "colibri #{version}", shell_output("#{bin}/coli --version")
    assert_match(/usage: coli/i, shell_output("#{bin}/coli --help 2>&1"))
    assert_match "colibri-tui #{version}", shell_output("#{libexec}/colibri-tui --version")

    # 3. Build Metadata
    manifest = JSON.parse((pkgshare/"build-manifest.json").read)
    assert_equal version.to_s, manifest["version"]
    assert_equal Hardware::CPU.arch.to_s, manifest["arch"]
  end
end
