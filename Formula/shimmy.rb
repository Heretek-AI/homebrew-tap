class Shimmy < Formula
  desc "Pure-Rust WebGPU & CUDA LLM inference engine"
  homepage "https://github.com/Michael-A-Kuykendall/shimmy"
  url "https://github.com/Michael-A-Kuykendall/shimmy/archive/refs/tags/v2.6.5.tar.gz"
  sha256 "1db5bad1b642bc529ef3e9c4a585be6e7e27c22da85035a8bfda69213755f465"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant: OS.mac? ? "metal" : "cpu",
      version: version,
    )
  end

  service do
    run [opt_bin/"shimmy", "serve", "--port", "11434", "--host", "127.0.0.1"]
    keep_alive true
    log_path var/"log/shimmy.log"
    error_log_path var/"log/shimmy.error.log"
  end

  test do
    # 1. Dynamic Linker & ABI Audit (Pure-Rust binary)
    if OS.linux?
      out = shell_output("ldd #{bin}/shimmy")
      refute_match(/not found/, out)
    elsif OS.mac?
      out = shell_output("otool -L #{bin}/shimmy")
      refute_match(/not found/, out)
    end

    # 2. CLI Introspection
    assert_match "shimmy", pipe_output("#{bin}/shimmy --version 2>&1")
    assert_match(/usage|commands/i, pipe_output("#{bin}/shimmy --help 2>&1"))
  end
end
