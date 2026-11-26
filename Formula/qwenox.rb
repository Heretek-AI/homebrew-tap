class Qwenox < Formula
  desc "High-performance Qwen runtime and kernel primitives for Strix Halo"
  homepage "https://github.com/IIIIIllllIIIIIlllll/Qwenox"
  url "https://github.com/IIIIIllllIIIIIlllll/Qwenox/archive/dedb058b1ca7d9c1cffbdb44b51defb2d496a692.tar.gz"
  version "0.1.0-gitdedb058"
  sha256 "43a1e8c4d88092c0440587eb02c74b98ded31dbd6b1e3eb313c01a47ab8eabbb"
  license "AGPL-3.0-only"
  head "https://github.com/IIIIIllllIIIIIlllll/Qwenox.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on "heretek-ai/tap/rocm-runtime"
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
    ENV.prepend "LDFLAGS", "-Wl,-rpath,#{formula_opt_lib("rocm-runtime")}"

    # Compile engine, bench, and API server tools
    system "bash", "build.sh", "all"

    bin.install "build/qwenox-engine" => "qwenox-engine"
    bin.install "build/qwenox-bench" => "qwenox-bench"
    bin.install "build/qwenox-api" => "qwenox-server"
    bin.install_symlink bin/"qwenox-engine" => "qwenox"

    %w[tok_cli tpl_cli eng_cli].each do |cli|
      bin.install "build/#{cli}" => "qwenox-#{cli.tr("_", "-")}" if File.exist?("build/#{cli}")
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:          "rocm",
      gpu_arch:         "gfx1151",
      rocm_root:        rocm,
      hipcc:            hipcc,
      cxx:              ENV.cxx,
      runtime_lib:      formula_opt_lib("rocm-runtime").to_s,
      rpath_limitation: "build.sh does not forward LDFLAGS; binaries keep the ROCm SDK RUNPATH",
      commit:           "dedb058b1ca7d9c1cffbdb44b51defb2d496a692",
    )
  end

  def caveats
    <<~EOS
      Qwenox targets the AMD Ryzen AI Max+ 395 ("Strix Halo", gfx1151) APU.
      It links the shared runtime from heretek-ai/tap/rocm-runtime, but the
      upstream build.sh does not forward LDFLAGS, so source builds keep the
      ROCm SDK RUNPATH from HOMEBREW_ROCM_PATH.
      Start the inference daemon:
        qwenox-engine --help
      Start the OpenAI-compatible HTTP API server:
        qwenox-server --help
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("ldd #{bin}/qwenox-engine")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    # 2. CLI Introspection
    assert_match(/qwenox|usage|engine/i, shell_output("#{bin}/qwenox-engine --help 2>&1"))
    assert_match(/usage|api|server/i, shell_output("#{bin}/qwenox-server --help 2>&1"))

    # 3. Device Discovery Smoke Test
    probe = shell_output("#{bin}/qwenox-engine --info 2>&1", nil)
    assert $CHILD_STATUS.exitstatus < 128, "Device probe crashed: #{probe}"
  end
end
