class Lucebox < Formula
  desc "LLM speculative inference server for heterogeneous hardware & consumer GPUs"
  homepage "https://github.com/Luce-Org/lucebox"
  url "https://github.com/Luce-Org/lucebox/archive/34b20876f97001ba4d9f936dbc68b6d406192688.tar.gz"
  version "0.1.0-git34b2087"
  sha256 "bdadfc3ef293ea2eb0480b0f71887e4125f4fe6d30960d7c768df8eb0dc5a435"
  license "Apache-2.0"
  head "https://github.com/Luce-Org/lucebox.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-rocm", "Build with AMD ROCm/HIP backend instead of NVIDIA CUDA"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "curl"
  depends_on :linux

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK.")
  end

  def install
    backend = build.with?("rocm") ? "hip" : "cuda"

    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DLUCE_SERVER=ON
      -DLUCE_TESTS=OFF
      -DLUCE_GPU_BACKEND=#{backend}
      -DCMAKE_INSTALL_RPATH=#{HOMEBREW_PREFIX}/lib
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]

    if build.with?("rocm")
      rocm = rocm_root
      ENV["ROCM_PATH"] = rocm
      ENV["HIP_PATH"] = rocm
      ENV.prepend_path "PATH", "#{rocm}/bin"
      ENV.prepend_path "PATH", "#{rocm}/llvm/bin"
      args << "-DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm}"
      args << "-DHIP_ROOT_DIR=#{rocm}"
      args << "-DHIP_PATH=#{rocm}"
      args << "-DLUCE_HIP_ARCHITECTURES=gfx1150;gfx1151"
    else
      cuda_root = [ENV["HOMEBREW_CUDA_PATH"], ENV["CUDA_PATH"], "/usr/local/cuda"].compact.find { |d| Dir.exist?(d) }
      if cuda_root
        ENV.prepend_path "PATH", "#{cuda_root}/bin"
        args << "-DCUDAToolkit_ROOT=#{cuda_root}"
      end
      args << "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90;120"
    end

    system "cmake", "-S", "server", "-B", "build", *std_cmake_args, *args
    system "cmake", "--build", "build", "--target", "luce_server"

    bin.install "build/luce_server" => "lucebox-server"
    bin.install_symlink bin/"lucebox-server" => "lucebox"

    if File.exist?("build/share/status.html")
      pkgshare.install "build/share/status.html"
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:    backend,
      cmake_args: args,
      commit:     "34b20876f97001ba4d9f936dbc68b6d406192688",
    )
  end

  def caveats
    <<~EOS
      Lucebox server starts with:
        lucebox-server --help
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("ldd #{bin}/lucebox-server")
    refute_match(/not found/, out)

    # 2. CLI Introspection
    assert_match(/luce|usage|server/i, shell_output("#{bin}/lucebox-server --help 2>&1"))
  end
end
