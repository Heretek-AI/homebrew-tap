class Strixite < Formula
  desc "Zero-dependency C++20/HIP inference engine for AMD Strix Halo (gfx1151)"
  homepage "https://github.com/shawnshekari/strixite"
  url "https://github.com/shawnshekari/strixite/archive/b455955a89683a16d0b71db0fd20b9f369d524d9.tar.gz"
  version "0.5.0"
  sha256 "16abb0c66a077085a5bd5424db8bf9f183e130926c9f2fe465e75608ccb49320"
  license "AGPL-3.0-only"
  head "https://github.com/shawnshekari/strixite.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  option "with-portable-cpu", "Compile host code with -march=x86-64-v3 instead of -march=znver5"

  depends_on "cmake" => :build
  depends_on "lld" => :build
  depends_on "ninja" => :build
  depends_on "gcc"
  depends_on :linux

  def install
    rocm_path = ENV.fetch("ROCM_PATH", "/opt/rocm")
    unless Dir.exist?(rocm_path)
      odie "ROCm installation not found at #{rocm_path}. Set ROCM_PATH to your ROCm SDK (ROCm 7+ / 10.1+)."
    end

    ENV["ROCM_PATH"] = rocm_path
    ENV["HIP_PATH"] = rocm_path
    ENV.prepend_path "PATH", formula_opt_bin("lld")
    ENV.prepend_path "PATH", "#{rocm_path}/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/lib/llvm/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/llvm/bin"

    clangxx = [
      "#{rocm_path}/lib/llvm/bin/clang++",
      "#{rocm_path}/llvm/bin/clang++",
      "#{rocm_path}/bin/amdclang++",
      "#{rocm_path}/bin/clang++",
    ].find { |c| File.executable?(c) } || "#{rocm_path}/llvm/bin/clang++"

    clang = [
      "#{rocm_path}/lib/llvm/bin/clang",
      "#{rocm_path}/llvm/bin/clang",
      "#{rocm_path}/bin/amdclang",
      "#{rocm_path}/bin/clang",
    ].find { |c| File.executable?(c) } || "#{rocm_path}/llvm/bin/clang"

    # Detect system/host GCC install directory containing crtbegin.o & libstdc++ headers
    gcc_install_dir = [
      "/usr/lib/gcc/x86_64-linux-gnu/14",
      "/usr/lib/gcc/x86_64-linux-gnu/13",
      "/usr/lib/gcc/x86_64-pc-linux-gnu/14",
      "/usr/lib/gcc/x86_64-pc-linux-gnu/13",
    ].find { |d| File.exist?("#{d}/crtbegin.o") }

    if OS.linux?
      ENV.append "LDFLAGS", "-L/usr/lib/x86_64-linux-gnu -L/lib/x86_64-linux-gnu"
    end

    host_arch = build.with?("portable-cpu") ? "x86-64-v3" : "znver5"

    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_CXX_COMPILER=#{clangxx}
      -DCMAKE_C_COMPILER=#{clang}
      -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
      -DHIP_ROOT_DIR=#{rocm_path}
      -DHIP_PATH=#{rocm_path}
      -DSTRIX_ROCM_ROOT=#{rocm_path}
      -DSTRIX_HOST_ARCH=#{host_arch}
      -DCMAKE_INSTALL_RPATH=#{rocm_path}/lib;#{formula_opt_lib("gcc")}/gcc/current
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DSTRIX_GCC_INSTALL_DIR=#{gcc_install_dir}" if gcc_install_dir

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args,
           "-DCMAKE_PREFIX_PATH=#{rocm_path};#{HOMEBREW_PREFIX}"
    system "cmake", "--build", "build"

    bin.install "build/strix_server"
    bin.install_symlink bin/"strix_server" => "strixite"
    bin.install "build/convert_qwen4exp"
    bin.install "build/convert_ngram_table"
    bin.install "build/transcode_ngram_table"
    bin.install "build/inspect_strixw"
    bin.install "build/check_stream_calls"

    if File.exist?("deploy/strix-server.conf")
      (etc/"strixite").install "deploy/strix-server.conf" => "strix_server.example.conf"
      default_conf = etc/"strixite/strix_server.conf"
      default_conf.write (etc/"strixite/strix_server.example.conf").read unless default_conf.exist?
    end
    doc.install "README.md"
    doc.install "docs" if Dir.exist?("docs")
  end

  def caveats
    <<~EOS
      1. Convert HuggingFace Qwen3.8-Flash-Next safetensors to Strixite .strixw v2 format:
           convert_qwen4exp /path/to/Qwen3.8-Flash-Next /path/to/qwen4exp-strixw --int4-shared

      2. Start the Strixite server (default port 5300):
           strix_server --model /path/to/qwen4exp-strixw --port 5300 --kv-mode fp8 --mtp-draft 3
         Or using a config file based on #{etc}/strixite/strix_server.example.conf:
           strix_server --config #{etc}/strixite/strix_server.example.conf
    EOS
  end

  service do
    run [opt_bin/"strix_server", "--config", etc/"strixite/strix_server.conf"]
    keep_alive true
    working_dir var
    log_path var/"log/strixite.log"
    error_log_path var/"log/strixite.log"
  end

  test do
    assert_match "Usage: ./strix_server --model", shell_output("#{bin}/strix_server --help")
  end
end
