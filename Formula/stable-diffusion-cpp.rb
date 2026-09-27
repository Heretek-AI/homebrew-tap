class StableDiffusionCpp < Formula
  desc "Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++"
  homepage "https://github.com/leejet/stable-diffusion.cpp"
  url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-841-6b3edaa/sd-master-6b3edaa-bin-Darwin-macOS-26.5.2-arm64.zip"
  version "929"
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
      url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-929-3f8527a/sd-master-3f8527a-bin-Darwin-macOS-26.6.2-arm64.zip"
      sha256 "1c8ee6c8e413e3335b1223bbc657ea5d86dae1819f8426a98b84c265587eb192"
    end
  end

  on_linux do
    if Hardware::CPU.intel?
      if build.with? "rocm"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-929-3f8527a/sd-master-3f8527a-bin-Linux-Ubuntu-24.04-x86_64-rocm-7.14.0.zip"
        sha256 "b4877986cc25cc04decc073874eed5ea411fc0bb19f5338f0ea3511a8e8b1c58"
      elsif build.with? "cpu"
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-929-3f8527a/sd-master-3f8527a-bin-Linux-Ubuntu-24.04-x86_64.zip"
        sha256 "9ad35ed309dbe59f5e66f35edafac9a69e6cc233ea6b9577071feae829159d37"
      else
        # Default: Mesa RADV / Vulkan universal acceleration
        url "https://github.com/leejet/stable-diffusion.cpp/releases/download/master-929-3f8527a/sd-master-3f8527a-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
        sha256 "e35cc73cf5ba9637d1dc1d717760e7b8428376a4905d57e72ec8c871864f62c7"
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
