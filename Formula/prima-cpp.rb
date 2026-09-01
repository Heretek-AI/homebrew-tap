class PrimaCpp < Formula
  desc "Distributed LLM inference on heterogeneous and low-resource home clusters"
  homepage "https://github.com/OpenCPIL/prima.cpp"
  url "https://github.com/OpenCPIL/prima.cpp/archive/288df6a2cc2120387e12d6f40798f30cc525c9ea.tar.gz"
  version "2026.09.01"
  sha256 "e4014ed07f0bfada0a583b99f907d6e5abca229b60a594e65a5b27dbebf80589"
  license "MIT"

  option "with-cuda", "Build with CUDA GPU acceleration"
  option "with-vulkan", "Build with Vulkan GPU acceleration"

  depends_on "cmake" => :build
  depends_on "ninja" => :build

  def install
    args = %w[
      -DCMAKE_BUILD_TYPE=Release
      -DLLAMA_BUILD_TESTS=OFF
      -DLLAMA_BUILD_EXAMPLES=ON
    ]

    args << "-DGGML_CUDA=ON" if build.with? "cuda"
    args << "-DGGML_VULKAN=ON" if build.with? "vulkan"

    system "cmake", "-S", ".", "-B", "build", "-G", "Ninja", *args, *std_cmake_args
    system "cmake", "--build", "build"

    # Install binaries
    bin.install Dir["build/bin/*"].select { |f| File.file?(f) && File.executable?(f) }
  end

  def caveats
    <<~EOS
      Prima.cpp enables distributed inference across heterogeneous home clusters.
      To launch a cluster:
        1. Master (Rank 0):
           llama-cli -m model.gguf --world 2 --rank 0 --master <MASTER_IP> --next <WORKER_IP> -ngl 16
        2. Worker (Rank 1):
           llama-cli -m model.gguf --world 2 --rank 1 --master <MASTER_IP> --next <MASTER_IP> -ngl 16
    EOS
  end

  test do
    assert_match "usage", pipe_output("#{bin}/llama-cli --help 2>&1")
  end
end
