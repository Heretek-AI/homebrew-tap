class Hipfire < Formula
  desc "Native LLM inference engine for AMD RDNA and CDNA GPUs"
  homepage "https://github.com/warpfront/hipfire"
  license "Apache-2.0"

  livecheck do
    url :stable
    strategy :github_latest
  end

  option "with-gfx1100", "Install the gfx1100 (RDNA3) kernel pack"
  option "with-gfx1201", "Install the gfx1201 (RDNA4) kernel pack"
  option "with-gfx906",  "Install the gfx906 (Vega 20 / GCN5) kernel pack"

  depends_on arch: :x86_64
  depends_on :linux

  on_linux do
    on_intel do
      url "https://github.com/warpfront/hipfire/releases/download/v0.4.8/hipfire-v0.4.8-linux-rocm-gfx1151-x64.tar.gz"
      sha256 "be498c980456f4b53d7b558beab40557a68e363edfe86181705ec6ddce50b0ab"
    end
  end

  kernel_shas = {
    "gfx1100" => "e008fd7fde80cda1f49035719ab4e518d286279d18f62faaf7a94fd8f9cc259b",
    "gfx1151" => "5a1e7a2e4a9afb25db757aca89a5ce6ec6e11d98961b3c9499da71d7b7b335d4",
    "gfx1201" => "f9b0a346aa75dbe2516198283415037b7aba4bb8a7c0907676fbf082b73d67fc",
    "gfx906"  => "419bad5a2c6b9f4f7bc92847792f6e36ebdb1eea6b1a8d9424d32b74585ac2b1",
  }
  kernel_pack = %w[gfx1100 gfx1201 gfx906].find { |arch| build.with?(arch) } || "gfx1151"

  resource "kernels-#{kernel_pack}" do
    url "https://github.com/warpfront/hipfire/releases/download/v0.4.8/hipfire-kernels-v0.4.8-#{kernel_pack}.tar.gz"
    sha256 kernel_shas.fetch(kernel_pack)
  end

  def install
    selected = %w[gfx1100 gfx1201 gfx906].select { |arch| build.with?(arch) }
    odie "Select at most one of --with-gfx1100, --with-gfx1201, or --with-gfx906" if selected.length > 1

    kernel_arch = selected.first || "gfx1151"

    libexec.install Dir["*"]
    chmod 0755, [libexec/"bin/hipfire", libexec/"bin/daemon"]

    rm_r libexec/"bin/kernels/compiled"
    resource("kernels-#{kernel_arch}").stage do
      (libexec/"bin/kernels/compiled").install kernel_arch
      (libexec/"bin/kernels/compiled").install "manifest.json" => "#{kernel_arch}.manifest.json"
    end

    bin.install_symlink libexec/"bin/hipfire"

    (pkgshare/"build-manifest.json").write JSON.pretty_generate(
      variant:       "rocm",
      version:       version,
      arch:          Hardware::CPU.arch.to_s,
      kernel_arch:   kernel_arch,
      kernel_source: "release-pack",
    )
  end

  def caveats
    <<~EOS
      hipfire loads the ROCm HIP runtime dynamically. It needs ROCm 7.2 or newer
      for Strix Halo (gfx1151) and ROCm 6.4 or newer for RDNA4 (gfx1201).

      The default install targets gfx1151. Install with one of
      --with-gfx1100, --with-gfx1201, or --with-gfx906 to select a different
      prebuilt kernel pack. Uninstall the previous build before switching packs.

      Pull a model and start the loopback daemon:
        hipfire pull qwen3.8:27b-mq4-xts
        hipfire serve 127.0.0.1:18011 --no-prewarm
      The service listens on 127.0.0.1:18011. hipfire has no --port flag, so the
      port is set with the documented positional HOST:PORT bind.
    EOS
  end

  service do
    run [opt_bin/"hipfire", "serve", "127.0.0.1:18011", "--no-prewarm"]
    keep_alive true
    working_dir var
    log_path var/"log/hipfire.log"
    error_log_path var/"log/hipfire.log"
  end

  test do
    # 1. Dynamic Linker & ABI Audit (ROCm is loaded dynamically)
    ldd_out = shell_output("ldd #{libexec}/bin/hipfire 2>&1")
    refute_match(/not found/, ldd_out)
    daemon_ldd_out = shell_output("ldd #{libexec}/bin/daemon 2>&1")
    refute_match(/not found/, daemon_ldd_out)

    # 2. CLI Introspection
    assert_match "hipfire #{version}", shell_output("#{bin}/hipfire --version")
    assert_match(/Usage: hipfire/i, shell_output("#{bin}/hipfire --help 2>&1"))

    # 3. Kernel Pack Layout
    manifest = JSON.parse((pkgshare/"build-manifest.json").read)
    kernel_arch = manifest["kernel_arch"]
    assert_predicate libexec/"bin/kernels/compiled/#{kernel_arch}", :directory?
    assert_predicate libexec/"bin/kernels/compiled/#{kernel_arch}.manifest.json", :file?
  end
end
