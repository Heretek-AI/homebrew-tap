class Lucebox < Formula
  desc "LLM speculative inference server for heterogeneous hardware & consumer GPUs"
  homepage "https://github.com/Luce-Org/lucebox"
  url "https://github.com/Luce-Org/lucebox/archive/34b20876f97001ba4d9f936dbc68b6d406192688.tar.gz"
  version "0.1.0-git34b2087"
  sha256 "92995410562a3517507d0f8ad7bd7cb8ea08346e60eb7a582de412e4de02f280"
  license "Apache-2.0"
  head "https://github.com/Luce-Org/lucebox.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-rocm", "Build with AMD ROCm/HIP backend instead of NVIDIA CUDA"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "curl"
  depends_on "heretek-ai/tap/cuda-runtime"
  depends_on :linux
  depends_on "nlohmann-json"

  def install
    backend = build.with?("rocm") ? "hip" : "cuda"

    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DLUCE_SERVER=ON
      -DLUCE_TESTS=OFF
      -DLUCE_GPU_BACKEND=#{backend}
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    rpath = "#{libexec}/lib;#{formula_opt_lib("cuda-runtime")};#{HOMEBREW_PREFIX}/lib"

    if build.with?("rocm")
      rocm = [
        ENV["HOMEBREW_ROCM_PATH"],
        ENV["ROCM_PATH"],
        "/opt/rocm-nightly",
        "/opt/rocm",
      ].compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
             odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK.")
      ENV["ROCM_PATH"] = rocm
      ENV["HIP_PATH"] = rocm
      ENV.prepend_path "PATH", "#{rocm}/bin"
      ENV.prepend_path "PATH", "#{rocm}/llvm/bin"
      args << "-DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm}"
      args << "-DHIP_ROOT_DIR=#{rocm}"
      args << "-DHIP_PATH=#{rocm}"
      args << "-DLUCE_HIP_ARCHITECTURES=gfx1150;gfx1151"
      rpath = "#{libexec}/lib;#{rocm}/lib;#{HOMEBREW_PREFIX}/lib"
    else
      cuda_root = [
        ENV["HOMEBREW_CUDA_PATH"],
        ENV["CUDA_HOME"],
        ENV["CUDA_PATH"],
        "/usr/local/cuda",
      ].compact.find { |d| File.executable?("#{d}/bin/nvcc") }
      if cuda_root
        ENV["CUDA_HOME"] = cuda_root
        ENV["CUDACXX"] = "#{cuda_root}/bin/nvcc"
        ENV.prepend_path "PATH", "#{cuda_root}/bin"
        # Superenv strips -L/usr/local/* flags; expose CUDA's lib dirs via
        # HOMEBREW_LIBRARY_PATHS so -lcudadevrt and -lcudart_static resolve at link.
        ENV.append_path "HOMEBREW_LIBRARY_PATHS", "#{cuda_root}/lib64"
        cuda_target_lib = "#{cuda_root}/targets/x86_64-linux/lib"
        ENV.append_path "HOMEBREW_LIBRARY_PATHS", cuda_target_lib if File.directory?(cuda_target_lib)
        args << "-DCUDAToolkit_ROOT=#{cuda_root}"
        args << "-DCMAKE_CUDA_COMPILER=#{cuda_root}/bin/nvcc"
        # nvcc cannot use Homebrew's superenv shim for its host-compiler
        # probe; point it at the real system compiler so the CUDA toolkit
        # headers are found without cuda-runtime supplying a partial copy.
        host_cxx = ["/usr/bin/g++-13", "/usr/bin/g++"].find { |path| File.executable?(path) }
        args << "-DCMAKE_CUDA_HOST_COMPILER=#{host_cxx}" if host_cxx
      end
      args << "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90;120"
      args << "-DCMAKE_CUDA_FLAGS=--threads=0"

      # CUDA 13.5's CUB no longer transitively includes <cuda/iterator>, which
      # argsort.cu (cuda::make_strided_iterator) and top-k.cu (cuda::discard_iterator) need.
      argsort_cu = "server/deps/llama.cpp/ggml/src/ggml-cuda/argsort.cu"
      if File.exist?(argsort_cu) &&
         File.read(argsort_cu).include?("#        define STRIDED_ITERATOR_AVAILABLE")
        inreplace argsort_cu,
                  "#        define STRIDED_ITERATOR_AVAILABLE",
                  "#        include <cuda/iterator>\n#        define STRIDED_ITERATOR_AVAILABLE"
      end
      topk_cu = "server/deps/llama.cpp/ggml/src/ggml-cuda/top-k.cu"
      if File.exist?(topk_cu) &&
         File.read(topk_cu).include?("#        define CUB_TOP_K_AVAILABLE") &&
         File.read(topk_cu).exclude?("<cuda/iterator>")
        inreplace topk_cu,
                  "#        define CUB_TOP_K_AVAILABLE",
                  "#        define CUB_TOP_K_AVAILABLE\n#        include <cuda/iterator>"
      end
    end
    rpath_colon = rpath.tr(";", ":")
    args << "-DCMAKE_INSTALL_RPATH=#{rpath}"
    args << "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-rpath,#{rpath_colon}"
    args << "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-rpath,#{rpath_colon}"
    if (sccache = ENV["HOMEBREW_SCCACHE_PATH"]) && File.executable?(sccache)
      ENV["SCCACHE_DIR"] = ENV["HOMEBREW_SCCACHE_DIR"] if ENV["HOMEBREW_SCCACHE_DIR"]
      %w[C CXX CUDA HIP].each { |lang| args << "-DCMAKE_#{lang}_COMPILER_LAUNCHER=#{sccache}" }
    end

    system "cmake", "-S", "server", "-B", "build", *std_cmake_args, *args
    system "cmake", "--build", "build", "--target", "luce_server"

    ggml_libs = Dir.glob("build/deps/llama.cpp/ggml/src/**/*.so*")
    (libexec/"lib").install ggml_libs unless ggml_libs.empty?

    bin.install "build/luce_server" => "lucebox-server"
    bin.install_symlink bin/"lucebox-server" => "lucebox"

    if File.exist?("build/share/status.html")
      pkgshare.install "build/share/status.html"
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:    backend,
      cmake_args: args,
      rpath:      rpath,
      commit:     "34b20876f97001ba4d9f936dbc68b6d406192688",
    )
  end

  def caveats
    <<~EOS
      Lucebox server starts with:
        lucebox-server --help

      The default CUDA build links the shared runtime from
      heretek-ai/tap/cuda-runtime. A --with-rocm source build keeps the ROCm SDK
      lib directory in its RUNPATH instead and deliberately does not depend on
      heretek-ai/tap/rocm-runtime, so CUDA users do not download the ~12 GB ROCm
      runtime.
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit (libcuda.so.1 comes from the host NVIDIA driver)
    out = shell_output("ldd #{bin}/lucebox-server")
    missing = out.lines.grep(/not found/).reject { |line| line.include?("libcuda.so.1") }
    assert_empty missing, "Unexpected missing shared libraries:\n#{missing.join}"

    # 2. CLI Introspection (only when a real NVIDIA driver is loaded: hosted CI
    # has none, and the libcuda.so.1 stub used for linkage checks cannot execute)
    if File.exist?("/proc/driver/nvidia/version")
      assert_match(/luce|usage|server/i, shell_output("#{bin}/lucebox-server --help 2>&1"))
    end
  end
end
