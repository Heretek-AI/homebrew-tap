class SaientQuartz < Formula
  desc "Pure-Rust GGUF LLM and Stable Diffusion inference engine"
  homepage "https://github.com/SaientAI/saient-quartz"
  url "https://github.com/SaientAI/saient-quartz/archive/5a2a82387b9548c6c165eb50880a5f49c54ef1ff.tar.gz"
  version "0.1.1"
  sha256 "558ba7a60506043f2310d3e9821725066598d75f21557231abfed207378116a8"
  license "MIT"
  head "https://github.com/SaientAI/saient-quartz.git", branch: "main"

  livecheck do
    skip "Tracks pinned upstream commit"
  end

  option "with-vulkan", "Build with Vulkan GPU support"

  depends_on "rust" => :build
  depends_on "shaderc" => :build if build.with?("vulkan")

  def install
    vulkan = build.with? "vulkan"
    ENV["GLSLC"] = formula_opt_bin("shaderc")/"glslc" if vulkan
    args = std_cargo_args
    args << "--features" << "vulkan" if vulkan

    system "cargo", "install", *args

    variant = vulkan ? "vulkan" : "cpu"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:  variant,
      version:  version,
      features: vulkan ? ["vulkan"] : [],
    )
  end

  def caveats
    <<~EOS
      --with-vulkan is a source-build option and must be selected when building
      from source; it is not enabled in the default build. Vulkan builds require
      a Vulkan loader (libvulkan) and a working ICD/driver at runtime.
    EOS
  end

  test do
    if OS.linux?
      out = shell_output("ldd #{bin}/quartz")
      refute_match(/not found/, out)
    elsif OS.mac?
      out = shell_output("otool -L #{bin}/quartz")
      refute_match(/not found/, out)
    end

    assert_match(/usage: quartz/i, pipe_output("#{bin}/quartz --inspect-wan 2>&1"))
  end
end
