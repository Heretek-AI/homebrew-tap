class LlamaAi < Formula
  desc "Turnkey APU Runner & Optimistic-First Profile Solver for LLMs"
  homepage "https://github.com/fewtarius/llama-ai"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1002/llama-ai-b1002-macos-arm64.tar.gz"
  version "1002"
  sha256 "19706aa66c66a33f6d9f0a89d70150937b42f36d3964943fcfd46aa1a62d26f6"
  license "GPL-3.0-or-later"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+|llama-ai-b\d+)["' >]}i)
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1002/llama-ai-b1002-linux-x64.tar.gz"
      sha256 "b59bd852aea436003137c7304bf5e08b15d6fa1c0c279c67eb01556214227d82"
    end
  end

  def install
    libexec.install Dir["*"]
    if (libexec/"llama-run.sh").exist?
      bin.write_exec_script (libexec/"llama-run.sh")
      (bin/"llama-ai").write <<~SH
        #!/bin/bash
        exec "#{libexec}/llama-run.sh" "$@"
      SH
    elsif (libexec/"llama-ai").exist?
      bin.write_exec_script (libexec/"llama-ai")
    end
  end

  test do
    assert_match "llama", shell_output("#{bin}/llama-ai --help 2>&1")
  end
end
