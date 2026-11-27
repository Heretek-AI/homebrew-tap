class Libosmos < Formula
  desc "HIP inference engine and OpenAI-compatible server for AMD Strix Halo"
  homepage "https://github.com/mrsirg97-rgb/libosmos"
  url "https://github.com/mrsirg97-rgb/libosmos/releases/download/v0.18.0/osmos-0.18.0.tar.gz"
  sha256 "df1bf65dac73ffc50f7b2d2b597488cb681315ca095cab141214670c209eb642"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  option "with-npu", "Enable AMD XDNA NPU support (NPU=1)"

  depends_on "patchelf" => :build
  depends_on arch: :x86_64
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on :linux

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK (ROCm 7+ / gfx1151).")
  end

  def install
    rocm = rocm_root
    ENV["ROCM_PATH"] = rocm
    ENV["HIP_PATH"] = rocm
    ENV.prepend_path "PATH", "#{rocm}/bin"
    ENV.prepend_path "PATH", "#{rocm}/lib/llvm/bin"
    ENV.prepend_path "PATH", "#{rocm}/llvm/bin"

    npu = build.with?("npu") ? "1" : "0"
    ENV.prepend "LDFLAGS", "-Wl,-rpath,#{formula_opt_lib("rocm-runtime")}"
    make_args = [
      "-j#{ENV.make_jobs}",
      "serve",
      "api",
      "ROCM=#{rocm}",
      "HIP_ARCH=gfx1151",
      "NPU=#{npu}",
    ]
    system "make", *make_args

    bin.install "bin/osmos-api", "bin/osmos-serve"
    lib.install "lib/libosmos.a"
    lib.install "lib/libosmos_hip.a" if File.exist?("lib/libosmos_hip.a")
    include.install "include/osmos"

    runtime_rpath = "#{formula_opt_lib("rocm-runtime")}:#{HOMEBREW_PREFIX}/lib"
    [bin/"osmos-api", bin/"osmos-serve"].each do |binary|
      system "patchelf", "--set-rpath", runtime_rpath, binary
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:          "rocm",
      rocm_root:        rocm,
      hip_arch:         "gfx1151",
      npu:              npu == "1",
      make_args:        make_args,
      runtime_lib:      formula_opt_lib("rocm-runtime").to_s,
      rpath_limitation: "Makefile hardcodes HIP_RUNPATH and ignores LDFLAGS; ELF RPATH is normalized with patchelf",
    )
  end

  def caveats
    <<~EOS
      libosmos is compiled for AMD Strix Halo (gfx1151) against a ROCm 7+
      installation with HIP. The build defaults to /opt/rocm; set
      HOMEBREW_ROCM_PATH to use a ROCm SDK installed elsewhere.

      libosmos links the shared runtime from heretek-ai/tap/rocm-runtime. The
      upstream Makefile hardcodes its RUNPATH to the ROCm SDK lib directory and
      does not consume LDFLAGS, so the installed ELF RPATH is normalized to the
      shared runtime with patchelf after build.

      Start the OpenAI-compatible API with a pack's own config:
        osmos-api --config /path/to/pack/osmos.json
      The stdin/stdout engine is:
        osmos-serve --model /path/to/pack/model.gguf

      The optional --with-npu build also requires AMD XRT
      (libxrt_coreutil), which this formula does not install.
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    serve_ldd = shell_output("ldd #{bin}/osmos-serve")
    refute_match(/not found/, serve_ldd)
    assert_match(/libamdhip64\.so/, serve_ldd)

    api_ldd = shell_output("ldd #{bin}/osmos-api")
    refute_match(/not found/, api_ldd)

    # 2. CLI Introspection
    assert_match(/osmos/i, pipe_output("#{bin}/osmos-api --version 2>&1"))
    assert_match(/usage: osmos-api/i, pipe_output("#{bin}/osmos-api --help 2>&1"))
  end
end
