class CrucibleStrixHalo < Formula
  desc "AMD Strix Halo (gfx1151) kernel harness and memory allocator tuners"
  homepage "https://github.com/jaedync/crucible-strix-halo"
  url "https://github.com/jaedync/crucible-strix-halo/archive/98e9870a8efb96f1a7f026764ccd6309f1fde465.tar.gz"
  version "0.33.1-git98e9870"
  sha256 "597dd9aba9c036c37dc085ef384456a33281bf6c02e5440cff223d69871ff4e9"
  license "Apache-2.0"
  head "https://github.com/jaedync/crucible-strix-halo.git", branch: "main"

  livecheck do
    skip "Tracks upstream commit"
  end

  depends_on "patchelf" => :build
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on :linux
  depends_on "openssl@3"
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
    ENV.prepend_path "PATH", "#{rocm}/lib/llvm/bin"
    ENV.prepend_path "PATH", "#{rocm}/llvm/bin"

    hipcc = [
      "#{rocm}/bin/hipcc",
      "#{rocm}/lib/llvm/bin/clang++",
      "#{rocm}/llvm/bin/clang++",
      "#{rocm}/bin/amdclang++",
    ].find { |c| File.executable?(c) } || "#{rocm}/bin/hipcc"

    ENV["HIPCC"] = hipcc
    ENV["GPU_ARCH"] = "gfx1151"

    # Disable split kernel compilation in CI to use direct hipcc compilation
    runtime_ldflags = "-Wl,-rpath,#{formula_opt_lib("rocm-runtime")}"
    system "make", "engine", "SPLIT=0", "ROCM_PATH=#{rocm}", "HIPCC=#{hipcc}", "GPU_ARCH=gfx1151",
           "LDFLAGS=#{runtime_ldflags}"

    bin.install "build/engine/crucible" => "crucible-strix-halo"

    if File.exist?("server/server.py")
      (libexec/"server").install Dir["server/*"]
      (bin/"crucible-strix-halo-server").write <<~SH
        #!/bin/bash
        exec "#{formula_opt_bin("python@3.12")}/python3" "#{libexec}/server/server.py" "$@"
      SH
      chmod 0755, bin/"crucible-strix-halo-server"
    end

    runtime_rpath = "#{formula_opt_lib("rocm-runtime")}:#{HOMEBREW_PREFIX}/lib"
    system "patchelf", "--set-rpath", runtime_rpath, bin/"crucible-strix-halo"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:          "rocm",
      gpu_arch:         "gfx1151",
      rocm_root:        rocm,
      hipcc:            hipcc,
      ldflags:          runtime_ldflags,
      rpath_limitation: "upstream flags may leave the SDK RUNPATH; installed ELF RPATH is normalized with patchelf",
      commit:           "aac3e4894a695fbf0db10c2de5607c9c2e6906f5",
    )
  end

  def caveats
    <<~EOS
      crucible-strix-halo is compiled natively for AMD Strix Halo (gfx1151).
      The installed binary RPATH is normalized to the shared
      heretek-ai/tap/rocm-runtime with patchelf, even if the upstream Makefile
      leaves the ROCm SDK RUNPATH in place.
      Run the engine verification harness:
        crucible-strix-halo --help
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("ldd #{bin}/crucible-strix-halo")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    # 2. CLI Introspection
    assert_match(/crucible|usage/i, shell_output("#{bin}/crucible-strix-halo --help 2>&1"))

    # 3. Device Discovery Smoke Test
    probe = shell_output("#{bin}/crucible-strix-halo --list-devices 2>&1", nil)
    assert $CHILD_STATUS.exitstatus < 128, "Device probe crashed: #{probe}"
  end
end
