# 🍺 Heretek-AI Homebrew Tap

<div align="center">

[![Brew CI & Formula Audit](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml)
[![Auto-Bump Formulae](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/autobump.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/autobump.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

<p align="center">
  <b>Zero-dependency, turnkey Homebrew distribution tap for high-performance LLM inference engines:</b><br/>
  <b><a href="https://github.com/fewtarius/CachyLLama">CachyLLama</a></b>, <b><a href="https://github.com/ciru-ai/ROCmFPX">ROCmFPX</a></b>, and <b><a href="https://github.com/fewtarius/llama-ai">llama-ai</a></b>.
</p>

</div>

---

## ⚡ Quick Start

### 1. Tap this Repository
```bash
brew tap Heretek-AI/tap
```

### 2. Install Packages

#### **CachyLLama** (Persistent KV Cache & MoE Residency)
```bash
# Universal Vulkan RADV (Runs on any Linux AMD APU, dGPU, Intel, or NVIDIA GPU):
brew install cachy-llama

# Or install dedicated ROCm 7 GPU acceleration for your hardware:
brew install cachy-llama --with-rocm-gfx1151  # AMD Strix Halo (Radeon 8060S / 128GB)
brew install cachy-llama --with-rocm-gfx1150  # AMD Strix Point (Radeon 890M / 880M)
brew install cachy-llama --with-rocm-gfx120X  # AMD RDNA4 (RX 9070 XT / 9070)
brew install cachy-llama --with-rocm-gfx110X  # AMD RDNA3 (RX 7900 / 7800, Radeon 780M)
brew install cachy-llama --with-rocm-gfx103X  # AMD RDNA2 / Steam Deck
brew install cachy-llama --with-rocm-gfx90a   # AMD Instinct MI210 / MI250X

# macOS (Apple Silicon M1/M2/M3/M4 Metal):
brew install cachy-llama
```

#### **ROCmFPX** (Low-bit Quantized ROCm 7 Inference Stack)
```bash
# Default: AMD Strix Halo (gfx1151):
brew install rocmfpx

# Or choose specific GPU architecture:
brew install rocmfpx --with-gfx1150  # AMD Strix Point (Radeon 890M)
brew install rocmfpx --with-gfx120X  # AMD RDNA4 (RX 9070 XT)
brew install rocmfpx --with-gfx110X  # AMD RDNA3 (RX 7900, Radeon 780M)
brew install rocmfpx --with-gfx103X  # AMD RDNA2 / Steam Deck
brew install rocmfpx --with-gfx90a   # AMD Instinct MI210 / MI250X
brew install rocmfpx --with-gfx908   # AMD Instinct MI100
```

#### **llama-ai** (Turnkey APU Runner & Optimistic Solver)
```bash
brew install llama-ai
```

---

## 🎯 Supported Hardware Matrix

| GPU / APU Target | GFX Target | Target Hardware | `cachy-llama` Option | `rocmfpx` Option |
| :--- | :--- | :--- | :--- | :--- |
| **RDNA3.5 (Strix Halo)** | `gfx1151` | Ryzen AI MAX+ Pro 395, Radeon 8060S (128GB) | `--with-rocm-gfx1151` | *(Default)* |
| **RDNA3.5 (Strix Point)** | `gfx1150` | Ryzen AI 9 HX 370 / 365, Radeon 890M / 880M | `--with-rocm-gfx1150` | `--with-gfx1150` |
| **RDNA4** | `gfx120X` | AMD Radeon RX 9070 XT, RX 9070, RX 9060 XT | `--with-rocm-gfx120X` | `--with-gfx120X` |
| **RDNA3** | `gfx110X` | Radeon 780M / 760M, RX 7900 XTX / XT / 7800 XT | `--with-rocm-gfx110X` | `--with-gfx110X` |
| **RDNA2** | `gfx103X` | Steam Deck (Van Gogh), 680M, RX 6800 / 6700 XT | `--with-rocm-gfx103X` | `--with-gfx103X` |
| **CDNA / CDNA2** | `gfx90a` | AMD Instinct MI250X, MI210 | `--with-rocm-gfx90a` | `--with-gfx90a` |
| **CDNA1** | `gfx908` | AMD Instinct MI100 | `--with-rocm-gfx908` | `--with-gfx908` |
| **Universal Vulkan** | `RADV` | Universal Linux APU/dGPU Support | *(Linux Default)* | N/A |
| **Apple Silicon** | `Metal` | Apple M1 / M2 / M3 / M4 (Pro / Max / Ultra) | *(macOS Default)* | N/A |

---

## 🚀 Running Inference & Background Services

### Command-Line Inference
All commands are installed with both upstream aliases and namespaced identifiers:

```bash
# Chat in terminal with GPU offload:
llama-cli -m /path/to/model.gguf -ngl 99 -p "Hello world!"
# Or namespaced:
cachy-llama-cli -m /path/to/model.gguf -ngl 99
rocmfpx-cli -m /path/to/model.gguf -ngl 99

# Quantize models to ROCmFPX formats:
rocmfpx-quantize model-BF16.gguf model-Q7.gguf Q7_0_ROCMFPX
```

### Background Daemon Service (`brew services`)
Run OpenAI-compatible local server as a background service:

```bash
# Start background server daemon on port 8080:
brew services start cachy-llama
# or
brew services start rocmfpx

# Check status:
brew services list

# Stop background server:
brew services stop cachy-llama
```

---

## 🛠️ Upstream Repositories & Automation

- **Automated Builders**:
  - [Heretek-AI/CachyLLama-BUILDER](https://github.com/Heretek-AI/CachyLLama-BUILDER)
  - [Heretek-AI/ROCmFPX-BUILDER](https://github.com/Heretek-AI/ROCmFPX-BUILDER)
- **Upstream Engines**:
  - [fewtarius/CachyLLama](https://github.com/fewtarius/CachyLLama)
  - [ciru-ai/ROCmFPX](https://github.com/ciru-ai/ROCmFPX)
  - [fewtarius/llama-ai](https://github.com/fewtarius/llama-ai)
  - [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)

---

## 📄 License

Licensed under the [MIT License](LICENSE).
