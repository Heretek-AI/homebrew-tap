class RulithInference < Formula
  desc "Rulith ROCm gfx1151 llama.cpp engine for Qwen3.8-Flash-Next EXL3/GGUF"
  homepage "https://github.com/rulith-dev/rulith-inference"
  url "https://github.com/rulith-dev/llama.cpp/archive/fa391c74002fd4927307945c0fe58667576c2d22.tar.gz"
  version "0.8.0-gitfa391c7"
  sha256 "4e695636cdf9164dfe1880cdf93db837aec86b88a2955e4a32fa0439b38e8f42"
  license "MIT"
  head "https://github.com/rulith-dev/llama.cpp.git", branch: "rulith"

  livecheck do
    skip "Tracks rulith-dev/llama.cpp rulith branch aligned with rulith-inference releases"
  end

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on :linux

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK (TheRock ROCm 10.1+).")
  end

  def install
    # Upstream defines mmh_ic/mmh_bc after their first use in mmh_gemm_et, which
    # MSVC accepts via delayed template parsing but Linux ROCm clang rejects.
    mmh_cu = "ggml/src/ggml-cuda/mul-mat-had.cu"
    if File.exist?(mmh_cu) && File.read(mmh_cu).include?("template <int N> struct mmh_ic")
      inreplace mmh_cu do |s|
        s.gsub!("template <int N> struct mmh_ic { static constexpr int  value = N; };\n" \
                "template <bool V> struct mmh_bc { static constexpr bool value = V; };\n", "")
        s.sub!("template <ggml_type type, int BM, int WM>\n" \
               "static __global__ void __launch_bounds__(256, 2) mmh_gemm_et(",
               "template <int N> struct mmh_ic { static constexpr int  value = N; };\n" \
               "template <bool V> struct mmh_bc { static constexpr bool value = V; };\n\n" \
               "template <ggml_type type, int BM, int WM>\n" \
               "static __global__ void __launch_bounds__(256, 2) mmh_gemm_et(")
      end
    end

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

    rpath = "#{libexec}/lib;#{formula_opt_lib("rocm-runtime")};#{HOMEBREW_PREFIX}/lib"
    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DGGML_HIP=ON
      -DGGML_VULKAN=OFF
      -DAMDGPU_TARGETS=gfx1151
      -DGPU_TARGETS=gfx1151
      -DGGML_HIP_GRAPHS=ON
      -DGGML_NATIVE=OFF
      -DGGML_AVX2=ON
      -DGGML_FMA=ON
      -DGGML_F16C=ON
      -DGGML_AVX512=OFF
      -DLLAMA_CURL=OFF
      -DLLAMA_USE_PREBUILT_UI=OFF
      -DLLAMA_BUILD_TESTS=OFF
      -DLLAMA_BUILD_EXAMPLES=OFF
      -DLLAMA_BUILD_TOOLS=ON
      -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
      -DHIP_ROOT_DIR=#{rocm_path}
      -DHIP_PATH=#{rocm_path}
      -DCMAKE_INSTALL_RPATH=#{rpath}
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args(install_prefix: libexec), *args,
           "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX}"
    system "cmake", "--build", "build", "--target", "llama-server", "llama-quantize", "llama-cli"

    # Install only the built binaries and shared libraries so unbuilt targets are never expected.
    (libexec/"bin").mkpath
    (libexec/"lib").mkpath
    Dir["build/bin/lib*.so*"].each { |lib_file| (libexec/"lib").install lib_file }

    # Expose only namespaced rulith-* binaries so we never collide with upstream llama.cpp.
    {
      "llama-server"   => "rulith-server",
      "llama-quantize" => "rulith-quantize",
      "llama-cli"      => "rulith-cli",
    }.each do |src_name, dst_name|
      built = buildpath/"build/bin"/src_name
      next unless built.exist?

      (libexec/"bin").install built
      bin.install_symlink libexec/"bin"/src_name => dst_name
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
      rulith-inference builds the Linux ROCm (gfx1151) engine from rulith-dev/llama.cpp
      (branch `rulith`, aligned with Rulith Inference v0.8.0) tuned for Qwen3.8-Flash-Next
      EXL3 and GGUF models on AMD Strix Halo (128 GB unified memory).

      Start the OpenAI/Anthropic-compatible server on port 18014:
        rulith-server -m /path/to/model.gguf --host 127.0.0.1 --port 18014

      Note: The desktop UI installer is Windows 11 only upstream; this formula provides
      the native Linux ROCm engine binaries (`rulith-server`, `rulith-quantize`, `rulith-cli`).
    EOS
  end

  service do
    run [opt_bin/"rulith-server", "--host", "127.0.0.1", "--port", "18014"]
    keep_alive true
    working_dir var
    log_path var/"log/rulith-inference.log"
    error_log_path var/"log/rulith-inference.log"
  end

  test do
    out = shell_output("ldd #{libexec}/bin/llama-server")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    assert_match(/usage|host|port/i, shell_output("#{bin}/rulith-server --help"))
  end
end
