# 🍺 Heretek-AI Homebrew Tap: High-Performance GPU Inference Engines

<div align="center">

[![Brew CI & Formula Audit](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml)
[![Auto-Bump Formulae](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/autobump.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/autobump.yml)
[![Build ROCmFPX](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/build-rocmfpx.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/build-rocmfpx.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![AMD ROCm 7.0](https://img.shields.io/badge/AMD%20ROCm-7.0%20Built--in-blue?logo=amd&logoColor=white)](https://github.com/ROCm/ROCm)
[![Apple Metal](https://img.shields.io/badge/Apple-Metal%20Accelerated-000000?logo=apple&logoColor=white)](https://developer.apple.com/metal/)
[![Mesa RADV Vulkan](https://img.shields.io/badge/Vulkan-Mesa%20RADV%20Wave64-FF5722?logo=vulkan&logoColor=white)](https://mesa3d.org)

<p align="center">
  <b>Zero-dependency, turnkey Homebrew tap delivering pre-compiled, GPU-accelerated builds of high-performance inference engines:</b><br/>
  <b><a href="#-rocmfpx-upstream">rocmfpx</a></b> (Canonical ROCm 7 llama.cpp Engine), <b><a href="#-stable-diffusion-cpp">stable-diffusion-cpp</a></b> (Diffusion Image & Video Inference), and <b><a href="#-shimmy">shimmy</a></b> (Pure-Rust WebGPU/CUDA Inference).
</p>

</div>

---

## ⚡ Quick Start

```bash
# 1. Tap the Heretek-AI repository
brew tap Heretek-AI/tap

# 2. Install your desired inference engine:
brew install rocmfpx              # Canonical ROCm 7 llama.cpp stack (AMD RDNA2..RDNA4 / CDNA)
brew install stable-diffusion-cpp # Fast SD, SDXL, Flux, SD3 & Wan image/video inference
brew install shimmy               # Pure-Rust WebGPU & CUDA LLM engine

# 3. Optional: Start background OpenAI-compatible server daemon (runs on boot):
brew services start rocmfpx
# or
brew services start stable-diffusion-cpp
# or
brew services start shimmy
```

> [!IMPORTANT]
> **⚡ Zero-Dependency Guarantee — Built-in ROCm™ 7 Runtimes**:  
> All Linux ROCm binaries bundle complete AMD ROCm 7 runtime libraries (`libhipblas.so`, `librocblas.so`, `libamdhip64.so`, `libhipblaslt.so`, and BLAS kernel packages) linked via portable `$ORIGIN` RPATHs. **No separate AMD ROCm™ SDK or driver installation is required!** Just install and run.

---

## 📊 At-a-Glance Engine Comparison

| Engine / Formula | Upstream Source | Primary Specialization | Key Highlights | Target Hardware & Backends |
| :--- | :--- | :--- | :--- | :--- |
| [**`rocmfpx`**](#-rocmfpx) | [`charlie12345/ROCmFPX`](https://github.com/charlie12345/ROCmFPX) | **Canonical ROCm 7 Engine** | • Official upstream ROCmFPX engine<br>• Active upstream `llama.cpp` synchronization<br>• High-performance MMQ/MMVQ ROCm 7 GPU acceleration<br>• Built in-repo across all AMD GFX targets | AMD Strix Halo (`gfx1151`), Strix Point (`gfx1150`), RDNA4 (`gfx120X`), RDNA3 (`gfx110X`), RDNA2 (`gfx103X`), CDNA (`gfx90a`, `gfx908`) |
| [**`stable-diffusion-cpp`**](#-stable-diffusion-cpp) | [`leejet/stable-diffusion.cpp`](https://github.com/leejet/stable-diffusion.cpp) | **Image & Video Diffusion Engine** | • **Stable Diffusion 1.x/2.x, SDXL, SD3, Flux, Wan 2.1/2.2**<br>• 4-bit / 8-bit / GGUF quantization support<br>• Rolling upstream releases with zero Python dependencies | Linux Vulkan RADV • Linux ROCm 7 • Linux CPU • Apple Silicon Metal |
| [**`shimmy`**](#-shimmy) | [`Michael-A-Kuykendall/shimmy`](https://github.com/Michael-A-Kuykendall/shimmy) | **Pure-Rust WebGPU Single Binary** | • **100% Rust** with <1s cold startup and ~50MB RAM footprint<br>• Native GGUF loading and OpenAI streaming completions<br>• Zero Python and zero C/C++ dependencies | Linux • macOS • Windows (WebGPU / Vulkan / CUDA / Metal) |

---

## 🎯 AMD GPU Architecture Support Matrix

| GPU / APU Target | GFX Code | Target Hardware & Devices | `rocmfpx` | `stable-diffusion-cpp` | `shimmy` |
| :--- | :--- | :--- | :---: | :---: | :---: |
| **AMD Strix Halo** | `gfx1151` | Ryzen AI Max+ 395 / Radeon 8060S (128GB Unified) | ✅ (Default) | ✅ (ROCm / Vulkan) | ✅ (WebGPU) |
| **AMD Strix Point** | `gfx1150` | Ryzen AI 9 HX 370 / Radeon 890M / 880M | ✅ (`--with-gfx1150`) | ✅ (ROCm / Vulkan) | ✅ (WebGPU) |
| **AMD RDNA4** | `gfx120X` | Radeon RX 9070 XT / RX 9070 | ✅ (`--with-gfx120X`) | ✅ (Vulkan RADV) | ✅ (WebGPU) |
| **AMD RDNA3** | `gfx110X` | Radeon RX 7900 XTX / 7800 XT / 780M / 760M | ✅ (`--with-gfx110X`) | ✅ (ROCm / Vulkan) | ✅ (WebGPU) |
| **AMD RDNA2** | `gfx103X` | Radeon RX 6800 / 6700 XT / Steam Deck (Van Gogh) | ✅ (`--with-gfx103X`) | ✅ (Vulkan RADV) | ✅ (WebGPU) |
| **AMD CDNA2** | `gfx90a` | AMD Instinct MI210 / MI250X | ✅ (`--with-gfx90a`) | ✅ (ROCm) | ⚠️ (CPU fallback) |
| **AMD CDNA1** | `gfx908` | AMD Instinct MI100 | ✅ (`--with-gfx908`) | ✅ (ROCm) | ⚠️ (CPU fallback) |
| **Multi-Arch Fatbin** | `multiarch` | Combined gfx1100 + gfx1151 binary | ✅ (`--with-multi-arch`) | — | — |
| **Apple Silicon** | `arm64` | M1 / M2 / M3 / M4 (Pro / Max / Ultra) | — | ✅ (Metal) | ✅ (Metal) |

---

## 📦 Detailed Formula Guide

### ⚡ `rocmfpx`
The canonical upstream **ROCmFPX** project maintained by Charlie ([`charlie12345/ROCmFPX`](https://github.com/charlie12345/ROCmFPX)), built directly in this repository with bundled AMD ROCm 7 runtime libraries.

```bash
# Default: Optimized for AMD Strix Halo (gfx1151)
brew install rocmfpx

# Or install for your specific GPU architecture:
brew install rocmfpx --with-multi-arch # Combined fatbin for gfx1100 + gfx1151
brew install rocmfpx --with-gfx1150    # AMD Strix Point (Radeon 890M / 880M)
brew install rocmfpx --with-gfx120X    # AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)
brew install rocmfpx --with-gfx110X    # AMD RDNA3 GPUs (RX 7900 XTX / 7800 XT / Radeon 780M)
brew install rocmfpx --with-gfx103X    # AMD RDNA2 / Steam Deck (Van Gogh / 680M / RX 6800)
brew install rocmfpx --with-gfx90a     # AMD Instinct MI210 / MI250X (CDNA2)
brew install rocmfpx --with-gfx908     # AMD Instinct MI100 (CDNA1)

# Start OpenAI-compatible server:
rocmfpx -m /path/to/model.gguf --port 8080

# Or run CLI chat:
rocmfpx-cli -m /path/to/model.gguf -ngl 99 -p "Hello world!"
```

---

### 🎨 `stable-diffusion-cpp`
Fast, lightweight image and video generation engine based on [`leejet/stable-diffusion.cpp`](https://github.com/leejet/stable-diffusion.cpp) in pure C/C++.

Supports Stable Diffusion 1.x/2.x, SDXL, SD3, Flux, and Wan video models:

```bash
# Default: Vulkan RADV acceleration on Linux; Metal on Apple Silicon
brew install stable-diffusion-cpp

# On Linux, optional acceleration flags:
brew install stable-diffusion-cpp --with-rocm   # AMD ROCm 7 GPU acceleration
brew install stable-diffusion-cpp --with-cpu    # CPU-only baseline

# Run text-to-image generation:
sd -m /path/to/sdxl.gguf -p "A cinematic view of an ancient library on Mars" -o output.png

# Launch HTTP generation server:
sd-server --host 0.0.0.0 --port 8080
```

---

### 🦀 `shimmy`
A pure-Rust LLM engine by Michael Kuykendall ([`Michael-A-Kuykendall/shimmy`](https://github.com/Michael-A-Kuykendall/shimmy)) using `wgpu` and native CUDA/WebGPU shaders. Single binary with sub-second cold starts and zero Python or C/C++ dependencies.

```bash
# Install via Cargo source compilation:
brew install shimmy

# Run OpenAI-compatible inference server on port 11434 (drop-in Ollama replacement):
shimmy serve --port 11434 --host 0.0.0.0

# Start background service:
brew services start shimmy
```

---

## 🛠️ In-Repo Automated Building & Maintenance

All builder workflows are consolidated directly into this repository:

- **`.github/workflows/build-rocmfpx.yml`**: Nightly and dispatch builds of `charlie12345/ROCmFPX` across Ubuntu & Windows with ROCm 7 runtime packaging.
- **`.github/workflows/autobump.yml`**: Scheduled synchronization for upstream releases and formula SHA256 checksums.
- **`.github/workflows/test-install-and-run.yml`**: Multi-OS install and binary validation suite.

```bash
# Test formula updater locally:
python3 scripts/update_formulae.py --repo all --dry-run
```

---

## 📄 License
This Homebrew Tap and its automation scripts are licensed under the [MIT License](LICENSE). Individual upstream packages remain licensed under their respective open-source licenses.
