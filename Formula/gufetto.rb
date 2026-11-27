class Gufetto < Formula
  desc "C11/C++23/HIP Strix Halo runtime with rotated KV cache & prefix pinning"
  homepage "https://github.com/community-token-labs/gufetto"
  url "https://github.com/community-token-labs/gufetto/archive/64f5d1afb0d4b60780b0ccc285a1d11e47e56800.tar.gz"
  version "0.26.0-gufetto-git64f5d1a"
  sha256 "3fa73c3b7e508aaec42b830bb756821cda42169773718245f78efb2a50615952"
  license "Apache-2.0"
  head "https://github.com/community-token-labs/gufetto.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-bf16-k-control", "Enable experimental bf16/q8_0-rotated and bf16/q4_0-rotated KV cache modes"
  option "with-npu", "Enable experimental AMD XDNA 2 NPU runtime support (requires XRT SDK)"
  option "with-tools", "Build and install developer tools (simple_chat, bench_q8_1, tune_hipblaslt)"
  option "with-znver4", "Compile host code with -march=znver4 + AVX-512 instead of -march=znver5"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "curl"
  depends_on "giflib"
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on "icu4c"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libsndfile"
  depends_on "libsoxr"
  depends_on :linux
  depends_on "openssl@3"
  depends_on "webp"

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK (ROCm 7+ / 10.1+).")
  end

  def install
    rocm_path = rocm_root
    ENV["ROCM_PATH"] = rocm_path
    ENV["HIP_PATH"] = rocm_path
    ENV.prepend_path "PATH", "#{rocm_path}/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/lib/llvm/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/llvm/bin"

    hip_compiler = [
      "#{rocm_path}/lib/llvm/bin/clang++",
      "#{rocm_path}/llvm/bin/clang++",
      "#{rocm_path}/bin/amdclang++",
      "#{rocm_path}/bin/clang++",
    ].find { |c| File.executable?(c) }

    if File.exist?("tools/tune_hipblaslt.cpp")
      inreplace "tools/tune_hipblaslt.cpp",
                'GUFO_SOURCE_DIR "/share/gufo/hipblaslt_tuning.txt"',
                "\"#{pkgshare}/hipblaslt_tuning.txt\""
    end

    if build.with?("znver4")
      inreplace "CMakeLists.txt",
                'set(GUFO_MARCH_FLAG "-march=znver5")',
                'set(GUFO_MARCH_FLAG "-march=znver4 -mavx512f -mavx512bf16 -mavx512bw -mavx512dq -mavx512vl")'
    end

    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("icu4c")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("openssl@3")/"pkgconfig"

    npu_flag = build.with?("npu") ? "ON" : "OFF"
    bf16_k_control_flag = build.with?("bf16-k-control") ? "ON" : "OFF"
    enable_tools = build.with?("tools")
    tools_flag = enable_tools ? "ON" : "OFF"
    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_HIP_ARCHITECTURES=gfx1151
      -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
      -DHIP_ROOT_DIR=#{rocm_path}
      -DHIP_PATH=#{rocm_path}
      -DGUFO_BUILD_TESTS=OFF
      -DGUFO_BUILD_EVAL=OFF
      -DGUFO_WERROR=OFF
      -DGUFO_ENABLE_SANITIZERS=OFF
      -DGUFO_ENABLE_NPU=#{npu_flag}
      -DGUFO_ENABLE_BF16_K_CONTROL=#{bf16_k_control_flag}
      -DGUFO_ENABLE_TOOLS=#{tools_flag}
      -DCMAKE_INSTALL_RPATH=#{formula_opt_lib("rocm-runtime")};#{HOMEBREW_PREFIX}/lib
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler

    prefix_paths = [
      rocm_path,
      HOMEBREW_PREFIX,
      formula_opt_prefix("icu4c"),
      formula_opt_prefix("openssl@3"),
    ].join(";")

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args,
           "-DCMAKE_PREFIX_PATH=#{prefix_paths}"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # CMake installs `gufo`, `gufo-server`, and optional developer tools
    # directly into `bin`; expose them only under the tap namespace.
    rm bin/"gufo-server" if (bin/"gufo-server").exist?
    mv bin/"gufo", bin/"gufetto"
    bin.install_symlink bin/"gufetto" => "gufetto-server"
    mv bin/"gufo-kernel-bench", bin/"gufetto-kernel-bench" if (bin/"gufo-kernel-bench").exist?
    rm bin/"tune_hipblaslt" if (bin/"tune_hipblaslt").exist?

    if enable_tools
      %w[bench_q8_1 tune_hipblaslt].each do |tool|
        bin.install "build/tools/#{tool}" => "gufetto-#{tool.tr("_", "-")}" if File.exist?("build/tools/#{tool}")
      end
      bin.install "build/examples/simple_chat" => "gufetto-simple-chat" if File.exist?("build/examples/simple_chat")
    end
    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:      "rocm",
      rocm_root:    rocm_path,
      hip_compiler: hip_compiler,
      cmake_args:   args,
    )
  end

  def caveats
    <<~EOS
      gufetto provides Flash-Next (qwen4exp) rotated KV cache quantization, multi-prefix pinning,
      and the Measured Model Admission Planner:
        gufetto serve --kv-cache-type q8_0/q4_0-rotated --pin-prefix-dir /path/to/prefixes
        gufetto diagnose --plan --model /path/to/model.gguf --context-len 32768

      Both `gufetto` and `gufetto-server` CLI entrypoints are installed in #{opt_bin}.
    EOS
  end

  service do
    run [opt_bin/"gufetto", "serve", "--host", "127.0.0.1", "--port", "18002"]
    keep_alive true
    working_dir var
    log_path var/"log/gufetto.log"
    error_log_path var/"log/gufetto.log"
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("ldd #{bin}/gufetto")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    # 2. CLI Introspection
    assert_match "gufo version", shell_output("#{bin}/gufetto version")
    assert_match "--kv-cache-type", shell_output("#{bin}/gufetto --help")
    assert_match "--pin-prefix-file", shell_output("#{bin}/gufetto --help")

    # 3. Device Discovery Smoke Test
    probe = shell_output("#{bin}/gufetto info 2>&1", nil)
    assert $CHILD_STATUS.exitstatus < 128, "Device probe crashed: #{probe}"
  end
end
