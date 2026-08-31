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
  <b><a href="#-q38rocm">q38rocm</a></b> (Qwen 3.8 27B @ 36 tok/s), <b><a href="#-rocmfpx">ROCmFPX</a></b> (Low-Bit Q2..Q8 & DualView), <b><a href="#-cachyllama">CachyLLama</a></b> (Persistent KV & MoE Residency), and <b><a href="#-llama-ai">llama-ai</a></b> (Turnkey APU Solver).
</p>

</div>

---

## ⚡ Quick Start

```bash
# 1. Tap the Heretek-AI repository
brew tap Heretek-AI/tap

# 2. Install your desired inference engine:
brew install q38rocm       # Dedicated Qwen 3.8 27B Strix Halo engine (36 tok/s)
brew install rocmfpx       # ROCmFPX low-bit quantization & DualView stack (AMD GPUs)
brew install cachy-llama   # Persistent KV cache & MoE residency (Linux & macOS Metal)
brew install llama-ai      # 1-click APU hardware solver & turnkey runner

# 3. Optional: Start background OpenAI-compatible server daemon (runs on boot):
brew services start q38rocm
```

> [!IMPORTANT]
> **⚡ Zero-Dependency Guarantee — Built-in ROCm™ 7 Runtimes**:  
> All Linux ROCm binaries bundle complete AMD ROCm 7 runtime libraries (`libhipblas.so`, `librocblas.so`, `libamdhip64.so`, `libhipblaslt.so`, and BLAS kernel packages) linked via portable `$ORIGIN` RPATHs. **No separate AMD ROCm™ SDK or driver installation is required!** Just install and run.

---

## 📊 At-a-Glance Engine Comparison

