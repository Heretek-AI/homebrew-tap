class Gufo < Formula
  desc "Pure C11/C++20/HIP multimodal inference engine for AMD Strix Halo (gfx1151)"
  homepage "https://github.com/gufo-org/gufo"
  url "https://github.com/gufo-org/gufo/archive/56ed8f4d2308da6ff30b4502a850b4e5d2113d94.tar.gz"
  version "0.28.1-git56ed8f4"
  sha256 "093ad26cfbd73330a9e810df8f24b12a9dd8ee2c54b85ac3ea3443ed56286019"
  license "Apache-2.0"
  head "https://github.com/gufo-org/gufo.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-tools", "Build and install developer tools (simple_chat, bench_q8_1, tune_hipblaslt, verify_*)"
  option "with-znver4", "Compile host code with -march=znver4 + AVX-512 instead of -march=znver5"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "curl"
  depends_on "ffmpeg"
  depends_on "giflib"
  depends_on "icu4c"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libsndfile"
  depends_on "libsoxr"
  depends_on :linux
  depends_on "openssl@3"
  depends_on "webp"

  conflicts_with "gufo-franzmoca", because: "both install `gufo` and `gufo-server` binaries"
  conflicts_with "gufetto", because: "both install `gufo` and `gufo-server` binaries"

  def install
    rocm_path = ENV.fetch("ROCM_PATH", "/opt/rocm")
    unless Dir.exist?(rocm_path)
      odie "ROCm installation not found at #{rocm_path}. Set ROCM_PATH to your ROCm SDK (ROCm 7+ / 10.1+)."
    end

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

    # 1. Prevent embedding versioned Cellar/ffmpeg/<ver> paths via file(REAL_PATH)
    ["src/models/embedding_gemma2/CMakeLists.txt", "src/models/embedding_gemma2/extension.cmake"].each do |f|
      next unless File.exist?(f)

      content = File.read(f)
      if content.include?('file(REAL_PATH "${_resolved}" _soname)')
        inreplace f, 'file(REAL_PATH "${_resolved}" _soname)', 'set(_soname "${_resolved}")'
      elsif content.include?('file(REAL_PATH "${GUFO_${upper}_LIBRARY}" runtime)')
        inreplace f, 'file(REAL_PATH "${GUFO_${upper}_LIBRARY}" runtime)', 'set(runtime "${GUFO_${upper}_LIBRARY}")'
      end
    end

    # 2. Prevent embedding temporary buildpath in tune_hipblaslt if --with-tools is active
    if File.exist?("tools/tune_hipblaslt.cpp") &&
       File.read("tools/tune_hipblaslt.cpp").include?('GUFO_SOURCE_DIR "/share/gufo/hipblaslt_tuning.txt"')
      inreplace "tools/tune_hipblaslt.cpp",
                'GUFO_SOURCE_DIR "/share/gufo/hipblaslt_tuning.txt"',
                "\"#{pkgshare}/hipblaslt_tuning.txt\""
    end

    # 3. Allow building on Zen 4 CI runners while preserving required AVX-512 intrinsics
    if build.with?("znver4")
      inreplace "CMakeLists.txt",
                'set(GUFO_MARCH_FLAG "-march=znver5")',
                'set(GUFO_MARCH_FLAG "-march=znver4 -mavx512f -mavx512bf16 -mavx512bw -mavx512dq -mavx512vl")'
    end

    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("icu4c")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("openssl@3")/"pkgconfig"

    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_HIP_ARCHITECTURES=gfx1151
      -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
      -DHIP_ROOT_DIR=#{rocm_path}
      -DHIP_PATH=#{rocm_path}
      -DGUFO_FFMPEG_LIBDIR=#{formula_opt_lib("ffmpeg")}
      -DGUFO_BUILD_TESTS=OFF
      -DGUFO_BUILD_EVAL=OFF
      -DGUFO_WERROR=OFF
      -DGUFO_ENABLE_SANITIZERS=OFF
      -DGUFO_ENABLE_TOOLS=#{build.with?("tools") ? "ON" : "OFF"}
      -DCMAKE_INSTALL_RPATH=#{rocm_path}/lib;#{HOMEBREW_PREFIX}/lib
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args,
           "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX};#{formula_opt_prefix("icu4c")};#{formula_opt_prefix("openssl@3")}"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    if build.with?("tools")
      %w[bench_q8_1 tune_hipblaslt verify_gemma4 verify_vae].each do |tool|
        bin.install "build/tools/#{tool}" => "gufo-#{tool.tr("_", "-")}" if File.exist?("build/tools/#{tool}")
      end
      bin.install "build/examples/simple_chat" => "gufo-simple-chat" if File.exist?("build/examples/simple_chat")
    end
  end

  def caveats
    <<~EOS
      gufo targets the AMD Ryzen AI Max+ 395 ("Strix Halo", gfx1151) APU with unified GTT memory.
      Models are stored by default in:
        ~/.cache/gufo/models (override via GUFO_MODELS_DIR or --model-dir)

      Start the OpenAI/Anthropic/Ollama-compatible server on port 8080:
        gufo serve --host 127.0.0.1 --port 8080
    EOS
  end

  service do
    run [opt_bin/"gufo", "serve", "--host", "127.0.0.1", "--port", "8080"]
    keep_alive true
    working_dir var
    log_path var/"log/gufo.log"
    error_log_path var/"log/gufo.log"
  end

  test do
    assert_match "gufo version", shell_output("#{bin}/gufo version")
    assert_match "Usage: gufo", shell_output("#{bin}/gufo --help")
  end
end
