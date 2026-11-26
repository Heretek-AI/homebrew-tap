class Infr < Formula
  desc "Vulkan-first and Metal-native LLM inference engine"
  homepage "https://github.com/kryptic-sh/infr"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  on_macos do
    on_arm do
      url "https://github.com/kryptic-sh/infr/releases/download/v0.3.0/infr-v0.3.0-aarch64-apple-darwin.tar.gz"
      sha256 "43410280ea15c8a30ead0d6fe088b3d1ac015f48ef65653da8c966cab6c1c01c"
    end

    on_intel do
      url "https://github.com/kryptic-sh/infr/releases/download/v0.3.0/infr-v0.3.0-x86_64-apple-darwin.tar.gz"
      sha256 "f302b249c857ea6cb8b5dbf44bfcbad4ac8dafd67817c2b0d0c207553877d590"
    end
  end

  on_linux do
    depends_on "vulkan-loader"

    on_intel do
      url "https://github.com/kryptic-sh/infr/releases/download/v0.3.0/infr-v0.3.0-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "d74d4281cf857180f564cc7012b4d6dfc8c08adfa94e07b566f08a3d0c1e1671"
    end

    on_arm do
      url "https://github.com/kryptic-sh/infr/releases/download/v0.3.0/infr-v0.3.0-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "a8457c916e6e00085bed4471d1906a57388a99593269fad75aa2dade26fc6b3e"
    end
  end

  resource "completions" do
    url "https://github.com/kryptic-sh/infr/releases/download/v0.3.0/infr-v0.3.0-completions-man.tar.gz"
    sha256 "c349dc78f67cf32d9c6410789266b769d304f0ba0a0b7a0a4e78c1c517f788c4"
  end

  def install
    bin.install "infr"

    resource("completions").stage do
      bash_completion.install "completions/infr.bash" => "infr"
      zsh_completion.install "completions/infr.zsh" => "_infr"
      fish_completion.install "completions/infr.fish"
      man1.install "infr.1"
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant: OS.mac? ? "metal" : "vulkan",
      version: version,
      arch:    Hardware::CPU.arch.to_s,
    )
  end

  def caveats
    <<~EOS
      Infr uses Metal on macOS and Vulkan on Linux, with a CPU fallback. Linux
      Vulkan builds need a Vulkan loader and a working ICD/driver at runtime.

      Pull a model and start the OpenAI-compatible server on loopback:
        infr pull unsloth/Qwen3-14B-GGUF:Q4_K_M
        infr serve unsloth/Qwen3-14B-GGUF:Q4_K_M
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    if OS.linux?
      out = shell_output("ldd #{bin}/infr 2>&1")
      refute_match(/not found/, out)
    elsif OS.mac?
      out = shell_output("otool -L #{bin}/infr 2>&1")
      refute_match(/not found/, out)
    end

    # 2. CLI Introspection
    assert_match "infr #{version}", shell_output("#{bin}/infr --version")
    assert_match(/Usage: infr/i, shell_output("#{bin}/infr --help 2>&1"))

    # 3. Shell Completions and Man Page
    assert_path_exists bash_completion/"infr"
    assert_path_exists zsh_completion/"_infr"
    assert_path_exists fish_completion/"infr.fish"
    assert_path_exists man1/"infr.1"
  end
end