| Engine / Formula | Primary Specialization | Key Architectural Highlights | Best Suited For | Acceleration Backends |
| :--- | :--- | :--- | :--- | :--- |
| [**`q38rocm`**](#-q38rocm) | **Qwen 3.8 27B Dedicated Deployment** | • 🔥 **30.56 – 36.04 tok/s** generation throughput<br>• Embedded MTP speculative decoding (K=4..6)<br>• **Asymmetric TurboQuant KV Cache** (`-ctk q8_0 -ctv turbo4`)<br>• Mesa RADV Wave64 cooperative matrix acceleration | Qwen 3.8 27B (ROCmFP4_FAST / ROCmFP8), long context coding agents (up to 262K context) | AMD Strix Halo (`gfx1151`) • ROCm 7 (HIP) + Vulkan RADV |
| [**`rocmfpx`**](#-rocmfpx) | **Low-Bit Quantization & Serving Stack** | • **ROCmFP2 (2.50 bpw)** through **ROCmFP8 (8.25 bpw)**<br>• **DualView Architecture**: Q7 storage + Q8 prefill shadow<br>• **ActiveFPX PromptForge** prompt-specialized runtime<br>• Certified profiles: `--with-kairic-edge`, `--with-promptforge` | Ornith 35B, DeepSeek, Nemotron, custom low-bit quantizations, CDNA accelerators | AMD ROCm 7 (`gfx1151`, `gfx1150`, `gfx120X`, `gfx110X`, `gfx103X`, `gfx90a`, `gfx908`, `multiarch`) |
| [**`cachy-llama`**](#-cachyllama) | **Persistent KV Cache & MoE Residency** | • **Cross-Turn KV Cache Preservation** (disk/RAM paging)<br>• **MoE Expert Residency & Dynamic Offload**<br>• Zero-prefill instant response on multi-turn conversations | Multi-turn AI agents, massive MoEs (DeepSeek V2/V3/R1, Qwen MoE, Mixtral, Grok) | Apple Silicon Metal (macOS) • Universal Linux Vulkan RADV • Linux ROCm |
| [**`llama-ai`**](#-llama-ai) | **Turnkey APU Solver & Profile Solver** | • Automated APU memory, bandwidth, and compute probe<br>• Optimistic profile solver for optimal quantization & context<br>• 1-command zero-config launch | Developers seeking zero-configuration APU/Mac deployment | Apple Silicon Metal (macOS) • Linux x64 Vulkan/CPU |

---

## 📦 Detailed Formula Installation & Usage Guide

### 🚀 `q38rocm`
High-performance deployment stack for **Qwen 3.8 27B** custom-engineered for **AMD Strix Halo (Ryzen AI Max+ 395 / Radeon 8060S)** APUs.

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

#### Why `q38rocm` reaches 36 tok/s on a 27B model:
1. **Memory Bandwidth Slashed**: `ROCmFP4_FAST` (13.55 GiB | 4.26 bpw) reduces memory payload by **75.2% vs FP16**, streaming past the 200 GB/s Strix Halo bus bandwidth.
2. **MTP Speculative Decoding**: Drafts 4–6 tokens in a single memory sweep with 75%–88% acceptance rates, multiplying speed from 14.0 tok/s to **36.04 tok/s**.
3. **Asymmetric TurboQuant KV Cache**: Keeps Keys in Q8 for precise routing while compressing Values to 4-bit, dropping 262K context RAM from 61.4 GB to **20.08 GB**.

---

### ⚡ `rocmfpx`
Ciru's low-bit quantization inference stack supporting custom ROCmFP formats, DualView Q7 storage, and certified model profiles.

```bash
# Default: Optimized for AMD Strix Halo (gfx1151)
brew install rocmfpx

# Or install for your specific GPU hardware:
brew install rocmfpx --with-gfx1150    # AMD Strix Point (Radeon 890M / 880M)
brew install rocmfpx --with-gfx120X    # AMD RDNA4 Discrete GPUs (RX 9070 XT / 9070)
brew install rocmfpx --with-gfx110X    # AMD RDNA3 GPUs (RX 7900 XTX / 7800 XT / Radeon 780M)
brew install rocmfpx --with-gfx103X    # AMD RDNA2 / Steam Deck (Van Gogh / 680M / RX 6800)
brew install rocmfpx --with-gfx90a     # AMD Instinct MI210 / MI250X (CDNA2)
brew install rocmfpx --with-gfx908     # AMD Instinct MI100 (CDNA1)
brew install rocmfpx --with-multi-arch # Combined fatbin for gfx1100 + gfx1151

# Or install certified model-specific profiles:
brew install rocmfpx --with-kairic-edge   # Qwen 3.8 27B IU4 Kairic Edge certified runtime
brew install rocmfpx --with-promptforge  # Qwen 3.8 27B ActiveFPX PromptForge runtime
brew install rocmfpx --with-q38rocm      # Qwen 3.8 27B ROCmFP4 tuned runtime
```

#### Format Catalog & DualView Architecture:
- **`Q2_0_ROCMFPX` (2.50 bpw)**: Ultra-compact format with frozen codebook and HIP MMQ/MMVQ dispatch.
- **`Q3_0_ROCMFPX` (3.50 bpw)**: Balanced 3-bit format with scale-search and packed execution paths.
- **`Q4_0_ROCMFP4` / `FAST` (4.50 / 4.25 bpw)**: Standard ROCmFP4 formats with serving stability.
- **`Q6_0_ROCMFPX` (6.50 bpw)**: Strix quality recipes with optimized GPU execution.
- **`Q7_0_ROCMFPX` (7.50 bpw DualView)**: Authoritative Q7 storage with zero-copy Q7 decode streaming and exact signed-Q8 prefill shadow.
- **`Q8_0_ROCMFPX` (8.25 bpw)**: Reference precision (<0.003 PPL loss).

Quantize any model with `rocmfpx-quantize`:
```bash
rocmfpx-quantize source-model-BF16.gguf output-model-FP7.gguf Q7_0_ROCMFPX
```

---

### 💾 `cachy-llama`
Persistent KV cache and MoE active expert memory residency manager. Eliminates prompt re-prefill latency across agent conversation turns.

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
brew install cachy-llama --with-cpu          # CPU-only baseline
```

#### Key Capabilities:
- **Cross-Turn KV Persistence**: Paged KV cache saves intermediate generation states to disk/RAM. Subsequent chat turns resume with **0 ms prefill latency**.
- **MoE Expert Residency**: Dynamically offloads dormant MoE experts while pinning hot routing pathways in VRAM, enabling massive MoE models (DeepSeek V3 671B, Mixtral 8x22B) to run on consumer hardware.

---

### 🎯 `llama-ai`
Turnkey APU runner and profile solver. Automatically detects system RAM, VRAM, and memory bus topology, calculates optimal context and quantization settings, and launches the engine.

```bash
# Install llama-ai
brew install llama-ai

# 1-Command Launch:
llama-ai
```

---

## 🎯 Comprehensive Hardware Compatibility Matrix

| GPU / APU Target | GFX Code | Target Hardware & Devices | `q38rocm` | `rocmfpx` Option | `cachy-llama` Option |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **AMD Strix Halo APU** | `gfx1151` | Ryzen AI MAX+ Pro 395, MAX 390, Radeon 8060S (128GB Unified RAM) | 🔥 **Native (36 tok/s)** | *(Default)* / `--with-q38rocm` | `--with-rocm-gfx1151` |
| **AMD Strix Point APU** | `gfx1150` | Ryzen AI 9 HX 370 / 365, Radeon 890M / 880M | Guarded Fallback | `--with-gfx1150` | `--with-rocm-gfx1150` |
| **AMD RDNA4 Discrete** | `gfx120X` | Radeon RX 9070 XT, RX 9070 GRE, RX 9070, RX 9060 XT | Guarded Fallback | `--with-gfx120X` | `--with-rocm-gfx120X` |
| **AMD RDNA3 Discrete & iGPU** | `gfx110X` | Radeon RX 7900 XTX / XT / GRE, RX 7800 XT, Radeon 780M / 760M | Guarded Fallback | `--with-gfx110X` | `--with-rocm-gfx110X` |
| **AMD RDNA2 / Handhelds** | `gfx103X` | Steam Deck (Van Gogh), Radeon 680M, RX 6950 XT / 6800 XT / 6700 XT | Guarded Fallback | `--with-gfx103X` | `--with-rocm-gfx103X` |
| **AMD CDNA2 Enterprise** | `gfx90a` | AMD Instinct MI250X, MI250, MI210 | N/A | `--with-gfx90a` | `--with-rocm-gfx90a` |
| **AMD CDNA1 Enterprise** | `gfx908` | AMD Instinct MI100 | N/A | `--with-gfx908` | N/A |
| **Universal Linux Vulkan** | `RADV` | Universal support for all AMD, Intel, NVIDIA GPUs via Mesa RADV Wave64 | N/A | N/A | *(Linux Default)* |
| **Apple Silicon** | `Metal` | Apple M1 / M2 / M3 / M4 (Standard, Pro, Max, Ultra) | N/A | N/A | *(macOS Default)* |

---

## 🛠️ Production Serving & Client Integration

All installed engines provide standard OpenAI-compatible API endpoints (`/v1/chat/completions`, `/v1/models`, `/health`) on ports `8000` or `8080`.

### 1. Managing Background Daemons (`brew services`)

```bash
# Start background server daemon on system boot:
brew services start q38rocm
# or
brew services start rocmfpx
# or
brew services start cachy-llama

# View status:
brew services list

# View logs:
tail -f $(brew --prefix)/var/log/q38rocm.log

# Stop background server:
brew services stop q38rocm
```

### 2. Client Configuration Snippets

#### Open WebUI
Set OpenAI Base URL: `http://localhost:8000/v1` (API Key: `sk-no-key-required`).

#### Continue.dev (`~/.continue/config.json`)
```json
{
  "models": [
    {
      "title": "Qwen 3.8 27B ROCmFP4 (Strix Halo)",
      "provider": "openai",
      "model": "qwen38-27b",
      "apiBase": "http://localhost:8000/v1"
    }
  ]
}
```

#### Cursor IDE
In **Settings > Models > OpenAI API Key**, configure base URL: `http://localhost:8000/v1`.

---

## 🔧 AMD Hardware Tweaks & Performance Optimization

To achieve maximum inference throughput on AMD Ryzen AI APUs and Radeon GPUs:

### 1. Set GPU Performance Governor to High
Prevent the GPU clock from down-throttling between token generation bursts:
```bash
echo "high" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
```

### 2. Expand TTM / GTT Memory Allocation Limits
The Linux `amdgpu` driver defaults to allocating only 50% of system RAM to the GPU. To allow large context sizes (128K–262K tokens) on AMD unified APUs:
```bash
# 64GB Unified RAM (expands GPU allocation to ~56 GiB):
echo 14680064 | sudo tee /sys/module/ttm/parameters/pages_limit

# 128GB Unified RAM / Strix Halo (expands GPU allocation to ~120 GiB):
echo 31457280 | sudo tee /sys/module/ttm/parameters/pages_limit

# Make persistent across reboots via GRUB (/etc/default/grub):
# Add 'ttm.pages_limit=31457280' to GRUB_CMDLINE_LINUX_DEFAULT, then run: sudo update-grub
```

### 3. Enable Transparent Hugepages (THP)
Reduces page fault latency during KV cache allocation:
```bash
echo "madvise" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

---

## 🏗️ Automated Builder Pipelines

Binaries distributed by this tap are automatically compiled, tested, and published nightly by dedicated GitHub Actions CI pipelines:

- [**`Heretek-AI/ROCmFPX-BUILDER`**](https://github.com/Heretek-AI/ROCmFPX-BUILDER): Multi-target AMD ROCm 7 matrix builds for ROCmFPX and `q38rocm`.
- [**`Heretek-AI/CachyLLama-BUILDER`**](https://github.com/Heretek-AI/CachyLLama-BUILDER): Multi-platform builds for CachyLLama (macOS Metal, Linux ROCm, Linux Vulkan) and `llama-ai`.

---

## 📄 License & Attribution

- **Homebrew Tap**: Licensed under the [MIT License](LICENSE).
- **ROCmFPX**: Developed by Ciru ([ciru-ai/ROCmFPX](https://github.com/ciru-ai/ROCmFPX)) under the MIT License.
- **q38rocm**: Developed by Julian ([julianmb/q38rocm](https://github.com/julianmb/q38rocm)) under the Apache 2.0 License.
- **CachyLLama & llama-ai**: Developed by fewtarius ([fewtarius/CachyLLama](https://github.com/fewtarius/CachyLLama), [fewtarius/llama-ai](https://github.com/fewtarius/llama-ai)) under the MIT / GPL-3.0 Licenses.
- **llama.cpp**: Developed by Georgi Gerganov and contributors under the MIT License.
