class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Darwin-macOS-26.5.2-arm64.zip"
  version "841"
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
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Darwin-macOS-26.5.2-arm64.zip"
      sha256 "1c7d0ddc18752cd88c084e0a636444697a0caea96763dcebdc08089ecf57b72f"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "rocm"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Linux-Ubuntu-24.04-x86_64-rocm-7.14.0.zip"
        sha256 "9493dd5feed685a79b7c5f31b342b28ad88cb048549a49cdd545e4ba574a7e15"
      elsif build.with? "cpu"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Linux-Ubuntu-24.04-x86_64.zip"
        sha256 "66998807a8b21b6d00358310a23791c67d2e68f7e1820d99d5c9ac12738d882e"
      else
        # Default: Mesa RADV / Vulkan universal acceleration
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
        sha256 "abf07bb51605a647fd874d766d71ad2bbd21b01a26fafd2c30d63259c1e34f44"
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
    assert_match "CLI Options:", pipe_output("#{bin}/sd-cli --help 2>&1")
  end
end
