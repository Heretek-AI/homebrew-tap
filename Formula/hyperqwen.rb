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
  depends_on :linux
  depends_on "python@3.12"

  resource "cutlass" do
    url "https://github.com/NVIDIA/cutlass/archive/refs/tags/v4.2.1.tar.gz"
    sha256 "a4513ba33ae82fd754843c6d8437bee1ac71a6ef1c74df886de2338e3917d4df"
  end

  resource "xgrammar" do
    url "https://github.com/cpuchip/xgrammar/archive/fa893f0cc2d117e51218e55ea5b0d88579741bf7.tar.gz"
    sha256 "74ac3dc455c3d2abb547dfc8bb66b5b41e701b52a00e1eac55f14f5577217f9f"
  end

  def install
    cuda_home = [ENV["HOMEBREW_CUDA_PATH"], ENV["CUDA_HOME"], ENV["CUDA_PATH"], "/usr/local/cuda"].compact.find do |d|
      Dir.exist?(d)
    end || "/usr/local/cuda"
    nvcc = "#{cuda_home}/bin/nvcc"
    have_nvcc = File.executable?(nvcc)

    if have_nvcc
      ENV["CUDA_HOME"] = cuda_home
      ENV.prepend_path "PATH", "#{cuda_home}/bin"
      ENV["TORCH_CUDA_ARCH_LIST"] = "8.0;8.6;8.9;12.0"
      ENV["MAX_JOBS"] = ENV.make_jobs.to_s
    else
      opoo "NVIDIA CUDA nvcc not found at #{nvcc}. liblsa.so will not be compiled at installation time."
    end

    # 1. Stage CUTLASS v4.2.1 so fa2/CMakeLists.txt does not run FetchContent
    cutlass_dir = buildpath/"fa2/csrc/cutlass"
    resource("cutlass").stage cutlass_dir
    ENV["CUTLASS_DIR"] = cutlass_dir.to_s
    if File.exist?("fa2/setup.py")
      inreplace "fa2/setup.py",
                "cmake_args = [",
                "cmake_args = [\"-DCUTLASS_DIR=#{cutlass_dir}\","
    end

    # 2. Stage xgrammar offline
    xgrammar_dir = libexec/"xgrammar_src"
    resource("xgrammar").stage xgrammar_dir

    # 3. Build liblsa.so for sm_80, sm_86, sm_89, sm_120 if nvcc is present
    if have_nvcc && File.exist?("lsa/lsa.cu")
      (libexec/"lib").mkpath
      system nvcc, "-O3",
             "-gencode=arch=compute_80,code=sm_80",
             "-gencode=arch=compute_86,code=sm_86",
             "-gencode=arch=compute_89,code=sm_89",
             "-gencode=arch=compute_120,code=sm_120",
             "--shared", "-Xcompiler", "-fPIC",
             "lsa/lsa.cu", "-o", libexec/"lib/liblsa.so", "-lcuda"
    end

    # 4. Create isolated Python 3.12 virtualenv runtime
    python3 = formula_opt_bin("python@3.12")/"python3.12"
    system python3, "-m", "venv", libexec/"venv"

    libexec.install "patches", "pthfa", "fa2", "lsa"
    libexec.install "bench" if Dir.exist?("bench")
    libexec.install "docker/entrypoint.sh" if File.exist?("docker/entrypoint.sh")
    libexec.install "bench.py" if File.exist?("bench.py")

    (bin/"hyperqwen").write <<~EOS
      #!/usr/bin/env bash
      if [ "$1" = "serve" ] || [ "$1" = "server" ]; then
        shift
        exec "#{bin}/hyperqwen-serve" "$@"
      elif [ "$1" = "bench" ]; then
        shift
        exec "#{bin}/hyperqwen-bench" "$@"
      elif [ "$1" = "chat" ]; then
        shift
        exec "#{bin}/hyperqwen-chat" "$@"
      fi
      cat << 'EOF'
      HyperQwen: NVIDIA CUDA appliance for Qwen3.8-27B-AWQ
      Usage:
        hyperqwen serve [args...]   Start OpenAI-compatible vLLM server
        hyperqwen bench [args...]   Run throughput benchmarks
        hyperqwen chat [args...]    Interactive chat session
      EOF
    EOS
    chmod 0755, bin/"hyperqwen"

    (bin/"hyperqwen-serve").write <<~EOS
      #!/usr/bin/env bash
      export VLLM_ATTENTION_BACKEND="${VLLM_ATTENTION_BACKEND:-FLASH_ATTN}"
      [ -f "#{libexec}/lib/liblsa.so" ] && export LD_PRELOAD="#{libexec}/lib/liblsa.so${LD_PRELOAD:+:$LD_PRELOAD}"
      MODEL="${HYPERQWEN_MODEL:-QuantTrio/Qwen3.8-27B-AWQ}"
      PORT="${HYPERQWEN_PORT:-18020}"
      exec "#{libexec}/venv/bin/python" -m vllm.entrypoints.openai.api_server \\
        --model "${MODEL}" \\
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
    bin.install_symlink bin/"hyperqwen-serve" => "hyperqwen-server"

    (bin/"hyperqwen-bench").write <<~EOS
      #!/usr/bin/env bash
      if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ]; then
        cat << 'EOF'
      Benchmark OpenAI-compatible endpoint with HyperQwen
      Usage:
        hyperqwen-bench --url http://127.0.0.1:18020 [options]
      EOF
        exit 0
      fi
      if [ -f "#{libexec}/bench.py" ]; then
        exec "#{libexec}/venv/bin/python" "#{libexec}/bench.py" "$@"
      elif [ -f "#{libexec}/bench/labd_bench.py" ]; then
        exec "#{libexec}/venv/bin/python" "#{libexec}/bench/labd_bench.py" "$@"
      fi
    EOS
    chmod 0755, bin/"hyperqwen-bench"

    (bin/"hyperqwen-chat").write <<~EOS
      #!/usr/bin/env bash
      exec "#{libexec}/venv/bin/python" -m vllm.entrypoints.chat "$@"
    EOS
    chmod 0755, bin/"hyperqwen-chat"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:   "cuda",
      cuda_home: cuda_home,
      have_nvcc: have_nvcc,
    )
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
    assert_match "HyperQwen", shell_output("#{bin}/hyperqwen --help")
    assert_match "Benchmark OpenAI-compatible", shell_output("#{bin}/hyperqwen-bench --help")
  end
end
