class LlamaAi < Formula
  desc "Turnkey APU Runner & Optimistic-First Profile Solver for LLMs"
  homepage "https://github.com/fewtarius/llama-ai"
  version "1.0.0"
  license "GPL-3.0-or-later"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+|llama-ai-b\d+)["' >]}i)
  end

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1000/llama-ai-b1000-macos-arm64.tar.gz"
      sha256 "a8d0b1a52ce8a031ed62ca1a2b75a39dbce878aec6a4c984aa31521cbed80c29"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/b1001/llama-ai-b1001-linux-x64-bundle.tar.gz"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
  end

  def install
    libexec.install Dir["*"]
    if File.exist?(libexec/"llama-run.sh")
      (bin/"llama-run").write_exec_script libexec/"llama-run.sh"
      (bin/"llama-ai").write_exec_script libexec/"llama-run.sh"
    elsif File.exist?(libexec/"llama-ai")
      (bin/"llama-ai").write_exec_script libexec/"llama-ai"
    end
  end

  test do
    assert_match "llama", shell_output("#{bin}/llama-ai --help 2>&1")
  end
end
