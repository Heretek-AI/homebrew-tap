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
  <b>Turnkey Homebrew tap delivering pre-compiled, GPU-accelerated builds of 11 high-performance local LLM, multimodal vision, and diffusion inference engines:</b><br/>
  <b><a href="#-rocmfpx">rocmfpx</a></b> • <b><a href="#-stable-diffusion-cpp">stable-diffusion-cpp</a></b> • <b><a href="#-shimmy">shimmy</a></b> • <b><a href="#-gufo">gufo</a></b> • <b><a href="#-gufo-franzmoca">gufo-franzmoca</a></b> • <b><a href="#-gufetto">gufetto</a></b> • <b><a href="#-strixite">strixite</a></b> • <b><a href="#-strata">strata</a></b> • <b><a href="#-project-maya">project-maya</a></b> • <b><a href="#-kyojin">kyojin</a></b> • <b><a href="#-hyperqwen">hyperqwen</a></b>
</p>

</div>

---

## ⚡ Quick Start

```bash
# 1. Tap the Heretek-AI repository
brew tap Heretek-AI/tap

# 2. Install your desired inference engine:
# --- Canonical Engines ---
brew install rocmfpx              # Canonical ROCm 7 llama.cpp stack (AMD RDNA2..RDNA4 / CDNA)
brew install stable-diffusion-cpp # Fast SD, SDXL, Flux, SD3 & Wan image/video inference
brew install shimmy               # Pure-Rust WebGPU & CUDA LLM engine

# --- AMD Strix Halo (gfx1151) Native Engines ---
brew install gufo                 # Canonical upstream C++20/HIP Strix Halo runtime (voice + decide)
brew install gufo-franzmoca       # DeepSeek-V4.1-Flash (763B SSD streaming) & Gemma 4 MTP engine
brew install gufetto              # C++23 runtime with Flash-Next rotated KV cache & admission planner
brew install strixite             # Zero-dependency C++20/HIP Qwen3.8-Flash-Next runtime

# --- Tiered MoE & Multi-Model Engines ---
brew install strata               # Tiered MoE engine (Qwen3.8, Qwen3.6-35B, DeepSeek-V4.1)
brew install project-maya         # Tiered MoE engine (GLM-5.3-Flash, Qwen-3.8, DeepSeek-V4.1, MiniMax-M3.1)

# --- Python / JIT & CUDA Appliances ---
brew install kyojin               # ExLlamaV3 Strix Halo / RDNA4 suite with 5 specialized servers
brew install hyperqwen            # NVIDIA CUDA 13.0 patched vLLM 0.32.0 appliance (sm_80..sm_120)

# 3. Optional: Start background OpenAI-compatible server daemon (runs on boot):
brew services start gufetto
# or
brew services start rocmfpx
```

> [!IMPORTANT]
> **⚡ Zero-Dependency Guarantee — Built-in ROCm™ 7 Runtimes**:  
> Linux ROCm packages bundle AMD ROCm 7 runtime libraries (`libhipblas.so`, `librocblas.so`, `libamdhip64.so`, `libhipblaslt.so`, and BLAS kernel packages) linked via portable `$ORIGIN` RPATHs.

---

## 📊 Master Engine Comparison Matrix (All 11 Formulas)

