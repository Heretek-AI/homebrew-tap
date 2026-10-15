class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Darwin-macOS-26.5.2-arm64.zip"
  version "968"
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
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-968-8cd731e/sd-master-8cd731e-bin-Darwin-macOS-26.6.2-arm64.zip"
      sha256 "767ce7a876fe4e6727c2020bc0593dd809d6a43a6a8b495c92837bf7449b9068"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "rocm"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-968-8cd731e/sd-master-8cd731e-bin-Linux-Ubuntu-24.04-x86_64-rocm-10.1.0.zip"
        sha256 "63cafa87f8ab6c28a261fd437109b6845a8eb706fcce7a3f13a811dba6e0cb77"
      elsif build.with? "cpu"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-968-8cd731e/sd-master-8cd731e-bin-Linux-Ubuntu-24.04-x86_64.zip"
        sha256 "27362e7b6d2c2bc1f56a38a65f74c270abb7f7fa2e3bd07be82be0b3c8de7abc"
      else
        # Default: Mesa RADV / Vulkan universal acceleration
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-968-8cd731e/sd-master-8cd731e-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
        sha256 "1e82f932a678e28035d64bc9909b9c122c6ec0f92fcfd8e9ac2bea99b5619505"
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
