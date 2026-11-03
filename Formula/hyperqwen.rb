class Hyperqwen < Formula
  desc "NVIDIA CUDA 13.0 patched vLLM 0.32.0 appliance for Qwen3.8-27B-AWQ"
  homepage "https://github.com/syv-ai/HyperQwen"
  url "https://github.com/syv-ai/HyperQwen/archive/6ab9bd05cb84b538a6595d634f3e337ac8a80856.tar.gz"
  version "0.1.0"
  sha256 "679dcdcf4a95781eb827291469f7c5fa072f5a1bef880daf7e9b95595706ff1a"
  license :cannot_represent
  head "https://github.com/syv-ai/HyperQwen.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on "cmake" => :build
  depends_on "git" => :build
  depends_on "ninja" => :build
  depends_on "python@3.12"
  depends_on :linux

  resource "cutlass" do
    url "https://github.com/NVIDIA/cutlass/archive/refs/tags/v4.2.1.tar.gz"
    sha256 "a4513ba33ae82fd754843c6d8437bee1ac71a6ef1c74df886de2338e3917d4df"
  end

  resource "xgrammar" do
    url "https://github.com/mlc-ai/xgrammar.git",
        revision: "d78c1ae84c2bd3faadbe2fbca3eeb4bfebba3e92"
  end

  def install
    cuda_home = ENV.fetch("CUDA_HOME", "/usr/local/cuda")
    nvcc = "#{cuda_home}/bin/nvcc"
    odie <<~EOS unless File.executable?(nvcc)
      HyperQwen requires NVIDIA CUDA Toolkit 13.0+ (nvcc not found at #{nvcc}).
      Note: HyperQwen uses inline NVIDIA PTX (sm_80/86/89/120) and does NOT support AMD ROCm/HIP.
    EOS

    ENV["CUDA_HOME"] = cuda_home
    ENV.prepend_path "PATH", "#{cuda_home}/bin"
    ENV["TORCH_CUDA_ARCH_LIST"] = "8.0;8.6;8.9;12.0"
    ENV["MAX_JOBS"] = ENV.make_jobs.to_s

    # 1. Stage CUTLASS v4.2.1 so fa2/CMakeLists.txt does not run FetchContent
    cutlass_dir = buildpath/"fa2/csrc/cutlass"
    resource("cutlass").stage cutlass_dir
    ENV["CUTLASS_DIR"] = cutlass_dir.to_s
    inreplace "fa2/setup.py",
              'cmake_args = [',
              "cmake_args = [\"-DCUTLASS_DIR=#{cutlass_dir}\","

    # 2. Stage xgrammar offline and patch patches/apply.py to use local checkout
    xgrammar_dir = buildpath/"xgrammar_src"
    resource("xgrammar").stage xgrammar_dir
    inreplace "patches/apply.py", "/tmp/xgrammar_build", xgrammar_dir.to_s

    # 3. Build liblsa.so for sm_80, sm_86, sm_89, sm_120 (instead of hardcoded sm_86)
    (libexec/"lib").mkpath
    system nvcc, "-O3",
           "-gencode=arch=compute_80,code=sm_80",
           "-gencode=arch=compute_86,code=sm_86",
           "-gencode=arch=compute_89,code=sm_89",
           "-gencode=arch=compute_120,code=sm_120",
           "--shared", "-Xcompiler", "-fPIC",
           "lsa/lsa.cu", "-o", libexec/"lib/liblsa.so", "-lcuda"

    # 4. Create isolated Python 3.12 virtualenv and install vLLM + custom extensions + 61 patches
    python3 = Formula["python@3.12"].opt_bin/"python3.12"
    system python3, "-m", "venv", libexec/"venv"
    pip = libexec/"venv/bin/pip"
    system pip, "install", "--upgrade", "pip", "setuptools", "wheel", "ninja", "cmake", "pybind11"
    system pip, "install", "vllm==0.32.0", "kvarn", "openai", "aiohttp"
    system pip, "install", "--no-build-isolation", "./pthfa"
    system pip, "install", "--no-build-isolation", "./fa2"

    site_packages = Utils.safe_popen_read(libexec/"venv/bin/python", "-c",
      "import site; print(site.getsitepackages()[0])").strip
    system libexec/"venv/bin/python", "patches/apply.py", site_packages

    libexec.install "bench.py", "patches", "entrypoint.sh"

    (bin/"hyperqwen-serve").write <<~EOS
      #!/usr/bin/env bash
      export VLLM_ATTENTION_BACKEND="${VLLM_ATTENTION_BACKEND:-FLASH_ATTN}"
      export LD_PRELOAD="#{libexec}/lib/liblsa.so${LD_PRELOAD:+:$LD_PRELOAD}"
      MODEL="${HYPERQWEN_MODEL:-QuantTrio/Qwen3.8-27B-AWQ}"
      PORT="${HYPERQWEN_PORT:-18020}"
      exec "#{libexec}/venv/bin/vllm" serve "${MODEL}" \\
        --host 127.0.0.1 \\
        --port "${PORT}" \\
        --trust-remote-code \\
        --quantization awq_marlin \\
        --kv-cache-dtype "${HYPERQWEN_KV_CACHE_DTYPE:-fp8_e4m3}" \\
        --gpu-memory-utilization "${HYPERQWEN_GPU_MEMORY_UTILIZATION:-0.90}" \\
        --max-model-len "${HYPERQWEN_MAX_MODEL_LEN:-32768}" \\
        --max-num-seqs "${HYPERQWEN_MAX_NUM_SEQS:-128}" \\
        --speculative-config '{"method":"qwen3_next_mtp","num_speculative_tokens":3}' \\
        --reasoning-parser qwen3 \\
        --enable-auto-tool-choice \\
        --tool-call-parser qwen3_coder \\
        --enable-prefix-caching \\
        "$@"
    EOS
    chmod 0755, bin/"hyperqwen-serve"

    (bin/"hyperqwen-bench").write <<~EOS
      #!/usr/bin/env bash
      exec "#{libexec}/venv/bin/python" "#{libexec}/bench.py" "$@"
    EOS
    chmod 0755, bin/"hyperqwen-bench"
  end

  def caveats
    <<~EOS
      HyperQwen is an NVIDIA CUDA 13.0 (sm_80/86/89/120) appliance for Qwen3.8-27B-AWQ.
      Start the server on port 18020:
        hyperqwen-serve
      Run throughput benchmarks:
        hyperqwen-bench --url http://localhost:18020 -c 1 4 8 16
    EOS
  end

  service do
    run [opt_bin/"hyperqwen-serve"]
    keep_alive true
    working_dir var
    log_path var/"log/hyperqwen.log"
    error_log_path var/"log/hyperqwen.log"
  end

  test do
    assert_match "Benchmark OpenAI-compatible", shell_output("#{bin}/hyperqwen-bench --help")
  end
end
