class Xolotl < Formula
  include Language::Python::Virtualenv

  desc "Tiered CUDA MoE engine for DeepSeek-V4.1, GLM-5.3, Qwen3.8 & Inkling"
  homepage "https://github.com/Indras-Mirror/Xolotl"
  url "https://github.com/Indras-Mirror/Xolotl/archive/52cf6b89eb9a4b6e2730e935bc384100c6151b45.tar.gz"
  version "0.2.8-git52cf6b89"
  sha256 "0f207c5e243d5e9b2c36060ab1a34d81d39456396f22bd16ca4b7c95a7c2eb98"
  license "MIT"
  head "https://github.com/Indras-Mirror/Xolotl.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "heretek-ai/tap/cuda-runtime"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on :linux
  depends_on "python@3.12"

  resource "llama.cpp" do
    url "https://github.com/ggml-org/llama.cpp/archive/6050b467c07a95c7b87debd4ddac2f8ba8d9b807.tar.gz"
    sha256 "64a750f710b8cf922d7dd931a1297a9cc236039f7e0f10759e9bfa555966e7ca"
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

  def cuda_root
    [ENV["HOMEBREW_CUDA_PATH"], ENV["CUDA_HOME"], ENV["CUDA_PATH"], "/usr/local/cuda"]
      .compact.find { |p| File.executable?("#{p}/bin/nvcc") } ||
      odie("NVIDIA CUDA toolkit not found. Set HOMEBREW_CUDA_PATH or CUDA_HOME to a CUDA 12/13 install with nvcc.")
  end

  def install
    llama_dir = buildpath/"third_party/llama.cpp"
    resource("llama.cpp").stage llama_dir
    patch_file = buildpath/"tools/xolotl/ggml/xolotl-ggml.patch"
    system "patch", "-p1", "-d", llama_dir.to_s, "-i", patch_file.to_s

    cuda = cuda_root
    ENV["CUDA_HOME"] = cuda
    ENV["CUDACXX"] = "#{cuda}/bin/nvcc"
    ENV.prepend_path "PATH", "#{cuda}/bin"

    # CUDA 13.5's CUB no longer transitively includes <cuda/iterator>.
    argsort_cu = llama_dir/"ggml/src/ggml-cuda/argsort.cu"
    if argsort_cu.exist? &&
       argsort_cu.read.include?("#        define STRIDED_ITERATOR_AVAILABLE") &&
       argsort_cu.read.exclude?("<cuda/iterator>")
      inreplace argsort_cu,
                "#        define STRIDED_ITERATOR_AVAILABLE",
                "#        include <cuda/iterator>\n#        define STRIDED_ITERATOR_AVAILABLE"
    end
    topk_cu = llama_dir/"ggml/src/ggml-cuda/top-k.cu"
    if topk_cu.exist? &&
       topk_cu.read.include?("#        define CUB_TOP_K_AVAILABLE") &&
       topk_cu.read.exclude?("<cuda/iterator>")
      inreplace topk_cu,
                "#        define CUB_TOP_K_AVAILABLE",
                "#        define CUB_TOP_K_AVAILABLE\n#        include <cuda/iterator>"
    end

    host_cxx = ["/usr/bin/g++-13", "/usr/bin/g++"].find { |path| File.executable?(path) }
    rpath = "#{formula_opt_lib("cuda-runtime")};#{HOMEBREW_PREFIX}/lib"
    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DSTRATA_BUILD_TESTS=OFF
      -DSTRATA_ENABLE_CUDA=ON
      -DSTRATA_GGML_CUDA=ON
      -DSTRATA_MMQ_KQUANTS=ON
      -DSTRATA_DSV41_FQ_OP=ON
      -DSTRATA_DSV41_HC_MIX=ON
      -DSTRATA_GGML_DIR=#{llama_dir}
      -DCMAKE_CUDA_ARCHITECTURES=80;86;89;90;100;120
      -DCMAKE_CUDA_COMPILER=#{cuda}/bin/nvcc
      -DCUDAToolkit_ROOT=#{cuda}
      -DCMAKE_INSTALL_RPATH=#{rpath}
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]
    args << "-DCMAKE_CUDA_HOST_COMPILER=#{host_cxx}" if host_cxx

    system "cmake", "-S", ".", "-B", "build-xolotl", *std_cmake_args, *args
    system "cmake", "--build", "build-xolotl"

    if (buildpath/"tools/vision/CMakeLists.txt").exist?
      vision_args = %W[
        -G Ninja
        -DCMAKE_BUILD_TYPE=Release
        -DLLAMA_DIR=#{llama_dir}
        -DCMAKE_INSTALL_RPATH=#{rpath}
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
      ]
      system "cmake", "-S", "tools/vision", "-B", "build-vision", *std_cmake_args, *vision_args
      system "cmake", "--build", "build-vision", "--target", "strata-vision"
    end

    %w[serve strata_control tools configs scripts chat.py strata.py].each do |entry|
      libexec.install entry if File.exist?(entry)
    end
    (libexec/"third_party/llama.cpp").install llama_dir/"gguf-py" if (llama_dir/"gguf-py").exist?

    venv = virtualenv_create(libexec/"venv", "python3.12")
    venv.pip_install resource("markupsafe")
    venv.pip_install resource("jinja2")
    venv.pip_install resource("regex")

    (libexec/"build-xolotl").mkpath
    binary_map = {
      "strata"         => "xolotl",
      "ds41_generate"  => "xolotl-ds41",
      "xolotl-dense"   => "xolotl-dense",
      "glm_generate"   => "xolotl-glm",
      "xolotl-inkling" => "xolotl-inkling",
      "ernie_generate" => "xolotl-ernie",
    }
    binary_map.each do |src_name, dst_name|
      src = buildpath/"build-xolotl"/src_name
      next unless src.exist?

      (libexec/"build-xolotl").install src
      (bin/dst_name).write <<~SH
        #!/usr/bin/env bash
        export LD_LIBRARY_PATH="#{formula_opt_lib("cuda-runtime")}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        exec "#{libexec}/build-xolotl/#{src_name}" "$@"
      SH
      chmod 0755, bin/dst_name
    end

    vision_bin = ["build-vision/bin/strata-vision", "build-vision/strata-vision"].find { |f| File.exist?(f) }
    if vision_bin
      (libexec/"build-vision").install vision_bin
      bin.install_symlink libexec/"build-vision/strata-vision" => "xolotl-vision"
    end

    (bin/"xolotl-serve").write <<~SH
      #!/usr/bin/env bash
      export PYTHONPATH="#{libexec}${PYTHONPATH:+:$PYTHONPATH}"
      export LD_LIBRARY_PATH="#{formula_opt_lib("cuda-runtime")}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      cd "#{libexec}"
      exec "#{libexec}/venv/bin/python" -m serve.server --engine strata "$@"
    SH
    chmod 0755, bin/"xolotl-serve"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:    "cuda",
      cuda_root:  cuda,
      cmake_args: args,
    )
  end

  def caveats
    <<~EOS
      Xolotl targets NVIDIA CUDA GPUs (sm_80 through sm_120) on Linux.
      Exposed commands (namespaced to avoid colliding with strata):
        xolotl, xolotl-ds41, xolotl-dense, xolotl-glm, xolotl-inkling, xolotl-ernie, xolotl-serve

      Serve a configured model (OpenAI- and Anthropic-compatible API):
        xolotl-serve --config /path/to/model.json --port 8090

      DeepSeek-V4.1 and GLM-5.3 have dedicated Python launchers under:
        #{libexec}/tools/v41/serve/serve_ds41.py
        #{libexec}/tools/glm/serve/serve_glm.py
    EOS
  end

  test do
    out = shell_output("ldd #{libexec}/build-xolotl/ds41_generate")
    refute_match(/not found/, out)
    assert_match(/libcudart\.so/, out)

    assert_match(/usage|model/i, shell_output("#{bin}/xolotl-ds41 --help 2>&1", 2))
  end
end
