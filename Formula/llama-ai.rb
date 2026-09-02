class LlamaAi < Formula
  desc "Turnkey APU Runner & Optimistic-First Profile Solver for LLMs"
  homepage "https://github.com/fewtarius/llama-ai"
  url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1002/llama-ai-b1002-macos-arm64.tar.gz"
  version "1022"
  sha256 "19706aa66c66a33f6d9f0a89baf228a60b1db7f3f7dc7ae9226e2a6e8272ea34"
  license "GPL-3.0-or-later"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?(b\d+|llama-ai-b\d+)["' >]}i)
  end

  on_linux do
    if Hardware::CPU.intel?
      url "https://github.com/Heretek-AI/CachyLLama-BUILDER/releases/download/llama-ai-b1021/llama-ai-b1021-linux-x64.tar.gz"
      sha256 "e037ccda5535f94e7dcfe203384ebd0e32a3a509d889c3333182618550483ea3"
    end
  end

  def install
    libexec.install Dir["*"]
    chmod 0755, Dir[libexec/"bin/*"] if (libexec/"bin").directory?
    chmod 0755, Dir[libexec/"*.sh"]
    chmod 0755, libexec/"llama-ai" if (libexec/"llama-ai").exist?

    if (libexec/"bin/llama-cli").exist?
      bin.write_exec_script (libexec/"bin/llama-cli")
      (bin/"llama-ai").write <<~SH
        #!/bin/bash
        exec "#{libexec}/bin/llama-cli" "$@"
      SH
    elsif (libexec/"llama-run.sh").exist?
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
    assert_match "llama", pipe_output("#{bin}/llama-ai --help 2>&1")
  end
end
