class Zinc < Formula
  desc "Zig inference engine with ROCm, Vulkan, and Metal backends"
  homepage "https://github.com/zolotukhin/zinc"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  option "with-vulkan", "Install the Vulkan build instead of the ROCm/HIP build"

  depends_on arch: :x86_64
  depends_on :linux

  on_linux do
    on_intel do
      if build.with? "vulkan"
        url "https://github.com/zolotukhin/zinc/releases/download/v0.1.1/zinc-v0.1.1-linux-x86_64-vulkan.tar.gz"
        sha256 "b1367bb8c0296f7d2f68bc6a27345228eedac4929d6892a60986223a1f9a5179"
      else
        url "https://github.com/zolotukhin/zinc/releases/download/v0.1.1/zinc-v0.1.1-linux-x86_64-rocm.tar.gz"
        sha256 "fd5a70764fbd92396b8c23cfb8e2772c99bbedb54478aeebd17dd6232b16e97f"
      end
    end
  end

  def install
    libexec.install Dir["*"]
    chmod 0755, [libexec/"bin/zinc", libexec/"bin/zinc-tokenize"]

    bin.install_symlink libexec/"bin/zinc"
    bin.install_symlink libexec/"bin/zinc-tokenize"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant: build.with?("vulkan") ? "vulkan" : "rocm",
      version: version,
      arch:    Hardware::CPU.arch.to_s,
    )
  end

  def caveats
    <<~EOS
      ZINC is a single-backend binary. The default install uses ROCm/HIP and
      needs a matching ROCm runtime (libamdhip64, libhipblas, libhiprtc) plus
      its runtime-compilation headers. Install with --with-vulkan (after
      uninstalling the default build) for the Vulkan variant, which needs a
      Vulkan loader and ICD instead.

      The HTTP server binds all interfaces; the upstream binary has no --host
      flag. The tap service passes --port 18009 (the upstream default is 8080).
      Use a host firewall if the API must stay loopback-only.

      Select a model before starting the service:
        zinc model pull qwen35-9b-q4k-m
        zinc model use qwen35-9b-q4k-m
        brew services start zinc
    EOS
  end

  service do
    run [opt_bin/"zinc", "serve", "--port", "18009"]
    keep_alive false
    working_dir var
    log_path var/"log/zinc.log"
    error_log_path var/"log/zinc.log"
  end

  test do
    # 1. Dynamic Linker & ABI Audit (ROCm libraries are external)
    ldd_out = shell_output("ldd #{libexec}/bin/zinc 2>&1")
    missing = ldd_out.lines.grep(/not found/).map(&:strip)
    unexpected = missing.grep_v(/\Alib(amdhip64|hipblas|hiprtc|vulkan)\.so/)
    assert_empty unexpected, "Unexpected missing libraries: #{unexpected.join(", ")}"

    # 2. CLI Introspection (only when the selected backend runtime is present)
    manifest = JSON.parse((pkgshare/"build-manifest.json").read)
    loader = Utils.popen_read("ldconfig", "-p")
    runtime_present = if manifest["variant"] == "vulkan"
      loader.include?("libvulkan.so.1")
    else
      loader.include?("libhipblas.so.3") || [
        "/opt/rocm/lib/libhipblas.so.3",
        "/opt/rocm/lib64/libhipblas.so.3",
        "/usr/lib/libhipblas.so.3",
        "/usr/lib64/libhipblas.so.3",
      ].any? { |path| File.exist?(path) }
    end

    if runtime_present
      assert_match "zinc #{version}", shell_output("#{bin}/zinc --version 2>&1")
      assert_match(/Usage:\s+zinc/m, shell_output("#{bin}/zinc --help 2>&1"))
    else
      opoo "#{manifest["variant"]} runtime not found; skipping the ZINC CLI execution checks."
    end

    # 3. Runtime Assets and Tokenizer
    assert_predicate libexec/"share/zinc", :directory?
    assert_path_exists bin/"zinc-tokenize"
  end
end
