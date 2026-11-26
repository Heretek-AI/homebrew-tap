# Heretek-AI Homebrew Tap

A Homebrew tap for 15 accelerator-focused inference runtimes, servers, and kernel harnesses. Most formulae target AMD ROCm on Linux; the tap also covers NVIDIA CUDA, Apple Metal, Vulkan, SYCL, and CPU paths where the pinned upstream project supports them.

[![Nightly CI Matrix](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/nightly-matrix.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/nightly-matrix.yml)
[![brew test-bot](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml)
[![Build ROCmFPX](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/build-rocmfpx.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/build-rocmfpx.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

The formula files under [`Formula/`](Formula/) and the automation ledger at [`.github/upstream-pins.json`](.github/upstream-pins.json) are the source of truth for upstream revisions, supported targets, installed command names, and options. This README describes the state of that pinned set, not every feature of every upstream project.

## Installation

### Direct install (recommended)

Install a formula by its fully qualified name. Homebrew adds the tap automatically and trusts only the formula being installed:

```bash
brew install heretek-ai/tap/gufo
```

Replace `gufo` with any formula name from the [catalog](#formula-catalog). Direct installation is the safest one-off path because it does not trust the rest of the tap.

### Manual tap

```bash
brew tap heretek-ai/tap
brew install gufo
```

After a manual tap, a short-name install needs a trust entry for that formula (see below). You can also keep using the fully qualified name:

```bash
brew install heretek-ai/tap/gufo
```

### Tap trust (Homebrew 6 and later)

Homebrew 6.0.0 and later require explicit trust for non-official taps. Formulae and casks are executable Ruby package definitions, so trusting a tap means accepting that its code may run when Homebrew loads it. Trust the specific formula you need whenever possible:

```bash
# Per-formula trust; the explicit --formula form is equivalent:
brew trust heretek-ai/tap/gufo
brew trust --formula heretek-ai/tap/gufo
```

Trust the whole tap only when you accept all of its current and future formulae, casks, and external commands:

```bash
brew trust --tap heretek-ai/tap

# The bare tap name is accepted as shorthand:
brew trust heretek-ai/tap
```

A direct `brew install heretek-ai/tap/<formula>` trusts only that formula. Trusting a whole tap is broader than most users need. Use `brew trust` to list trusted entries and `brew untrust ...` to remove them.

### Brewfile

A standard Brewfile entry is:

```ruby
tap "heretek-ai/tap"
brew "gufo"
brew "rocmfpx"
```

On Homebrew 6 and later, declare trust in the Brewfile. Trust only selected formulae:

```ruby
tap "heretek-ai/tap", trusted: { formulae: ["gufo", "rocmfpx"] }
brew "gufo"
brew "rocmfpx"
```

Or trust the whole tap, or individual fully qualified entries:

```ruby
tap "heretek-ai/tap", trusted: true
brew "gufo"

# Equivalent per-entry form:
brew "heretek-ai/tap/gufo", trusted: true
```

`brew bundle cleanup` resets Homebrew's trust store to the declarations in the selected Brewfile, so keep the trust entries you intend to retain.

### Installing a non-default variant

Formula options are evaluated when the formula is installed from source. If a bottle is available for your platform, force a source build so the option takes effect:

```bash
brew install --build-from-source --with-tools heretek-ai/tap/gufo
```

For `rocmfpx` and `stable-diffusion-cpp`, options select a different prebuilt artifact rather than changing a compiler build:

```bash
brew install --with-gfx120X heretek-ai/tap/rocmfpx
brew install --with-rocm heretek-ai/tap/stable-diffusion-cpp
```

If you reinstall or rebuild a non-default variant, keep the same flags.

## Formula catalog

The catalog is alphabetical. Each subsection lists the upstream project, purpose, supported platforms/backends, exact installed commands, and every option declared by the formula. Run `brew info heretek-ai/tap/<formula>` to see the same options through Homebrew.

### Catalog

| Formula | Upstream | Purpose | Platforms / backends |
| :--- | :--- | :--- | :--- |
| [`crucible-strix-halo`](#crucible-strix-halo) | [jaedync/crucible-strix-halo](https://github.com/jaedync/crucible-strix-halo) | Strix Halo kernel harness and memory allocator tuners | Linux, ROCm `gfx1151` |
| [`gufetto`](#gufetto) | [community-token-labs/gufetto](https://github.com/community-token-labs/gufetto) | C11/C++23 multimodal runtime with rotated KV cache and prefix pinning | Linux, ROCm `gfx1151`; optional XDNA 2 NPU |
| [`gufo`](#gufo) | [gufo-org/gufo](https://github.com/gufo-org/gufo) | C11/C++20/HIP multimodal inference engine | Linux, ROCm `gfx1151` |
| [`gufo-franzmoca`](#gufo-franzmoca) | [franzmoca/gufo](https://github.com/franzmoca/gufo) | Strix Halo engine with DeepSeek-V4.1-Flash and Gemma 4 MTP workflows | Linux, ROCm `gfx1151` |
| [`hyperqwen`](#hyperqwen) | [syv-ai/HyperQwen](https://github.com/syv-ai/HyperQwen) | Patched vLLM appliance for Qwen3.8-27B-AWQ | Linux, NVIDIA CUDA `sm_80`/`sm_86`/`sm_89`/`sm_120` |
| [`kyojin`](#kyojin) | [Yamz-Labs/kyojin](https://github.com/Yamz-Labs/kyojin) | EXL3/GGUF inference engine with five model server entrypoints | Linux, ROCm (default) or CUDA |
| [`lucebox`](#lucebox) | [Luce-Org/lucebox](https://github.com/Luce-Org/lucebox) | Speculative LLM inference server for consumer GPUs | Linux, CUDA (default) or ROCm |
| [`project-maya`](#project-maya) | [mw00/project-maya](https://github.com/mw00/project-maya) | Tiered MoE engine for GLM, Qwen, DeepSeek, and MiniMax models | Linux ROCm/CUDA, macOS Metal |
| [`qwenox`](#qwenox) | [IIIIIllllIIIIIlllll/Qwenox](https://github.com/IIIIIllllIIIIIlllll/Qwenox) | Qwen runtime and kernel primitives | Linux, ROCm `gfx1151` |
| [`rocmfpx`](#rocmfpx) | [charlie12345/ROCmFPX](https://github.com/charlie12345/ROCmFPX) | llama.cpp-compatible ROCm inference stack with bundled runtimes | Linux, ROCm; artifact selected by gfx target |
| [`shimmy`](#shimmy) | [Michael-A-Kuykendall/shimmy](https://github.com/Michael-A-Kuykendall/shimmy) | Pure-Rust local LLM inference server | Linux CPU; macOS Metal |
| [`snowllm`](#snowllm) | [snowllm/snowllm](https://github.com/snowllm/snowllm) | HIP kernels and embedded LLM runner for Ryzen AI Max | Linux, ROCm |
| [`stable-diffusion-cpp`](#stable-diffusion-cpp) | [leejet/stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) | Stable Diffusion, SDXL, Flux, SD3, and Wan inference | Linux Vulkan/ROCm/CPU; macOS arm64 Metal |
| [`strata`](#strata) | [Niko1221/Strata](https://github.com/Niko1221/Strata) | Tiered MoE engine for Qwen and DeepSeek models | Linux ROCm/CUDA/SYCL, macOS Metal |
| [`strixite`](#strixite) | [shawnshekari/strixite](https://github.com/shawnshekari/strixite) | Zero-dependency C++20/HIP Qwen runtime | Linux, ROCm `gfx1151` |

### Command and option map

| Formula | Installed commands | Options |
| :--- | :--- | :--- |
| `crucible-strix-halo` | `crucible-strix-halo`; `crucible-strix-halo-server` when upstream ships `server/server.py` | None |
| `gufetto` | `gufetto`, `gufetto-server`; `gufetto-kernel-bench` when built; with `--with-tools`: `gufetto-bench-q8-1`, `gufetto-tune-hipblaslt`, `gufetto-simple-chat` | `--with-bf16-k-control`, `--with-npu`, `--with-tools`, `--with-znver4` |
| `gufo` | `gufo`, `gufo-server`; `gufo-kernel-bench` when built; with `--with-tools`: `gufo-bench-q8-1`, `gufo-tune-hipblaslt`, `gufo-verify-gemma4`, `gufo-verify-vae`, `gufo-simple-chat` | `--with-tools`, `--with-znver4` |
| `gufo-franzmoca` | `gufo-franzmoca`, `gufo-franzmoca-server`; `gufo-franzmoca-kernel-bench` when built; tools on by default: `gufo-franzmoca-dsv41-stream-order`, `gufo-franzmoca-inspect-gguf-tensors`, `gufo-franzmoca-verify-dsv41-UD-iq1m`, `gufo-franzmoca-verify-gemma4`, `gufo-franzmoca-verify-vae`, `gufo-franzmoca-bench-q8-1`, `gufo-franzmoca-tune-hipblaslt` | `--without-tools`, `--with-znver4` |
| `hyperqwen` | `hyperqwen`, `hyperqwen-serve`, `hyperqwen-server`, `hyperqwen-bench`, `hyperqwen-chat` | None |
| `kyojin` | `kyojin-serve`, `kyojin-bench`, `kyojin-convert`, `kyojin-chat` | `--with-rdna4`, `--with-cuda` |
| `lucebox` | `lucebox-server`, `lucebox` | `--with-rocm` |
| `project-maya` | Linux build outputs: `maya`, `maya-ds4`, `maya-mm3`, `maya-vision`; macOS: `maya`, `maya-metal`, `maya-vision`; all: `maya-server`, `maya-cli`, `maya-chat`, `maya-setup`; Linux tools when built: `maya-tune-hipblaslt`, `maya-peer-probe`, `maya-plan`, `maya-device`, `maya-gguf`, `maya-dequant`, `maya-load`, `maya-concurrent`, `maya-overlap` | `--with-wave64`, `--with-all-amdgpu`, `--with-cuda`, `--with-native` |
| `qwenox` | `qwenox-engine`, `qwenox`, `qwenox-bench`, `qwenox-server`; when built: `qwenox-tok-cli`, `qwenox-tpl-cli`, `qwenox-eng-cli` | None |
| `rocmfpx` | `rocmfpx` and `rocmfpx-server` from the bundled `llama-server`; `rocmfpx-cli`, `rocmfpx-quantize`, `rocmfpx-bench`, `rocmfpx-perplexity` when present in the artifact | `--with-multi-arch`, `--with-gfx1150`, `--with-gfx120X`, `--with-gfx110X`, `--with-gfx103X`, `--with-gfx90a`, `--with-gfx908` |
| `shimmy` | `shimmy` | None |
| `snowllm` | `snowllm`; upstream also declares `snowllm-mineru` (optional MinerU dependencies are not installed by this formula) | None |
| `stable-diffusion-cpp` | `sd-cli`, `sd-server`, `stable-diffusion` | `--with-rocm`, `--with-cpu` |
| `strata` | `strata`, `strata-cli`, `strata-server`, `strata-chat`, `strata-setup`; engines/tools when built: `strata-q36`, `strata-dsv41`, `strata-split-2`, `strata-split-3`, `strata-split-4`, `strata-device`, `strata-plan`, `strata-gguf`, `strata-dequant`, `strata-load`, `strata-concurrent`, `strata-overlap`, `strata-vision` or `strata-vision-hip` | `--with-all-amdgpu`, `--with-cuda`, `--with-sycl`, `--with-native` |
| `strixite` | `strixite-server`, `strixite`, `strixite-convert-qwen4exp`, `strixite-convert-ngram-table`, `strixite-transcode-ngram-table`, `strixite-inspect-strixw`, `strixite-check-stream-calls` | `--with-portable-cpu` |

### crucible-strix-halo

**Upstream:** [jaedync/crucible-strix-halo](https://github.com/jaedync/crucible-strix-halo)
**Purpose:** AMD Strix Halo kernel harness and memory allocator tuners.
**Platforms/backends:** Linux only; ROCm `gfx1151` (`GPU_ARCH=gfx1151` in the formula).
**Commands:** `crucible-strix-halo`; `crucible-strix-halo-server` is installed when the pinned upstream source contains `server/server.py`.
**Options:** None.

```bash
crucible-strix-halo --help
crucible-strix-halo --list-devices
```

### gufetto

**Upstream:** [community-token-labs/gufetto](https://github.com/community-token-labs/gufetto)
**Purpose:** C11/C++23 Strix Halo runtime with rotated KV cache quantization, multi-prefix pinning, and a measured model admission planner. Also provides an experimental XDNA 2 NPU path.
**Platforms/backends:** Linux only; ROCm `gfx1151`. The upstream binary is installed as `gufetto`, not `gufo`.  
**Commands:** `gufetto`, `gufetto-server`; `gufetto-kernel-bench` when built. With `--with-tools`: `gufetto-bench-q8-1`, `gufetto-tune-hipblaslt`, `gufetto-simple-chat`.  
**Options:**
- `--with-bf16-k-control` enables experimental bf16/q8_0-rotated and bf16/q4_0-rotated KV cache modes.
- `--with-npu` enables the experimental AMD XDNA 2 NPU runtime; it requires an XRT SDK that this formula does not install.
- `--with-tools` installs `gufetto-bench-q8-1`, `gufetto-tune-hipblaslt`, and `gufetto-simple-chat`.
- `--with-znver4` compiles host code for `-march=znver4` plus AVX-512 instead of the default `-march=znver5`.

```bash
gufetto --help
gufetto info
gufetto serve --host 127.0.0.1 --port 8080
gufetto diagnose --plan --model /path/to/model.gguf --context-len 32768
```

`gufetto`, `gufo`, and `gufo-franzmoca` can be installed side-by-side: each exposes a distinct command name and the tap does not install a bare `gufo` binary from the variants.

### gufo

**Upstream:** [gufo-org/gufo](https://github.com/gufo-org/gufo)
**Purpose:** Pure C11/C++20/HIP multimodal inference engine for AMD Strix Halo, with an OpenAI/Anthropic/Ollama-compatible server mode.
**Platforms/backends:** Linux only; ROCm `gfx1151`.
**Options:**
- `--with-tools` installs `gufo-bench-q8-1`, `gufo-tune-hipblaslt`, `gufo-verify-gemma4`, `gufo-verify-vae`, and `gufo-simple-chat`.
- `--with-znver4` compiles host code for `-march=znver4` plus AVX-512 instead of the default `-march=znver5`.

```bash
gufo --help
gufo version
gufo info
gufo serve --host 127.0.0.1 --port 8080
```

Models are stored under `~/.cache/gufo/models` by default; override with `GUFO_MODELS_DIR` or `--model-dir`.

### gufo-franzmoca

**Upstream:** [franzmoca/gufo](https://github.com/franzmoca/gufo)
**Purpose:** Strix Halo engine with dedicated DeepSeek-V4.1-Flash streaming and Gemma 4 MTP workflows.
**Platforms/backends:** Linux only; ROCm `gfx1151`. The upstream binary is installed as `gufo-franzmoca`, not `gufo`.
**Options:**
- `--without-tools` skips the DeepSeek-V4.1-Flash and Gemma 4 verification/streaming tools that are built by default.
- `--with-znver4` compiles host code for `-march=znver4` plus AVX-512 instead of the default `-march=znver5`.

```bash
gufo-franzmoca --help
gufo-franzmoca info
gufo-franzmoca serve --host 127.0.0.1 --port 8080
```

`gufo-franzmoca`, `gufo`, and `gufetto` can be installed side-by-side: each exposes a distinct command name and the tap does not install a bare `gufo` binary from the variants.

### hyperqwen

**Upstream:** [syv-ai/HyperQwen](https://github.com/syv-ai/HyperQwen)
**Purpose:** NVIDIA CUDA appliance built around a patched vLLM server for Qwen3.8-27B-AWQ, including an OpenAI-compatible server, benchmark wrapper, and chat wrapper.
**Platforms/backends:** Linux only; NVIDIA CUDA. The formula compiles its `liblsa.so` helper for `sm_80`, `sm_86`, `sm_89`, and `sm_120` when `nvcc` is available.
**Options:** None.

```bash
hyperqwen --help
hyperqwen serve
hyperqwen bench --url http://127.0.0.1:18020 -c 1 4 8 16
hyperqwen chat --help
```

`hyperqwen-serve` reads `HYPERQWEN_MODEL`, `HYPERQWEN_PORT` (default `18020`), `HYPERQWEN_KV_CACHE_DTYPE`, `HYPERQWEN_GPU_MEMORY_UTILIZATION`, `HYPERQWEN_MAX_MODEL_LEN`, and `HYPERQWEN_MAX_NUM_SEQS`. If `nvcc` is not found at install time, the package still installs but `liblsa.so` is not compiled.

### kyojin

**Upstream:** [Yamz-Labs/kyojin](https://github.com/Yamz-Labs/kyojin)
**Purpose:** EXL3/GGUF inference engine with five server entrypoints: `qwen`, `glm`, `mimo`, `ds41`, and `flint`.
**Platforms/backends:** Linux. ROCm is the default (`gfx1151`, or `gfx1151;gfx1150;gfx1200;gfx1201` with `--with-rdna4`). `--with-cuda` selects a CUDA build instead and sets `TORCH_CUDA_ARCH_LIST=8.0;8.6;8.9;9.0;12.0`.
**Options:**
- `--with-rdna4` adds RDNA4 (`gfx1200`, `gfx1201`) and RDNA3.5 (`gfx1150`) targets alongside `gfx1151`.
- `--with-cuda` builds for NVIDIA CUDA instead of AMD ROCm.

```bash
kyojin-serve --help
kyojin-serve qwen -m /path/to/Qwen3.8-35B-A3B-EXL3 --mtp --port 8000
kyojin-serve ds41 -m /path/to/DeepSeek-V4.1-Flash-GGUF --ngram --port 8000
kyojin-bench --help
kyojin-convert --help
kyojin-chat --help
```

The wrappers set `ROCM_PATH`/`EXL3_ROCM_SDK`, unset `HSA_OVERRIDE_GFX_VERSION`, preload `libhsa-runtime64.so.1`, and seed `~/.triton/cache` from the bundled Triton archive on first use.

### lucebox

**Upstream:** [Luce-Org/lucebox](https://github.com/Luce-Org/lucebox)
**Purpose:** Speculative LLM inference server for consumer GPUs.
**Platforms/backends:** Linux. The default build uses CUDA (`75;80;86;89;90;120` compute architectures); `--with-rocm` builds the HIP backend for `gfx1150;gfx1151` instead.
**Options:**
- `--with-rocm` builds with AMD ROCm/HIP instead of NVIDIA CUDA.

```bash
lucebox --help
lucebox-server --help
```

`lucebox` is a symlink to `lucebox-server`.

### project-maya

**Upstream:** [mw00/project-maya](https://github.com/mw00/project-maya)
**Purpose:** Tiered MoE engine for GLM-5.3-Flash, Qwen-3.8, DeepSeek-V4.1, and MiniMax models, with Python orchestration and C++ engines.
**Platforms/backends:** Linux ROCm (default), Linux CUDA, or macOS Metal. Linux HIP targets default to `gfx1100;gfx1150;gfx1151`. CUDA builds use `70;75;80;86;89;90;100;120`.
**Options:**
- `--with-wave64` compiles HIP kernels for Wave64 CDNA/Vega targets: `gfx906;gfx908;gfx942;gfx950`.
- `--with-all-amdgpu` compiles HIP kernels for `gfx1100;gfx1101;gfx1102;gfx1150;gfx1151;gfx1200;gfx1201`.
- `--with-cuda` builds the NVIDIA CUDA backend instead of AMD ROCm/HIP.
- `--with-native` enables `-march=native` in `ggml-cpu`; the default uses portable AVX2 with runtime AVX-512 dispatch.

```bash
maya-cli --help
maya-cli --model glm51 --port 8095
maya --help
maya-server --help
maya-vision --help
```

On Linux the native engines are `maya` (GLM-5.3-Flash and Qwen-3.8-Flash-Next), `maya-ds4` (DeepSeek-V4.1-Flash), and `maya-mm3` (MiniMax-M3.1-Flash). On macOS the Metal engine is also available as `maya-metal`.

### qwenox

**Upstream:** [IIIIIllllIIIIIlllll/Qwenox](https://github.com/IIIIIllllIIIIIlllll/Qwenox)
**Purpose:** Qwen runtime and kernel primitives for Strix Halo.
**Platforms/backends:** Linux only; ROCm `gfx1151` (`GPU_ARCH=gfx1151` in the formula).
**Options:** None.

```bash
qwenox-engine --help
qwenox-engine --info
qwenox-server --help
qwenox-bench --help
```

`qwenox` is a symlink to `qwenox-engine`. The tokenizer, template, and engine CLIs are installed as `qwenox-tok-cli`, `qwenox-tpl-cli`, and `qwenox-eng-cli` when the build produces them.

### rocmfpx

**Upstream:** [charlie12345/ROCmFPX](https://github.com/charlie12345/ROCmFPX)
**Purpose:** Canonical upstream ROCmFPX llama.cpp stack, distributed with bundled AMD ROCm runtime libraries.
**Platforms/backends:** Linux x86_64; AMD ROCm. Each option selects a different prebuilt release artifact. The default artifact is `gfx1151`.
**Options (choose one target artifact):**
- `--with-multi-arch` — one binary for `gfx1100` + `gfx1151`.
- `--with-gfx1150` — Strix Point APUs (`gfx1150`).
- `--with-gfx120X` — RDNA4 discrete GPUs.
- `--with-gfx110X` — RDNA3 GPUs.
- `--with-gfx103X` — RDNA2 GPUs / Steam Deck.
- `--with-gfx90a` — Instinct MI210 / MI250X.
- `--with-gfx908` — Instinct MI100.

```bash
rocmfpx --help
rocmfpx --host 127.0.0.1 --port 8080
rocmfpx-cli --help
rocmfpx-quantize --help
rocmfpx-bench --help
rocmfpx-perplexity --help
```

`rocmfpx` and `rocmfpx-server` are both links to the bundled `llama-server` when that binary is present in the artifact. The tap does not link any bare `llama-*` command into `PATH`. This formula has no `gfx94X` option; older documentation that lists `gfx942` is out of date for the current formula.

### shimmy

**Upstream:** [Michael-A-Kuykendall/shimmy](https://github.com/Michael-A-Kuykendall/shimmy)
**Purpose:** Pure-Rust local LLM inference server.
**Platforms/backends:** Linux CPU; macOS Metal. The upstream CUDA and Vulkan Cargo features are not enabled by this tap because the pinned upstream features are empty/unimplemented.
**Options:** None.

```bash
shimmy --help
shimmy --version
shimmy serve --port 11434 --host 127.0.0.1
```

### snowllm

**Upstream:** [snowllm/snowllm](https://github.com/snowllm/snowllm)
**Purpose:** Hand-written HIP kernels and an embedded LLM runner for AMD Ryzen AI Max APUs.
**Platforms/backends:** Linux only; ROCm. The formula requires a ROCm installation containing `include/hip/hip_runtime.h` and creates a Python 3.12 virtualenv for the package. The formula does not pass an explicit GPU architecture; the pinned upstream kernels target Ryzen AI Max (`gfx1151`).
**Options:** None.

```bash
snowllm --help
```

The pinned upstream package also declares `snowllm-mineru`; its optional MinerU dependency stack is not installed by this formula.

### stable-diffusion-cpp

**Upstream:** [leejet/stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp)
**Purpose:** Stable Diffusion, SDXL, Flux, SD3, and Wan image/video diffusion inference.
**Platforms/backends:** Linux x86_64 with Vulkan (default), ROCm, or CPU prebuilt artifacts; macOS arm64 with a prebuilt Metal artifact.
**Options:**
- `--with-rocm` installs the prebuilt Linux ROCm 10.1.0 artifact.
- `--with-cpu` installs the prebuilt Linux CPU baseline instead of the Vulkan default.

```bash
stable-diffusion --help
sd-cli --help
sd-server --host 127.0.0.1 --port 8080
```

`stable-diffusion` is this tap's alias for `sd-cli`. It is not homebrew-core's `sd`, which is an unrelated find-and-replace CLI.

### strata

**Upstream:** [Niko1221/Strata](https://github.com/Niko1221/Strata)
**Purpose:** Tiered MoE engine for Qwen3.8-Flash-Next, Qwen3.6, and DeepSeek-V4.1, with Python orchestration and C++ engines.
**Platforms/backends:** Linux ROCm (default), Linux CUDA, Linux Intel oneAPI SYCL, or macOS Metal. Linux HIP targets default to `gfx1100;gfx1150;gfx1151`. CUDA builds use `75;80;86;89;90;100;120`.
**Options:**
- `--with-all-amdgpu` compiles HIP kernels for all supported AMD GPUs; the upstream option describes the range as `gfx906` through `gfx1201`.
- `--with-cuda` builds the NVIDIA CUDA backend instead of AMD ROCm/HIP.
- `--with-sycl` builds the Intel Arc/Xe oneAPI SYCL backend.
- `--with-native` enables `-march=native` in `ggml-cpu`; the default uses portable AVX2 with runtime AVX-512 dispatch.

```bash
strata-cli --help
strata-cli --model qwen38 --port 8095
strata-server --help
strata-q36 --help
strata-dsv41 --help
```

`strata` and `strata-cli` are launcher entrypoints for the Python orchestrator; `strata-server`, `strata-chat`, and `strata-setup` are the server, chat, and setup wrappers. The C++ engine variants and tools are linked when the build produces them.

### strixite

**Upstream:** [shawnshekari/strixite](https://github.com/shawnshekari/strixite)
**Purpose:** Zero-dependency C++20/HIP inference engine for Qwen3.8-Flash-Next, including `.strixw` v2 conversion and inspection tools.
**Platforms/backends:** Linux only; ROCm `gfx1151`. Host code defaults to `-march=znver5`.
**Options:**
- `--with-portable-cpu` compiles host code for `-march=x86-64-v3` instead of `-march=znver5`.

```bash
strixite --help
strixite-convert-qwen4exp /path/to/Qwen3.8-Flash-Next /path/to/qwen4exp-strixw --int4-shared
strixite-server --model /path/to/qwen4exp-strixw --port 5300 --kv-mode fp8 --mtp-draft 3
strixite-server --config "$(brew --prefix)/etc/strixite/strix_server.example.conf"
```

`strixite` is a symlink to `strixite-server`. The formula installs an example configuration at `$(brew --prefix)/etc/strixite/strix_server.example.conf` and creates `strix_server.conf` from it if that file does not already exist.

## Command names and coexistence

The tap avoids linking upstream generic names that would collide with other packages:

- **No bare `llama-*`.** `rocmfpx` exposes `rocmfpx`, `rocmfpx-server`, `rocmfpx-cli`, `rocmfpx-quantize`, `rocmfpx-bench`, and `rocmfpx-perplexity`; the bundled `llama-*` binaries stay under the formula's `libexec`.
- **No bare `sd`.** `stable-diffusion-cpp` installs the upstream names `sd-cli` and `sd-server`, plus the tap alias `stable-diffusion` for `sd-cli`. Homebrew-core's `sd` is a different program and is not replaced.
- **No bare `gufo` from the variants.** `gufetto` renames upstream `gufo` to `gufetto`; `gufo-franzmoca` renames it to `gufo-franzmoca`. Neither installs a bare `gufo` or `gufo-server`, so all three gufo-family formulae can be installed side-by-side.
- **Formula-prefixed helpers.** Kyojin, Project Maya, Strata, Qwenox, Strixite, and HyperQwen install their helper tools with formula-specific prefixes (`kyojin-*`, `maya-*`, `strata-*`, `qwenox-*`, `strixite-*`, `hyperqwen-*`).

If a short name is ambiguous with a core formula, use the fully qualified tap name: `brew install heretek-ai/tap/<formula>`.

## Hardware and backend compatibility

This matrix reflects targets that are actually selected in the formula files. "Source" means the formula installs from the pinned source revision and compiles it (or, for Python packages, installs it into a virtualenv) unless a matching CI bottle is published.

| Formula | AMD ROCm (Linux) | macOS Metal | NVIDIA CUDA | CPU / Vulkan / other | Install path |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `crucible-strix-halo` | `gfx1151` | — | — | — | Source |
| `gufetto` | `gfx1151` | — | — | Optional XDNA 2 NPU (`--with-npu`, external XRT) | Source |
| `gufo` | `gfx1151` | — | — | — | Source |
| `gufo-franzmoca` | `gfx1151` | — | — | — | Source |
| `hyperqwen` | — | — | `sm_80`, `sm_86`, `sm_89`, `sm_120` | — | Source |
| `kyojin` | `gfx1151` default; `--with-rdna4` adds `gfx1150`, `gfx1200`, `gfx1201` | — | `--with-cuda` | — | Source |
| `lucebox` | `--with-rocm`: `gfx1150`, `gfx1151` | — | Default build: compute `75;80;86;89;90;120` | — | Source |
| `project-maya` | Default: `gfx1100`, `gfx1150`, `gfx1151`; `--with-all-amdgpu`: `gfx1100`–`gfx1201`; `--with-wave64`: `gfx906`, `gfx908`, `gfx942`, `gfx950` | Yes | `--with-cuda`: `70;75;80;86;89;90;100;120` | CPU fallback compiled into GPU builds | Source |
| `qwenox` | `gfx1151` | — | — | — | Source |
| `rocmfpx` | Default `gfx1151`; `gfx1150`; `gfx120X`; `gfx110X`; `gfx103X`; `gfx90a`; `gfx908`; multi-arch `gfx1100`+`gfx1151` | — | — | — | Prebuilt ROCm zip with bundled runtime |
| `shimmy` | — | Yes | — | Linux CPU | Source (Rust) |
| `snowllm` | `gfx1151` (Ryzen AI Max kernels) | — | — | — | Python/HIP install; requires ROCm |
| `stable-diffusion-cpp` | `--with-rocm` prebuilt ROCm 10.1.0 artifact | Yes (arm64) | — | Default Linux Vulkan; `--with-cpu` | Prebuilt upstream zip |
| `strata` | Default: `gfx1100`, `gfx1150`, `gfx1151`; `--with-all-amdgpu`: upstream `all` (option describes `gfx906`–`gfx1201`) | Yes | `--with-cuda`: `75;80;86;89;90;100;120` | `--with-sycl` (Intel oneAPI); CPU fallback compiled into GPU builds | Source |
| `strixite` | `gfx1151` | — | — | — | Source |

### Target notes

- `gfx1151` is AMD Strix Halo / Ryzen AI Max. `gfx1150` is Strix Point. `gfx1100` and `gfx110X` are RDNA3 families; `gfx1200`, `gfx1201`, and `gfx120X` are RDNA4; `gfx103X` is RDNA2. `gfx908` is Instinct MI100 and `gfx90a` is Instinct MI210/MI250X.
- `gfx906`, `gfx942`, and `gfx950` are available only through Project Maya's `--with-wave64` option in this tap. `gfx908` is also available as a `rocmfpx` target. Strata's `--with-all-amdgpu` passes the upstream `all` target list.
- `rocmfpx` does **not** provide a `gfx94X` artifact in the current formula. Do not apply the old `gfx942` claim from earlier documentation.
- macOS support is limited to `project-maya`, `strata`, `shimmy`, and `stable-diffusion-cpp`. The other formulae declare Linux only.
- CUDA support is limited to `hyperqwen`, `kyojin --with-cuda`, `lucebox` (default), `project-maya --with-cuda`, and `strata --with-cuda`. `shimmy`'s pinned upstream CUDA feature is not enabled here.
- Vulkan is supported by `stable-diffusion-cpp` (default Linux artifact). SYCL is supported by `strata --with-sycl`. The CPU-only paths are `shimmy` on Linux and `stable-diffusion-cpp --with-cpu`; Project Maya and Strata compile a CPU fallback into their GPU builds but do not offer a standalone CPU option.

### Prebuilt artifacts and source builds

- **Always prebuilt:** `rocmfpx` installs a ROCmFPX release zip with bundled AMD ROCm runtime libraries; `stable-diffusion-cpp` installs upstream release zips for Vulkan, ROCm, CPU, or macOS Metal. Neither formula needs a compiler for its default artifact.
- **Source by default:** the other 13 formulae install from pinned source revisions. Homebrew may pour a matching bottle produced by the nightly matrix; if no bottle matches your OS/architecture/variant, it builds from source.
- **Toolchain coupling:** source-built binaries link against the ROCm or CUDA installation present at build time. Rebuild or reinstall if that SDK moves. `rocmfpx` is the formula that bundles ROCm runtime libraries into the installed prefix.
- **Bottles are platform- and variant-specific.** There is no universal bottle for a formula with `gfx` or backend options. Use `--build-from-source` when you need a non-default option.

## Build prerequisites and the ROCm path

### Common prerequisites

- Homebrew on Linux x86_64 or macOS. Linux-only formulae declare `depends_on :linux`.
- Homebrew installs the declared build dependencies (for example `cmake`, `ninja`, `pkgconf`, `python@3.12`, `rust`, `gcc`, or `lld`) as part of the install.
- macOS source builds need the Xcode Command Line Tools and a Metal-capable toolchain.
- Some formulae use Python 3.12 virtualenvs (`project-maya`, `strata`, `snowllm`, `hyperqwen`, `kyojin`); the formula handles the virtualenv, but the ROCm or CUDA SDK is still external.

### AMD ROCm

The ROCm formulae look for a usable SDK in this order:

1. `HOMEBREW_ROCM_PATH`
2. `ROCM_PATH`
3. `/opt/rocm-nightly`
4. `/opt/rocm`

They require `include/hip/hip_runtime.h` under the selected root. Point Homebrew at your SDK explicitly:

```bash
export HOMEBREW_ROCM_PATH=/opt/rocm
brew install --build-from-source heretek-ai/tap/gufo
```

If no path contains the HIP headers, installation stops with a message asking you to set `HOMEBREW_ROCM_PATH`. The tap's CI resolves AMD TheRock nightly ROCm tarballs (the ledger's minimum is `10.1.0`) into `/opt/rocm-nightly`; that directory is a CI convention, not a requirement. A normal `/opt/rocm` installation works when selected explicitly.

The formulae bake the chosen ROCm library path into the binary's RPATH. Moving or replacing the SDK after installation can leave the binary unable to find `libamdhip64.so` or related libraries; rebuild or reinstall after such a change.

### NVIDIA CUDA

CUDA formulae probe `HOMEBREW_CUDA_PATH`, `CUDA_HOME`, `CUDA_PATH`, and `/usr/local/cuda` for a toolkit. Install a CUDA toolkit that provides `nvcc`, then either place it at `/usr/local/cuda` or pass `HOMEBREW_CUDA_PATH`:

```bash
export HOMEBREW_CUDA_PATH=/usr/local/cuda
brew install --build-from-source heretek-ai/tap/lucebox
```

`hyperqwen` compiles `liblsa.so` only when `nvcc` is found; without it, the package still installs but the helper library is skipped. `lucebox` builds CUDA by default, so AMD users must pass `--with-rocm`.

Two formulae need extra care in the current revision: `project-maya` and `strata` resolve a ROCm root before selecting `--with-cuda` or `--with-sycl`, so those source builds still need a ROCm SDK with HIP headers available even when they compile a non-HIP backend. The formula file is authoritative if this changes.

### macOS Metal

Only `project-maya`, `strata`, `shimmy`, and `stable-diffusion-cpp` support macOS in this tap. There is no ROCm or CUDA path on macOS. Prebuilt CI bottles target `arm64_sonoma`. `project-maya`, `strata`, and `shimmy` can build from source on macOS; `stable-diffusion-cpp` currently declares only an arm64 macOS artifact.

### Nightly matrix and ROCmFPX builds

The tap uses two separate build systems:

- **Nightly matrix** ([`.github/workflows/nightly-matrix.yml`](.github/workflows/nightly-matrix.yml)) runs at 02:00 UTC or by manual dispatch. A change gate reads [`.github/upstream-pins.json`](.github/upstream-pins.json), compares pinned upstream commits and the AMD ROCm index, and emits a build matrix. Builds run on Ubuntu 24.04 for ROCm/CUDA variants, macOS 14 for Metal variants, and optionally a self-hosted `gfx1151` runner for hardware validation. The workflow resolves ROCm into `/opt/rocm-nightly`, runs formula tests and a three-tier linkage/device/inference validation harness, publishes validation proofs and release assets, and merges bottle blocks and ledger updates back into `main`.
- **ROCmFPX builder** ([`.github/workflows/build-rocmfpx.yml`](.github/workflows/build-rocmfpx.yml)) is a separate workflow that builds ROCmFPX plus bundled ROCm for Linux and Windows. The Linux `gfx` artifacts feed the `rocmfpx` formula; the workflow publishes `b####` releases. This is not the same pipeline as the nightly matrix.

## Usage examples

Every command below is installed by the corresponding formula. Use `--help` for the full flag set; this tap does not guarantee flags that are not shown here.

### AMD Strix Halo runtimes

```bash
# Kernel harness
crucible-strix-halo --help
crucible-strix-halo --list-devices

# Gufo family
gufo --help
gufo info
gufo serve --host 127.0.0.1 --port 8080

gufetto --help
gufetto info
gufetto serve --host 127.0.0.1 --port 8080
gufetto diagnose --plan --model /path/to/model.gguf --context-len 32768

gufo-franzmoca --help
gufo-franzmoca info
gufo-franzmoca serve --host 127.0.0.1 --port 8080

# Qwen runtime
qwenox-engine --info
qwenox-server --help

# Embedded runner
snowllm --help

# Strixite conversion and server
strixite-convert-qwen4exp /path/to/Qwen3.8-Flash-Next /path/to/qwen4exp-strixw --int4-shared
strixite-server --model /path/to/qwen4exp-strixw --port 5300 --kv-mode fp8 --mtp-draft 3
```

### llama.cpp, diffusion, and local servers

```bash
# ROCmFPX / llama.cpp stack
rocmfpx --help
rocmfpx --host 127.0.0.1 --port 8080
rocmfpx-cli --help

# Stable Diffusion / Flux / SD3 / Wan
stable-diffusion --help
sd-cli --help
sd-server --host 127.0.0.1 --port 8080

# Shimmy
shimmy --help
shimmy serve --port 11434 --host 127.0.0.1
```

### Tiered, multimodal, and CUDA servers

```bash
# Strata
strata-cli --help
strata-cli --model qwen38 --port 8095
strata-server --help
strata-q36 --help
strata-dsv41 --help

# Project Maya
maya-cli --help
maya-cli --model glm51 --port 8095
maya-server --help
maya-vision --help

# Kyojin
kyojin-serve --help
kyojin-serve qwen -m /path/to/Qwen3.8-35B-A3B-EXL3 --mtp --port 8000
kyojin-bench --help

# HyperQwen
hyperqwen --help
hyperqwen serve
hyperqwen bench --url http://127.0.0.1:18020 -c 1 4 8 16
hyperqwen chat --help

# Lucebox
lucebox --help
lucebox-server --help
```

## Services

Only the formulae below declare a `service` block. Start a service with `brew services start <formula>`; use `brew services run <formula>` to run it without registering it at login.

| Formula | Service executable | Default endpoint | Notes |
| :--- | :--- | :--- | :--- |
| `gufo` | `gufo serve` | `127.0.0.1:8080` | Logs to `$(brew --prefix)/var/log/gufo.log` |
| `gufetto` | `gufetto serve` | `127.0.0.1:8080` | Logs to `$(brew --prefix)/var/log/gufetto.log` |
| `gufo-franzmoca` | `gufo-franzmoca serve` | `127.0.0.1:8080` | Logs to `$(brew --prefix)/var/log/gufo-franzmoca.log` |
| `hyperqwen` | `hyperqwen-serve` | `127.0.0.1:18020` | Port overridable with `HYPERQWEN_PORT` |
| `kyojin` | `kyojin-serve qwen` | `127.0.0.1:8000` | Starts the Qwen engine by default |
| `project-maya` | `maya-cli --port 8095` | port `8095` | Host selection is left to the application |
| `rocmfpx` | `rocmfpx` | `127.0.0.1:8080` | `llama-server` endpoint |
| `shimmy` | `shimmy serve` | `127.0.0.1:11434` | Default port is `11434` |
| `stable-diffusion-cpp` | `sd-server` | `127.0.0.1:8080` | Diffusion HTTP server |
| `strata` | `strata-cli --port 8095` | port `8095` | Host selection is left to the application |
| `strixite` | `strixite-server --config ...` | config-defined | Shipped example defaults to port `5300` |

`crucible-strix-halo`, `lucebox`, `qwenox`, and `snowllm` have no service block and must be launched manually.

```bash
brew services list
brew services start gufo
brew services stop gufo
brew services restart gufo
brew services run gufo
brew services info gufo
```

Service logs live under `$(brew --prefix)/var/log/`. Where a service block defines a working directory, it is `$(brew --prefix)/var`.

## Updating

```bash
brew update
brew outdated
brew upgrade
brew upgrade gufo
```

`brew update` refreshes the tap; `brew outdated` lists formulae with newer versions; `brew upgrade` upgrades everything; `brew upgrade <formula>` upgrades one formula. If you installed a non-default variant, reinstall it with the same options after the upgrade.

## Troubleshooting

### General checks

```bash
brew doctor
brew --prefix
brew info heretek-ai/tap/gufo
brew reinstall gufo
```

If the tap metadata is stale or a formula is missing:

```bash
brew untap heretek-ai/tap && brew tap heretek-ai/tap
```

Then reinstall or re-trust the formula.

### Trust errors

If Homebrew reports that a tap or formula is untrusted, trust the narrowest entry that satisfies the install:

```bash
brew trust --formula heretek-ai/tap/gufo
# or, for every item in the tap:
brew trust --tap heretek-ai/tap
```

A fully qualified `brew install heretek-ai/tap/gufo` trusts only `gufo`. Aliases require trust for the canonical formula, not the alias.

### Missing ROCm or CUDA

- **ROCm:** verify that `$HOMEBREW_ROCM_PATH/include/hip/hip_runtime.h` exists, or that `/opt/rocm-nightly` or `/opt/rocm` contains it. Then reinstall with `HOMEBREW_ROCM_PATH` set.
- **CUDA:** verify that `nvcc --version` works and that the toolkit is at `/usr/local/cuda` or pointed to by `HOMEBREW_CUDA_PATH`, `CUDA_HOME`, or `CUDA_PATH`.
- **Wrong backend:** `lucebox` defaults to CUDA; use `--with-rocm` on AMD. `stable-diffusion-cpp` defaults to Vulkan on Linux; use `--with-rocm` or `--with-cpu` for those artifacts.
- **Options ignored:** if a bottle was poured, reinstall with `--build-from-source` and the option.

### Service and linkage issues

```bash
brew services info gufo
tail -n 100 "$(brew --prefix)/var/log/gufo.log"
ldd "$(brew --prefix)/opt/gufo/bin/gufo"
```

If a source-built binary cannot find `libamdhip64.so` after an SDK change, rebuild it with the current `HOMEBREW_ROCM_PATH`. If a macOS binary cannot resolve a dylib, check `otool -L` and reinstall.

### Documentation

```bash
brew help
man brew
```

More documentation: <https://docs.brew.sh>, including [Tap Trust](https://docs.brew.sh/Tap-Trust) and [How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap).

## Maintenance and contributing

Changes land through pull requests; do not push directly to `main`. The nightly publish job is the automation that commits bottle blocks and ledger updates directly to `main`.

### Local checks

```bash
brew style Formula/
brew audit --strict --online --tap=heretek-ai/tap
./scripts/test_local_tap.sh
pytest tests/ -v
```

`./scripts/test_local_tap.sh` syncs tracked tap paths into Homebrew's tap directory, runs `brew style`, runs the strict audit, and executes the Python test suites. `pytest tests/ -v` runs the resolver, ledger, formula-update, and validation-harness tests directly.

### CI and pull requests

- [`tests.yml`](.github/workflows/tests.yml) runs `brew test-bot --only-cleanup-before`, `--only-setup`, and `--only-tap-syntax`, provisions ROCm on Linux, runs `brew test-bot --only-formulae --root-url=https://ghcr.io/v2/heretek-ai/tap`, and runs `pytest tests/ -v` plus ShellCheck.
- Pull-request bottles use the GHCR root URL `https://ghcr.io/v2/heretek-ai/tap`.
- After review, publish with the `publish` workflow (`brew pr-pull`) or locally:

```bash
brew pr-pull --tap=heretek-ai/tap --head-sha=<reviewed-head-sha> <pr-number>
```

Passing `--head-sha` makes the publish fail if the pull request head moves after review. The publish workflow also generates build provenance attestations.

### Formula updates and autobump

- Update the pinned revision in the formula and the matching entry in [`.github/upstream-pins.json`](.github/upstream-pins.json) together.
- The autobump workflow runs `brew bump --no-fork --open-pr --bump-synced --tap=heretek-ai/tap` on a schedule and also handles builder-release dispatches through `scripts/update_formulae.py`. Both paths open a pull request; `brew test-bot` must pass before merge.
- The nightly matrix and the ROCmFPX builder are separate build systems: the matrix produces per-formula bottles and validation proofs, while the ROCmFPX builder produces the `b####` release archives consumed by `rocmfpx`.

### Adding or changing a formula

1. Add or edit the formula under [`Formula/`](Formula/).
2. Add the ledger entry and variant policy to [`.github/upstream-pins.json`](.github/upstream-pins.json).
3. Run `brew style`, the strict online audit, the local tap script, and `pytest`.
4. Open a pull request and let `brew test-bot` and the nightly matrix validate it.

## License and attribution

The tap's own code and automation are licensed under the [MIT License](LICENSE). Each formula remains subject to its upstream project's license. The formula metadata reports:

| License | Formulae |
| :--- | :--- |
| `Apache-2.0` | `crucible-strix-halo`, `gufetto`, `gufo`, `gufo-franzmoca`, `lucebox`, `shimmy`, `snowllm` |
| `MIT` | `kyojin`, `rocmfpx`, `stable-diffusion-cpp` |
| `AGPL-3.0-only` | `qwenox`, `strixite` |
| `:cannot_represent` | `hyperqwen`, `project-maya`, `strata` |

`:cannot_represent` means Homebrew's license metadata cannot express the upstream license; consult the upstream repository for the actual terms. The AGPL-3.0-only formulae carry the corresponding source-availability and distribution obligations.

Upstream projects and trademarks belong to their respective authors. Performance figures, model support, and hardware claims are upstream properties, not guarantees from this tap. Measure on your own hardware and review the upstream documentation before relying on a specific model, quantization, or backend.
