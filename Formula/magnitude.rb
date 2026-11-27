class Magnitude < Formula
  desc "Local inference runtime and agent harness"
  homepage "https://github.com/magnitudedev/magnitude"
  license "Apache-2.0"

  livecheck do
    url :stable
    regex(%r{^@magnitudedev/cli@v?(\d+(?:\.\d+)+)$}i)
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/magnitudedev/magnitude/releases/download/%40magnitudedev%2Fcli%400.3.5/magnitude-cli-darwin-arm64.tar.gz"
      sha256 "aecd2ba0e3eab32f90ba1d43d9a71386f274000f3d42ef2066797bbb98a9fe6e"
    end

    on_intel do
      url "https://github.com/magnitudedev/magnitude/releases/download/%40magnitudedev%2Fcli%400.3.5/magnitude-cli-darwin-x64.tar.gz"
      sha256 "49a69f6abccfb921b0155018e069baf2e92fa5feee298e0a269f845d6af56f3d"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/magnitudedev/magnitude/releases/download/%40magnitudedev%2Fcli%400.3.5/magnitude-cli-linux-x64-gnu.tar.gz"
      sha256 "3bc741477ac72a9c415eede0246a7bcc2dcb308eb36050664bc03b6a60ba3ed6"
    end

    on_arm do
      url "https://github.com/magnitudedev/magnitude/releases/download/%40magnitudedev%2Fcli%400.3.5/magnitude-cli-linux-arm64-gnu.tar.gz"
      sha256 "848e55496b6655983b91c08e38777f72f91a255d51a22550007d2a99baeb668c"
    end
  end

  def install
    bin.install "magnitude-cli" => "magnitude"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant: OS.mac? ? "darwin" : "linux-gnu",
      version: version,
      arch:    Hardware::CPU.arch.to_s,
    )
  end

  def caveats
    <<~EOS
      The Magnitude CLI can run local models through `magnitude models` and
      start the foreground service with `magnitude serve`. Runtime state and
      downloaded models are stored under the invoking user's home directory.
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    if OS.linux?
      out = shell_output("ldd #{bin}/magnitude 2>&1")
      refute_match(/not found/, out)
    elsif OS.mac?
      out = shell_output("otool -L #{bin}/magnitude 2>&1")
      refute_match(/not found/, out)
    end

    # 2. CLI Introspection
    assert_match version.to_s, shell_output("#{bin}/magnitude --version")
    assert_match(/Usage: magnitude/i, shell_output("#{bin}/magnitude --help 2>&1"))

    # 3. Build Metadata
    manifest = JSON.parse((pkgshare/"build-manifest.json").read)
    assert_equal version.to_s, manifest["version"]
    assert_equal Hardware::CPU.arch.to_s, manifest["arch"]
  end
end