| Formula | Upstream Source | Primary Languages & Build System | Primary Focus & Models | Default Backend | Port | Binary Aliases & CLI Tools |
| :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| [**`rocmfpx`**](#-rocmfpx) | [`charlie12345/ROCmFPX`](https://github.com/charlie12345/ROCmFPX) | C/C++ (CMake + ROCm 7) | General GGUF LLMs (`llama.cpp` upstream fork) | AMD ROCm 7 (`gfx1151` default) | `8080` | `rocmfpx`, `rocmfpx-cli`, `rocmfpx-server` |
| [**`stable-diffusion-cpp`**](#-stable-diffusion-cpp) | [`leejet/stable-diffusion.cpp`](https://github.com/leejet/stable-diffusion.cpp) | C/C++ (CMake) | Image & video diffusion (SD, SDXL, Flux, SD3, Wan 2.1) | Vulkan RADV / Metal / ROCm | `8080` | `sd`, `sd-server` |
| [**`shimmy`**](#-shimmy) | [`Michael-A-Kuykendall/shimmy`](https://github.com/Michael-A-Kuykendall/shimmy) | Rust (Cargo) | Ultra-lightweight GGUF server (<1s cold boot, ~50MB RAM) | WebGPU / Vulkan / Metal / CUDA | `11434` | `shimmy` |
| [**`gufo`**](#-gufo) | [`gufo-org/gufo`](https://github.com/gufo-org/gufo) | C11, C++20, HIP (CMake + Ninja) | Upstream Strix Halo runtime, `gufo speak` (voice), `gufo decide`, WebSockets | AMD ROCm HIP (`gfx1151` strictly enforced) | `8080` | `gufo`, `gufo-server` |
| [**`gufo-franzmoca`**](#-gufo-franzmoca) | [`franzmoca/gufo`](https://github.com/franzmoca/gufo) | C11, C++20, HIP (CMake + Ninja) | DeepSeek-V4.1-Flash (763B SSD streaming) & Gemma 4 MTP | AMD ROCm HIP (`gfx1151` strictly enforced) | `8080` | `gufo`, `gufo-franzmoca`, `gufo-dsv41-stream-order` |
| [**`gufetto`**](#-gufetto) | [`fewtarius/gufetto`](https://github.com/fewtarius/gufetto) | C11, **C++23**, HIP (CMake + Ninja) | Flash-Next rotated Q4/Q8 KV cache, multi-prefix pinning, admission planner | AMD ROCm HIP (`gfx1151`) + XDNA 2 NPU | `8080` | `gufo`, `gufetto`, `gufo-server` |
| [**`strixite`**](#-strixite) | [`shawnshekari/strixite`](https://github.com/shawnshekari/strixite) | C++20, HIP, C11 (CMake + Clang + lld) | Zero-dependency `.strixw` v2 runtime for Qwen3.8-Flash-Next | AMD ROCm HIP (`gfx1151` hardcoded) | `5300` | `strix_server`, `strixite`, `convert_qwen4exp` |
| [**`strata`**](#-strata) | [`Niko1221/Strata`](https://github.com/Niko1221/Strata) | C++17, HIP/CUDA/Metal + Python | Tiered MoE for Qwen3.8, Qwen3.6-35B, DeepSeek-V4.1-Flash | Multi-Backend (ROCm HIP / Metal / CUDA) | `8080` / `8095` | `strata`, `strata-q36`, `strata-dsv41`, `strata-cli` |
| [**`project-maya`**](#-project-maya) | [`mw00/project-maya`](https://github.com/mw00/project-maya) | C++20, HIP/CUDA/Metal + Python | Tiered MoE for GLM-5.3-Flash, Qwen-3.8, DeepSeek-V4.1, MiniMax-M3.1 | Multi-Backend (ROCm HIP / Metal / CUDA) | `8080` / `8095` | `maya`, `maya-ds4`, `maya-mm3`, `maya-cli` |
| [**`kyojin`**](#-kyojin) | [`Yamz-Labs/kyojin`](https://github.com/Yamz-Labs/kyojin) | Python, C++20, HIP/CUDA (PyTorch JIT) | ExLlamaV3 Strix Halo / RDNA4 suite with 5 specialized servers | AMD ROCm HIP (`gfx1151`) / CUDA | `8000` | `kyojin-serve`, `kyojin-bench`, `kyojin-convert` |
| [**`hyperqwen`**](#-hyperqwen) | [`syv-ai/HyperQwen`](https://github.com/syv-ai/HyperQwen) | Python 3.12, CUDA C++17, Inline PTX | NVIDIA CUDA 13.0 patched vLLM 0.32.0 appliance (Qwen3.8-27B) | NVIDIA CUDA 13.0 (`sm_80..sm_120` ONLY) | `18020` | `hyperqwen-serve`, `hyperqwen-bench` |

---

## 🎯 Hardware Architecture & Backend Support Matrix

| Hardware / Target | ISA Code | `rocmfpx` | `sd-cpp` | `shimmy` | `gufo` | `gufo-fm` | `gufetto` | `strixite` | `strata` | `maya` | `kyojin` | `hyperqwen` |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **AMD Strix Halo** | `gfx1151` | ✅ Default | ✅ | ✅ | ✅ Pure | ✅ Pure | ✅ Pure | ✅ Pure | ✅ | ✅ | ✅ | ❌ |
| **AMD Strix Point** | `gfx1150` | ✅ Option | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ Option | ✅ | ✅ Option | ❌ |
| **AMD RDNA4** | `gfx120X` | ✅ Option | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ Default | ✅ | ✅ Option | ❌ |
| **AMD RDNA3** | `gfx110X` | ✅ Option | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ Default | ✅ | ✅ | ❌ |
| **AMD RDNA2** | `gfx103X` | ✅ Option | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ⚠️ Option | ❌ | ⚠️ | ❌ |
| **AMD CDNA 1/2/3** | `gfx90X` | ✅ Option | ✅ | ⚠️ CPU | ❌ | ❌ | ❌ | ❌ | ✅ Option | ✅ Option | ❌ | ❌ |
| **AMD XDNA 2 NPU** | `accel0` | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Built-in | ❌ | ❌ | ❌ | ❌ | ❌ |
| **NVIDIA CUDA** | `sm_80..120`| ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ Option | ✅ Option | ✅ Option | ✅ Core |
| **Apple Silicon** | `arm64` Metal| ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ Metal | ✅ Metal | ❌ | ❌ |
| **Vulkan / WebGPU**| SPIR-V / WGSL| ❌ | ✅ Default| ✅ Default| ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Host CPU SIMD** | AVX-512/AVX2| ✅ | ✅ | ✅ | Zen4/Zen5 | Zen4/Zen5 | Zen4/Zen5 | Zen4/Zen5 | AVX-512 | AVX-512 | AVX2 | x86-64 |

---

## 🧠 Model & Feature Compatibility Matrix

| Feature / Model Family | `rocmfpx` | `sd-cpp` | `shimmy` | `gufo` | `gufo-fm` | `gufetto` | `strixite` | `strata` | `maya` | `kyojin` | `hyperqwen` |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Qwen3.8-Flash-Next** | ✅ GGUF | ❌ | ✅ GGUF | ✅ Native | ✅ Native | ✅ Rotated KV | ✅ `.strixw` | ✅ Native | ✅ Native | ✅ `qwen` | ❌ |
| **Qwen3.6-35B-A3B** | ✅ GGUF | ❌ | ✅ GGUF | ❌ | ❌ | ❌ | ❌ | ✅ `strata-q36`| ✅ `maya` | ✅ `qwen` | ❌ |
| **Qwen3.8-27B-AWQ** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Core |
| **DeepSeek-V4.1-Flash (763B)** | ⚠️ GGUF | ❌ | ❌ | ❌ | ✅ SSD Stream| ❌ | ❌ | ✅ `strata-dsv`| ✅ `maya-ds4` | ✅ `ds41` | ❌ |
| **Gemma 4 (26B-A4B & 31B)**| ⚠️ GGUF | ❌ | ❌ | ⚠️ Extension | ✅ MTP Spec | ❌ | ❌ | ❌ | ❌ | ✅ `flint` | ❌ |
| **GLM-5.3-Flash / 4.7** | ✅ GGUF | ❌ | ✅ GGUF | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ `maya` | ✅ `glm` | ❌ |
| **MiniMax-M3.1-Flash** | ⚠️ GGUF | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ `maya-mm3` | ❌ | ❌ |
| **MiMo-V2-Flash** | ⚠️ GGUF | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ `mimo` | ❌ |
| **General GGUF LLMs** | ✅ Full | ❌ | ✅ Full | ❌ | ❌ | ❌ | ❌ | ⚠️ Pack tool | ⚠️ Pack tool | ⚠️ EXL3/GGUF | ❌ |
| **Diffusion (SD/SDXL/Flux/Wan)**| ❌ | ✅ Core | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Multimodal Vision Tower**| ❌ | ❌ | ❌ | ✅ Built-in | ✅ Built-in | ❌ | ✅ Built-in | ✅ `vision-hip`| ✅ `vision-hip`| ❌ | ❌ |
| **Speculative Decoding** | N-gram | ❌ | ❌ | MTP / N-gram | MTP / Lookup| N-gram | MTP / N-gram | MTP / DSpark | MTP / DSpark | MTP / N-gram | MTP |

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
```

---

### 🎨 `stable-diffusion-cpp`
Fast, lightweight image and video generation engine based on [`leejet/stable-diffusion.cpp`](https://github.com/leejet/stable-diffusion.cpp) in pure C/C++. Supports Stable Diffusion 1.x/2.x, SDXL, SD3, Flux, and Wan video models:

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
brew install shimmy

# Run OpenAI-compatible inference server on port 11434 (drop-in Ollama replacement):
shimmy serve --port 11434 --host 0.0.0.0
```

---

### 🦉 `gufo` / `gufo-franzmoca` / `gufetto` (AMD Strix Halo gfx1151 Native Engines)

Pure C11/C++20/C++23/HIP inference engines built specifically for the AMD Ryzen AI Max+ 395 ("Strix Halo", `gfx1151`) APU:

- **`gufo`** ([`gufo-org/gufo`](https://github.com/gufo-org/gufo)): Modular Source Extension Architecture, `gufo speak` (voice assistant), `gufo decide`, `/v1/realtime` WebSockets, and Qwen-Image-2.1-Turbo.
- **`gufo-franzmoca`** ([`franzmoca/gufo`](https://github.com/franzmoca/gufo)): 763B DeepSeek-V4.1-Flash (at up to 1M context with NVMe `--stream-experts` and dual-SSD split streaming) + Gemma 4 (26B-A4B & 31B) with MTP speculative decoding.
- **`gufetto`** ([`fewtarius/gufetto`](https://github.com/fewtarius/gufetto)): C++23 runtime with Flash-Next rotated Q4/Q8 KV cache, multi-prefix pinning (`--pin-prefix-dir`), and Measured Model Admission Planner (`gufo diagnose --plan`).

```bash
# Install canonical upstream gufo:
brew install gufo

# Or install franzmoca's DeepSeek-V4.1-Flash & Gemma 4 engine:
brew install gufo-franzmoca

# Or install fewtarius's rotated KV cache & multi-prefix pinning runtime:
brew install gufetto

# Start OpenAI-compatible server on port 8080:
gufo serve --host 127.0.0.1 --port 8080
```

---

### ⚡ `strixite` (Zero-Dependency Qwen3.8-Flash-Next Strix Halo Engine)
From-scratch C++20/HIP inference runtime by Shawn Shekari ([`shawnshekari/strixite`](https://github.com/shawnshekari/strixite)) for Strix Halo (`gfx1151`). Converts safetensors directly to `.strixw` v2 weights with zero external library dependencies.

```bash
brew install strixite

# Convert HuggingFace safetensors:
convert_qwen4exp /path/to/hf-weights /path/to/strixw --int4-shared

# Launch server on port 5300:
strix_server --model /path/to/strixw --port 5300 --kv-mode fp8 --mtp-draft 3
```

---

### 🏔️ `strata` & `project-maya` (Tiered MoE Multi-Model Engines)
Hybrid C++/Python engines designed for tiered GPU/CPU MoE inference across Strix Halo, discrete AMD RDNA3/RDNA4 GPUs, Apple Silicon Metal, and NVIDIA CUDA:

- **`strata`** ([`Niko1221/Strata`](https://github.com/Niko1221/Strata)): Tiered inference for Qwen3.8-Flash-Next, Qwen3.6-35B-A3B, and DeepSeek-V4.1-Flash with multi-GPU splitting (`strata-split-2/3/4`).
- **`project-maya`** ([`mw00/project-maya`](https://github.com/mw00/project-maya)): Tiered inference for GLM-5.3-Flash, Qwen-3.8, DeepSeek-V4.1-Flash, and MiniMax-M3.1-Flash with runtime CPUID AVX-512 expert kernels.

```bash
# Install Strata:
brew install strata

# Install Project Maya:
brew install project-maya

# Launch servers:
strata-cli --model qwen38 --port 8095
maya-cli --model glm51 --port 8095
```

---

### 🥋 `kyojin` (ExLlamaV3 Strix Halo & RDNA4 MoE Suite)
Python + C++20/HIP fork of ExLlamaV3 by Yamz Labs ([`Yamz-Labs/kyojin`](https://github.com/Yamz-Labs/kyojin)) featuring 5 specialized model servers (`qwen`, `glm`, `mimo`, `ds41`, `flint`) with automatic Strix Halo ROCm 7 runtime environment configuration.

```bash
brew install kyojin

# Start dedicated server:
kyojin-serve qwen -m /path/to/qwen-exl3 --mtp --port 8000
kyojin-serve ds41 -m /path/to/dsv41-gguf --ngram --port 8000
```

---

### 🚀 `hyperqwen` (NVIDIA CUDA 13.0 Qwen3.8-27B Appliance)
Turnkey NVIDIA CUDA 13.0 (`sm_80`/`sm_86`/`sm_89`/`sm_120`) appliance by Syv AI ([`syv-ai/HyperQwen`](https://github.com/syv-ai/HyperQwen)) wrapping a patched vLLM 0.32.0 distribution with custom inline PTX Flash Attention and Local Symbol Acceleration (`liblsa.so`).

```bash
brew install hyperqwen

# Start OpenAI-compatible vLLM server on port 18020:
hyperqwen-serve
```

---

## 🛠️ In-Repo Automated Building & Maintenance

All builder workflows are consolidated directly into this repository:

- **`.github/workflows/build-bottles.yml`**: Nightly and dispatch builds of Linux x86_64 bottles across all 11 formulas with AMD TheRock ROCm 7 runtime packaging.
- **`.github/workflows/build-rocmfpx.yml`**: Nightly and dispatch builds of `charlie12345/ROCmFPX` across Ubuntu & Windows with ROCm 7 runtime packaging.
- **`.github/workflows/autobump.yml`**: Scheduled synchronization for upstream releases, commit SHAs, and formula checksums.
- **`.github/workflows/test-install-and-run.yml`**: Multi-OS install and binary validation suite.

```bash
# Test formula updater locally:
python3 scripts/update_formulae.py --repo all --dry-run
```

---

## 📄 License
This Homebrew Tap and its automation scripts are licensed under the [MIT License](LICENSE). Individual upstream packages remain licensed under their respective open-source licenses.
