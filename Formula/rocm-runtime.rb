class RocmRuntime < Formula
  desc "Shared AMD ROCm runtime libraries for GPU inference engines"
  homepage "https://github.com/ROCm/TheRock"
  url "https://nightly.repo.amd.com/rocm/core/tarball/therock-dist-linux-gfx1151-10.3.0a20261126.tar.gz"
  sha256 "874371b060a4ea2a8be617aee1107e7703628e28609642f706a691a690524abd"
  license "MIT"

  livecheck do
    url "https://nightly.repo.amd.com/rocm/core/tarball/"
    regex(/therock-dist-linux-gfx1151-(\d+(?:\.\d+)+a\d+)(?:\.tar\.gz)/i)
  end

  keg_only "it is a shared runtime that engines link against via opt_lib"

  depends_on arch: :x86_64
  depends_on :linux

  resource "gfx110X" do
    url "https://nightly.repo.amd.com/rocm/core/tarball/therock-dist-linux-gfx110X-all-10.3.0a20261126.tar.gz"
    sha256 "7e4c85c878a848708fcb99d95390c7b04ff54f8679730b06c71244380922d157"
  end

  resource "gfx1150" do
    url "https://nightly.repo.amd.com/rocm/core/tarball/therock-dist-linux-gfx1150-10.3.0a20261126.tar.gz"
    sha256 "269e69b8662bb9a539eee7cf110439359e3d134d6afe6d9eb9fb002c1dfabafc"
  end

  resource "gfx120X" do
    url "https://nightly.repo.amd.com/rocm/core/tarball/therock-dist-linux-gfx120X-all-10.3.0a20261126.tar.gz"
    sha256 "d0b3a3c2661f71323f7d471ae448b0e750e315e19c054d7f276551f4db8821ad"
  end

  def install
    runtime_libraries = [
      "lib/libamdhip64.so*",
      "lib/libhsa-runtime64.so*",
      "lib/libamd_comgr.so*",
      "lib/librocm_kpack.so*",
      "lib/librocprofiler-register.so*",
      "lib/librocblas.so*",
      "lib/libhipblas.so*",
      "lib/libhipblaslt.so*",
      "lib/librocsolver.so*",
      "lib/libtensilelite-host.so*",
      "lib/librocroller.so*",
      "lib/liborigami.so*",
      "lib/libroctx64.so*",
      "lib/libroctracer64.so*",
    ].flat_map { |pattern| Dir[pattern] }
    lib.install runtime_libraries

    if (buildpath/"lib/rocm_sysdeps").directory?
      (lib/"rocm_sysdeps").install "lib/rocm_sysdeps/lib", "lib/rocm_sysdeps/share"
    end

    (lib/"rocblas").install "lib/rocblas/library" if (buildpath/"lib/rocblas/library").directory?
    (lib/"hipblaslt").install "lib/hipblaslt/library" if (buildpath/"lib/hipblaslt/library").directory?

    if (buildpath/".kpack").directory?
      kept_kpacks = (Dir[".kpack/blas_lib_*.kpack"] + Dir[".kpack/solver_lib_*.kpack"])
                    .map { |path| File.basename(path) }
      prefix.install ".kpack"
      (prefix/".kpack").children.each do |kpack|
        rm_r kpack unless kept_kpacks.include?(kpack.basename.to_s)
      end
    end

    %w[gfx110X gfx1150 gfx120X].each do |family|
      resource(family).stage do
        install_missing(lib/"rocblas/library", "lib/rocblas/library/*")
        install_missing(lib/"hipblaslt/library", "lib/hipblaslt/library/*")
        install_missing(prefix/".kpack", ".kpack/blas_lib_*.kpack")
        install_missing(prefix/".kpack", ".kpack/solver_lib_*.kpack")
      end
    end

    libraries = Dir["#{lib}/**/*.so*"].map { |path| path.delete_prefix("#{lib}/") }.sort
    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      version:            version,
      families:           %w[gfx1151 gfx110X gfx1150 gfx120X],
      libraries:          libraries,
      compiler_libraries: "intentionally excluded",
      note:               "Runtime-only install. Compiler, profiler, MIOpen and LLVM payloads are excluded.",
    )
  end

  def caveats
    <<~EOS
      rocm-runtime is keg-only because it provides a shared ROCm runtime.
      Link engines against it with Formula["rocm-runtime"].opt_lib rather than
      relying on `brew link`.

      For runtime kernel loading, set:
        export ROCM_PATH="#{opt_prefix}"
        export ROCM_KPACK_PATH="#{opt_prefix}/.kpack"

      This formula installs runtime libraries only. Source builds still need a
      full ROCm SDK with hipcc; point HOMEBREW_ROCM_PATH at that SDK.

      The formula downloads four GPU-family tarballs (about 12 GB) but installs
      only about 1.3 GB of runtime libraries, kpack kernels and BLAS libraries.
    EOS
  end

  test do
    refute_empty Dir["#{lib}/libamdhip64.so*"]
    kernel_files = Dir["#{lib}/rocblas/library/**/*"] + Dir["#{prefix}/.kpack/blas_lib_*.kpack"]
    refute_empty kernel_files
    refute_empty Dir["#{lib}/hipblaslt/library/**/*"]

    assert_empty Dir["#{lib}/libLLVM*"]
    assert_empty Dir["#{lib}/libclang*"]

    manifest = JSON.parse((pkgshare/"build-manifest.json").read)
    assert_equal version.to_s, manifest["version"]
  end

  private

  def install_missing(destination, pattern)
    destination.mkpath
    Dir[pattern].each do |source|
      target = destination/File.basename(source)
      destination.install source unless target.exist?
    end
  end
end
