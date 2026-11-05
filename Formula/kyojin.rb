class Kyojin < Formula
  desc "Strix Halo (gfx1151) & RDNA4 EXL3/GGUF inference engine with 5 model servers"
  homepage "https://github.com/Yamz-Labs/kyojin"
  url "https://github.com/Yamz-Labs/kyojin/archive/f52fb101598d93f5134ab7fb09a1aec8d8a9d918.tar.gz"
  version "1.8.7"
  sha256 "c74042168670e96474bf4a82bea99c02c58787c755219b8f614499fcc900cea3"
  license "MIT"
  head "https://github.com/Yamz-Labs/kyojin.git", branch: "main"

  option "with-rdna4", "Include RDNA4 (gfx1200;gfx1201) and RDNA3.5 (gfx1150) alongside gfx1151"
  option "with-cuda", "Build for NVIDIA CUDA (sm_80+) instead of AMD ROCm"

  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on :linux
  depends_on "python@3.12"

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK.")
  end

  def install
    python3 = formula_opt_bin("python@3.12")/"python3.12"

    system python3, "-m", "venv", libexec/"venv"
    pip = libexec/"venv/bin/pip"
    system pip, "install", "--upgrade", "pip", "setuptools", "wheel", "ninja"

    if build.with?("cuda")
      ENV["TORCH_CUDA_ARCH_LIST"] = "8.0;8.6;8.9;9.0;12.0"
      system pip, "install", "torch", "torchvision"
    else
      rocm_path = rocm_root
      ENV["ROCM_PATH"] = rocm_path
      ENV["HIP_PATH"] = rocm_path
      ENV["PYTORCH_ROCM_ARCH"] = build.with?("rdna4") ? "gfx1151;gfx1150;gfx1200;gfx1201" : "gfx1151"
      ENV.prepend_path "PATH", "#{rocm_path}/bin"
      ENV.prepend_path "PATH", "#{rocm_path}/lib/llvm/bin"
      ENV.prepend_path "PATH", "#{rocm_path}/llvm/bin"
      ENV.append "CPATH", "#{rocm_path}/include"
      ENV.append "LDFLAGS", "-L#{rocm_path}/lib"

      torch_index = ENV.fetch("KYOJIN_TORCH_INDEX_URL", "https://download.pytorch.org/whl/nightly/rocm7.1")
      system pip, "install", "--pre", "torch", "torchvision", "pytorch-triton-rocm", "--index-url", torch_index
    end

    # Install runtime and undocumented server dependencies (aiohttp, jinja2)
    system pip, "install",
           "safetensors>=0.4.2",
           "tokenizers>=0.21.1",
           "numpy>=2.1.0",
           "rich>=13.7.1",
           "pillow>=10.3.0",
           "typing_extensions>=4.11.0",
           "marisa_trie>=1.2.1",
           "kbnf>=0.4.2",
           "formatron>=0.5.0",
           "aiohttp>=3.9.0",
           "jinja2>=3.1.0"

    # Enable AVX2/FMA/F16C SIMD kernels in cpu_IQ1_M.cpp and quantize_row_q8_K
    ENV["CFLAGS"] = "-O3 -mavx2 -mfma -mf16c -I#{rocm_path}/include"
    ENV["CXXFLAGS"] = "-O3 -mavx2 -mfma -mf16c -I#{rocm_path}/include"
    ENV["MAX_JOBS"] = ENV.make_jobs.to_s

    # AOT-compile exllamav3_ext C++/HIP extension into libexec/venv
    system pip, "install", "--no-build-isolation", "--no-deps", "."

    # Preserve repo scripts and tools/ hierarchy in libexec
    libexec.install "tools", "examples", "convert.py", "eval"
    pkgshare.install "triton-3.7.0-gfx1151.tar.xz" if File.exist?("triton-3.7.0-gfx1151.tar.xz")

    # Write Strix Halo-safe environment launcher helper
    (libexec/"kyojin-env.sh").write <<~EOS
      #!/usr/bin/env bash
      set -e
      export ROCM_PATH="${ROCM_PATH:-#{rocm_path}}"
      export EXL3_ROCM_SDK="${EXL3_ROCM_SDK:-${ROCM_PATH}}"
      unset HSA_OVERRIDE_GFX_VERSION
      if [ -f "${ROCM_PATH}/lib/libhsa-runtime64.so.1" ]; then
        export LD_PRELOAD="${ROCM_PATH}/lib/libhsa-runtime64.so.1${LD_PRELOAD:+:$LD_PRELOAD}"
      fi
      if [ ! -d "${HOME}/.triton/cache" ] && [ -f "#{pkgshare}/triton-3.7.0-gfx1151.tar.xz" ]; then
        mkdir -p "${HOME}/.triton"
        tar -xJf "#{pkgshare}/triton-3.7.0-gfx1151.tar.xz" -C "${HOME}/.triton" 2>/dev/null || true
      fi
    EOS
    chmod 0755, libexec/"kyojin-env.sh"

    # Multi-engine server dispatcher: kyojin-serve <qwen|glm|mimo|ds41|flint> [args...]
    (bin/"kyojin-serve").write <<~EOS
      #!/usr/bin/env bash
      source "#{libexec}/kyojin-env.sh"
      ENGINE="${1:-qwen}"
      case "${ENGINE}" in
        qwen|glm|mimo|ds41|flint)
          shift
          exec "#{libexec}/venv/bin/python" "#{libexec}/tools/${ENGINE}/serve.py" "$@"
          ;;
        -h|--help)
          echo "Usage: kyojin-serve <qwen|glm|mimo|ds41|flint> [serve.py options]"
          echo "Engines:"
          echo "  qwen  : Qwen3.8-35B-A3B / 27B / 122B / 9B / 4B (MTP speculative decoding)"
          echo "  glm   : GLM-4.7-Flash / GLM-5.3-Flash (draft model or n-gram speculative)"
          echo "  mimo  : MiMo-V2-Flash (hybrid SWA + global MLA + n-gram speculative)"
          echo "  ds41  : DeepSeek-V4.1-Flash 763B GGUF (GPU MLA + DSpark + AVX2 CPU IQ1_M experts)"
          echo "  flint : Gemma 4 26B-A4B MoE & 31B Dense"
          exit 0
          ;;
        *)
          exec "#{libexec}/venv/bin/python" "#{libexec}/tools/qwen/serve.py" "$@"
          ;;
      esac
    EOS
    chmod 0755, bin/"kyojin-serve"

    (bin/"kyojin-bench").write <<~EOS
      #!/usr/bin/env bash
      source "#{libexec}/kyojin-env.sh"
      exec "#{libexec}/venv/bin/python" "#{libexec}/tools/bench.py" "$@"
    EOS
    chmod 0755, bin/"kyojin-bench"

    (bin/"kyojin-convert").write <<~EOS
      #!/usr/bin/env bash
      source "#{libexec}/kyojin-env.sh"
      exec "#{libexec}/venv/bin/python" "#{libexec}/convert.py" "$@"
    EOS
    chmod 0755, bin/"kyojin-convert"

    (bin/"kyojin-chat").write <<~EOS
      #!/usr/bin/env bash
      source "#{libexec}/kyojin-env.sh"
      exec "#{libexec}/venv/bin/python" "#{libexec}/examples/chat.py" "$@"
    EOS
    chmod 0755, bin/"kyojin-chat"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant: build.with?("cuda") ? "cuda" : "rocm",
      python:  python3,
      commit:  "f52fb101598d93f5134ab7fb09a1aec8d8a9d918",
    )
  end

  def caveats
    <<~EOS
      Kyojin wrappers automatically configure Strix Halo ROCm environment variables:
        - Sets LD_PRELOAD to ${ROCM_PATH}/lib/libhsa-runtime64.so.1
        - Unsets HSA_OVERRIDE_GFX_VERSION
        - Seeds ~/.triton/cache from #{pkgshare}/triton-3.7.0-gfx1151.tar.xz on first run

      Start an OpenAI-compatible server (port 8000):
        kyojin-serve qwen -m /path/to/Qwen3.8-35B-A3B-EXL3 --mtp --port 8000
        kyojin-serve ds41 -m /path/to/DeepSeek-V4.1-Flash-GGUF --ngram --port 8000
    EOS
  end

  service do
    run [opt_bin/"kyojin-serve", "qwen", "--host", "127.0.0.1", "--port", "8000"]
    keep_alive true
    working_dir var
    log_path var/"log/kyojin.log"
    error_log_path var/"log/kyojin.log"
  end

  test do
    # 1. CLI Introspection
    assert_match "Usage: kyojin-serve", shell_output("#{bin}/kyojin-serve --help")
    assert_match(/bench|kyojin/i, shell_output("#{bin}/kyojin-bench --help 2>&1"))

    # 2. Device Discovery Smoke Test
    probe = shell_output("#{bin}/kyojin-serve --list-devices 2>&1", nil)
    assert $CHILD_STATUS.exitstatus < 128, "Device probe crashed: #{probe}"
  end
end
