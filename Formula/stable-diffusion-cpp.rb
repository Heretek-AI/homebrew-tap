class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Darwin-macOS-26.5.2-arm64.zip"
  version "866"
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
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-866-42d6c0a/sd-master-42d6c0a-bin-Darwin-macOS-26.6.2-arm64.zip"
      sha256 "ff6a473344c4b339f9066bfc3026b73359bec3ed697ba2db5f2bcd041ec01d78"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "rocm"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-866-42d6c0a/sd-master-42d6c0a-bin-Linux-Ubuntu-24.04-x86_64-rocm-7.14.0.zip"
        sha256 "cf032ad0bc8c243dcf32ea75a77db8fb9452443221d9d6d89f8fdd3a4c71dc99"
      elsif build.with? "cpu"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-866-42d6c0a/sd-master-42d6c0a-bin-Linux-Ubuntu-24.04-x86_64.zip"
        sha256 "7480a7097cd3bd91627dd4d806af7e273f0b9f8dfdd4b37be47bfccdae693f06"
      else
        # Default: Mesa RADV / Vulkan universal acceleration
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-866-42d6c0a/sd-master-42d6c0a-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
        sha256 "e219ff6124abf367b5ef7089b10cc1efd870478cece4561ed18a828f0a2b2292"
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
