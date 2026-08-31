class Shimmy < Formula
  desc "Pure-Rust WebGPU & CUDA LLM inference engine"
  homepage "https://github.com/Michael-A-Kuykendall/shimmy"
  url "https://github.com/Michael-A-Kuykendall/shimmy/archive/refs/tags/v2.6.4.tar.gz"
  sha256 "9d9b410898618cbcfe3bf171c4d75d5d6542ebe08fb73e20d4115ad99e3b10ab"
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
    assert_match "shimmy", shell_output("#{bin}/shimmy --version 2>&1")
  end
end
