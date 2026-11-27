class Rocmfpx < Formula
  desc "High-Performance AMD ROCm llama.cpp Inference Stack (Upstream)"
  homepage "https://github.com/charlie12345/ROCmFPX"
  url "https://github.com/charlie12345/ROCmFPX/archive/fb08d7cdb67082ddda15a25e64dc7ec413afc41c.tar.gz"
  version "2026.09.23"
  sha256 "ddcda52aa6dafa2cf99109b428b6c3f3e37b23786b34cf78e47634b0d38cfa58"
  license "MIT"
  head "https://github.com/charlie12345/ROCmFPX.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on arch: :x86_64
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on :linux

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |path| File.exist?("#{path}/include/hip/hip_runtime.h") } ||
      odie("ROCm SDK not found. Set HOMEBREW_ROCM_PATH to a full ROCm SDK with HIP headers (ROCm 7+ / 10.1+).")
  end

  def install
    rocm_path = rocm_root
    runtime_lib = formula_opt_lib("rocm-runtime")
    gpu_targets = "gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201"
    compiler = [
      "#{rocm_path}/lib/llvm/bin/clang++",
      "#{rocm_path}/llvm/bin/clang++",
      "#{rocm_path}/bin/amdclang++",
      "#{rocm_path}/bin/clang++",
    ].find { |path| File.executable?(path) } ||
               odie("HIP compiler not found under #{rocm_path}. Set HOMEBREW_ROCM_PATH to a full ROCm SDK.")

    ENV["ROCM_PATH"] = rocm_path
    ENV["HIP_PATH"] = rocm_path
    ENV.prepend_path "PATH", "#{rocm_path}/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/lib/llvm/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/llvm/bin"
    # Build the literal "$ORIGIN" without Ruby interpolating a global variable.
    origin = 36.chr + "ORIGIN"

    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DGGML_HIP=ON
      -DGPU_TARGETS=#{gpu_targets}
      -DCMAKE_HIP_ARCHITECTURES=#{gpu_targets}
      -DCMAKE_HIP_COMPILER=#{compiler}
      -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
      -DHIP_ROOT_DIR=#{rocm_path}
      -DHIP_PATH=#{rocm_path}
      -DLLAMA_BUILD_TESTS=OFF
      -DLLAMA_BUILD_EXAMPLES=OFF
      -DLLAMA_BUILD_TOOLS=ON
      -DLLAMA_BUILD_SERVER=ON
      -DLLAMA_BUILD_WEBUI=OFF
      -DLLAMA_USE_PREBUILT_WEBUI=OFF
      -DLLAMA_CURL=OFF
      -DGGML_NATIVE=OFF
      -DGGML_CCACHE=OFF
      -DCMAKE_INSTALL_RPATH=#{runtime_lib};#{HOMEBREW_PREFIX}/lib;#{origin}
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args,
           "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX}"
    system "cmake", "--build", "build", "--parallel", ENV.make_jobs.to_s

    # The llama.cpp tools link shared ggml/llama libraries from build/bin. Keep
    # them next to the executables so the portable $ORIGIN RPATH resolves them.
    (libexec/"bin").install Dir["build/bin/llama-*"], Dir["build/bin/lib*.so*"]

    base = libexec/"bin"
    {
      "rocmfpx"            => "llama-server",
      "rocmfpx-server"     => "llama-server",
      "rocmfpx-cli"        => "llama-cli",
      "rocmfpx-quantize"   => "llama-quantize",
      "rocmfpx-bench"      => "llama-bench",
      "rocmfpx-perplexity" => "llama-perplexity",
      "rocmfpx-mtmd-cli"   => "llama-mtmd-cli",
    }.each do |name, target|
      bin.install_symlink base/target => name if (base/target).exist?
    end

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:     "rocm",
      commit:      "fb08d7cdb67082ddda15a25e64dc7ec413afc41c",
      gpu_targets: gpu_targets,
      runtime_lib: runtime_lib.to_s,
      rocm_root:   rocm_path,
      cmake_args:  args,
    )
  end

  def caveats
    <<~EOS
      rocmfpx is a fat binary compiled for:
        gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201

      It links the shared runtime from heretek-ai/tap/rocm-runtime instead of
      bundling ROCm libraries. For manual runs set:
        export ROCM_PATH="#{formula_opt_prefix("rocm-runtime")}"
        export ROCM_KPACK_PATH="#{formula_opt_prefix("rocm-runtime")}/.kpack"
      The brew service sets both automatically.

      Building from source still needs a full ROCm SDK (HIP headers and a HIP
      compiler). Point HOMEBREW_ROCM_PATH at that SDK; the installed binary only
      needs the shared runtime.

      Model files are not included. Pass a GGUF model explicitly, for example:
        rocmfpx --model /path/to/model.gguf --host 127.0.0.1 --port 18007
    EOS
  end

  service do
    run [opt_bin/"rocmfpx", "--host", "127.0.0.1", "--port", "18007"]
    environment_variables ROCM_PATH:       formula_opt_prefix("rocm-runtime"),
                          ROCM_KPACK_PATH: "#{formula_opt_prefix("rocm-runtime")}/.kpack"
    keep_alive true
    log_path var/"log/rocmfpx.log"
    error_log_path var/"log/rocmfpx.error.log"
  end

  test do
    output = pipe_output("#{bin}/rocmfpx --version 2>&1")
    output = pipe_output("#{bin}/rocmfpx --help 2>&1") unless output.match?(/version|usage|llama/i)
    assert_match(/version|usage|llama/i, output)
  end
end
