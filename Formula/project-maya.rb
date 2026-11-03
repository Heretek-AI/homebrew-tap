class ProjectMaya < Formula
  include Language::Python::Virtualenv

  desc "Tiered MoE engine for GLM-5.3-Flash, Qwen-3.8, DeepSeek-V4.1 & MiniMax"
  homepage "https://github.com/mw00/project-maya"
  url "https://github.com/mw00/project-maya/archive/3c935e411cd6625a9af0f292dd0af52598e866d8.tar.gz"
  version "1.1.52"
  sha256 "739cbbf961339961314f6902962b2ffd65ac9179b3150712ddf123c3aee4b733"
  license :cannot_represent
  head "https://github.com/mw00/project-maya.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-wave64", "Compile HIP kernels for AMD Wave64 CDNA/Vega GPUs (gfx906;gfx908;gfx942;gfx950)"
  option "with-cuda", "Build with NVIDIA CUDA backend instead of AMD ROCm/HIP"
  option "with-native", "Enable -march=native in ggml-cpu (default uses portable AVX2 + runtime AVX-512 dispatch)"

  depends_on "cmake" => :build
  depends_on "git" => :build
  depends_on "ninja" => :build
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "python@3.12"

  resource "llama.cpp" do
    url "https://github.com/ggml-org/llama.cpp/archive/3cf03257f219afbe7334045ff7c6a06ac68c627d.tar.gz"
    sha256 "c076d7534afa0e5d0ec2a0d425b11e791c16f3de0d727221aea071cef156a280"
  end

  def install
    llama_dir = buildpath/"third_party/llama.cpp"
    resource("llama.cpp").stage llama_dir

    portable = build.with?("native") ? "OFF" : "ON"

    if OS.mac?
      system "cmake", "-S", ".", "-B", "build-metal", "-G", "Ninja",
             "-DCMAKE_BUILD_TYPE=Release",
             "-DMAYA_ENABLE_METAL=ON",
             "-DMAYA_METAL_TESTS=OFF",
             "-DMAYA_GGML_DIR=#{llama_dir}",
             "-DMAYA_BUILD_ID=#{version}",
             *std_cmake_args
      system "cmake", "--build", "build-metal", "--target", "maya-metal"

      system "cmake", "-S", "tools/vision", "-B", "build-metal/vision", "-G", "Ninja",
             "-DCMAKE_BUILD_TYPE=Release",
             "-DLLAMA_DIR=#{llama_dir}",
             *std_cmake_args
      system "cmake", "--build", "build-metal/vision", "--target", "maya-vision"
    else
      rocm_path = ENV.fetch("ROCM_PATH", "/opt/rocm")
      hip_archs = if build.with?("wave64")
        "gfx906;gfx908;gfx942;gfx950"
      else
        "gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201"
      end

      backend_args = if build.with?("cuda")
        %w[-DSTRATA_ENABLE_CUDA=ON -DSTRATA_PREFILL_MMQ=ON -DCMAKE_CUDA_ARCHITECTURES=70;75;80;86;89;90;100;120]
      else
        odie "ROCm installation not found at #{rocm_path}." unless Dir.exist?(rocm_path)
        ENV["ROCM_PATH"] = rocm_path
        ENV["HIP_PATH"] = rocm_path
        ENV.prepend_path "PATH", "#{rocm_path}/bin"
        ENV.prepend_path "PATH", "#{rocm_path}/lib/llvm/bin"
        ENV.prepend_path "PATH", "#{rocm_path}/llvm/bin"

        hip_compiler = [
          "#{rocm_path}/bin/hipcc",
          "#{rocm_path}/lib/llvm/bin/clang++",
          "#{rocm_path}/llvm/bin/clang++",
          "#{rocm_path}/bin/clang++",
        ].find { |c| File.executable?(c) }

        hip_args = %W[
          -DSTRATA_ENABLE_HIP=ON
          -DSTRATA_PREFILL_MMQ=ON
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
        -DSTRATA_NATIVE_EXPERTS=ON
        -DSTRATA_PORTABLE=#{portable}
        -DSTRATA_GGML_DIR=#{llama_dir}
        -DMAYA_BUILD_ID=#{version}
      ] + backend_args

      system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args,
             "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX}"
      system "cmake", "--build", "build"

      vision_args = %W[
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DLLAMA_DIR=#{llama_dir}
        -DSTRATA_PORTABLE=#{portable}
      ]
      unless build.with?("cuda")
        vision_args += %W[
          -DSTRATA_VISION_HIP=ON
          -DSTRATA_VISION_HIP_TARGETS=#{hip_archs}
          -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
          -DHIP_ROOT_DIR=#{rocm_path}
        ]
        vision_args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler
      end
      system "cmake", "-S", "tools/vision", "-B", "build/vision", *std_cmake_args, *vision_args,
             "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX}"
      system "cmake", "--build", "build/vision", "--target", "maya-vision"
    end

    libexec.install "maya.py", "setup.py", "chat.py", "serve", "tools"
    libexec.install "VERSION" if File.exist?("VERSION")
    (libexec/"third_party/llama.cpp").install llama_dir/"gguf-py"

    if OS.mac?
      (libexec/"build-metal").install "build-metal/maya-metal"
      bin.install_symlink libexec/"build-metal/maya-metal" => "maya"
      bin.install_symlink libexec/"build-metal/maya-metal" => "maya-metal"
      if File.exist?("build-metal/vision/maya-vision")
        (libexec/"build-metal").install "build-metal/vision/maya-vision"
        bin.install_symlink libexec/"build-metal/maya-vision" => "maya-vision"
      end
    else
      (libexec/"build").mkpath
      %w[maya maya-ds4 maya-mm3].each do |b|
        if File.exist?("build/#{b}")
          (libexec/"build").install "build/#{b}"
          bin.install_symlink libexec/"build/#{b}" => b
        end
      end
      %w[
        tune_hipblaslt peer_probe
        strata-plan strata-device strata-gguf strata-dequant
        strata-load strata-concurrent strata-overlap
      ].each do |tool|
        next unless File.exist?("build/#{tool}")

        (libexec/"build").install "build/#{tool}"
        alias_name = tool.start_with?("strata-") ? tool.sub("strata-", "maya-") : "maya-#{tool.tr("_", "-")}"
        bin.install_symlink libexec/"build/#{tool}" => alias_name
      end
      if File.exist?("build/vision/maya-vision")
        (libexec/"build").install "build/vision/maya-vision"
        bin.install_symlink libexec/"build/maya-vision" => "maya-vision"
      end
    end

    venv = virtualenv_create(libexec/"venv", "python3.12")
    Dir.glob("third_party/wheels/*.whl").each { |whl| venv.pip_install whl }
    venv.pip_install libexec/"third_party/llama.cpp/gguf-py"
    libexec.install_symlink libexec/"venv" => ".venv"

    env_vars = {
      MAYA_NO_VENV: "1",
      MAYA_GGUF_PY: "#{libexec}/third_party/llama.cpp/gguf-py",
      PATH:         "#{opt_bin}:#{ENV.fetch("PATH")}",
    }

    (bin/"maya-server").write_env_script libexec/"venv/bin/python", "#{libexec}/serve/server.py", env_vars
    (bin/"maya-cli").write_env_script libexec/"venv/bin/python", "#{libexec}/maya.py", env_vars
    (bin/"maya-chat").write_env_script libexec/"venv/bin/python", "#{libexec}/chat.py", env_vars
    (bin/"maya-setup").write_env_script libexec/"venv/bin/python", "#{libexec}/setup.py", env_vars
  end

  def caveats
    <<~EOS
      Project Maya C++ engines and Python orchestrators are installed:
        - `maya-cli`    : Hardware auto-profiler, downloader/packer, and launcher (`maya.py`)
        - `maya-server` : OpenAI-compatible HTTP server (`serve/server.py`, default port 8080)
        - `maya`        : C++ engine for GLM-5.3-Flash & Qwen-3.8-Flash-Next
        - `maya-ds4`    : C++ engine for DeepSeek-V4.1-Flash (763B MoE)
        - `maya-mm3`    : C++ engine for MiniMax-M3.1-Flash (200B MoE)
        - `maya-vision` : Multimodal vision encoder

      Quick start:
        maya-cli --model glm51 --port 8095
    EOS
  end

  service do
    run [opt_bin/"maya-cli", "--port", "8095"]
    keep_alive true
    working_dir var
    log_path var/"log/project-maya.log"
    error_log_path var/"log/project-maya.log"
  end

  test do
    assert_match "MAYA", shell_output("#{bin}/maya-cli --help")
    assert_match "GPU", shell_output("#{bin}/maya-device 2>&1") if File.exist?(bin/"maya-device")
  end
end
