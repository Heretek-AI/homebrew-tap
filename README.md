# 🍺 Heretek-AI Homebrew Tap: High-Performance llama.cpp Forks & LLM Inference Engines

<div align="center">

[![Brew CI & Formula Audit](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml)
[![Auto-Bump Formulae](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/autobump.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/autobump.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![AMD ROCm 7.0](https://img.shields.io/badge/AMD%20ROCm-7.0%20Built--in-blue?logo=amd&logoColor=white)](https://github.com/ROCm/ROCm)
[![Apple Metal](https://img.shields.io/badge/Apple-Metal%20Accelerated-000000?logo=apple&logoColor=white)](https://developer.apple.com/metal/)
[![Mesa RADV Vulkan](https://img.shields.io/badge/Vulkan-Mesa%20RADV%20Wave64-FF5722?logo=vulkan&logoColor=white)](https://mesa3d.org)

<p align="center">
  <b>Zero-dependency, turnkey Homebrew tap delivering pre-compiled, GPU-accelerated builds of specialized <a href="https://github.com/ggml-org/llama.cpp">llama.cpp</a> forks and LLM inference engines:</b><br/>
  <b><a href="#-rocmfpx-upstream">rocmfpx</a></b> (Canonical Upstream Engine), <b><a href="#-ciru-rocmfpx">ciru-rocmfpx</a></b> (DualView Q7 & PromptForge), <b><a href="#-q38rocm">q38rocm</a></b> (Qwen 3.8 27B @ 36 tok/s), <b><a href="#-cachyllama">CachyLLama</a></b> (Persistent KV & MoE Residency), and <b><a href="#-llama-ai">llama-ai</a></b> (Turnkey APU Solver).
</p>

</div>

---

## ⚡ Quick Start

```bash
# 1. Tap the Heretek-AI repository
brew tap Heretek-AI/tap

# 2. Install your desired inference engine:
brew install rocmfpx       # Canonical Upstream ROCmFPX (charlie12345/ROCmFPX)
brew install ciru-rocmfpx  # Ciru-AI ROCmFPX (DualView Q7, PromptForge, Kairic Edge)
brew install q38rocm       # Dedicated Qwen 3.8 27B Strix Halo stack (36 tok/s)
brew install cachy-llama   # Persistent KV cache & MoE residency (Linux & macOS Metal)
brew install llama-ai      # 1-click APU hardware solver & turnkey runner

# 3. Optional: Start background OpenAI-compatible server daemon (runs on boot):
brew services start rocmfpx
# or
brew services start ciru-rocmfpx
# or
brew services start q38rocm
```

> [!IMPORTANT]
> **⚡ Zero-Dependency Guarantee — Built-in ROCm™ 7 Runtimes**:  
> All Linux ROCm binaries bundle complete AMD ROCm 7 runtime libraries (`libhipblas.so`, `librocblas.so`, `libamdhip64.so`, `libhipblaslt.so`, and BLAS kernel packages) linked via portable `$ORIGIN` RPATHs. **No separate AMD ROCm™ SDK or driver installation is required!** Just install and run.

---

## 📊 At-a-Glance Engine Comparison

| Engine / Formula | Upstream Source | Primary Specialization | Key Highlights | Target Hardware & Backends |
| :--- | :--- | :--- | :--- | :--- |
| [**`rocmfpx`**](#-rocmfpx-upstream) | [`charlie12345/ROCmFPX`](https://github.com/charlie12345/ROCmFPX) | **Canonical Upstream ROCm Engine** | • Official, actively maintained upstream ROCmFPX engine<br>• Active upstream `llama.cpp` synchronization<br>• High-performance MMQ/MMVQ ROCm 7 GPU acceleration | AMD RDNA2, RDNA3, RDNA3.5, RDNA4, CDNA |
| [**`ciru-rocmfpx`**](#-ciru-rocmfpx) | [`ciru-ai/ROCmFPX`](https://github.com/ciru-ai/ROCmFPX) | **Low-Bit Quantization & DualView Fork** | • **ROCmFP2 (2.50 bpw)** through **ROCmFP8 (8.25 bpw)**<br>• **DualView Architecture**: Q7 storage + Q8 prefill shadow<br>• **ActiveFPX PromptForge** & **Kairic Edge** profiles | AMD ROCm 7 (`gfx1151`, `gfx1150`, `gfx120X`, `gfx110X`, `gfx103X`, `gfx90a`, `gfx908`) |
| [**`q38rocm`**](#-q38rocm) | [`julianmb/q38rocm`](https://github.com/julianmb/q38rocm) | **Qwen 3.8 27B Dedicated Deployment** | • 🔥 **30.56 – 36.04 tok/s** generation throughput<br>• Embedded MTP speculative decoding (K=4..6)<br>• **Asymmetric TurboQuant KV Cache** (`-ctk q8_0 -ctv turbo4`)<br>• Mesa RADV Wave64 cooperative matrices | AMD Strix Halo (`gfx1151`) • ROCm 7 (HIP) + Vulkan RADV |
| [**`cachy-llama`**](#-cachyllama) | [`fewtarius/CachyLLama`](https://github.com/fewtarius/CachyLLama) | **Persistent KV Cache & MoE Residency** | • **Cross-Turn KV Cache Preservation** (disk/RAM paging)<br>• **MoE Expert Residency & Dynamic Offload**<br>• Zero-prefill instant response on multi-turn conversations | Universal Linux Vulkan RADV • Linux ROCm • Linux CPU / CUDA |
| [**`llama-ai`**](#-llama-ai) | [`fewtarius/llama-ai`](https://github.com/fewtarius/llama-ai) | **Turnkey APU Solver & Profile Engine** | • Automated APU memory, bandwidth, and compute probe<br>• Optimistic profile solver for optimal quantization & context<br>• 1-command zero-config launch | Linux x64 Vulkan/CPU |
| [**`prima-cpp`**](#-primacpp) | [`OpenCPIL/prima.cpp`](https://github.com/OpenCPIL/prima.cpp) | **Distributed Heterogeneous Cluster Engine** | • **Distributed 30B–70B Model Inference** across home LAN<br>• Smart pipeline parallelism with automatic device profiling<br>• OS weight prefetching across mixed GPU/CPU nodes | Linux CUDA • Vulkan • CPU OpenMP • Apple Silicon |
| [**`shimmy`**](#-shimmy) | [`Michael-A-Kuykendall/shimmy`](https://github.com/Michael-A-Kuykendall/shimmy) | **Pure-Rust WebGPU & CUDA Single Binary** | • **100% Rust** with <1s cold startup and ~50MB RAM footprint<br>• Native GGUF loading and OpenAI streaming completions<br>• Zero Python and zero C/C++ dependencies | Linux • macOS • Windows (WebGPU / Vulkan / CUDA / Metal) |

---

## 📦 Detailed Formula Installation & Usage Guide

### ⚡ `rocmfpx` (Upstream)
The canonical upstream **ROCmFPX** project maintained by Charlie ([`charlie12345/ROCmFPX`](https://github.com/charlie12345/ROCmFPX)), providing the latest upstream syncs, stable ROCm 7 HIP acceleration, and multi-GPU matrix coverage.

```bash
# Default: Optimized for AMD Strix Halo (gfx1151)
brew install rocmfpx

# Or install for your specific GPU architecture:
brew install rocmfpx --with-gfx1150    # AMD Strix Point (Radeon 890M / 880M)
brew install rocmfpx --with-gfx120X    # AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)
brew install rocmfpx --with-gfx110X    # AMD RDNA3 GPUs (RX 7900 XTX / 7800 XT / Radeon 780M)
brew install rocmfpx --with-gfx103X    # AMD RDNA2 / Steam Deck (Van Gogh / 680M / RX 6800)
brew install rocmfpx --with-gfx90a     # AMD Instinct MI210 / MI250X (CDNA2)
brew install rocmfpx --with-gfx908     # AMD Instinct MI100 (CDNA1)
brew install rocmfpx --with-multi-arch # Combined fatbin for gfx1100 + gfx1151

# Start OpenAI server:
rocmfpx -m /path/to/model.gguf --port 8080

# Or run CLI chat:
rocmfpx-cli -m /path/to/model.gguf -ngl 99 -p "Hello world!"
```

---

### 🧬 `ciru-rocmfpx` (Ciru Research Fork)
Ciru's specialized research fork ([`ciru-ai/ROCmFPX`](https://github.com/ciru-ai/ROCmFPX)) featuring proprietary low-bit quantization formats, DualView Q7 storage, and certified model profiles.

```bash
# Install Ciru-AI ROCmFPX (Default: gfx1151)
brew install ciru-rocmfpx

# Or install certified model profiles:
brew install ciru-rocmfpx --with-kairic-edge   # Qwen 3.8 27B IU4 Kairic Edge certified runtime
brew install ciru-rocmfpx --with-promptforge  # Qwen 3.8 27B ActiveFPX PromptForge certified runtime

# Or choose GPU target:
brew install ciru-rocmfpx --with-gfx1150
brew install ciru-rocmfpx --with-gfx120X
brew install ciru-rocmfpx --with-gfx110X

# Quantize models to ROCmFPX formats:
ciru-fpx-quantize model-BF16.gguf model-Q7.gguf Q7_0_ROCMFPX
```

---

### 🚀 `q38rocm`
High-performance deployment stack for **Qwen 3.8 27B** custom-engineered by Julian ([`julianmb/q38rocm`](https://github.com/julianmb/q38rocm)) for **AMD Strix Halo (Ryzen AI Max+ 395 / Radeon 8060S)** APUs.

```bash
# Install q38rocm
brew install q38rocm

# Start OpenAI-compatible server on port 8000 (36 tok/s sustained decode):
q38rocm -m Qwen3.8-27B-ROCmFP4-FAST.gguf --port 8000

# Or launch with namespaced CLI:
q38rocm-cli -m Qwen3.8-27B-ROCmFP4-FAST.gguf -ngl 99 -p "Write a binary search tree in Rust"

# Start as a background daemon:
brew services start q38rocm
```

---

### 💾 `cachy-llama`
Persistent KV cache and MoE active expert memory residency manager by fewtarius ([`fewtarius/CachyLLama`](https://github.com/fewtarius/CachyLLama)). Eliminates prompt re-prefill latency across agent conversation turns.

```bash
# macOS (Apple Silicon Metal M1/M2/M3/M4):
brew install cachy-llama

# Linux Universal (Mesa RADV Vulkan - works on any AMD/Intel/NVIDIA GPU):
brew install cachy-llama

# Linux AMD ROCm 7 GPU Acceleration:
brew install cachy-llama --with-rocm-gfx1151  # Strix Halo (Radeon 8060S / 128GB)
brew install cachy-llama --with-rocm-gfx1150  # Strix Point (Radeon 890M / 880M)
brew install cachy-llama --with-rocm-gfx120X  # RDNA4 (RX 9070 XT)
brew install cachy-llama --with-rocm-gfx110X  # RDNA3 (RX 7900 / 7800 / 780M)
brew install cachy-llama --with-rocm-gfx103X  # RDNA2 / Steam Deck
brew install cachy-llama --with-rocm-gfx90a   # Instinct MI210 / MI250X
```

---

### 🎯 `llama-ai`
Turnkey APU runner and profile solver by fewtarius ([`fewtarius/llama-ai`](https://github.com/fewtarius/llama-ai)). Automatically detects system RAM, VRAM, and memory bus topology, calculates optimal context and quantization settings, and launches the engine.

```bash
# Install llama-ai
brew install llama-ai

# 1-Command Launch:
llama-ai
```

---

## 🎯 Comprehensive Hardware Compatibility Matrix

| GPU / APU Target | GFX Code | Target Hardware & Devices | `rocmfpx` (Upstream) | `ciru-rocmfpx` | `q38rocm` | `cachy-llama` |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| **AMD Strix Halo APU** | `gfx1151` | Ryzen AI MAX+ Pro 395, MAX 390, Radeon 8060S (128GB) | *(Default)* | *(Default)* | 🔥 **Native (36 tok/s)** | `--with-rocm-gfx1151` |
| **AMD Strix Point APU** | `gfx1150` | Ryzen AI 9 HX 370 / 365, Radeon 890M / 880M | `--with-gfx1150` | `--with-gfx1150` | Guarded Fallback | `--with-rocm-gfx1150` |
| **AMD RDNA4 Discrete** | `gfx120X` | Radeon RX 9070 XT, RX 9070 GRE, RX 9070, RX 9060 XT | `--with-gfx120X` | `--with-gfx120X` | Guarded Fallback | `--with-rocm-gfx120X` |
| **AMD RDNA3 Discrete & iGPU** | `gfx110X` | Radeon RX 7900 XTX / XT / GRE, RX 7800 XT, Radeon 780M / 760M | `--with-gfx110X` | `--with-gfx110X` | Guarded Fallback | `--with-rocm-gfx110X` |
| **AMD RDNA2 / Handhelds** | `gfx103X` | Steam Deck (Van Gogh), Radeon 680M, RX 6950 XT / 6800 XT | `--with-gfx103X` | `--with-gfx103X` | Guarded Fallback | `--with-rocm-gfx103X` |
| **AMD CDNA2 Enterprise** | `gfx90a` | AMD Instinct MI250X, MI250, MI210 | `--with-gfx90a` | `--with-gfx90a` | N/A | `--with-rocm-gfx90a` |
| **AMD CDNA1 Enterprise** | `gfx908` | AMD Instinct MI100 | `--with-gfx908` | `--with-gfx908` | N/A | N/A |
| **Universal Linux Vulkan** | `RADV` | Universal support for all AMD, Intel, NVIDIA GPUs via Mesa RADV | N/A | N/A | N/A | *(Linux Default)* |
| **Apple Silicon** | `Metal` | Apple M1 / M2 / M3 / M4 (Standard, Pro, Max, Ultra) | N/A | N/A | N/A | *(macOS Default)* |

---

## 🛠️ Production Serving & Client Integration

All installed engines provide standard OpenAI-compatible API endpoints (`/v1/chat/completions`, `/v1/models`, `/health`) on ports `8000` or `8080`.

### 1. Managing Background Daemons (`brew services`)

```bash
# Start background server daemon on system boot:
brew services start rocmfpx
# or
brew services start ciru-rocmfpx
# or
brew services start q38rocm
# or
brew services start cachy-llama

# View status:
brew services list

# Stop background server:
brew services stop rocmfpx
```

### 2. Client Configuration Snippets

#### Open WebUI
Set OpenAI Base URL: `http://localhost:8080/v1` (API Key: `sk-no-key-required`).

#### Continue.dev (`~/.continue/config.json`)
```json
{
  "models": [
    {
      "title": "ROCmFPX (Strix Halo)",
      "provider": "openai",
      "model": "local-model",
      "apiBase": "http://localhost:8080/v1"
    }
  ]
}
```

#### Cursor IDE
In **Settings > Models > OpenAI API Key**, configure base URL: `http://localhost:8080/v1`.

---

## 🔧 AMD Hardware Tweaks & Performance Optimization

To achieve maximum inference throughput on AMD Ryzen AI APUs and Radeon GPUs:

### 1. Set GPU Performance Governor to High
```bash
echo "high" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
```

### 2. Expand TTM / GTT Memory Allocation Limits
```bash
# 64GB Unified RAM (expands GPU allocation to ~56 GiB):
echo 14680064 | sudo tee /sys/module/ttm/parameters/pages_limit

# 128GB Unified RAM / Strix Halo (expands GPU allocation to ~120 GiB):
echo 31457280 | sudo tee /sys/module/ttm/parameters/pages_limit
```

### 3. Enable Transparent Hugepages (THP)
```bash
echo "madvise" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

---

## 🏗️ Automated Builder Pipelines

Binaries distributed by this tap are automatically compiled, tested, and published nightly by dedicated GitHub Actions CI pipelines:

- [**`Heretek-AI/ROCmFPX-BUILDER`**](https://github.com/Heretek-AI/ROCmFPX-BUILDER): Multi-target AMD ROCm 7 matrix builds for upstream `charlie12345/ROCmFPX`, `ciru-ai/ROCmFPX`, and `q38rocm`.
- [**`Heretek-AI/CachyLLama-BUILDER`**](https://github.com/Heretek-AI/CachyLLama-BUILDER): Multi-platform builds for CachyLLama (macOS Metal, Linux ROCm, Linux Vulkan) and `llama-ai`.

---

## 📄 License & Attribution

- **Homebrew Tap**: Licensed under the [MIT License](LICENSE).
- **ROCmFPX (Upstream)**: Developed by Charlie ([charlie12345/ROCmFPX](https://github.com/charlie12345/ROCmFPX)) under the MIT License.
- **ROCmFPX (Ciru Fork)**: Developed by Ciru ([ciru-ai/ROCmFPX](https://github.com/ciru-ai/ROCmFPX)) under the MIT License.
- **q38rocm**: Developed by Julian ([julianmb/q38rocm](https://github.com/julianmb/q38rocm)) under the Apache 2.0 License.
- **CachyLLama & llama-ai**: Developed by fewtarius ([fewtarius/CachyLLama](https://github.com/fewtarius/CachyLLama), [fewtarius/llama-ai](https://github.com/fewtarius/llama-ai)) under the MIT / GPL-3.0 Licenses.
- **llama.cpp**: Developed by Georgi Gerganov and contributors under the MIT License.
