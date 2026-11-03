class GufoFranzmoca < Formula
  desc "Strix Halo engine with DeepSeek-V4.1-Flash (763B) & Gemma 4 MTP"
  homepage "https://github.com/franzmoca/gufo"
  url "https://github.com/franzmoca/gufo/archive/01fb6f4e39464003efffd97d79607005146280f0.tar.gz"
  version "0.28.1-franzmoca-git01fb6f4"
  sha256 "609a2d8296b8da4b80ca758c622db368854b4e07b9fc5873c829675909f6d312"
  license "Apache-2.0"
  head "https://github.com/franzmoca/gufo.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "without-tools", "Skip building DeepSeek-V4.1-Flash & Gemma 4 verification/streaming tools"
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

  conflicts_with "gufo", because: "both install `gufo` and `gufo-server` binaries"
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

    ["src/models/embedding_gemma2/CMakeLists.txt", "src/models/embedding_gemma2/extension.cmake"].each do |f|
      next unless File.exist?(f)

      content = File.read(f)
      if content.include?('file(REAL_PATH "${_resolved}" _soname)')
        inreplace f, 'file(REAL_PATH "${_resolved}" _soname)', 'set(_soname "${_resolved}")'
      elsif content.include?('file(REAL_PATH "${GUFO_${upper}_LIBRARY}" runtime)')
        inreplace f, 'file(REAL_PATH "${GUFO_${upper}_LIBRARY}" runtime)', 'set(runtime "${GUFO_${upper}_LIBRARY}")'
      end
    end

    if File.exist?("tools/tune_hipblaslt.cpp") &&
       File.read("tools/tune_hipblaslt.cpp").include?('GUFO_SOURCE_DIR "/share/gufo/hipblaslt_tuning.txt"')
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

    enable_tools = build.with?("tools")
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
      -DGUFO_ENABLE_TOOLS=#{enable_tools ? "ON" : "OFF"}
      -DCMAKE_INSTALL_RPATH=#{rocm_path}/lib;#{HOMEBREW_PREFIX}/lib
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

    bin.install_symlink bin/"gufo" => "gufo-franzmoca"

    if enable_tools
      %w[
        dsv41_stream_order
        inspect_gguf_tensors
        verify_dsv41_UD_iq1m
        verify_gemma4
        verify_vae
        bench_q8_1
        tune_hipblaslt
      ].each do |tool|
        bin.install "build/tools/#{tool}" => "gufo-#{tool.tr("_", "-")}" if File.exist?("build/tools/#{tool}")
      end
    end
  end

  def caveats
    <<~EOS
      gufo-franzmoca adds native engines for:
        1. DeepSeek-V4.1-Flash (763B MoE at up to 1M context on 128 GB Strix Halo):
           - GTT-resident IQ1_M / UD-IQ1_M or NVMe SSD expert streaming (--stream-experts)
           - Dual-SSD split streaming via GUFO_DSV41_EXPERT_TAILS_DIR
        2. Gemma 4 (26B-A4B MoE & 31B Dense) with gemma4-assistant MTP speculative decoding:
           - --draft-policy calibrated|confidence|fixed --prefill-weights off|compact|decoded

      Both `gufo` and `gufo-franzmoca` CLI entrypoints are installed in #{opt_bin}.
    EOS
  end

  service do
    run [opt_bin/"gufo", "serve", "--host", "127.0.0.1", "--port", "8080"]
    keep_alive true
    working_dir var
    log_path var/"log/gufo-franzmoca.log"
    error_log_path var/"log/gufo-franzmoca.log"
  end

  test do
    assert_match "gufo version", shell_output("#{bin}/gufo-franzmoca version")
    assert_match "--stream-experts", shell_output("#{bin}/gufo-franzmoca --help")
  end
end
