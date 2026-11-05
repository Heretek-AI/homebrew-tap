class Qwenox < Formula
  desc "High-performance Qwen runtime and kernel primitives for Strix Halo"
  homepage "https://github.com/IIIIIllllIIIIIlllll/Qwenox"
  url "https://github.com/IIIIIllllIIIIIlllll/Qwenox/archive/dedb058b1ca7d9c1cffbdb44b51defb2d496a692.tar.gz"
  version "0.1.0-gitdedb058"
  sha256 "0561584c6c96568bb908d16781fec86c07bb500ca89f64a4d673dfa2f5ae120d"
  license "AGPL-3.0-only"
  head "https://github.com/IIIIIllllIIIIIlllll/Qwenox.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on :linux
  depends_on "webp"

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK.")
  end

  def install
    rocm = rocm_root
    ENV["ROCM_PATH"] = rocm
    ENV["HIP_PATH"] = rocm
    ENV.prepend_path "PATH", "#{rocm}/bin"
    ENV.prepend_path "PATH", "#{rocm}/lib/llvm/bin"
    ENV.prepend_path "PATH", "#{rocm}/llvm/bin"

    hipcc = [
      "#{rocm}/bin/hipcc",
      "#{rocm}/lib/llvm/bin/clang++",
      "#{rocm}/llvm/bin/clang++",
      "#{rocm}/bin/amdclang++",
    ].find { |c| File.executable?(c) } || "#{rocm}/bin/hipcc"

    ENV["HIPCC"] = hipcc
    ENV["GPU_ARCH"] = "gfx1151"

    # Compile engine, bench, and API server tools
    system "bash", "build.sh", "all"

    bin.install "build/qwenox-engine" => "qwenox_engine"
    bin.install "build/qwenox-bench" => "qwenox_bench"
    bin.install "build/qwenox-api" => "qwenox_server"
    bin.install_symlink bin/"qwenox_engine" => "qwenox"

    %w[tok_cli tpl_cli eng_cli].each do |cli|
      bin.install "build/#{cli}" => "qwenox-#{cli.tr("_", "-")}" if File.exist?("build/#{cli}")
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:   "rocm",
      gpu_arch:  "gfx1151",
      rocm_root: rocm,
      hipcc:     hipcc,
      cxx:       ENV.cxx,
      commit:    "dedb058b1ca7d9c1cffbdb44b51defb2d496a692",
    )
  end

  def caveats
    <<~EOS
      Qwenox targets the AMD Ryzen AI Max+ 395 ("Strix Halo", gfx1151) APU.
      Start the inference daemon:
        qwenox_engine --help
      Start the OpenAI-compatible HTTP API server:
        qwenox_server --help
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("ldd #{bin}/qwenox_engine")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    # 2. CLI Introspection
    assert_match(/qwenox|usage|engine/i, shell_output("#{bin}/qwenox_engine --help 2>&1"))
    assert_match(/usage|api|server/i, shell_output("#{bin}/qwenox_server --help 2>&1"))

    # 3. Device Discovery Smoke Test
    probe = shell_output("#{bin}/qwenox_engine --info 2>&1", nil)
    assert $CHILD_STATUS.exitstatus < 128, "Device probe crashed: #{probe}"
  end
end
