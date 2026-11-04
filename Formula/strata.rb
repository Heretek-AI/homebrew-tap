class Strata < Formula
  include Language::Python::Virtualenv

  desc "Tiered MoE engine for Qwen3.8-Flash-Next, Qwen3.6 & DeepSeek-V4.1"
  homepage "https://github.com/Niko1221/Strata"
  url "https://github.com/Niko1221/Strata/archive/ffa80d73133ea5c548aefe57889a16e8085a938f.tar.gz"
  version "0.2.10"
  sha256 "0ea269d1961646ad7574965044ecd04bdc75af27f535e4c2a81ca902a7eec584"
  license :cannot_represent
  head "https://github.com/Niko1221/Strata.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-all-amdgpu", "Compile HIP kernels for all supported AMD GPUs (gfx906..gfx1201)"
  option "with-cuda", "Build with NVIDIA CUDA backend instead of AMD ROCm/HIP"
  option "with-sycl", "Build with Intel Arc/Xe oneAPI SYCL backend"
  option "with-native", "Enable -march=native in ggml-cpu (default uses portable AVX2 + runtime AVX-512 dispatch)"

  depends_on "cmake" => :build
  depends_on "git" => :build
  depends_on "ninja" => :build
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "python@3.12"

  # Pinned llama.cpp source required by STRATA_NATIVE_EXPERTS & tools/vision (third_party/ggml/VERSION.txt)
  resource "llama.cpp" do
    url "https://github.com/ggml-org/llama.cpp/archive/3cf03257f219afbe7334045ff7c6a06ac68c627d.tar.gz"
    sha256 "c076d7534afa0e5d0ec2a0d425b11e791c16f3de0d727221aea071cef156a280"
  end

  def install
    llama_dir = buildpath/"third_party/llama.cpp"
    resource("llama.cpp").stage llama_dir

    portable = build.with?("native") ? "OFF" : "ON"

    if OS.mac?
      args = %W[
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DSTRATA_BUILD_TESTS=OFF
        -DSTRATA_ENABLE_METAL=ON
        -DSTRATA_NATIVE_EXPERTS=ON
        -DSTRATA_PORTABLE=#{portable}
        -DSTRATA_GGML_DIR=#{llama_dir}
        -DMAYA_GGML_DIR=#{llama_dir}
        -DSTRATA_BUILD_ID=#{version}
      ]
      system "cmake", "-S", ".", "-B", "build-metal", *args, *std_cmake_args
      system "cmake", "--build", "build-metal"

      system "cmake", "-S", "tools/vision", "-B", "build-metal/vision", "-G", "Ninja",
             "-DCMAKE_BUILD_TYPE=Release", "-DLLAMA_DIR=#{llama_dir}", *std_cmake_args
      system "cmake", "--build", "build-metal/vision", "--target", "strata-vision"
    else
      rocm_path = ENV.fetch("ROCM_PATH", "/opt/rocm")
      hip_archs = build.with?("all-amdgpu") ? "all" : "gfx1151;gfx1100;gfx1201"

      backend_args = if build.with?("cuda")
        %w[-DSTRATA_ENABLE_CUDA=ON -DSTRATA_PREFILL_MMQ=ON -DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90;100;120]
      elsif build.with?("sycl")
        %w[-DSTRATA_ENABLE_SYCL=ON]
      else
        odie "ROCm installation not found at #{rocm_path}." unless Dir.exist?(rocm_path)
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

        hip_args = %W[
          -DSTRATA_ENABLE_HIP=ON
          -DSTRATA_PREFILL_MMQ=ON
          -DSTRATA_ALLOW_EXPERIMENTAL_HIP_ARCHS=ON
          -DCMAKE_HIP_ARCHITECTURES=#{hip_archs}
          -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
          -DHIP_ROOT_DIR=#{rocm_path}
          -DHIP_PATH=#{rocm_path}
          -DCMAKE_INSTALL_RPATH=#{rocm_path}/lib;#{HOMEBREW_PREFIX}/lib
          -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
        ]
        hip_args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler
        hip_args
      end

      args = %W[
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DSTRATA_BUILD_TESTS=OFF
        -DSTRATA_NATIVE_EXPERTS=ON
        -DSTRATA_PORTABLE=#{portable}
        -DSTRATA_BUILD_SPLIT=ON
        -DSTRATA_BUILD_QWEN36=ON
        -DSTRATA_BUILD_DSV41=ON
        -DSTRATA_GGML_DIR=#{llama_dir}
        -DSTRATA_BUILD_ID=#{version}
      ] + backend_args

      system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args,
             "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX}"
      system "cmake", "--build", "build"

      vision_target = (build.without?("cuda") && build.without?("sycl")) ? "strata-vision-hip" : "strata-vision"
      vision_args = %W[
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DLLAMA_DIR=#{llama_dir}
        -DSTRATA_PORTABLE=#{portable}
      ]
      if vision_target == "strata-vision-hip"
        vision_args += %W[
          -DSTRATA_VISION_HIP=ON
          -DSTRATA_VISION_HIP_ARCHS=gfx1151;gfx1100;gfx1201
          -DSTRATA_VISION_HIP_TARGETS=gfx1151;gfx1100;gfx1201
          -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
          -DHIP_ROOT_DIR=#{rocm_path}
        ]
        vision_args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler
      end
      system "cmake", "-S", "tools/vision", "-B", "build/vision", *std_cmake_args, *vision_args,
             "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX}"
      system "cmake", "--build", "build/vision", "--target", "strata-vision"
    end

    # Install runtime layout into libexec so strata.py / serve/server.py resolve ROOT-relative paths
    libexec.install "strata.py", "setup.py", "chat.py", "serve", "tools"
    libexec.install "VERSION" if File.exist?("VERSION")
    (libexec/"third_party/llama.cpp").install llama_dir/"gguf-py"

    if OS.mac?
      (libexec/"build-metal").mkpath
      %w[strata-metal strata-q36-metal strata-dsv41-metal].each do |b|
        if File.exist?("build-metal/#{b}")
          (libexec/"build-metal").install "build-metal/#{b}"
          bin.install_symlink libexec/"build-metal/#{b}" => b.sub("-metal", "")
        end
      end
      strata_vision_mac = ["build-metal/vision/bin/strata-vision", "build-metal/vision/strata-vision"].find do |f|
        File.exist?(f)
      end
      if strata_vision_mac
        (libexec/"build-metal").install strata_vision_mac => "strata-vision"
        bin.install_symlink libexec/"build-metal/strata-vision" => "strata-vision"
      end
    else
      (libexec/"build").mkpath
      %w[
        strata strata-q36 strata-dsv41
        strata-split-2 strata-split-3 strata-split-4
        strata-device strata-plan strata-gguf strata-dequant
        strata-load strata-concurrent strata-overlap
      ].each do |b|
        next unless File.exist?("build/#{b}")

        (libexec/"build").install "build/#{b}"
        bin.install_symlink libexec/"build/#{b}" => b
      end
      strata_vision_linux = [
        "build/vision/bin/strata-vision-hip", "build/vision/strata-vision-hip",
        "build/vision/bin/strata-vision", "build/vision/strata-vision"
      ].find { |f| File.exist?(f) }
      if strata_vision_linux
        target_name = File.basename(strata_vision_linux)
        (libexec/"build").install strata_vision_linux => target_name
        bin.install_symlink libexec/"build/#{target_name}" => target_name
      end
    end

    # Create isolated Python virtualenv in libexec/venv and symlink libexec/.venv
    venv = virtualenv_create(libexec/"venv", "python3.12")
    Dir.glob("third_party/wheels/*.whl").each { |whl| venv.pip_install whl }
    venv.pip_install libexec/"third_party/llama.cpp/gguf-py"
    libexec.install_symlink libexec/"venv" => ".venv"

    env_vars = {
      STRATA_NO_VENV: "1",
      STRATA_GGUF_PY: "#{libexec}/third_party/llama.cpp/gguf-py",
      PATH:           "#{opt_bin}:#{ENV.fetch("PATH")}",
    }

    (bin/"strata").write_env_script libexec/"venv/bin/python", "#{libexec}/strata.py", env_vars
    (bin/"strata-server").write_env_script libexec/"venv/bin/python", "#{libexec}/serve/server.py", env_vars
    (bin/"strata-cli").write_env_script libexec/"venv/bin/python", "#{libexec}/strata.py", env_vars
    (bin/"strata-chat").write_env_script libexec/"venv/bin/python", "#{libexec}/chat.py", env_vars
    (bin/"strata-setup").write_env_script libexec/"venv/bin/python", "#{libexec}/setup.py", env_vars
  end

  def caveats
    <<~EOS
      Strata C++ engines and Python orchestrators are installed:
        - `strata-cli`    : Hardware auto-profiler, model downloader/packer, and launcher (`strata.py`)
        - `strata-server` : OpenAI-compatible HTTP server (`serve/server.py`, default port 8080)
        - `strata`        : Native C++ engine for Qwen3.8-Flash-Next
        - `strata-q36`    : Native C++ engine for Qwen3.6-35B-A3B
        - `strata-dsv41`  : Native C++ engine for DeepSeek-V4.1-Flash (763B MoE)

      Quick start:
        strata-cli --model qwen38 --port 8095
    EOS
  end

  service do
    run [opt_bin/"strata-cli", "--port", "8095"]
    keep_alive true
    working_dir var
    log_path var/"log/strata.log"
    error_log_path var/"log/strata.log"
  end

  test do
    assert_match "STRATA", shell_output("#{bin}/strata-cli --help")
    assert_match "GPU", shell_output("#{bin}/strata-device 2>&1") if File.exist?(bin/"strata-device")
  end
end
