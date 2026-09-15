class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Darwin-macOS-26.5.2-arm64.zip"
  version "869"
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
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-869-07a85c7/sd-master-07a85c7-bin-Darwin-macOS-26.6.2-arm64.zip"
      sha256 "0fc228abbfbf3fffd9c62c498136a9448e8e8cb5f5f29091748731cf587a4859"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "rocm"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-869-07a85c7/sd-master-07a85c7-bin-Linux-Ubuntu-24.04-x86_64-rocm-7.14.0.zip"
        sha256 "18b1e2295608f64458d63e167bb5fc722e30c1307e1691f556968fab7397c070"
      elsif build.with? "cpu"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-869-07a85c7/sd-master-07a85c7-bin-Linux-Ubuntu-24.04-x86_64.zip"
        sha256 "38dfa88068f0beef416763c96154fc3f24ad8284fa1864fe3118280ef28093ce"
      else
        # Default: Mesa RADV / Vulkan universal acceleration
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-869-07a85c7/sd-master-07a85c7-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
        sha256 "550b4b3bb0b0e98c13ba7569e39e2ec90b9f8fa9e3dd641689e835278000555f"
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
