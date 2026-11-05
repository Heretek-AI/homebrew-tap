class Snowllm < Formula
  include Language::Python::Virtualenv

  desc "Hand-written HIP kernels and embedded LLM runner for AMD Ryzen AI Max"
  homepage "https://github.com/snowllm/snowllm"
  url "https://github.com/snowllm/snowllm/archive/52b4bac0914d202fd2877f576c4db462b21815a7.tar.gz"
  version "0.3.22.dev3-git52b4bac"
  sha256 "039a5ca2f39cbf81bbbfd986b206775ee7cb1372dfca7a174f8841ce2ca6d5ea"
  license "Apache-2.0"
  head "https://github.com/snowllm/snowllm.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on :linux
  depends_on "python@3.12"

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm-nightly", "/opt/rocm"]
      .compact.find { |p| File.exist?("#{p}/include/hip/hip_runtime.h") } ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to your ROCm SDK.")
  end

  def install
    rocm = rocm_root
    ENV["ROCM_PATH"] = rocm
    ENV["HIP_PATH"] = rocm
    ENV.prepend_path "PATH", "#{rocm}/bin"
    ENV.prepend_path "PATH", "#{rocm}/llvm/bin"

    venv = virtualenv_create(libexec, "python3.12")
    venv.pip_install_and_link buildpath

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:   "rocm",
      rocm_root: rocm,
      python:    formula_opt_bin("python@3.12")/"python3.12",
      commit:    "52b4bac0914d202fd2877f576c4db462b21815a7",
    )
  end

  test do
    assert_match(/snowllm|usage|options/i, shell_output("#{bin}/snowllm --help 2>&1"))
  end
end
