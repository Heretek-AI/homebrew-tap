class CudaRuntime < Formula
  desc "Shared NVIDIA CUDA runtime libraries for GPU inference engines"
  homepage "https://developer.nvidia.com/cuda-toolkit"
  url "https://developer.download.nvidia.com/compute/cuda/redist/cuda_cudart/linux-x86_64/cuda_cudart-linux-x86_64-13.5.37-archive.tar.xz"
  sha256 "26ca1b8963ce1b73e0e77113c711730545cacaaee7233c0526477d96d4c621fe"
  license :cannot_represent

  livecheck do
    url "https://developer.download.nvidia.com/compute/cuda/redist/cuda_cudart/linux-x86_64/"
    regex(/cuda_cudart-linux-(?:x86_64|sbsa)-(\d+(?:\.\d+)+)-archive(?:\.tar\.xz)/i)
    strategy :page_match
  end

  keg_only "it is a shared runtime that engines link against via opt_prefix"

  depends_on :linux

  on_linux do
    on_arm do
      url "https://developer.download.nvidia.com/compute/cuda/redist/cuda_cudart/linux-sbsa/cuda_cudart-linux-sbsa-13.5.37-archive.tar.xz"
      sha256 "9da80d6aa87f5bc46971c1343024f30a850aca9aac03da95219880aaf854154f"
    end
  end

  resource "cublas" do
    on_arm do
      url "https://developer.download.nvidia.com/compute/cuda/redist/libcublas/linux-sbsa/libcublas-linux-sbsa-13.10.0.20-archive.tar.xz"
      sha256 "b3bd7cff0eeb8b114164534a5c92c1496917dac65653c4e51d29b63d55cd42d6"
    end

    on_intel do
      url "https://developer.download.nvidia.com/compute/cuda/redist/libcublas/linux-x86_64/libcublas-linux-x86_64-13.10.0.20-archive.tar.xz"
      sha256 "6da2dd456733bc45235e344a6e6aab3e8f43fb775a835c5dc432f4a1fc9f93d2"
    end
  end

  def install
    # Runtime-only package: do not install CUDA headers. The cudart archive's
    # cuda_runtime.h includes crt/host_config.h, which is only present in the
    # full toolkit; exposing it here shadows the toolkit headers during builds.
    lib.install Dir["lib/libcudart.so*"]
    (prefix/"LICENSE").install "LICENSE" if (buildpath/"LICENSE").exist?

    resource("cublas").stage do
      lib.install Dir["lib/libcublas.so*"]
      lib.install Dir["lib/libcublasLt.so*"]
      (prefix/"LICENSE.cublas").install "LICENSE" if File.exist?("LICENSE")
    end
  end

  def caveats
    <<~EOS
      cuda-runtime is keg-only: it provides shared CUDA runtime libraries
      without linking them into the Homebrew prefix.

      Point builds at it with:
        export CUDA_HOME="#{opt_prefix}"
        export CUDAToolkit_ROOT="#{opt_prefix}"
        export LD_LIBRARY_PATH="#{opt_prefix}/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

      NVCC and the rest of the CUDA toolkit are NOT included. Building CUDA
      code from source still requires the full NVIDIA CUDA toolkit, including
      its headers; none are installed by this runtime-only formula.
    EOS
  end

  test do
    assert_path_exists lib/"libcudart.so"
    assert_path_exists lib/"libcublas.so"
    assert_path_exists lib/"libcublasLt.so"
  end
end
