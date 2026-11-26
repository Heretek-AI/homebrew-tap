class GemmaCpp < Formula
  desc "C++ inference engine for Gemma and PaliGemma models"
  homepage "https://github.com/google/gemma.cpp"
  url "https://github.com/google/gemma.cpp/archive/refs/tags/v0.1.4.tar.gz"
  sha256 "748eca98c85d0fe3e5134eb11c68ea8ec12a94b88f520fce1fafb4e03f0e11ff"
  license "Apache-2.0"
  head "https://github.com/google/gemma.cpp.git", branch: "main"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "openssl@3"

  resource "highway" do
    url "https://github.com/google/highway/archive/2a16a50ff61071bb25ddef0ce35d92b0e2b9c579.tar.gz"
    sha256 "64f377b8bd652a2b8b427965b43c542f90357ad5126ebe59856eb2dcb75bdd5c"
  end

  resource "sentencepiece" do
    url "https://github.com/google/sentencepiece/archive/53de76561cfc149d3c01037f0595669ad32a5e7c.tar.gz"
    sha256 "e3d43b4601ac22ce7637cc5f4b41d94b9ffea6cc4d61d3d9189dcd638595c532"
  end

  resource "json" do
    url "https://github.com/nlohmann/json/archive/9cca280a4d0ccf0c08f47a99aa71d1b0e52f8d03.tar.gz"
    sha256 "0dbc5e40a01ff142e7e68c03e85247a4dcede2f592d12d3677dee3664d17975a"
  end

  resource "httplib" do
    url "https://github.com/yhirose/cpp-httplib/archive/refs/tags/v0.18.1.tar.gz"
    sha256 "405abd8170f2a446fc8612ac635d0db5947c0d2e156e32603403a4496255ff00"
  end

  resource "benchmark" do
    url "https://github.com/google/benchmark/archive/refs/tags/v1.8.2.tar.gz"
    sha256 "2aab2980d0376137f969d92848fbb68216abb07633034534fc8c65cc4e7a0e93"
  end

  def install
    resource("highway").stage(buildpath/"deps/highway")
    resource("sentencepiece").stage(buildpath/"deps/sentencepiece")
    resource("json").stage(buildpath/"deps/json")
    resource("httplib").stage(buildpath/"deps/httplib")
    resource("benchmark").stage(buildpath/"deps/benchmark")

    # The pinned SentencePiece revision relies on a transitive <cstdint> include
    # that GCC 15 and newer no longer provide.
    inreplace "deps/sentencepiece/src/sentencepiece_processor.h",
              "#include <cstring>",
              "#include <cstdint>\n#include <cstring>"

    openssl = formula_opt_prefix("openssl@3")
    ENV["OPENSSL_ROOT_DIR"] = openssl.to_s

    args = %W[
      -G Ninja
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
      -DCMAKE_PREFIX_PATH=#{openssl}
      -DOPENSSL_ROOT_DIR=#{openssl}
      -DFETCHCONTENT_SOURCE_DIR_HIGHWAY=#{buildpath}/deps/highway
      -DFETCHCONTENT_SOURCE_DIR_SENTENCEPIECE=#{buildpath}/deps/sentencepiece
      -DFETCHCONTENT_SOURCE_DIR_JSON=#{buildpath}/deps/json
      -DFETCHCONTENT_SOURCE_DIR_HTTPLIB=#{buildpath}/deps/httplib
      -DFETCHCONTENT_SOURCE_DIR_BENCHMARK=#{buildpath}/deps/benchmark
    ]

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build", "--target", "gemma", "--parallel", ENV.make_jobs.to_s

    bin.install "build/gemma" => "gemma-cpp"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:    OS.mac? ? "metal-cpu" : "cpu",
      version:    version,
      cmake_args: args,
    )
  end

  def caveats
    <<~EOS
      gemma-cpp is a CPU-only build using Highway SIMD; there is no Metal or CUDA
      backend. Model weights are not included. Download Gemma 2/3 or PaliGemma
      .sbs weights and the matching tokenizer from Kaggle or Hugging Face, then
      pass them to gemma-cpp as described in the upstream README.
    EOS
  end

  test do
    if OS.linux?
      out = shell_output("ldd #{bin}/gemma-cpp")
      refute_match(/not found/, out)
    elsif OS.mac?
      out = shell_output("otool -L #{bin}/gemma-cpp")
      refute_match(/not found/, out)
    end

    # The pinned CLI validates --weights before handling --help, so pass a
    # throwaway file; --help stops before the weights are read.
    (testpath/"empty.sbs").write ""
    assert_match(/weights|usage|gemma/i,
                 shell_output("#{bin}/gemma-cpp --weights #{testpath}/empty.sbs --help 2>&1"))
  end
end
