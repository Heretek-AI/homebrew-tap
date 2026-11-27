class Strixolotl < Formula
  desc "AMD Strix Halo HIP port of Xolotl for DeepSeek-V4.1-Flash (GSQ-217)"
  homepage "https://github.com/snowsh1ne/strixolotl"
  url "https://github.com/snowsh1ne/strixolotl/archive/20d3c7a77006d8ae4e171929c6658dce40c06a0d.tar.gz"
  version "0.1.0-git20d3c7a"
  sha256 "8385acbbc0581c1f238edc02b1665e89bc3d0f62e8ccf40e3ce4bcf78b3cd544"
  license "MIT"
  head "https://github.com/snowsh1ne/strixolotl.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on :linux
  depends_on "python@3.12"

  resource "llama.cpp" do
    url "https://github.com/ggml-org/llama.cpp/archive/3cf03257f219afbe7334045ff7c6a06ac68c627d.tar.gz"
    sha256 "c076d7534afa0e5d0ec2a0d425b11e791c16f3de0d727221aea071cef156a280"
  end

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK.")
  end

  def install
    llama_dir = buildpath/"third_party/llama.cpp"
    resource("llama.cpp").stage llama_dir

    patch_file = buildpath/"xolotl/tools/xolotl/ggml/xolotl-ggml.patch"
    system "patch", "-p1", "-d", llama_dir.to_s, "-i", patch_file.to_s

    Dir[buildpath/"xolotl/tools/xolotl/ggml/strix-*.patch"].each do |extra_patch|
      system "patch", "-p1", "-d", llama_dir.to_s, "-i", extra_patch
    end

    rocm_path = rocm_root
    ENV["ROCM_PATH"] = rocm_path
    ENV["HIP_PATH"] = rocm_path
    ENV.prepend_path "PATH", "#{rocm_path}/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/lib/llvm/bin"
    ENV.prepend_path "PATH", "#{rocm_path}/llvm/bin"

    hip_compiler = [
      "#{rocm_path}/lib/llvm/bin/clang++",
      "#{rocm_path}/llvm/bin/clang++",
      "#{rocm_path}/bin/amdclang++",
      "#{rocm_path}/bin/clang++",
    ].find { |c| File.executable?(c) }

    bitcode_dir = [
      "#{rocm_path}/lib/llvm/amdgcn/bitcode",
      "#{rocm_path}/amdgcn/bitcode",
    ].find { |d| Dir.exist?(d) }

    hip_flags = ["--rocm-path=#{rocm_path}"]
    hip_flags << "--rocm-device-lib-path=#{bitcode_dir}" if bitcode_dir

    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DSTRATA_ENABLE_HIP=ON
      -DSTRATA_ENABLE_CUDA=OFF
      -DSTRATA_GGML_HIP=ON
      -DSTRATA_PREFILL_MMQ=ON
      -DSTRATA_MMQ_KQUANTS=ON
      -DSTRATA_DSV41_FQ_OP=ON
      -DSTRATA_DSV41_HC_MIX=ON
      -DSTRATA_BUILD_TESTS=OFF
      -DSTRATA_GGML_DIR=#{llama_dir}
      -DCMAKE_HIP_ARCHITECTURES=gfx1151
      -DCMAKE_HIP_COMPILER_ROCM_ROOT=#{rocm_path}
      -DHIP_ROOT_DIR=#{rocm_path}
      -DHIP_PATH=#{rocm_path}
      -DCMAKE_HIP_FLAGS=#{hip_flags.join(" ")}
      -DCMAKE_INSTALL_RPATH=#{formula_opt_lib("rocm-runtime")};#{HOMEBREW_PREFIX}/lib
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DCMAKE_HIP_COMPILER=#{hip_compiler}" if hip_compiler

    system "cmake", "-S", "xolotl", "-B", "build-strix", *std_cmake_args, *args,
           "-DCMAKE_PREFIX_PATH=#{rocm_path};#{rocm_path}/lib/llvm;#{HOMEBREW_PREFIX}"
    system "cmake", "--build", "build-strix", "--target", "ds41_generate"

    (libexec/"bin").install "build-strix/ds41_generate"
    libexec.install "xolotl/serve" if (buildpath/"xolotl/serve").exist?
    (libexec/"tools").install "xolotl/tools/v41" if (buildpath/"xolotl/tools/v41").exist?
    libexec.install "scripts" if (buildpath/"scripts").exist?

    (bin/"strixolotl").write <<~SH
      #!/usr/bin/env bash
      export HSA_DISABLE_COREDUMP_ON_EXCEPTION=1
      export LD_LIBRARY_PATH="#{formula_opt_lib("rocm-runtime")}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec "#{libexec}/bin/ds41_generate" "$@"
    SH
    chmod 0755, bin/"strixolotl"

    python3 = formula_opt_bin("python@3.12")/"python3.12"
    (bin/"strixolotl-serve").write <<~SH
      #!/usr/bin/env bash
      export HSA_DISABLE_COREDUMP_ON_EXCEPTION=1
      export PYTHONPATH="#{libexec}${PYTHONPATH:+:$PYTHONPATH}"
      export LD_LIBRARY_PATH="#{formula_opt_lib("rocm-runtime")}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec "#{python3}" "#{libexec}/tools/v41/serve/serve_ds41.py" --engine "#{libexec}/bin/ds41_generate" "$@"
    SH
    chmod 0755, bin/"strixolotl-serve"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:      "rocm",
      rocm_root:    rocm_path,
      hip_compiler: hip_compiler,
      cmake_args:   args,
    )
  end

  def caveats
    <<~EOS
      strixolotl targets AMD Strix Halo (gfx1151, 128 GB unified memory) on Linux
      for DeepSeek-V4.1-Flash-1017 (GSQ-217 quant, 1M context, DSpark MTP).

      Recommended kernel parameters:
        amdgpu.gttsize=131072 ttm.pages_limit=33554432

      Serve a configured DeepSeek-V4.1 model on loopback:
        strixolotl-serve --config /path/to/strata-ds41.json --host 127.0.0.1 --port 18013
    EOS
  end

  test do
    out = shell_output("ldd #{libexec}/bin/ds41_generate")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    assert_match(/usage|model/i, shell_output("#{bin}/strixolotl --help 2>&1"))
  end
end
