# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "English"

module Homebrew
  module Cmd
    # Diagnose accelerator hardware and recommend formulae from the Heretek-AI tap.
    class Heretek < AbstractCommand
      TAP = "heretek-ai/tap"

      STRIX_HALO_FORMULAE = %w[
        crucible-strix-halo
        gufetto
        gufo
        gufo-franzmoca
        kyojin
        libosmos
        qwenox
        rocmfpx
        snowllm
        strixite
      ].freeze

      RDNA3_FORMULAE = %w[
        hipfire
        nib
        project-maya
        rocmfpx
        stable-diffusion-cpp
        strata
        zinc
      ].freeze

      RDNA4_FORMULAE = %w[
        hipfire
        project-maya
        rocmfpx
        strata
      ].freeze

      BLACKWELL_FORMULAE = %w[
        basalt
        hyperqwen
        lucebox
      ].freeze

      CUDA_8_9_FORMULAE = %w[
        hyperqwen
        lucebox
        shimmy
      ].freeze

      APPLE_SILICON_FORMULAE = %w[
        colibri
        gemma-cpp
        infr
        magnitude
        project-maya
        saient-quartz
        shimmy
        stable-diffusion-cpp
        strata
        uzu
      ].freeze

      CPU_VULKAN_FORMULAE = %w[
        colibri
        gemma-cpp
        infr
        saient-quartz
        shimmy
        stable-diffusion-cpp
        zinc
      ].freeze

      TTM_MIN_GIB = 24
      PAGE_SIZE_BYTES = 4096

      cmd_args do
        usage_banner <<~EOS
          `heretek` <subcommand>

          Inspect accelerator hardware and recommend formulae from the Heretek-AI tap.
        EOS
        description <<~EOS
          Run a diagnostic or print install recommendations for this machine.

          Subcommands:
            doctor      Report OS, CPU, memory, AMD ROCm, NVIDIA CUDA, Apple Metal,
                        Vulkan, and tap runtime status with actionable next steps.
            recommend   Detect the GPU family and print exact `brew install` commands
                        plus the matching curated Brewfile when one exists.

          The command never fails because a GPU or tool is absent.
        EOS

        named_args :subcommand, min: 0, max: 1
      end

      def run
        case args.named.first
        when "doctor"
          doctor
        when "recommend"
          recommend
        when nil
          odie "A subcommand is required. Use `brew heretek doctor` or `brew heretek recommend`."
        else
          odie "Unknown subcommand `#{args.named.first}`. " \
               "Use `brew heretek doctor` or `brew heretek recommend`."
        end
      end

      private

      def doctor
        ohai "System"
        puts "OS:       #{OS.kernel_name} #{OS.kernel_version} (#{Hardware::CPU.arch})"
        puts "CPU:      #{cpu_model}"
        puts "Memory:   #{total_memory}"
        puts

        ohai "AMD ROCm"
        amd_targets = amd_gfx_targets
        rocminfo = which("rocminfo")
        if rocminfo
          output = command_output("rocminfo")
          if amd_targets.empty?
            detail = output.gsub(/\e\[[0-9;]*m/, "").lines.find do |line|
              line.match?(/module is not loaded|no gpu|no device|error|failed/i)
            end
            puts "rocminfo:      no usable GPU device detected"
            puts "               #{detail.strip}" if detail
          else
            puts "rocminfo:      gfx target(s) #{amd_targets.join(", ")}"
          end
        else
          puts "rocminfo:      not installed"
        end

        rocm_dirs = ["/opt/rocm", "/opt/rocm-nightly"].select { |dir| Dir.exist?(dir) }
        rocm_status = rocm_dirs.empty? ? "not present" : rocm_dirs.join(", ")
        puts "/opt/rocm:     #{rocm_status}"
        puts "ROCM_PATH:     #{ENV.fetch("ROCM_PATH", "not set")}"

        if which("hipcc")
          hipcc_version = command_output("hipcc", "--version").lines.first&.strip
          hipcc_status = hipcc_version.presence || "installed"
          puts "hipcc:         #{hipcc_status}"
        else
          puts "hipcc:         not installed"
        end

        amdhip = library_matches("libamdhip64.so")
        amdhip_status = amdhip.empty? ? "not found" : amdhip.first
        puts "libamdhip64:   #{amdhip_status}"

        ttm = ttm_pages_limit
        if ttm.nil?
          puts "ttm pages:     not exposed by this kernel"
        else
          gib = (ttm * PAGE_SIZE_BYTES) / (1024.0**3)
          puts "ttm pages:     #{ttm} pages (~#{format("%.1f", gib)} GiB)"
          if ttm.zero? || gib < TTM_MIN_GIB
            suggested = (TTM_MIN_GIB * (1024**3)) / PAGE_SIZE_BYTES
            puts "               Recommendation: raise TTM for large model weights, for example"
            puts "               `ttm.pages_limit=#{suggested}` (24 GiB at 4 KiB pages) on the"
            puts "               kernel command line, then reboot. Only AMD GPUs use TTM."
          end
        end
        puts

        ohai "NVIDIA CUDA"
        nvidia_gpus = nvidia_devices
        if nvidia_gpus.empty?
          nvidia_status = which("nvidia-smi") ? "no GPU detected" : "not installed"
          puts "nvidia-smi:    #{nvidia_status}"
        else
          nvidia_gpus.each do |gpu|
            puts "GPU:           #{gpu[:name]} (#{gpu[:memory]}, driver #{gpu[:driver]}, " \
                 "compute #{gpu[:compute]})"
          end
        end

        if which("nvcc")
          nvcc_version = command_output("nvcc", "--version").lines.grep(/release/i).first&.strip
          nvcc_status = nvcc_version.presence || "installed"
          puts "nvcc:          #{nvcc_status}"
        else
          puts "nvcc:          not installed"
        end

        cudart = library_matches("libcudart.so.13")
        cublas = library_matches("libcublas.so.13")
        cudart_status = cudart.empty? ? "not found" : cudart.first
        cublas_status = cublas.empty? ? "not found" : cublas.first
        puts "libcudart.so.13: #{cudart_status}"
        puts "libcublas.so.13: #{cublas_status}"
        if cudart.empty? || cublas.empty?
          puts "               Install `brew install #{TAP}/cuda-runtime` or a CUDA 13 toolkit."
        end
        puts

        ohai "Apple Metal"
        if OS.mac? && which("system_profiler")
          output = command_output("system_profiler", "SPDisplaysDataType")
          metal = output[/Metal(?: Support)?:\s*(.+)/i, 1]
          metal_status = metal&.strip || "not reported by system_profiler"
          puts "Metal:         #{metal_status}"
        elsif OS.mac?
          puts "system_profiler: not installed"
        else
          puts "Not applicable on #{OS.kernel_name}."
        end
        puts

        ohai "Vulkan"
        vulkaninfo_status = which("vulkaninfo") ? "installed" : "not installed"
        puts "vulkaninfo:    #{vulkaninfo_status}"
        vulkan = library_matches("libvulkan.so")
        vulkan_status = vulkan.empty? ? "not found" : vulkan.first
        puts "libvulkan.so:  #{vulkan_status}"
        puts

        ohai "Tap runtimes"
        installed = {}
        %w[rocm-runtime cuda-runtime].each do |runtime|
          opt = HOMEBREW_PREFIX/"opt"/runtime
          prefix = if opt.directory?
            opt.to_s
          else
            Dir.glob((HOMEBREW_PREFIX/"Cellar"/runtime/"*").to_s).max
          end
          installed[runtime] = !prefix.nil?
          if prefix
            puts "#{runtime}: installed (#{prefix})"
          else
            puts "#{runtime}: not installed"
            puts "  brew install #{TAP}/#{runtime}"
          end
        end
        puts

        ohai "Next steps"
        steps = []
        if amd_targets.any? && !installed["rocm-runtime"]
          steps << "Install the shared ROCm runtime: `brew install #{TAP}/rocm-runtime`."
        end
        if nvidia_gpus.any? && !installed["cuda-runtime"]
          steps << "Install the shared CUDA runtime: `brew install #{TAP}/cuda-runtime`."
        end
        if amd_targets.any? && ttm && (ttm.zero? || (ttm * PAGE_SIZE_BYTES) / (1024.0**3) < TTM_MIN_GIB)
          suggested = (TTM_MIN_GIB * (1024**3)) / PAGE_SIZE_BYTES
          steps << "For AMD GPUs with large models, set `ttm.pages_limit=#{suggested}` and reboot."
        end
        if amd_targets.empty? && nvidia_gpus.empty?
          steps << "No AMD or NVIDIA device was detected; the CPU/Vulkan formulae still work."
        end
        steps << "Get a complete formula set: `brew heretek recommend`."
        steps << "Browse the curated bundles in `Brewfiles/` and use `brew bundle --file=...`."

        steps.each_with_index do |step, index|
          number = index + 1
          puts "#{number}. #{step}"
        end
      end

      def recommend
        amd_targets = amd_gfx_targets
        nvidia_gpus = nvidia_devices
        apple_silicon = OS.mac? && Hardware::CPU.arm?
        vulkan_detected = !which("vulkaninfo").nil? || library_matches("libvulkan.so").any?

        amd_description = if amd_targets.empty?
          "rocminfo unavailable or no device detected"
        else
          amd_targets.join(", ")
        end
        nvidia_description = if nvidia_gpus.empty?
          "nvidia-smi unavailable or no device detected"
        else
          nvidia_gpus.map { |gpu| "#{gpu[:name]} (compute #{gpu[:compute]})" }.join(", ")
        end
        apple_description = apple_silicon ? "yes (#{Hardware::CPU.arch})" : "no"
        vulkan_description = vulkan_detected ? "detected" : "not detected"

        puts "Detected hardware:"
        puts "  AMD ROCm: #{amd_description}"
        puts "  NVIDIA CUDA: #{nvidia_description}"
        puts "  Apple Silicon: #{apple_description}"
        puts "  Vulkan loader: #{vulkan_description}"
        puts

        profiles = []

        if amd_targets.include?("gfx1151")
          profiles << ["AMD Strix Halo (gfx1151)", STRIX_HALO_FORMULAE, "rocm-runtime", "strix-halo"]
        end

        if amd_targets.any? { |target| target.start_with?("gfx110") }
          profiles << ["AMD RDNA3 (gfx1100 family)", RDNA3_FORMULAE, "rocm-runtime", "rdna3"]
        end

        if amd_targets.any? { |target| target.start_with?("gfx120") }
          profiles << ["AMD RDNA4 (gfx1200 family)", RDNA4_FORMULAE, "rocm-runtime", nil]
        end

        if nvidia_gpus.any?
          max_compute = nvidia_gpus.map { |gpu| gpu[:compute].to_f }.max

          if max_compute >= 12.0
            profiles << ["NVIDIA Blackwell (CUDA sm_120+)", BLACKWELL_FORMULAE, "cuda-runtime", "blackwell"]
          elsif max_compute >= 8.0
            profiles << ["NVIDIA CUDA 8.x/9.x", CUDA_8_9_FORMULAE, "cuda-runtime", nil]
          end
        end

        if apple_silicon
          profiles << ["Apple Silicon (Metal)", APPLE_SILICON_FORMULAE, nil, "apple-silicon"]
        end

        profiles << ["CPU / Vulkan fallback", CPU_VULKAN_FORMULAE, nil, nil] if profiles.empty?

        profiles.each do |name, formulae, runtime, brewfile|
          puts "Recommended profile: #{name}"
          puts "  brew install #{TAP}/#{runtime}" if runtime
          formulae.sort.each do |formula|
            puts "  brew install #{TAP}/#{formula}"
          end
          if name == "NVIDIA CUDA 8.x/9.x"
            puts "  Note: shimmy uses its CPU build on Linux in this tap; Metal is used on macOS."
          end
          if brewfile
            puts "  Brewfile: Brewfiles/#{brewfile}.Brewfile"
            puts "  Install the set: brew bundle --file=Brewfiles/#{brewfile}.Brewfile"
          else
            puts "  Brewfile: no curated Brewfile matches this profile; use the install lines above."
          end
          puts
        end

        puts "Run `brew heretek doctor` for full hardware diagnostics."
      end

      def cpu_model
        if OS.mac?
          model = command_output("sysctl", "-n", "machdep.cpu.brand_string").strip
          return model if model.present?
        elsif OS.linux?
          line = File.readlines("/proc/cpuinfo", chomp: true).find { |entry| entry.start_with?("model name") }
          return line.split(":", 2).last.strip if line
        end

        "unknown"
      rescue
        "unknown"
      end

      def total_memory
        bytes = if OS.mac?
          command_output("sysctl", "-n", "hw.memsize").strip.to_i
        elsif OS.linux?
          meminfo = File.read("/proc/meminfo")
          meminfo[/^MemTotal:\s+(\d+) kB/, 1].to_i * 1024
        else
          0
        end

        return "unknown" if bytes.zero?

        format("%.1f GiB", bytes / (1024.0**3))
      rescue
        "unknown"
      end

      def amd_gfx_targets
        return [] unless which("rocminfo")

        command_output("rocminfo").scan(/gfx[0-9a-f]+/i).map(&:downcase).uniq.sort
      end

      def nvidia_devices
        return [] unless which("nvidia-smi")

        output = Utils.popen_read(
          "nvidia-smi",
          "--query-gpu=name,memory.total,driver_version,compute_cap",
          "--format=csv,noheader",
          err: File::NULL,
        )
        status = $CHILD_STATUS
        return [] unless status&.success?

        output.lines.filter_map do |line|
          name, memory, driver, compute = line.strip.split(",", 4).map(&:strip)
          next if name.blank?

          { name: name, memory: memory, driver: driver, compute: compute }
        end
      rescue
        []
      end

      def ttm_pages_limit
        path = "/sys/module/ttm/parameters/pages_limit"
        return unless File.exist?(path)

        File.read(path).strip.to_i
      rescue
        nil
      end

      def command_output(*args)
        Utils.popen_read(*args, err: :out).to_s
      rescue
        ""
      end

      def library_matches(soname)
        matches = []

        if which("ldconfig")
          Utils.popen_read("ldconfig", "-p", err: File::NULL).each_line do |line|
            matches << line.strip if line.include?(soname)
          end
        end

        %w[
          /usr/local/cuda/lib64
          /usr/local/cuda/targets/x86_64-linux/lib
          /usr/local/cuda/targets/aarch64-linux/lib
          /usr/local/cuda-13.0/lib64
          /opt/cuda/lib64
          /usr/lib/x86_64-linux-gnu
          /usr/lib/aarch64-linux-gnu
          /usr/lib64
          /lib64
          /usr/lib
        ].each do |directory|
          Dir.glob(File.join(directory, "#{soname}*")).each { |path| matches << path }
        end

        matches.uniq.sort
      rescue
        []
      end
    end
  end
end
