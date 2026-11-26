class Basalt < Formula
  desc "NVIDIA CUDA 13 inference engine for Blackwell GPUs"
  homepage "https://github.com/jesdga95/basalt"
  url "https://github.com/jesdga95/basalt/archive/refs/tags/v0.5.7.tar.gz"
  sha256 "6cbb5a96fee548dd6992be39b9bf70d4300d04668694a4954cbea71782df0b31"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on :linux

  on_linux do
    on_intel do
      url "https://github.com/jesdga95/basalt/releases/download/v0.5.7/basalt-v0.5.7-linux-x64.tar.gz"
      sha256 "a390c775c41d54454ca21c1e547855bf6c251732533ca387e8b890e538090525"
    end
  end

  on_arm do
    depends_on "cmake" => :build
    depends_on "ninja" => :build
  end

  def cuda_root
    [ENV["HOMEBREW_CUDA_PATH"], ENV["CUDA_HOME"], ENV["CUDA_PATH"], "/usr/local/cuda"]
      .compact.find { |p| File.executable?("#{p}/bin/nvcc") } ||
      odie("NVIDIA CUDA 13 toolkit not found. Set HOMEBREW_CUDA_PATH or CUDA_HOME to a CUDA 13 install with nvcc.")
  end

  def install
    variant = "cuda-prebuilt"
    cuda = nil
    cmake_args = nil

    if Hardware::CPU.arm?
      variant = "cuda-source"
      cuda = cuda_root
      ENV["CUDA_HOME"] = cuda
      ENV.prepend_path "PATH", "#{cuda}/bin"

      cmake_args = %W[
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DBUILD_TESTING=OFF
        -DBASALT_MODELS=all
        -DCMAKE_CUDA_ARCHITECTURES=121
        -DCMAKE_CUDA_COMPILER=#{cuda}/bin/nvcc
        -DCUDAToolkit_ROOT=#{cuda}
        -DCMAKE_INSTALL_RPATH=#{cuda}/lib64;#{cuda}/targets/aarch64-linux/lib
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
      ]
      system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *cmake_args
      system "cmake", "--build", "build", "--target",
             "basalt", "basalt-bench", "basalt-probe", "basalt-vision"

      (libexec/"bin").install "bin/basalt", "bin/basalt-bench", "bin/basalt-probe", "bin/basalt-vision"
      libexec.install "serve", "tools", "data", "docs", "requirements.txt",
                      "LICENSE", "THIRD_PARTY_LICENSES", "README.md"
    else
      libexec.install Dir["*"]
    end

    %w[basalt basalt-bench basalt-probe basalt-vision].each do |tool|
      (bin/tool).write <<~SH
        #!/usr/bin/env bash
        export PYTHONPATH="#{libexec}${PYTHONPATH:+:$PYTHONPATH}"
        exec "#{libexec}/bin/#{tool}" "$@"
      SH
      chmod 0755, bin/tool
    end

    (etc/"basalt").mkpath
    example = etc/"basalt/basalt_config.example.json"
    example.write <<~JSON
      {
        "version": 2,
        "models": [
          {
            "model": "/path/to/model.basalt",
            "gpu": "0",
            "max-context": 262144,
            "kv": "fp16"
          }
        ],
        "engine": {
          "resident-experts": true
        },
        "server": {
          "host": "127.0.0.1",
          "port": 8080
        }
      }
    JSON
    config = etc/"basalt/basalt_config.json"
    config.write example.read unless config.exist?

    manifest = {
      variant: variant,
      arch:    Hardware::CPU.arch.to_s,
    }
    if cuda
      manifest[:cuda_root] = cuda
      manifest[:cmake_args] = cmake_args
    end
    (pkgshare/"build-manifest.json").write JSON.pretty_generate(manifest)
  end

  def caveats
    <<~EOS
      Basalt needs the NVIDIA CUDA 13 runtime libraries (libcudart.so.13,
      libcublas.so.13 and libcublasLt.so.13) on the library path; this formula
      does not install CUDA.

      Edit #{etc}/basalt/basalt_config.json to point "models" at your .basalt
      pack, then install the Python server's dependencies:
        python3 -m venv #{opt_libexec}/.venv
        #{opt_libexec}/.venv/bin/pip install -r #{opt_libexec}/requirements.txt

      Upstream publishes no linux-arm64 release archive, so on arm64 (DGX Spark
      GB10) Basalt is built from source and needs CUDA 13 with GCC 13 or newer.
    EOS
  end

  service do
    run [opt_bin/"basalt", "serve", "--config", etc/"basalt/basalt_config.json", "--host", "127.0.0.1"]
    keep_alive true
    working_dir var
    log_path var/"log/basalt.log"
    error_log_path var/"log/basalt.error.log"
  end

  test do
    # 1. Dynamic Linker & ABI Audit (CUDA 13 runtime libraries are external)
    ldd_out = shell_output("ldd #{libexec}/bin/basalt 2>&1")
    missing = ldd_out.lines.grep(/not found/).map(&:strip)
    unexpected = missing.grep_v(/\Alib(cudart|cublas|cublasLt)\.so/)
    assert_empty unexpected, "Unexpected missing libraries: #{unexpected.join(", ")}"

    # 2. CLI Introspection (only when the external CUDA 13 runtime is present)
    cuda_runtime = [
      "/usr/local/cuda-13.0/targets/x86_64-linux/lib/libcudart.so.13",
      "/usr/local/cuda-13.0/targets/aarch64-linux/lib/libcudart.so.13",
      "/usr/local/cuda/targets/x86_64-linux/lib/libcudart.so.13",
      "/usr/local/cuda/targets/aarch64-linux/lib/libcudart.so.13",
    ].any? { |path| File.exist?(path) } || Utils.popen_read("ldconfig", "-p").include?("libcudart.so.13")

    if cuda_runtime
      assert_match(/usage|basalt serve/i, pipe_output("#{bin}/basalt --help 2>&1"))
      assert_match(/usage: basalt-bench/i, pipe_output("#{bin}/basalt-bench --help 2>&1"))
      assert_match(/usage: basalt-probe/i, pipe_output("#{bin}/basalt-probe --help 2>&1"))
      assert_match(/usage: basalt-vision/i, pipe_output("#{bin}/basalt-vision --help 2>&1"))
    else
      opoo "CUDA 13 runtime not found; skipping the CLI execution checks."
    end
  end
end
