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
  end

  service do
    run [opt_bin/"shimmy", "serve", "--port", "11434", "--host", "0.0.0.0"]
    keep_alive true
    log_path var/"log/shimmy.log"
    error_log_path var/"log/shimmy.error.log"
  end

  test do
    assert_match "shimmy", pipe_output("#{bin}/shimmy --version 2>&1")
  end
end
