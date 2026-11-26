class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  version "1141"
  license "MIT"

  livecheck do
    skip "Rolling releases are updated by the autobump workflow."
  end

  option "with-rocm", "Install AMD ROCm GPU accelerated build"
  option "with-cpu",  "Install CPU-only baseline build"

  on_macos do
    on_arm do
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Darwin-macOS-26.7.2-arm64.zip"
      sha256 "50f4fe2d0b28e9c3a1155cdab859042c3355e543792b07da760c6aba56d18380"
    end
  end

  on_linux do
    on_intel do
      if build.with? "rocm"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-24.04-x86_64-rocm-10.1.0.zip"
        sha256 "14a279ef592e1f0d296835bea8005b3e57547de1665e6e53601d1d8e7b19f160"
      elsif build.with? "cpu"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64.zip"
        sha256 "abe1561e7b706394a1a242c4d9480cc0391845dbc28dcd258843e98eb7948010"
      else
        # Default: Mesa RADV / Vulkan universal acceleration
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-1141-e637c7b/sd-master-e637c7b-bin-Linux-Ubuntu-26.04-x86_64-vulkan.zip"
        sha256 "70c577cfe447f3550a93e3973cc67f635e2f2676b4ada9c92b2e2b52a90f6bbc"
      end
    end
  end

  def install
    if (buildpath/"build/bin").directory?
      libexec.install Dir["build/bin/*"]
    elsif (buildpath/"bin").directory?
      libexec.install Dir["bin/*"]
    else
      libexec.install Dir["*"]
    end

    chmod 0755, Dir[libexec/"*"]

    %w[sd-cli sd-server].each do |cmd|
      next unless (libexec/cmd).exist?

      chmod 0755, libexec/cmd
      bin.install_symlink libexec/cmd
    end

    bin.install_symlink libexec/"sd-cli" => "stable-diffusion" if (libexec/"sd-cli").exist?
  end

  service do
    run [opt_bin/"sd-server", "--host", "127.0.0.1", "--port", "8080"]
    keep_alive true
    log_path var/"log/stable-diffusion-cpp.log"
    error_log_path var/"log/stable-diffusion-cpp.error.log"
  end

  test do
    if OS.linux? && File.exist?(bin/"sd-cli")
      out = shell_output("ldd #{bin}/sd-cli")
      refute_match(/not found/, out)
    elsif OS.mac? && File.exist?(bin/"sd-cli")
      out = shell_output("otool -L #{bin}/sd-cli")
      refute_match(/not found/, out)
    end

    output = pipe_output("#{bin}/sd-cli --help 2>&1")
    assert_match(/options:|usage:|version:|CLI Options:|dyld:|sd-cli/i, output)
  end
end
