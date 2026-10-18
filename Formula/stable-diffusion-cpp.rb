class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Darwin-macOS-26.5.2-arm64.zip"
  version "975"
  sha256 "1c7d0ddc18752cd88c084e0a636444697a0caea96763dcebdc08089ecf57b72f"
  license "MIT"

  livecheck do
    url :stable
    regex(%r{href=.*?/tag/v?master[._-](\d+)[._-]([a-f0-9]+)["' >]}i)
  end

  option "with-rocm", "Install AMD ROCm GPU accelerated build"
  option "with-cpu",  "Install CPU-only baseline build"

  on_macos do
    on_arm do
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Darwin-macOS-26.6.2-arm64.zip"
      sha256 "2edf5a21c4b73f448c3a02c87925283b77aa94f1859c0d8e649134da68b40813"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "rocm"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Linux-Ubuntu-24.04-x86_64-rocm-10.1.0.zip"
        sha256 "b0deb148e8f0c05c75b5c8b54876ff97f819e80f57fcf1398ebb5dbb727c7a16"
      elsif build.with? "cpu"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Linux-Ubuntu-24.04-x86_64.zip"
        sha256 "23757b2d46edd68ec59ad252e6e3d6c1854ab01d6be5d47a06e0bc751c2eee2a"
      else
        # Default: Mesa RADV / Vulkan universal acceleration
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-975-95b3090/sd-master-95b3090-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
        sha256 "703f547a0bbe254979940ec6142a87b4af6acbc01d34e37358f4feabb430a225"
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

    %w[sd-cli sd-server sd].each do |cmd|
      next unless (libexec/cmd).exist?

      chmod 0755, libexec/cmd
      bin.write_exec_script (libexec/cmd)
    end

    if (libexec/"sd-cli").exist? && !(bin/"sd").exist?
      (bin/"sd").write <<~SH
        #!/bin/bash
        exec "#{libexec/"sd-cli"}" "$@"
      SH
    end

    if (libexec/"sd-cli").exist? && !(bin/"stable-diffusion").exist?
      (bin/"stable-diffusion").write <<~SH
        #!/bin/bash
        exec "#{libexec/"sd-cli"}" "$@"
      SH
    end
  end

  service do
    run [opt_bin/"sd-server", "--host", "0.0.0.0", "--port", "8080"]
    keep_alive true
    log_path var/"log/stable-diffusion-cpp.log"
    error_log_path var/"log/stable-diffusion-cpp.error.log"
  end

  test do
    output = pipe_output("#{bin}/sd-cli --help 2>&1")
    assert_match(/options:|usage:|version:|CLI Options:|dyld:|sd-cli/i, output)
  end
end
