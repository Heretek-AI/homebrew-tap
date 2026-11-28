class Gufo < Formula
  desc "Pure C11/C++20/HIP multimodal inference engine for AMD Strix Halo (gfx1151)"
  homepage "https://github.com/gufo-org/gufo"
  url "https://github.com/gufo-org/gufo/archive/45486593ef7a62d3e12a249833e644585efdff00.tar.gz"
  version "0.28.1-git4548659"
  sha256 "acc79a5be10996ca8c22ad25413e1407740b8d20a32ece474ffc666e0d3f5818"
  license "Apache-2.0"
  head "https://github.com/gufo-org/gufo.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-tools", "Build and install developer tools (simple_chat, bench_q8_1, tune_hipblaslt, verify_*)"
  option "with-znver4", "Compile host code with -march=znver4 + AVX-512 instead of -march=znver5"
  option "with-npu", "Require the XRT-based NPU backend (fails if Xilinx XRT is not installed)"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
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

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK (ROCm 7+ / 10.1+).")
  end

  def install
    xrt_path = [
      ENV.fetch("XILINX_XRT", nil),
      "/opt/xilinx/xrt",
      *Dir.glob("/opt/xilinx/xrt*"),
      HOMEBREW_PREFIX,
      "/usr/local",
      "/usr",
    ].compact.find { |path| File.exist?("#{path}/include/xrt/xrt_bo.h") }
    if build.with?("npu") && !xrt_path
      odie <<~EOS
        gufo: --with-npu requires Xilinx XRT, but no XRT installation was found.
        Install XRT (providing include/xrt/xrt_bo.h and libxrt_coreutil.so), or
        point XILINX_XRT at the XRT prefix, then retry.
      EOS
    end
    unless xrt_path
      top_level = "CMakeLists.txt"
      npu_level = "src/core/npu/CMakeLists.txt"
      upstream_xrt = <<~CMAKE
        find_path(GUFO_XRT_INCLUDE_DIR NAMES xrt/xrt_bo.h
          HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES include REQUIRED)
        if(WIN32)
          find_library(GUFO_XRT_COREUTIL_LIBRARY NAMES xrt_coreutil
            HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES lib lib64 REQUIRED)
          add_library(XRT::xrt_coreutil UNKNOWN IMPORTED)
        else()
          # Production XRT is dynamically linked; do not fall back to a static archive.
          set(_GUFO_SAVED_FIND_LIBRARY_SUFFIXES "${CMAKE_FIND_LIBRARY_SUFFIXES}")
          set(CMAKE_FIND_LIBRARY_SUFFIXES .so)
          find_library(GUFO_XRT_COREUTIL_LIBRARY NAMES xrt_coreutil
            HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES lib lib64 REQUIRED)
          set(CMAKE_FIND_LIBRARY_SUFFIXES "${_GUFO_SAVED_FIND_LIBRARY_SUFFIXES}")
          unset(_GUFO_SAVED_FIND_LIBRARY_SUFFIXES)
          add_library(XRT::xrt_coreutil SHARED IMPORTED)
        endif()
        set_target_properties(XRT::xrt_coreutil PROPERTIES
          IMPORTED_LOCATION "${GUFO_XRT_COREUTIL_LIBRARY}"
          INTERFACE_INCLUDE_DIRECTORIES "${GUFO_XRT_INCLUDE_DIR}")
        if(NOT WIN32)
          set_property(TARGET XRT::xrt_coreutil PROPERTY INTERFACE_LINK_LIBRARIES uuid)
        endif()
      CMAKE
      optional_xrt = <<~CMAKE
        find_path(GUFO_XRT_INCLUDE_DIR NAMES xrt/xrt_bo.h
          HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES include)
        if(GUFO_XRT_INCLUDE_DIR)
          if(WIN32)
            find_library(GUFO_XRT_COREUTIL_LIBRARY NAMES xrt_coreutil
              HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES lib lib64)
          else()
            # Production XRT is dynamically linked; do not fall back to a static archive.
            set(_GUFO_SAVED_FIND_LIBRARY_SUFFIXES "${CMAKE_FIND_LIBRARY_SUFFIXES}")
            set(CMAKE_FIND_LIBRARY_SUFFIXES .so)
            find_library(GUFO_XRT_COREUTIL_LIBRARY NAMES xrt_coreutil
              HINTS ${_GUFO_XRT_PREFIXES} PATH_SUFFIXES lib lib64)
            set(CMAKE_FIND_LIBRARY_SUFFIXES "${_GUFO_SAVED_FIND_LIBRARY_SUFFIXES}")
            unset(_GUFO_SAVED_FIND_LIBRARY_SUFFIXES)
          endif()
          if(GUFO_XRT_COREUTIL_LIBRARY)
            if(WIN32)
              add_library(XRT::xrt_coreutil UNKNOWN IMPORTED)
            else()
              add_library(XRT::xrt_coreutil SHARED IMPORTED)
            endif()
            set_target_properties(XRT::xrt_coreutil PROPERTIES
              IMPORTED_LOCATION "${GUFO_XRT_COREUTIL_LIBRARY}"
              INTERFACE_INCLUDE_DIRECTORIES "${GUFO_XRT_INCLUDE_DIR}")
            if(NOT WIN32)
              set_property(TARGET XRT::xrt_coreutil PROPERTY INTERFACE_LINK_LIBRARIES uuid)
            endif()
          endif()
        endif()
      CMAKE

      upstream_module = <<~CMAKE
        if(WIN32)
          # Use the xrt_coreutil.dll the NPU driver installs in System32; a copy
      CMAKE
      guarded_module = <<~CMAKE
        if(GUFO_XRT_INCLUDE_DIR AND GUFO_XRT_COREUTIL_LIBRARY)
        if(WIN32)
          # Use the xrt_coreutil.dll the NPU driver installs in System32; a copy
      CMAKE
      upstream_end = <<~CMAKE
        endif()
        # Host operators: AVX2 + FMA (every Strix Halo and development x86 CPU).
      CMAKE
      guarded_end = <<~CMAKE
        endif()
        endif()
        # Host operators: AVX2 + FMA (every Strix Halo and development x86 CPU).
      CMAKE

      { top_level => [[upstream_xrt, optional_xrt]],
        npu_level => [[upstream_module, guarded_module], [upstream_end, guarded_end]] }.each do |path, edits|
        content = File.read(path)
        edits.each do |before, after|
          unless content.include?(before)
            raise "gufo: unexpected upstream CMake in #{path}; refusing to disable the XRT backend"
          end

          inreplace path, before, after
        end
      end
    end
    ENV["XILINX_XRT"] = xrt_path if xrt_path

    rocm_path = rocm_root
    # Newer ROCm ships hipCUB in include/hipccl and requires libhipcxx from that
    # same root. Prefer it over the bare include directory so the hipCUB headers
    # can find <hip/std/version> during the HIP compilation.
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
      -DGUFO_FFMPEG_LIBDIR=#{formula_opt_lib("ffmpeg")}
      -DGUFO_BUILD_TESTS=OFF
      -DGUFO_BUILD_EVAL=OFF
      -DGUFO_WERROR=OFF
      -DGUFO_ENABLE_SANITIZERS=OFF
      -DGUFO_ENABLE_TOOLS=#{tools_flag}
      -DCMAKE_INSTALL_RPATH=#{formula_opt_lib("rocm-runtime")};#{HOMEBREW_PREFIX}/lib
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler
    # gufo uses find_path(HIPCUB_INCLUDE_DIR ...) rather than the hipCUB CMake
    # package, so it would otherwise find /opt/rocm/include and miss libhipcxx.
    args << "-DHIPCUB_INCLUDE_DIR=#{hipcub_dir}" if hipcub_dir
    if (sccache = ENV["HOMEBREW_SCCACHE_PATH"]) && File.executable?(sccache)
      ENV["SCCACHE_DIR"] = ENV["HOMEBREW_SCCACHE_DIR"] if ENV["HOMEBREW_SCCACHE_DIR"]
      %w[C CXX HIP].each { |lang| args << "-DCMAKE_#{lang}_COMPILER_LAUNCHER=#{sccache}" }
    end

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

    # CMake installs `tune_hipblaslt` directly into `bin`; expose it only as
    # the namespaced `gufo-tune-hipblaslt` installed by the tools block below.
    rm bin/"tune_hipblaslt" if (bin/"tune_hipblaslt").exist?

    if enable_tools
      %w[bench_q8_1 tune_hipblaslt verify_gemma4 verify_vae].each do |tool|
        bin.install "build/tools/#{tool}" => "gufo-#{tool.tr("_", "-")}" if File.exist?("build/tools/#{tool}")
      end
      bin.install "build/examples/simple_chat" => "gufo-simple-chat" if File.exist?("build/examples/simple_chat")
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:      "rocm",
      rocm_root:    rocm_path,
      hip_compiler: hip_compiler,
      npu_xrt:      xrt_path,
      cmake_args:   args,
    )
  end

  def caveats
    <<~EOS
      gufo targets the AMD Ryzen AI Max+ 395 ("Strix Halo", gfx1151) APU with unified GTT memory.
      Models are stored by default in:
        ~/.cache/gufo/models (override via GUFO_MODELS_DIR or --model-dir)

      Start the OpenAI/Anthropic/Ollama-compatible server on port 18001:
        gufo serve --host 127.0.0.1 --port 18001
    EOS
  end

  service do
    run [opt_bin/"gufo", "serve", "--host", "127.0.0.1", "--port", "18001"]
    keep_alive true
    working_dir var
    log_path var/"log/gufo.log"
    error_log_path var/"log/gufo.log"
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("ldd #{bin}/gufo")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    # 2. CLI Introspection
    assert_match "gufo version", shell_output("#{bin}/gufo --version")
    assert_match(/Usage: .*gufo/, shell_output("#{bin}/gufo --help"))

    # 3. Device Discovery Smoke Test
    probe = shell_output("#{bin}/gufo probe")
    assert_match "Hello, Strix Halo!", probe
    assert_match "OK", probe
  end
end
