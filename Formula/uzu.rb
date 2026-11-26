class Uzu < Formula
  desc "Apple Silicon inference engine and Mirai CLI"
  homepage "https://github.com/trymirai/uzu"
  url "https://github.com/trymirai/uzu/releases/download/0.7.5/mirai-aarch64-apple-darwin.tar.gz"
  sha256 "3b545704ccb2f57202a91dde470a3d29e05b1546ecc567bc21951054b93f1c4f"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on macos: :tahoe

  on_macos do
    on_intel do
      url "https://github.com/trymirai/uzu/releases/download/0.7.5/mirai-x86_64-apple-darwin.tar.gz"
      sha256 "9a6387d22a8b5f66e51035f2b5fad1fecd4483247f7cccd199f934d9711fc0a1"
    end
  end

  def install
    binary = Hardware::CPU.arm? ? "mirai-aarch64-apple-darwin" : "mirai-x86_64-apple-darwin"
    bin.install binary => "mirai"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant: Hardware::CPU.arm? ? "metal" : "cpu",
      version: version,
      arch:    Hardware::CPU.arch.to_s,
    )
  end

  def caveats
    <<~EOS
      Mirai downloads and converts models on first use. Apple Silicon uses the
      Metal backend; Intel Macs use the CPU build. The prebuilt CLI requires
      macOS 26.4 or newer.

      Start the OpenAI-compatible server on loopback:
        mirai server --model trymirai/Qwen3.5-4B-M
      The server defaults to 127.0.0.1:8000 and accepts --host and --port.
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("otool -L #{bin}/mirai 2>&1")
    refute_match(/not found/, out)

    # 2. CLI Introspection
    assert_match version.to_s, shell_output("#{bin}/mirai --version")
    assert_match(/usage: (cli|mirai)/i, shell_output("#{bin}/mirai --help 2>&1"))

    # 3. Build Metadata
    manifest = JSON.parse((pkgshare/"build-manifest.json").read)
    assert_equal version.to_s, manifest["version"]
  end
end
