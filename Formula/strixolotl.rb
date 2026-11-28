class Strixolotl < Formula
  include Language::Python::Virtualenv

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

  resource "markupsafe" do
    url "https://files.pythonhosted.org/packages/38/9b/e422a865e1d5d57d0e509b4e0bf1c1a70a7f6382c29a5aa428df994c8bc8/markupsafe-3.0.4.tar.gz"
    sha256 "2e9ad7dd851bf45fab9f75cbff4cb493fee9979e8d8c7c9c3ee119022518edd6"
  end

  resource "jinja2" do
    url "https://files.pythonhosted.org/packages/df/bf/f7da0350254c0ed7c72f3e33cef02e048281fec7ecec5f032d4aac52226b/jinja2-3.1.6.tar.gz"
    sha256 "0137fb05990d35f1275a587e9aee6d56da821fc83491a0fb838183be43f66d6d"
  end

  resource "regex" do
    url "https://files.pythonhosted.org/packages/fa/b8/61d96601b737305a04161da340499cbb3299029d4ea0f9c717bc35977c2b/regex-2026.11.25.tar.gz"
    sha256 "d3ea8d9698f13f3fd08c65f9bed0bb07bcfff80b61dfa14d86b8cc398f886588"
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
    if (sccache = ENV["HOMEBREW_SCCACHE_PATH"]) && File.executable?(sccache)
      ENV["SCCACHE_DIR"] = ENV["HOMEBREW_SCCACHE_DIR"] if ENV["HOMEBREW_SCCACHE_DIR"]
      %w[C CXX HIP].each { |lang| args << "-DCMAKE_#{lang}_COMPILER_LAUNCHER=#{sccache}" }
    end

    system "cmake", "-S", "xolotl", "-B", "build-strix", *std_cmake_args, *args,
           "-DCMAKE_PREFIX_PATH=#{rocm_path};#{rocm_path}/lib/llvm;#{HOMEBREW_PREFIX}"
    system "cmake", "--build", "build-strix", "--target", "ds41_generate", "strata-device"

    (libexec/"bin").install "build-strix/ds41_generate", "build-strix/strata-device"
    libexec.install "xolotl/serve" if (buildpath/"xolotl/serve").exist?
    libexec.install "xolotl/tools" if (buildpath/"xolotl/tools").exist?
    libexec.install "scripts" if (buildpath/"scripts").exist?

    venv = virtualenv_create(libexec/"venv", "python3.12")
    venv.pip_install resource("markupsafe")
    venv.pip_install resource("jinja2")
    venv.pip_install resource("regex")

    (bin/"strixolotl").write <<~SH
      #!/usr/bin/env bash
      export HSA_DISABLE_COREDUMP_ON_EXCEPTION=1
      export LD_LIBRARY_PATH="#{formula_opt_lib("rocm-runtime")}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec "#{libexec}/bin/ds41_generate" "$@"
    SH
    chmod 0755, bin/"strixolotl"

    (bin/"strixolotl-serve").write <<~SH
      #!/usr/bin/env bash
      export HSA_DISABLE_COREDUMP_ON_EXCEPTION=1
      export PYTHONPATH="#{libexec}${PYTHONPATH:+:$PYTHONPATH}"
      export LD_LIBRARY_PATH="#{formula_opt_lib("rocm-runtime")}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      exec "#{libexec}/venv/bin/python" "#{libexec}/tools/v41/serve/serve_ds41.py" --engine strata "$@"
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

      Serve a configured DeepSeek-V4.1 model on loopback (set "exe": "#{opt_libexec}/bin/ds41_generate" in your JSON config):
        strixolotl-serve --config /path/to/strata-ds41.json --host 127.0.0.1 --port 18013
    EOS
  end

  test do
    out = shell_output("ldd #{libexec}/bin/ds41_generate")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    dev_out = shell_output("ldd #{libexec}/bin/strata-device")
    refute_match(/not found/, dev_out)
    assert_match(/libamdhip64\.so/, dev_out)

    assert_match(/usage|model/i, shell_output("#{bin}/strixolotl --help 2>&1", 2))
    assert_match(/device|no GPU/i, pipe_output("#{libexec}/bin/strata-device --list-devices 2>&1"))
  end
end
