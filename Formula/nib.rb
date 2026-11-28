class Nib < Formula
  desc "C++17 HIP inference engine for Inkling 2 Mini on AMD RDNA3"
  homepage "https://github.com/Chromadera/nib"
  url "https://github.com/Chromadera/nib/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "cc774dc9f934b72d6c6258f3f533f913e49857b10a16ffc84bfd25dfcf45949a"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "cmake" => :build
  depends_on "patchelf" => :build
  depends_on arch: :x86_64
  depends_on "heretek-ai/tap/rocm-runtime"
  depends_on :linux

  def rocm_root
    [ENV["HOMEBREW_ROCM_PATH"], ENV["ROCM_PATH"], "/opt/rocm", "/usr"]
      .compact.find do |path|
        File.exist?("#{path}/include/hip/hip_runtime.h") &&
          !Dir["#{path}/lib*/libamdhip64.so*"].empty?
      end ||
      odie("ROCm installation not found. Set HOMEBREW_ROCM_PATH to a ROCm SDK with HIP headers and libamdhip64.")
  end

  def install
    rocm = rocm_root
    hipcc = "#{rocm}/bin/hipcc"
    unless File.executable?(hipcc)
      odie("hipcc not found at #{hipcc}. Install the HIP compiler or set HOMEBREW_ROCM_PATH.")
    end

    ENV["ROCM_PATH"] = rocm
    ENV["HIP_PATH"] = rocm
    ENV.prepend_path "PATH", "#{rocm}/bin"

    args = %W[
      -DROCM_PATH=#{rocm}
      -DHIP_COMPILER=#{hipcc}
      -DGPU_TARGET=gfx1100
      -DCMAKE_INSTALL_RPATH=#{formula_opt_lib("rocm-runtime")};#{HOMEBREW_PREFIX}/lib
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    ]

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args
    system "cmake", "--build", "build", "--parallel", ENV.make_jobs.to_s

    bin.install "build/nib"

    runtime_rpath = "#{formula_opt_lib("rocm-runtime")}:#{HOMEBREW_PREFIX}/lib"
    system "patchelf", "--set-rpath", runtime_rpath, bin/"nib"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:      "rocm",
      version:      version,
      arch:         Hardware::CPU.arch.to_s,
      rocm_root:    rocm,
      hip_compiler: hipcc,
      gpu_target:   "gfx1100",
      runtime_lib:  formula_opt_lib("rocm-runtime").to_s,
      rpath:        runtime_rpath,
      cmake_args:   args,
    )
  end

  def caveats
    <<~EOS
      nib is built from source against the AMD ROCm installation selected by
      HOMEBREW_ROCM_PATH (falling back to ROCM_PATH, /opt/rocm, then /usr). It
      targets RDNA3 gfx1100 (Radeon RX 7900 XTX/XT and PRO W7900), compiles with
      hipcc, and requires ROCm 7.2 or newer. The compiled code objects are
      gfx1100-only; other GPUs will fail to load kernels.

      Model weights are not included (about 17.3 GiB). Download the Inkling 2
      Mini Nib pack from Hugging Face (degenmeowster/Inkling-2-Mini-Nib-Pack)
      and start the loopback server:
        nib serve -m models/Inkling-2-Mini-NVFP4-Mixed.gguf \\
          --mtp models/mtp.safetensors \\
          --mmproj models/mmproj-Inkling-2-Mini-Q8_0.gguf \\
          --host 127.0.0.1 --port 4444

      Full context needs about 22.2 GiB of VRAM (a 24 GB card is recommended).
      On 20 GB RX 7900 XT cards, nib auto-selects q4_1 KV and a smaller context.
    EOS
  end

  test do
    # 1. Dynamic Linker & ABI Audit
    out = shell_output("ldd #{bin}/nib 2>&1")
    refute_match(/not found/, out)
    assert_match(/libamdhip64\.so/, out)

    # 2. CLI Introspection
    assert_match "nib #{version} (gfx1100", shell_output("#{bin}/nib --version")
    assert_match(/Usage: .*nib/, shell_output("#{bin}/nib --help 2>&1"))

    # 3. Build Metadata
    manifest = JSON.parse((pkgshare/"build-manifest.json").read)
    assert_equal version.to_s, manifest["version"]
    assert_equal "gfx1100", manifest["gpu_target"]
  end
end
