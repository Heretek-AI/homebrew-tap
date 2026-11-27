class GufoDs41 < Formula
  desc "Gufo Strix Halo engine with DeepSeek-V4.1-Flash (763B) extension"
  homepage "https://github.com/franzmoca/ds41-gufo-extension"
  url "https://github.com/gufo-org/gufo/archive/60c48924a040edc0f025e8d27e6236fcaecc22fd.tar.gz"
  version "0.5.1-gufo60c4892"
  sha256 "d738808a482863f308cd2c4c500f4a1cbd31563d0c9dcb35c82882549fcb2c43"
  license "Apache-2.0"

  livecheck do
    skip "Tracks ds41-gufo-extension release and its flake-pinned Gufo revision"
  end

  option "with-tools", "Build and install developer tools (simple_chat, bench_q8_1, tune_hipblaslt)"
  option "with-znver4", "Compile host code with -march=znver4 + AVX-512 instead of -march=znver5"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "curl"
  depends_on "ffmpeg"
  depends_on "giflib"
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on "icu4c@79"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libsndfile"
  depends_on "libsoxr"
  depends_on :linux
  depends_on "openssl@4"
  depends_on "webp"
  depends_on "zlib-ng-compat"

  resource "ds41-gufo-extension" do
    url "https://github.com/franzmoca/ds41-gufo-extension/archive/refs/tags/v0.5.1.tar.gz"
    sha256 "9cb35b339af195ca76018a224416602802be76b1cc66a1e0f335c31fedab3186"
  end

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK (ROCm 7+ / 10.1+).")
  end

  def install
    ext_dir = buildpath/"extensions/ds41-gufo-extension"
    resource("ds41-gufo-extension").stage ext_dir

    rocm_path = rocm_root
    hipcub_dir = ["#{rocm_path}/include/hipccl", "#{rocm_path}/include"].find do |path|
      File.exist?("#{path}/hip/std/version") || File.exist?("#{path}/cuda/std/version")
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

    # Make the optional dlopen'd NPU XRT module conditional when Xilinx XRT is
    # not installed on the build host (gufo-ds41 executes on HIP gfx1151).
    xrt_present = [ENV["XILINX_XRT"], "/opt/xilinx/xrt"].compact.any? do |p|
      File.exist?("#{p}/include/xrt/xrt_bo.h")
    end
    unless xrt_present
      inreplace "CMakeLists.txt" do |s|
        s.sub!(
          "find_path(GUFO_XRT_INCLUDE_DIR NAMES xrt/xrt_bo.h\n  " \
          "HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES include REQUIRED)",
          "find_path(GUFO_XRT_INCLUDE_DIR NAMES xrt/xrt_bo.h\n  " \
          "HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES include)",
        )
        s.sub!(
          "  find_library(GUFO_XRT_COREUTIL_LIBRARY NAMES xrt_coreutil\n    " \
          "HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES lib lib64 REQUIRED)\n  " \
          "set(CMAKE_FIND_LIBRARY_SUFFIXES \"${_GUFO_SAVED_FIND_LIBRARY_SUFFIXES}\")\n  " \
          "unset(_GUFO_SAVED_FIND_LIBRARY_SUFFIXES)\n  " \
          "add_library(XRT::xrt_coreutil SHARED IMPORTED)\n" \
          "endif()\n" \
          "set_target_properties(XRT::xrt_coreutil PROPERTIES\n  " \
          "IMPORTED_LOCATION \"${GUFO_XRT_COREUTIL_LIBRARY}\"\n  " \
          "INTERFACE_INCLUDE_DIRECTORIES \"${GUFO_XRT_INCLUDE_DIR}\")\n" \
          "if(NOT WIN32)\n  " \
          "set_property(TARGET XRT::xrt_coreutil PROPERTY INTERFACE_LINK_LIBRARIES uuid)\n" \
          "endif()",
          "  find_library(GUFO_XRT_COREUTIL_LIBRARY NAMES xrt_coreutil\n    " \
          "HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES lib lib64)\n  " \
          "set(CMAKE_FIND_LIBRARY_SUFFIXES \"${_GUFO_SAVED_FIND_LIBRARY_SUFFIXES}\")\n  " \
          "unset(_GUFO_SAVED_FIND_LIBRARY_SUFFIXES)\n  " \
          "if(GUFO_XRT_INCLUDE_DIR AND GUFO_XRT_COREUTIL_LIBRARY)\n    " \
          "add_library(XRT::xrt_coreutil SHARED IMPORTED)\n  " \
          "endif()\n" \
          "endif()\n" \
          "if(TARGET XRT::xrt_coreutil)\n  " \
          "set_target_properties(XRT::xrt_coreutil PROPERTIES\n    " \
          "IMPORTED_LOCATION \"${GUFO_XRT_COREUTIL_LIBRARY}\"\n    " \
          "INTERFACE_INCLUDE_DIRECTORIES \"${GUFO_XRT_INCLUDE_DIR}\")\n  " \
          "if(NOT WIN32)\n    " \
          "set_property(TARGET XRT::xrt_coreutil PROPERTY INTERFACE_LINK_LIBRARIES uuid)\n  " \
          "endif()\n" \
          "endif()",
        )
      end
      inreplace "src/core/npu/CMakeLists.txt",
                "  add_library(gufo_npu_xrt MODULE xrt_backend.cpp)\n  " \
                "target_include_directories(gufo_npu_xrt PRIVATE ${PROJECT_SOURCE_DIR})\n  " \
                "target_compile_features(gufo_npu_xrt PRIVATE cxx_std_20)\n  " \
                "target_link_libraries(gufo_npu_xrt PRIVATE XRT::xrt_coreutil)\n  " \
                "target_link_options(gufo_npu_xrt PRIVATE \"LINKER:--no-undefined\")\n  " \
                "set_target_properties(gufo_npu_xrt PROPERTIES\n    " \
                "CXX_VISIBILITY_PRESET hidden\n    " \
                "VISIBILITY_INLINES_HIDDEN ON)\n  " \
                "install(TARGETS gufo_npu_xrt LIBRARY DESTINATION lib/gufo)\n  " \
                "add_dependencies(gufo_npu gufo_npu_xrt)\n  " \
                "target_compile_definitions(gufo_npu PRIVATE\n    " \
                "\"GUFO_NPU_XRT_BUILD_MODULE=\\\"$<TARGET_FILE:gufo_npu_xrt>\\\"\")",
                "  if(TARGET XRT::xrt_coreutil)\n    " \
                "add_library(gufo_npu_xrt MODULE xrt_backend.cpp)\n    " \
                "target_include_directories(gufo_npu_xrt PRIVATE ${PROJECT_SOURCE_DIR})\n    " \
                "target_compile_features(gufo_npu_xrt PRIVATE cxx_std_20)\n    " \
                "target_link_libraries(gufo_npu_xrt PRIVATE XRT::xrt_coreutil)\n    " \
                "target_link_options(gufo_npu_xrt PRIVATE \"LINKER:--no-undefined\")\n    " \
                "set_target_properties(gufo_npu_xrt PROPERTIES\n      " \
                "CXX_VISIBILITY_PRESET hidden\n      " \
                "VISIBILITY_INLINES_HIDDEN ON)\n    " \
                "install(TARGETS gufo_npu_xrt LIBRARY DESTINATION lib/gufo)\n    " \
                "add_dependencies(gufo_npu gufo_npu_xrt)\n    " \
                "target_compile_definitions(gufo_npu PRIVATE\n      " \
                "\"GUFO_NPU_XRT_BUILD_MODULE=\\\"$<TARGET_FILE:gufo_npu_xrt>\\\"\")\n  " \
                "endif()"
    end

    if (build.bottle? || build.with?("znver4")) &&
       File.read("CMakeLists.txt").include?('set(GUFO_MARCH_FLAG "-march=znver5")')
      inreplace "CMakeLists.txt",
                'set(GUFO_MARCH_FLAG "-march=znver5")',
                'set(GUFO_MARCH_FLAG "-march=znver4 -mavx512f -mavx512bf16 -mavx512bw -mavx512dq -mavx512vl")'
    end

    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("icu4c@79")/"pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", formula_opt_lib("openssl@4")/"pkgconfig"

    enable_tools = build.with?("tools")
    tools_flag = enable_tools ? "ON" : "OFF"
    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_HIP_ARCHITECTURES=gfx1151
      -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
      -DHIP_ROOT_DIR=#{rocm_path}
      -DHIP_PATH=#{rocm_path}
      -DGUFO_EXTENSION_DIRS=#{ext_dir}
      -DGUFO_FFMPEG_LIBDIR=#{formula_opt_lib("ffmpeg")}
      -DGUFO_BUILD_TESTS=OFF
      -DGUFO_BUILD_EVAL=OFF
      -DGUFO_WERROR=OFF
      -DGUFO_ENABLE_SANITIZERS=OFF
      -DGUFO_BUILD_TOOLS=#{tools_flag}
      -DCMAKE_INSTALL_RPATH=#{formula_opt_lib("rocm-runtime")};#{HOMEBREW_PREFIX}/lib
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler
    args << "-DHIPCUB_INCLUDE_DIR=#{hipcub_dir}" if hipcub_dir

    prefix_paths = [
      rocm_path,
      HOMEBREW_PREFIX,
      formula_opt_prefix("icu4c@79"),
      formula_opt_prefix("openssl@4"),
    ].join(";")

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args,
           "-DCMAKE_PREFIX_PATH=#{prefix_paths}"
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

    # Expose binaries only under the gufo-ds41 namespace so it installs alongside gufo.
    rm bin/"gufo-server" if (bin/"gufo-server").exist?
    mv bin/"gufo", bin/"gufo-ds41"
    bin.install_symlink bin/"gufo-ds41" => "gufo-ds41-server"
    mv bin/"gufo-kernel-bench", bin/"gufo-ds41-kernel-bench" if (bin/"gufo-kernel-bench").exist?

    if enable_tools
      mv bin/"tune_hipblaslt", bin/"gufo-ds41-tune-hipblaslt" if (bin/"tune_hipblaslt").exist?
      bin.install "build/tools/bench_q8_1" => "gufo-ds41-bench-q8-1" if File.exist?("build/tools/bench_q8_1")
      bin.install "build/examples/simple_chat" => "gufo-ds41-simple-chat" if File.exist?("build/examples/simple_chat")
    elsif (bin/"tune_hipblaslt").exist?
      rm bin/"tune_hipblaslt"
    end

    pkgshare.install ext_dir/"tools/ds41/engram_split.py" if (ext_dir/"tools/ds41/engram_split.py").exist?

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:      "rocm",
      extension:    "ds41-gufo-extension@v0.5.1",
      rocm_root:    rocm_path,
      hip_compiler: hip_compiler,
      cmake_args:   args,
    )
  end

  def caveats
    <<~EOS
      gufo-ds41 builds upstream Gufo with the franzmoca/ds41-gufo-extension (v0.5.1)
      for DeepSeek-V4.1-Flash-1017 (763B) on AMD Strix Halo (gfx1151, 128 GB unified memory).

      Start the OpenAI/Anthropic-compatible server on port 18003:
        gufo-ds41 serve llm \\
          -m /path/to/DeepSeek-V4.1-Flash-1017-UD-IQ1_M-00001-of-00005.gguf \\
          --stream-experts --speculative dspark \\
          --dspark-model /path/to/DeepSeek-V4.1-Flash-1017-DSpark-draft-Q2K-Q4K.gguf \\
          --host 127.0.0.1 --port 18003

      gufo-ds41 installs alongside gufo without binary collisions.
    EOS
  end

  service do
    run [opt_bin/"gufo-ds41", "serve", "--host", "127.0.0.1", "--port", "18003"]
    keep_alive true
    working_dir var
    log_path var/"log/gufo-ds41.log"
    error_log_path var/"log/gufo-ds41.log"
  end

  test do
    out = shell_output("ldd #{bin}/gufo-ds41")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    assert_match "gufo version", shell_output("#{bin}/gufo-ds41 --version")
    assert_match(/Usage: .*gufo/, shell_output("#{bin}/gufo-ds41 --help"))
  end
end
