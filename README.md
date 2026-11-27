# Heretek-AI Homebrew Tap

A Homebrew tap for 26 accelerator-focused inference runtimes, servers, and kernel harnesses, two keg-only shared runtime formulae (`rocm-runtime` and `cuda-runtime`), and two macOS GUI casks. Most formulae target AMD ROCm on Linux; the tap also covers NVIDIA CUDA, Apple Metal, Vulkan, SYCL, and CPU paths where the pinned upstream project supports them.

[![brew test-bot](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/tests.yml)
[![brew pr-pull](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/publish.yml/badge.svg)](https://github.com/Heretek-AI/homebrew-tap/actions/workflows/publish.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

The formula files under [`Formula/`](Formula/), the cask files under [`Casks/`](Casks/), and the automation ledger at [`.github/upstream-pins.json`](.github/upstream-pins.json) are the source of truth for upstream revisions, supported targets, installed command names, and options. This README describes the state of that pinned set, not every feature of every upstream project.

## Installation

### Direct install (recommended)

Install a formula by its fully qualified name. Homebrew adds the tap automatically and trusts only the formula being installed:

```bash
brew install heretek-ai/tap/gufo
```

Replace `gufo` with any formula name from the [catalog](#formula-catalog). Direct installation is the safest one-off path because it does not trust the rest of the tap.

### Check hardware and get recommendations

`brew heretek doctor` reports the detected OS, CPU, memory, AMD ROCm, NVIDIA CUDA, Apple Metal, Vulkan, and tap runtime status without failing when a tool or GPU is absent. `brew heretek recommend` prints exact install commands for the detected GPU family and points at a curated Brewfile when one matches.

```bash
brew heretek doctor
brew heretek recommend
```

The external command lives in [`cmd/heretek.rb`](cmd/heretek.rb). Homebrew 6 and later may ask you to trust it before the first run:

```bash
brew trust --command heretek-ai/tap/heretek
```

Neither subcommand changes the system; they only print diagnostics and install commands.

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

# Per-cask trust:
brew trust --cask heretek-ai/tap/kokon
```

Trust the whole tap only when you accept all of its current and future formulae, casks, and external commands:

```bash
brew trust --tap heretek-ai/tap

# The bare tap name is accepted as shorthand:
brew trust heretek-ai/tap
```

A direct `brew install heretek-ai/tap/<formula>` or `brew install --cask heretek-ai/tap/<cask>` trusts only that item. Trusting a whole tap is broader than most users need. Use `brew trust` to list trusted entries and `brew untrust ...` to remove them.

### Brewfile

A standard Brewfile entry is:

```ruby
tap "heretek-ai/tap"
brew "gufo"
brew "gufo-ds41"
cask "kokon"
```

On Homebrew 6 and later, declare trust in the Brewfile. Trust only selected formulae:

```ruby
tap "heretek-ai/tap", trusted: { formulae: ["gufo", "gufo-ds41"] }
brew "gufo"
brew "gufo-ds41"
```

Or trust the whole tap, or individual fully qualified entries:

```ruby
tap "heretek-ai/tap", trusted: true
brew "gufo"

# Equivalent per-entry form:
brew "heretek-ai/tap/gufo", trusted: true
```

`brew bundle cleanup` resets Homebrew's trust store to the declarations in the selected Brewfile, so keep the trust entries you intend to retain.

### Curated Brewfiles

[`Brewfiles/`](Brewfiles/) contains tested bundles for common accelerator families. Each file declares selector trust for exactly the formulae it installs:

| Brewfile | Target hardware |
| :--- | :--- |
| [`Brewfiles/strix-halo.Brewfile`](Brewfiles/strix-halo.Brewfile) | AMD Strix Halo / Ryzen AI Max (`gfx1151`) on Linux |
| [`Brewfiles/rdna3.Brewfile`](Brewfiles/rdna3.Brewfile) | AMD RDNA3 (`gfx1100` family) on Linux |
| [`Brewfiles/blackwell.Brewfile`](Brewfiles/blackwell.Brewfile) | NVIDIA Blackwell (`sm_120`) and DGX Spark (`sm_121`) on Linux |
| [`Brewfiles/apple-silicon.Brewfile`](Brewfiles/apple-silicon.Brewfile) | Apple Silicon macOS |

```bash
brew bundle --file=Brewfiles/strix-halo.Brewfile
```

Use `brew heretek recommend` if you are unsure which file matches your machine. [`Brewfiles/README.md`](Brewfiles/README.md) documents the variants, runtime prerequisites, and check-only usage with `brew bundle list`.

### Installing a non-default variant

Formula options are evaluated when the formula is installed from source. If a bottle is available for your platform, force a source build so the option takes effect:

```bash
brew install --build-from-source --with-tools heretek-ai/tap/gufo
```

For `stable-diffusion-cpp`, options select a different prebuilt artifact rather than changing a compiler build:

```bash
brew install --with-rocm heretek-ai/tap/stable-diffusion-cpp
```

If you reinstall or rebuild a non-default variant, keep the same flags.

### Casks (macOS GUI applications)

macOS desktop applications live in the top-level [`Casks/`](Casks/) directory, following [Homebrew's tap cask guidance](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap#casks). Install a cask by its fully qualified name:

```bash
brew install --cask heretek-ai/tap/kokon
brew install --cask heretek-ai/tap/hatchlight
```

Casks do not accept formula options. Homebrew installs the architecture-appropriate artifact automatically when the upstream publishes both Apple Silicon and Intel builds.

## Formula catalog

The catalog is alphabetical. Each subsection lists the upstream project, purpose, supported platforms/backends, exact installed commands, and every option declared by the formula or cask. Run `brew info heretek-ai/tap/<formula>` or `brew info --cask heretek-ai/tap/<cask>` to see the same options through Homebrew.

### Catalog

<!-- BEGIN GENERATED: formula-catalog -->
| Formula | Upstream | Purpose | Platforms / backends |
| :--- | :--- | :--- | :--- |
| [`basalt`](#basalt) | [jesdga95/basalt](https://github.com/jesdga95/basalt) | NVIDIA CUDA 13 inference engine for Blackwell GPUs | Linux, CUDA |
| [`colibri`](#colibri) | [JustVugg/colibri](https://github.com/JustVugg/colibri) | Run large MoE models locally with a tiny C engine | Linux + macOS, Metal/CPU |
| [`crucible-strix-halo`](#crucible-strix-halo) | [jaedync/crucible-strix-halo](https://github.com/jaedync/crucible-strix-halo) | AMD Strix Halo (gfx1151) kernel harness and memory allocator tuners | Linux, ROCm |
| [`cuda-runtime`](#cuda-runtime) | [developer.nvidia.com/cuda-toolkit](https://developer.nvidia.com/cuda-toolkit) | Shared NVIDIA CUDA runtime libraries for GPU inference engines | Linux x86_64 + arm64, CUDA runtime |
| [`gufo`](#gufo) | [gufo-org/gufo](https://github.com/gufo-org/gufo) | Pure C11/C++20/HIP multimodal inference engine for AMD Strix Halo (gfx1151) | Linux, ROCm |
| [`gufo-ds41`](#gufo-ds41) | [franzmoca/ds41-gufo-extension](https://github.com/franzmoca/ds41-gufo-extension) | Gufo Strix Halo engine with DeepSeek-V4.1-Flash (763B) extension | Linux, ROCm |
| [`hipfire`](#hipfire) | [warpfront/hipfire](https://github.com/warpfront/hipfire) | Native LLM inference engine for AMD RDNA and CDNA GPUs | Linux x86_64, ROCm |
| [`hyperqwen`](#hyperqwen) | [syv-ai/HyperQwen](https://github.com/syv-ai/HyperQwen) | NVIDIA CUDA 13.0 patched vLLM 0.32.0 appliance for Qwen3.8-27B-AWQ | Linux, CUDA |
| [`infr`](#infr) | [kryptic-sh/infr](https://github.com/kryptic-sh/infr) | Vulkan-first and Metal-native LLM inference engine | Linux + macOS, Metal/Vulkan |
| [`kyojin`](#kyojin) | [Yamz-Labs/kyojin](https://github.com/Yamz-Labs/kyojin) | Strix Halo (gfx1151) & RDNA4 EXL3/GGUF inference engine with 5 model servers | Linux, ROCm/CUDA |
| [`libosmos`](#libosmos) | [mrsirg97-rgb/libosmos](https://github.com/mrsirg97-rgb/libosmos) | HIP inference engine and OpenAI-compatible server for AMD Strix Halo | Linux x86_64, ROCm |
| [`lucebox`](#lucebox) | [Luce-Org/lucebox](https://github.com/Luce-Org/lucebox) | LLM speculative inference server for heterogeneous hardware & consumer GPUs | Linux, ROCm/CUDA |
| [`magnitude`](#magnitude) | [magnitudedev/magnitude](https://github.com/magnitudedev/magnitude) | Local inference runtime and agent harness | Linux + macOS, Metal/CPU |
| [`nib`](#nib) | [Chromadera/nib](https://github.com/Chromadera/nib) | C++17 HIP inference engine for Inkling 2 Mini on AMD RDNA3 | Linux x86_64, ROCm |
| [`project-maya`](#project-maya) | [mw00/project-maya](https://github.com/mw00/project-maya) | Tiered MoE engine for GLM-5.3-Flash, Qwen-3.8, DeepSeek-V4.1 & MiniMax | Linux + macOS, ROCm/CUDA/Metal |
| [`qwenox`](#qwenox) | [IIIIIllllIIIIIlllll/Qwenox](https://github.com/IIIIIllllIIIIIlllll/Qwenox) | High-performance Qwen runtime and kernel primitives for Strix Halo | Linux, ROCm |
| [`rocm-runtime`](#rocm-runtime) | [ROCm/TheRock](https://github.com/ROCm/TheRock) | Shared AMD ROCm runtime libraries for GPU inference engines | Linux x86_64, ROCm runtime |
| [`rulith-inference`](#rulith-inference) | [rulith-dev/rulith-inference](https://github.com/rulith-dev/rulith-inference) | Rulith ROCm gfx1151 llama.cpp engine for Qwen3.8-Flash-Next EXL3/GGUF | Linux, ROCm |
| [`shimmy`](#shimmy) | [Michael-A-Kuykendall/shimmy](https://github.com/Michael-A-Kuykendall/shimmy) | Pure-Rust WebGPU & CUDA LLM inference engine | Linux + macOS, Metal/CPU |
| [`snowllm`](#snowllm) | [snowllm/snowllm](https://github.com/snowllm/snowllm) | Hand-written HIP kernels and embedded LLM runner for AMD Ryzen AI Max | Linux, ROCm |
| [`stable-diffusion-cpp`](#stable-diffusion-cpp) | [leejet/stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) | Fast Stable Diffusion, SDXL, Flux, SD3 & Wan inference in C/C++ | Linux + macOS, ROCm/Metal/Vulkan/CPU |
| [`strata`](#strata) | [Niko1221/Strata](https://github.com/Niko1221/Strata) | Tiered MoE engine for Qwen3.8-Flash-Next, Qwen3.6 & DeepSeek-V4.1 | Linux + macOS, ROCm/CUDA/Metal/SYCL |
| [`strixite`](#strixite) | [shawnshekari/strixite](https://github.com/shawnshekari/strixite) | Zero-dependency C++20/HIP inference engine for AMD Strix Halo (gfx1151) | Linux, ROCm |
| [`strixolotl`](#strixolotl) | [snowsh1ne/strixolotl](https://github.com/snowsh1ne/strixolotl) | AMD Strix Halo HIP port of Xolotl for DeepSeek-V4.1-Flash (GSQ-217) | Linux, ROCm |
| [`uzu`](#uzu) | [trymirai/uzu](https://github.com/trymirai/uzu) | Apple Silicon inference engine and Mirai CLI | macOS, Metal/CPU |
| [`xolotl`](#xolotl) | [Indras-Mirror/Xolotl](https://github.com/Indras-Mirror/Xolotl) | Tiered CUDA MoE engine for DeepSeek-V4.1, GLM-5.3, Qwen3.8 & Inkling | Linux, CUDA |
| [`zinc`](#zinc) | [zolotukhin/zinc](https://github.com/zolotukhin/zinc) | Zig inference engine with ROCm, Vulkan, and Metal backends | Linux x86_64, ROCm/Vulkan |
<!-- END GENERATED: formula-catalog -->

### Cask catalog

<!-- BEGIN GENERATED: cask-catalog -->
| Cask | Upstream | Purpose | Platforms |
| :--- | :--- | :--- | :--- |
| [`hatchlight`](#hatchlight) | [hatchlight/hatchlight](https://github.com/hatchlight/hatchlight) | Compare AI image and video generation models side by side | macOS, Apple Silicon and Intel |
| [`kokon`](#kokon) | [GabrieleLozupone/kokon](https://github.com/GabrieleLozupone/kokon) | Local AI photo editor that runs on your own GPU | macOS 15+, Apple Silicon |
<!-- END GENERATED: cask-catalog -->

### Command and option map

| Formula | Installed commands | Options |
| :--- | :--- | :--- |
| `basalt` | `basalt`, `basalt-bench`, `basalt-probe`, `basalt-vision` | None |
| `colibri` | `coli`; engine and tool binaries remain under `libexec/colibri` | None |
| `crucible-strix-halo` | `crucible-strix-halo`; `crucible-strix-halo-server` when upstream ships `server/server.py` | None |
| `cuda-runtime` | None (keg-only; installs shared libraries only) | None |
| `gufo` | `gufo`, `gufo-server`; `gufo-kernel-bench` when built; with `--with-tools`: `gufo-bench-q8-1`, `gufo-tune-hipblaslt`, `gufo-verify-gemma4`, `gufo-verify-vae`, `gufo-simple-chat` | `--with-tools`, `--with-znver4` |
| `gufo-ds41` | `gufo-ds41`, `gufo-ds41-server`; `gufo-ds41-kernel-bench` when built; with `--with-tools`: `gufo-ds41-bench-q8-1`, `gufo-ds41-tune-hipblaslt`, `gufo-ds41-simple-chat` | `--with-tools`, `--with-znver4` |
| `hipfire` | `hipfire`; the daemon stays at `libexec/bin/daemon` | `--with-gfx1100`, `--with-gfx1201`, `--with-gfx906` |
| `hyperqwen` | `hyperqwen`, `hyperqwen-serve`, `hyperqwen-server`, `hyperqwen-bench`, `hyperqwen-chat` | None |
| `infr` | `infr` | None |
| `kyojin` | `kyojin-serve`, `kyojin-bench`, `kyojin-convert`, `kyojin-chat` | `--with-rdna4`, `--with-cuda` |
| `libosmos` | `osmos-api`, `osmos-serve` | `--with-npu` |
| `lucebox` | `lucebox-server`, `lucebox` | `--with-rocm` |
| `magnitude` | `magnitude` | None |
| `nib` | `nib` | None |
| `project-maya` | Linux build outputs: `maya`, `maya-ds4`, `maya-mm3`, `maya-vision`; macOS: `maya`, `maya-metal`, `maya-vision`; all: `maya-server`, `maya-cli`, `maya-chat`, `maya-setup`; Linux tools when built: `maya-tune-hipblaslt`, `maya-peer-probe`, `maya-plan`, `maya-device`, `maya-gguf`, `maya-dequant`, `maya-load`, `maya-concurrent`, `maya-overlap` | `--with-wave64`, `--with-all-amdgpu`, `--with-cuda`, `--with-native` |
| `qwenox` | `qwenox-engine`, `qwenox`, `qwenox-bench`, `qwenox-server`; when built: `qwenox-tok-cli`, `qwenox-tpl-cli`, `qwenox-eng-cli` | None |
| `rocm-runtime` | None (keg-only; installs shared libraries and kernel packs) | None |
| `rulith-inference` | `rulith-server`, `rulith-quantize`, `rulith-cli` | None |
| `shimmy` | `shimmy` | None |
| `snowllm` | `snowllm`; upstream also declares `snowllm-mineru` (optional MinerU dependencies are not installed by this formula) | None |
| `stable-diffusion-cpp` | `sd-cli`, `sd-server`, `stable-diffusion` | `--with-rocm`, `--with-cpu` |
| `strata` | `strata`, `strata-cli`, `strata-server`, `strata-chat`, `strata-setup`; engines/tools when built: `strata-q36`, `strata-dsv41`, `strata-split-2`, `strata-split-3`, `strata-split-4`, `strata-device`, `strata-plan`, `strata-gguf`, `strata-dequant`, `strata-load`, `strata-concurrent`, `strata-overlap`, `strata-vision` or `strata-vision-hip` | `--with-all-amdgpu`, `--with-cuda`, `--with-sycl`, `--with-native` |
| `strixite` | `strixite-server`, `strixite`, `strixite-convert-qwen4exp`, `strixite-convert-ngram-table`, `strixite-transcode-ngram-table`, `strixite-inspect-strixw`, `strixite-check-stream-calls` | `--with-portable-cpu` |
| `strixolotl` | `strixolotl`, `strixolotl-serve` | None |
| `uzu` | `mirai` | None |
| `xolotl` | `xolotl`, `xolotl-ds41`, `xolotl-dense`, `xolotl-glm`, `xolotl-inkling`, `xolotl-ernie`, `xolotl-vision`, `xolotl-serve` | None |
| `zinc` | `zinc`, `zinc-tokenize` | `--with-vulkan` |

### basalt

**Upstream:** [jesdga95/basalt](https://github.com/jesdga95/basalt)
**Purpose:** Local inference engine for Qwen3.8-Flash-Next, DeepSeek-V4.1-Flash, Qwen3.8-27B, Hy4-flash, and Inkling 2 Mini, with MoE expert RAM/SSD offload, an OpenAI/Anthropic-compatible server, and a built-in web UI.
**Platforms/backends:** Linux only. The Intel path installs the official prebuilt `linux-x64` archive built for NVIDIA Blackwell `sm_120` and needs a CUDA 13 runtime. The arm64 path builds the same release from the verified source tarball for the DGX Spark GB10 (`sm_121`), which upstream does not yet publish as a prebuilt archive; it needs CMake, Ninja, GCC 13+, and a CUDA 13 toolkit.
**Options:** None. Architecture selects prebuilt versus source.
**Commands:** `basalt`, `basalt-bench`, `basalt-probe`, `basalt-vision`.

```bash
basalt --help
basalt-probe --model /path/to/model.basalt
basalt serve --config "$(brew --prefix)/etc/basalt/basalt_config.json" --host 127.0.0.1
```

The formula installs the release tree under `libexec`, puts executable wrappers in `bin`, and writes an example configuration to `$(brew --prefix)/etc/basalt/basalt_config.example.json`. The server is written in Python; install its pinned dependencies into the formula's virtualenv before starting it:

```bash
python3 -m venv "$(brew --prefix)/opt/basalt/libexec/.venv"
"$(brew --prefix)/opt/basalt/libexec/.venv/bin/pip" install -r "$(brew --prefix)/opt/basalt/libexec/requirements.txt"
```

Edit `basalt_config.json` to point at your `.basalt` model packs, then start the service. The shipped config and service listen on `127.0.0.1:18012`. A CUDA 13 runtime must be visible to the loader; the prebuilt archive carries a `/usr/local/cuda-13.0` RUNPATH, so install the toolkit there or set `LD_LIBRARY_PATH` to your CUDA 13 library directory.

### colibri

**Upstream:** [JustVugg/colibri](https://github.com/JustVugg/colibri)
**Purpose:** Tiny C inference engine for large MoE models, with experts streamed from disk, an OpenAI-compatible server, a terminal UI, and per-family engine binaries.
**Platforms/backends:** Linux x86_64 and arm64 from the official prebuilt archives; macOS arm64 from the official Metal archive. The Linux archives include CPU and Vulkan engines; the macOS archive requires macOS 26 (Tahoe) or newer, `libomp`, and uses Metal. Upstream publishes no macOS Intel archive, so the formula requires arm64 on macOS.
**Options:** None. The OS and architecture select the archive.
**Commands:** `coli`; the engine and support binaries stay under `libexec/colibri`.

```bash
coli --help
coli info --model /path/to/model
coli serve --model /path/to/model
```

`coli setup` performs the one-step hardware detection, model selection/download, and engine preparation. `coli` is the only command linked into `PATH`; upstream does not intend the engine binaries to be run directly.

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

### cuda-runtime

**Upstream:** [NVIDIA CUDA toolkit](https://developer.nvidia.com/cuda-toolkit)
**Purpose:** Keg-only shared NVIDIA CUDA 13 runtime used by the tap's CUDA engines. It installs `libcudart.so.13` from the `cuda_cudart` archive and `libcublas.so.13`/`libcublasLt.so.13` from the separate `libcublas` archive (shared libraries only; headers are intentionally excluded).
**Platforms/backends:** Linux x86_64 and Linux arm64 (SBSA/DGX Spark); CUDA runtime only.
**Commands:** None. The formula installs shared libraries under its keg prefix.
**Options:** None.

`cuda-runtime` is keg-only because it provides shared libraries for other formulae. Engines resolve it with `formula_opt_prefix("cuda-runtime")` and link against its `lib` directory. For a manual build or a shell session:

```bash
export CUDA_HOME="$(brew --prefix cuda-runtime)"
export CUDAToolkit_ROOT="$CUDA_HOME"
export LD_LIBRARY_PATH="$CUDA_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

The formula does not include `nvcc`, the CUDA compiler, or the rest of the toolkit. Building CUDA code from source still needs a full CUDA 13 toolkit with `nvcc`; set `HOMEBREW_CUDA_PATH`, `CUDA_HOME`, or `CUDA_PATH` to that toolkit. `basalt`'s prebuilt x86_64 archive expects `libcudart.so.13` and `libcublas.so.13` on the loader path, which this formula supplies without installing a full toolkit.

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
gufo serve --host 127.0.0.1 --port 18001
```

Models are stored under `~/.cache/gufo/models` by default; override with `GUFO_MODELS_DIR` or `--model-dir`.

### gufo-ds41

**Upstream:** [franzmoca/ds41-gufo-extension](https://github.com/franzmoca/ds41-gufo-extension) (built with its flake-pinned [gufo-org/gufo](https://github.com/gufo-org/gufo) revision)
**Purpose:** Upstream Gufo compiled with the DeepSeek-V4.1-Flash (763B) Strix Halo source extension, supporting resident and SSD-streamed expert execution, DSpark speculative decoding, and Engram tables. Replaces the deprecated `gufo-franzmoca` fork.
**Platforms/backends:** Linux only; ROCm `gfx1151`. The upstream binary is installed as `gufo-ds41`, not `gufo`.
**Options:**
- `--with-tools` installs `gufo-ds41-bench-q8-1`, `gufo-ds41-tune-hipblaslt`, and `gufo-ds41-simple-chat`.
- `--with-znver4` compiles host code for `-march=znver4` plus AVX-512 instead of the default `-march=znver5`.

```bash
gufo-ds41 --help
gufo-ds41 --version
gufo-ds41 serve --host 127.0.0.1 --port 18003
```

`gufo-ds41` and `gufo` can be installed side-by-side without binary collisions.

### hipfire

**Upstream:** [warpfront/hipfire](https://github.com/warpfront/hipfire)
**Purpose:** Native Rust + HIP inference engine for AMD RDNA and CDNA GPUs, with an OpenAI-compatible daemon, curated model registry, quantization, benchmarks, and prebuilt HIP kernel packs.
**Platforms/backends:** Linux x86_64 only. The default install targets `gfx1151` (Strix Halo / Ryzen AI Max) and installs its prebuilt kernel pack. The optional kernel packs add `gfx1100` (RDNA3), `gfx1201` (RDNA4), or `gfx906` (Vega 20 / GCN5). ROCm is loaded dynamically at runtime.
**Options:**
- `--with-gfx1100` installs the `gfx1100` kernel pack instead of the bundled `gfx1151` pack.
- `--with-gfx1201` installs the `gfx1201` kernel pack.
- `--with-gfx906` installs the `gfx906` kernel pack.

Only one kernel-pack option may be selected. The release binaries themselves are shared across these packs.

```bash
hipfire --help
hipfire pull qwen3.8:27b-mq4-xts
hipfire serve 127.0.0.1:18011 --no-prewarm
hipfire profile
```

The service listens on `127.0.0.1:18011`. hipfire has no `--port` flag; the service uses the documented positional `HOST:PORT` bind. ROCm 7.2 or newer is required for `gfx1151`; RDNA4 needs ROCm 6.4 or newer. The CLI's `daemon` helper stays under `libexec/bin`, beside the kernel packs, so `PATH` does not gain a generic `daemon` command.

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

`hyperqwen-serve` reads `HYPERQWEN_MODEL`, `HYPERQWEN_PORT` (default `18020`), `HYPERQWEN_KV_CACHE_DTYPE`, `HYPERQWEN_GPU_MEMORY_UTILIZATION`, `HYPERQWEN_MAX_MODEL_LEN`, and `HYPERQWEN_MAX_NUM_SEQS`. The service block sets `HYPERQWEN_PORT=18020` explicitly. If `nvcc` is not found at install time, the package still installs but `liblsa.so` is not compiled.

### infr

**Upstream:** [kryptic-sh/infr](https://github.com/kryptic-sh/infr)
**Purpose:** From-the-metal inference server with a Vulkan-first Linux path, native Apple Metal on macOS, an OpenAI-compatible API, and GGUF/Hugging Face model handling.
**Platforms/backends:** Linux x86_64 and arm64 from prebuilt archives using Vulkan, with a CPU fallback; macOS arm64 and Intel from prebuilt archives using Metal or CPU.
**Options:** None. The OS and architecture select the archive.
**Commands:** `infr`; shell completions and `infr(1)` are installed with the formula.

```bash
infr --help
infr pull unsloth/Qwen3-14B-GGUF:Q4_K_M
infr serve unsloth/Qwen3-14B-GGUF:Q4_K_M
```

`infr serve` defaults to `127.0.0.1:8080`. Linux Vulkan builds need a Vulkan loader and a working ICD/driver at runtime.

### kyojin

**Upstream:** [Yamz-Labs/kyojin](https://github.com/Yamz-Labs/kyojin)
**Purpose:** EXL3/GGUF inference engine with five server entrypoints: `qwen`, `glm`, `mimo`, `ds41`, and `flint`.
**Platforms/backends:** Linux. ROCm is the default (`gfx1151`, or `gfx1151;gfx1150;gfx1200;gfx1201` with `--with-rdna4`). `--with-cuda` selects a CUDA build instead and sets `TORCH_CUDA_ARCH_LIST=8.0;8.6;8.9;9.0;12.0`.
**Options:**
- `--with-rdna4` adds RDNA4 (`gfx1200`, `gfx1201`) and RDNA3.5 (`gfx1150`) targets alongside `gfx1151`.
- `--with-cuda` builds for NVIDIA CUDA instead of AMD ROCm.

```bash
kyojin-serve --help
kyojin-serve qwen -m /path/to/Qwen3.8-35B-A3B-EXL3 --mtp --port 18010
kyojin-serve ds41 -m /path/to/DeepSeek-V4.1-Flash-GGUF --ngram --port 18010
kyojin-bench --help
kyojin-convert --help
kyojin-chat --help
```

The wrappers set `ROCM_PATH`/`EXL3_ROCM_SDK`, unset `HSA_OVERRIDE_GFX_VERSION`, preload `libhsa-runtime64.so.1`, and seed `~/.triton/cache` from the bundled Triton archive on first use.

### libosmos

**Upstream:** [mrsirg97-rgb/libosmos](https://github.com/mrsirg97-rgb/libosmos)
**Purpose:** Pure C/HIP inference engine for AMD Strix Halo (`gfx1151`) covering DeepSeek-V4.1-Flash with SSD-streamed experts, Qwen3.8-Flash-Next, Inkling-2-Small/Mini, Hy4-flash, and `osmos1.7b`, with an OpenAI-compatible `osmos-api` server.
**Platforms/backends:** Linux x86_64 only; ROCm `gfx1151`. The formula builds against the ROCm SDK selected by `HOMEBREW_ROCM_PATH`, `ROCM_PATH`, `/opt/rocm-nightly`, or `/opt/rocm`, and targets Strix Halo explicitly.
**Options:**
- `--with-npu` passes `NPU=1` to the Makefile and enables the experimental AMD XDNA NPU path. It requires AMD XRT (`libxrt_coreutil`) and NPU kernels supplied outside this formula.

```bash
osmos-api --version
osmos-api --config /path/to/pack/osmos.json --host 127.0.0.1 --port 8091
osmos-serve --model /path/to/pack/first-shard.gguf
```

The formula installs `osmos-api`, `osmos-serve`, the static `libosmos.a`/`libosmos_hip.a` libraries, and the public `osmos` headers. The release tarball bundles `third_party/libevt`, so no submodule checkout is needed.

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

### magnitude

**Upstream:** [magnitudedev/magnitude](https://github.com/magnitudedev/magnitude)
**Purpose:** Local inference runtime and agent harness, distributed as a self-contained `magnitude` CLI.
**Platforms/backends:** macOS arm64 and Intel; Linux x86_64 and arm64 (glibc). The formula installs the `magnitude-cli-*` release archive and names the command `magnitude`.
**Options:** None. The OS and architecture select the archive.
**Commands:** `magnitude`.

```bash
magnitude --help
magnitude hardware
magnitude models
magnitude serve
```

The release tag is the npm-style `@magnitudedev/cli@0.3.5`; the formula pins the equivalent GitHub release assets and uses an explicit `livecheck` regex for that tag shape. Runtime state and downloaded models live under the invoking user's home directory.

### nib

**Upstream:** [Chromadera/nib](https://github.com/Chromadera/nib)
**Purpose:** C++17 / HIP inference engine for Inkling 2 Mini with a built-in OpenAI-compatible server and web UI, tuned for AMD RDNA3.
**Platforms/backends:** Linux x86_64 only, built from source with CMake and `hipcc` against a ROCm SDK. The formula targets `gfx1100` (Radeon RX 7900 XTX/XT) and `-march=native` host code.
**Options:** None. `HOMEBREW_ROCM_PATH` selects the ROCm SDK at build time; the formula falls back to `ROCM_PATH`, `/opt/rocm`, then `/usr`.
**Commands:** `nib`.

```bash
nib --version
nib serve -m models/Inkling-2-Mini-NVFP4-Mixed.gguf --host 127.0.0.1 --port 4444
```

Model packs are not bundled. Download the Inkling 2 Mini Nib pack from Hugging Face (`degenmeowster/Inkling-2-Mini-Nib-Pack`) and pass the GGUF, MTP, and multimodal projector paths as shown in the upstream README. The server requires a `gfx1100` GPU and enough VRAM for the pack (upstream documents 16 GiB as insufficient and 20 GiB as the practical floor).

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
maya-cli --model glm51 --host 127.0.0.1 --port 18005
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

### rocm-runtime

**Upstream:** [ROCm/TheRock](https://github.com/ROCm/TheRock)
**Purpose:** Keg-only shared AMD ROCm runtime for the tap's HIP engines. It provides `libamdhip64`, `libhsa-runtime64`, `libamd_comgr`, rocBLAS/hipBLAS/hipBLASLt, rocSOLVER, and the `.kpack` kernel packs, without the compiler or profiler payloads.
**Platforms/backends:** Linux x86_64; ROCm runtime. The formula downloads four GPU-family tarballs (`gfx1151`, `gfx110X`, `gfx1150`, and `gfx120X`) and installs roughly 1.4 GB of runtime libraries and kernel packs.
**Commands:** None. The formula installs shared libraries and kernel packs under its keg prefix.
**Options:** None.

`rocm-runtime` is keg-only because engines link against it through `formula_opt_lib("rocm-runtime")` or `formula_opt_prefix("rocm-runtime")` rather than the default Homebrew prefix. For a manual run or shell session:

```bash
export ROCM_PATH="$(brew --prefix rocm-runtime)"
export ROCM_KPACK_PATH="$ROCM_PATH/.kpack"
export LD_LIBRARY_PATH="$ROCM_PATH/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

The formula installs runtime libraries only. Compiler, LLVM, profiler, MIOpen, and other SDK payloads are excluded. Source builds still need a full ROCm SDK with HIP headers and `hipcc`; set `HOMEBREW_ROCM_PATH` to that SDK. The installed engines only need this shared runtime plus the kernel packs.

### rulith-inference

**Upstream:** [rulith-dev/rulith-inference](https://github.com/rulith-dev/rulith-inference) / [rulith-dev/llama.cpp (`rulith` branch)](https://github.com/rulith-dev/llama.cpp/tree/rulith)
**Purpose:** Linux ROCm `gfx1151` engine build of Rulith's patched `llama.cpp` stack tuned for Qwen3.8-Flash-Next EXL3/GGUF with MTP speculative decoding on AMD Strix Halo.
**Platforms/backends:** Linux only; AMD ROCm `gfx1151` (TheRock ROCm 10.1+ recommended). Upstream's desktop GUI installer is Windows 11 only; this formula packages the native Linux engine binaries.
**Options:** None.

```bash
rulith-server --help
rulith-server -m /path/to/model.gguf --host 127.0.0.1 --port 18014
rulith-quantize --help
rulith-cli --help
```

`rulith-server`, `rulith-quantize`, and `rulith-cli` are namespaced symlinks to the bundled binaries under `libexec/bin` so no bare `llama-*` commands are linked into `PATH`. The `brew services` endpoint listens on `127.0.0.1:18014`.

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
sd-server --host 127.0.0.1 --port 18008
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
strata-cli --model qwen38 --host 127.0.0.1 --port 18006
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
strixite-server --model /path/to/qwen4exp-strixw --host 127.0.0.1 --port 18004 --kv-mode fp8 --mtp-draft 3
strixite-server --config "$(brew --prefix)/etc/strixite/strix_server.example.conf"
```

`strixite` is a symlink to `strixite-server`. The formula installs an example configuration at `$(brew --prefix)/etc/strixite/strix_server.example.conf` and creates `strix_server.conf` from it if that file does not already exist. The installed example uses `host = 127.0.0.1` and `port = 18004`, and the service passes the same values explicitly.

### strixolotl

**Upstream:** [snowsh1ne/strixolotl](https://github.com/snowsh1ne/strixolotl)
**Purpose:** AMD Strix Halo (`gfx1151`) HIP/ROCm port of Xolotl for DeepSeek-V4.1-Flash-1017 (GSQ-217 quant, 1M context, DSpark MTP speculative decoding).
**Platforms/backends:** Linux only; ROCm `gfx1151`.
**Options:** None.

```bash
strixolotl --help
strixolotl-serve --config /path/to/strata-ds41.json --host 127.0.0.1 --port 18013
```

### uzu

**Upstream:** [trymirai/uzu](https://github.com/trymirai/uzu)
**Purpose:** Apple-focused inference engine with the `mirai` CLI, an interactive terminal app, and an OpenAI-compatible server.
**Platforms/backends:** macOS only. Apple Silicon uses the Metal build; Intel Macs use the CPU build. The prebuilt CLI requires macOS 26.4 or newer. The formula installs the upstream `mirai-*-apple-darwin.tar.gz` CLI archive as `mirai`.
**Options:** None. Architecture selects the archive.
**Commands:** `mirai`.

```bash
mirai --help
mirai --model trymirai/Qwen3.5-4B-M
mirai server --model trymirai/Qwen3.5-4B-M
```

The server defaults to `127.0.0.1:8000` and accepts `--host` and `--port`. The CLI downloads and converts models on first use; the GUI `.dmg` is not installed by this formula.

### xolotl

**Upstream:** [Indras-Mirror/Xolotl](https://github.com/Indras-Mirror/Xolotl)
**Purpose:** Tiered CUDA MoE and dense inference engine built on Strata for DeepSeek-V4.1-Flash (552B), GLM-5.3-Flash (320B), Qwen3.8-Flash-Next (125B), Qwen3.8-27B, Inkling-2-Mini, Muse Glimmer 30B, LFM3-Omni, and ERNIE-5.5-Flash.
**Platforms/backends:** Linux only; NVIDIA CUDA (`sm_80` through `sm_120`).
**Options:** None.

```bash
xolotl-ds41 --help
xolotl-dense --selftest
xolotl-serve --config /path/to/model.json --port 8090
```

All binaries are namespaced (`xolotl`, `xolotl-ds41`, `xolotl-dense`, `xolotl-glm`, `xolotl-inkling`, `xolotl-ernie`, `xolotl-vision`, `xolotl-serve`) so `xolotl` installs cleanly alongside `strata`.

### zinc

**Upstream:** [zolotukhin/zinc](https://github.com/zolotukhin/zinc)
**Purpose:** Zig inference engine and OpenAI-compatible server with ROCm/HIP, Vulkan, and Metal backends.
**Platforms/backends:** Linux x86_64 only in this tap. The default archive is the ROCm/HIP build; `--with-vulkan` installs the Vulkan build instead. Each binary contains one backend and has no runtime switch.
**Options:**
- `--with-vulkan` installs the Vulkan archive instead of the ROCm/HIP archive.

```bash
zinc --version
zinc model pull qwen35-9b-q4k-m
zinc model use qwen35-9b-q4k-m
zinc serve --port 18009
```

The ROCm build needs the matching ROCm runtime and runtime-compilation headers. The Vulkan build needs a Vulkan loader and ICD. ZINC's HTTP listener binds all interfaces on port `8080` by default and upstream exposes no `--host` flag; the tap service passes `--port 18009`. Use a host firewall if the API must stay loopback-only. Run `zinc model pull` and `zinc model use` before starting the service, because `zinc serve` exits when no active model is configured.

### hatchlight

**Upstream:** [hatchlight/hatchlight](https://github.com/hatchlight/hatchlight)
**Purpose:** Desktop studio that sends one prompt to many local or BYOK image and video generation models and compares the results side by side.
**Platforms:** macOS, with separate Apple Silicon and Intel disk images in the pinned release.
**Artifact:** `Hatchlight_0.7.0_aarch64.dmg` for Apple Silicon and `Hatchlight_0.7.0_x64.dmg` for Intel from the `v0.7.0` GitHub release.

```bash
brew install --cask heretek-ai/tap/hatchlight
```

### kokon

**Upstream:** [GabrieleLozupone/kokon](https://github.com/GabrieleLozupone/kokon)
**Purpose:** Local AI photo editor that generates and edits images on the user's own GPU, with brush-based change/remove/replace/add operations and an optional browser-based remote mode.
**Platforms:** macOS 15 (Sequoia) or newer on Apple Silicon. Upstream publishes only an `aarch64` macOS disk image in the pinned release, so the cask declares an arm64 requirement.
**Artifact:** `Kokon_0.12.1_aarch64.dmg` from the `v0.12.1` GitHub release.

```bash
brew install --cask heretek-ai/tap/kokon
```

## Command names and coexistence

The tap avoids linking upstream generic names that would collide with other packages:

- **No bare `llama-*`.** `rulith-inference` exposes `rulith-server`, `rulith-quantize`, and `rulith-cli`; the bundled `llama-*` binaries stay under the formula's `libexec`.
- **No bare `sd`.** `stable-diffusion-cpp` installs the upstream names `sd-cli` and `sd-server`, plus the tap alias `stable-diffusion` for `sd-cli`. Homebrew-core's `sd` is a different program and is not replaced.
- **No bare engine or daemon names.** `colibri` links only its `coli` launcher; the `colibri`, `colibri-tui`, and per-family engine binaries stay under `libexec/colibri`. `hipfire` links only `hipfire`; its `daemon` helper stays at `libexec/bin/daemon`. `magnitude` installs its upstream `magnitude-cli` archive as `magnitude`, and `uzu` installs its `mirai-*-apple-darwin` archive as `mirai`.
- **No bare `gufo` from extensions.** `gufo-ds41` renames upstream `gufo` to `gufo-ds41`, so it installs side-by-side with `gufo`.
- **Formula-prefixed helpers.** Kyojin, Project Maya, Strata, Xolotl, Strixolotl, Qwenox, Strixite, and HyperQwen install their helper tools with formula-specific prefixes (`kyojin-*`, `maya-*`, `strata-*`, `xolotl-*`, `strixolotl-*`, `qwenox-*`, `strixite-*`, `hyperqwen-*`).

If a short name is ambiguous with a core formula, use the fully qualified tap name: `brew install heretek-ai/tap/<formula>`.

## Hardware and backend compatibility

This generated matrix combines the pinned variant ledger, the validation specs, and formula metadata. "Source" means the formula installs from the pinned source revision and compiles it (or, for Python packages, installs it into a virtualenv) unless a matching CI bottle is published.

<!-- BEGIN GENERATED: hardware-matrix -->
| Hardware family | Recommended formulae / install commands |
| :--- | :--- |
| AMD Strix Halo (`gfx1151`) | Runtime: `brew install heretek-ai/tap/rocm-runtime`<br>`brew install heretek-ai/tap/crucible-strix-halo`<br>`brew install heretek-ai/tap/gufo`<br>`brew install heretek-ai/tap/gufo-ds41`<br>`brew install heretek-ai/tap/hipfire`<br>`brew install heretek-ai/tap/kyojin`<br>`brew install heretek-ai/tap/libosmos`<br>`brew install --with-rocm heretek-ai/tap/lucebox`<br>`brew install heretek-ai/tap/project-maya`<br>`brew install heretek-ai/tap/qwenox`<br>`brew install heretek-ai/tap/rulith-inference`<br>`brew install heretek-ai/tap/snowllm`<br>`brew install heretek-ai/tap/strata`<br>`brew install heretek-ai/tap/strixite`<br>`brew install heretek-ai/tap/strixolotl` |
| AMD RDNA3 (`gfx1100` family) | Runtime: `brew install heretek-ai/tap/rocm-runtime`<br>`brew install --with-gfx1100 heretek-ai/tap/hipfire`<br>`brew install heretek-ai/tap/nib`<br>`brew install heretek-ai/tap/project-maya`<br>`brew install heretek-ai/tap/strata` |
| AMD RDNA4 (`gfx1200` family) | Runtime: `brew install heretek-ai/tap/rocm-runtime`<br>`brew install --with-gfx1201 heretek-ai/tap/hipfire`<br>`brew install --with-rdna4 heretek-ai/tap/kyojin`<br>`brew install heretek-ai/tap/project-maya`<br>`brew install heretek-ai/tap/strata` |
| NVIDIA Blackwell (CUDA `sm_120`/`sm_121`) | Runtime: `brew install heretek-ai/tap/cuda-runtime`<br>`brew install heretek-ai/tap/basalt`<br>`brew install heretek-ai/tap/hyperqwen`<br>`brew install --with-cuda heretek-ai/tap/kyojin`<br>`brew install heretek-ai/tap/lucebox`<br>`brew install --with-cuda heretek-ai/tap/project-maya`<br>`brew install --with-cuda heretek-ai/tap/strata`<br>`brew install heretek-ai/tap/xolotl` |
| NVIDIA CUDA (`sm_80`-`sm_90`) | Runtime: `brew install heretek-ai/tap/cuda-runtime`<br>`brew install heretek-ai/tap/hyperqwen`<br>`brew install --with-cuda heretek-ai/tap/kyojin`<br>`brew install heretek-ai/tap/lucebox`<br>`brew install --with-cuda heretek-ai/tap/project-maya`<br>`brew install --with-cuda heretek-ai/tap/strata`<br>`brew install heretek-ai/tap/xolotl` |
| Apple Silicon (macOS) | Runtime: none<br>`brew install heretek-ai/tap/colibri`<br>`brew install heretek-ai/tap/infr`<br>`brew install heretek-ai/tap/magnitude`<br>`brew install heretek-ai/tap/project-maya`<br>`brew install heretek-ai/tap/shimmy`<br>`brew install heretek-ai/tap/stable-diffusion-cpp`<br>`brew install heretek-ai/tap/strata`<br>`brew install heretek-ai/tap/uzu` |
| CPU / Vulkan fallback | Runtime: none<br>`brew install heretek-ai/tap/colibri`<br>`brew install heretek-ai/tap/infr`<br>`brew install heretek-ai/tap/magnitude`<br>`brew install heretek-ai/tap/shimmy`<br>`brew install heretek-ai/tap/stable-diffusion-cpp`<br>`brew install --with-vulkan heretek-ai/tap/zinc` |
<!-- END GENERATED: hardware-matrix -->

### Target notes

- `gfx1151` is AMD Strix Halo / Ryzen AI Max. `gfx1150` is Strix Point. `gfx1100` and `gfx110X` are RDNA3 families; `gfx1200`, `gfx1201`, and `gfx120X` are RDNA4; `gfx103X` is RDNA2. `gfx908` is Instinct MI100 and `gfx90a` is Instinct MI210/MI250X.
- `gfx906`, `gfx942`, and `gfx950` are available through Project Maya's `--with-wave64` option. `hipfire` also ships a `gfx906` kernel-pack option.
- macOS support covers `colibri` (arm64 only), `infr` (arm64 and Intel), `magnitude` (arm64 and Intel), `project-maya`, `strata`, `shimmy`, `stable-diffusion-cpp`, and `uzu` (arm64 and Intel); the two casks are macOS GUI applications. The other formulae declare Linux only. `colibri` declares an arm64 requirement on macOS because upstream publishes no Intel archive.
- CUDA support covers `basalt`, `hyperqwen`, `kyojin --with-cuda`, `lucebox` (default), `project-maya --with-cuda`, `strata --with-cuda`, and `xolotl`. `shimmy`'s pinned upstream CUDA feature is not enabled here.
- Vulkan is supported by `colibri` (Linux archive), `infr` (Linux archive), `stable-diffusion-cpp` (default Linux artifact), and `zinc --with-vulkan`. SYCL is supported by `strata --with-sycl`. The CPU-only paths are `shimmy` on Linux and `stable-diffusion-cpp --with-cpu`; `infr`, `colibri`, and `uzu` include a CPU fallback, and Project Maya and Strata compile a CPU fallback into their GPU builds but do not offer a standalone CPU option.
- `basalt`, `colibri`, `infr`, and `magnitude` publish different archives per platform/architecture. `basalt` is the only one that pairs a prebuilt x86_64 archive with a source build on arm64; the other three install prebuilt archives for every supported target.

### Prebuilt artifacts and source builds

- **Always prebuilt:** `stable-diffusion-cpp` installs upstream release zips for Vulkan, ROCm, CPU, or macOS Metal; `colibri`, `hipfire`, `infr`, `magnitude`, `uzu`, and `zinc` install upstream CLI/engine archives. None of these needs a compiler for its default artifact.
- **Hybrid:** `basalt` installs the upstream Blackwell archive on Linux x86_64 and builds the verified source tag on Linux arm64 (DGX Spark).
- **Source by default:** the remaining formulae install from pinned source revisions, including `gufo-ds41`, `rulith-inference`, `strixolotl`, `xolotl`, and `nib`, which build with CMake against the host ROCm or CUDA SDK. Homebrew may pour a matching CI bottle; if no bottle matches your OS/architecture/variant, it builds from source.
- **Toolchain coupling:** source-built binaries link against the ROCm or CUDA installation present at build time. Prebuilt ROCm binaries such as `hipfire` and `zinc` load the host ROCm runtime dynamically and need a compatible SDK on the loader path. Rebuild or reinstall if that SDK moves. The tap's `rocm-runtime` and `cuda-runtime` formulae provide shared runtimes without compilers; `basalt`'s x86_64 archive expects the CUDA 13 runtime on the loader path.
- **Bottles are platform- and variant-specific.** There is no universal bottle for a formula with `gfx` or backend options. Use `--build-from-source` when you need a non-default option.

## Build prerequisites and the ROCm path

### Common prerequisites

- Homebrew on Linux x86_64, Linux arm64 (DGX Spark for `basalt`), or macOS.
- Homebrew installs the declared build dependencies (for example `cmake`, `ninja`, `pkgconf`, `python@3.12`, `rust`, `gcc`, or `lld`) as part of the install.
- macOS source builds need the Xcode Command Line Tools and a Metal-capable toolchain.
- Some formulae use Python 3.12 virtualenvs (`project-maya`, `strata`, `snowllm`, `hyperqwen`, `kyojin`); the formula handles the virtualenv, but the ROCm or CUDA SDK is still external. `basalt`'s Python server dependencies are installed by the user into the formula's `libexec/.venv` as shown in its caveats.

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

If no path contains the HIP headers, installation stops with a message asking you to set `HOMEBREW_ROCM_PATH`. Source builds in CI use a full pinned SDK in the `stx-halo` runner or the `brew-rocm` toolchain image; `/opt/rocm-nightly` remains a local fallback, not a requirement. A normal `/opt/rocm` installation works when selected explicitly.

Bottles link against the shared keg-only `rocm-runtime` (`Formula["rocm-runtime"].opt_lib`) and record that relocatable path in RPATH, so they do not embed the SDK path. Source builds still need the SDK for headers and `hipcc`. Moving or replacing the `rocm-runtime` keg after installation can leave a binary unable to find `libamdhip64.so` or related libraries; reinstall the engine after such a change.

`libosmos` uses the same resolution order and additionally builds for Strix Halo `gfx1151` with `HIP_ARCH=gfx1151`. Pass `--with-npu` only when AMD XRT and the NPU kernels are already available; the formula does not install XRT.

`nib` uses the same resolution order (with `/usr` as a final fallback for distro ROCm packages), builds with `hipcc`, and passes `-DGPU_TARGET=gfx1100` to CMake. `hipfire` and `zinc` install prebuilt binaries that load ROCm dynamically; they do not compile HIP kernels during installation, but they need a matching ROCm runtime at run time. `hipfire` also installs a prebuilt kernel pack selected by `--with-gfx1100`, `--with-gfx1201`, or `--with-gfx906`.

### NVIDIA CUDA

CUDA formulae probe `HOMEBREW_CUDA_PATH`, `CUDA_HOME`, `CUDA_PATH`, and `/usr/local/cuda` for a toolkit. Install a CUDA toolkit that provides `nvcc`, then either place it at `/usr/local/cuda` or pass `HOMEBREW_CUDA_PATH`:

```bash
export HOMEBREW_CUDA_PATH=/usr/local/cuda
brew install --build-from-source heretek-ai/tap/lucebox
```

`hyperqwen` compiles `liblsa.so` only when `nvcc` is found; without it, the package still installs but the helper library is skipped. `lucebox` builds CUDA by default, so AMD users must pass `--with-rocm`.

`basalt` is CUDA 13 only. On Linux x86_64 it installs upstream's prebuilt Blackwell `sm_120` archive, and the formula depends on `cuda-runtime`; its wrappers prepend `Formula["cuda-runtime"].opt_lib` to `LD_LIBRARY_PATH`, so the CUDA 13 runtime libraries (`libcudart.so.13`, `libcublas.so.13`, `libcublasLt.so.13`) come from the shared runtime instead of a hard-coded toolkit path. On Linux arm64 (DGX Spark GB10) the formula builds the same tag from source for `sm_121` and requires a CUDA 13 toolkit with `nvcc` plus GCC 13+; set `HOMEBREW_CUDA_PATH` if the toolkit is not at `/usr/local/cuda`.

Two formulae need extra care in the current revision: `project-maya` and `strata` resolve a ROCm root before selecting `--with-cuda` or `--with-sycl`, so those source builds still need a ROCm SDK with HIP headers available even when they compile a non-HIP backend. The formula file is authoritative if this changes.

### macOS Metal

Only `colibri`, `infr`, `magnitude`, `project-maya`, `strata`, `shimmy`, `stable-diffusion-cpp`, and `uzu` support macOS in this tap, and the `kokon` and `hatchlight` casks install macOS GUI applications. There is no ROCm or CUDA path on macOS. Prebuilt CI bottles target `arm64_sonoma`. `colibri` installs an upstream arm64 Metal archive and requires `libomp`; `infr` installs arm64 or Intel archives; `magnitude` installs arm64 or Intel CLI archives; `uzu` installs the arm64 Metal or Intel CPU CLI archive. `project-maya`, `strata`, and `shimmy` can build from source on macOS; `stable-diffusion-cpp` currently declares only an arm64 macOS artifact.

## CI and publishing pipeline

The tap uses a single bottle pipeline: [`tests.yml`](.github/workflows/tests.yml) runs `brew test-bot`, [`publish.yml`](.github/workflows/publish.yml) runs `brew pr-pull`, and built bottles are stored in GHCR at `https://ghcr.io/v2/heretek-ai/tap`. There is no separate nightly-matrix or ROCmFPX-builder workflow.

- **Test and build (`tests.yml`).** `brew test-bot` runs on macOS and Linux, including a hosted CUDA job and a self-hosted `stx-halo` ROCm job. The self-hosted job builds ROCm bottles and runs the hardware validation harness; it is gated to same-repository pull requests, pushes to `main`, and manual dispatches so fork code never runs on maintainer hardware. The workflow also runs the Python suites, ShellCheck, `brew style` for formulae, casks, and `cmd/`, and `python3 scripts/generate_readme.py --check`.
- **Publish (`publish.yml`).** A maintainer dispatches `brew pr-pull` with the pull request number and an optional reviewed head SHA. It downloads the GHCR bottles, merges the bottle blocks into `main`, pushes the commit, and records build provenance attestations. Passing `--head-sha` makes publishing fail if the branch moved after review.
- **Autobump (`autobump.yml`).** Release-tag and livecheck bumps run every six hours; commit-tracking and rolling bumps run weekly and on `builder-release` dispatches. Both paths open pull requests labelled `autobump` and run `brew test-bot` before merge. Configure the optional GitHub App with `vars.APP_ID` and `secrets.APP_PRIVATE_KEY`; without the App the workflow falls back to `GITHUB_TOKEN`, and pull requests created with that token do not trigger `brew test-bot`.
- **Auto-publish (`auto-publish.yml`).** A `workflow_run` listener waits for `brew test-bot` to finish. When a successful, same-repository pull request carries the `autobump` label, it dispatches `publish.yml`; human pull requests remain manual. Fork pull requests are never auto-published.
- **Self-hosted `stx-halo` gate.** The ROCm/hardware job only accepts trusted refs: same-repository pull requests, `main` pushes, and manual runs. It also requires the repository variable `STX_HALO_ENABLED=true`, and the job targets the protected `stx-halo` environment, so a maintainer must approve the deployment before any step runs on the physical machine. Until the runner is registered and the variable is set, the job is skipped rather than queued. This keeps untrusted fork code and secrets off the maintainer machine.

## Usage examples

Every command below is installed by the corresponding formula. Use `--help` for the full flag set; this tap does not guarantee flags that are not shown here.

### Hardware detection

```bash
brew heretek doctor      # diagnostics and actionable next steps
brew heretek recommend   # exact install commands for the detected GPU
```

`doctor` prints the TTM `pages_limit`, driver and runtime library status, and the install commands for missing tap runtimes. `recommend` maps AMD `gfx1151`, `gfx1100`-family, `gfx1200`-family, NVIDIA `sm_80`-`sm_121`, Apple Silicon, and the CPU/Vulkan fallback to formula sets and Brewfiles.

### AMD Strix Halo runtimes

```bash
# Kernel harness
crucible-strix-halo --help
crucible-strix-halo --list-devices

# Gufo family
gufo --help
gufo info
gufo serve --host 127.0.0.1 --port 18001

gufo-ds41 --help
gufo-ds41 --version
gufo-ds41 serve --host 127.0.0.1 --port 18003

# Rulith Inference (Linux ROCm gfx1151 engine)
rulith-server --help
rulith-server -m /path/to/model.gguf --host 127.0.0.1 --port 18014

# Strixolotl (DeepSeek-V4.1-Flash HIP port of Xolotl)
strixolotl --help
strixolotl-serve --config /path/to/strata-ds41.json --host 127.0.0.1 --port 18013

# Qwen runtime
qwenox-engine --info
qwenox-server --help

# Strix Halo MoE engine with SSD-streamed experts
osmos-api --version
osmos-api --config /path/to/pack/osmos.json --host 127.0.0.1 --port 8091
osmos-serve --model /path/to/pack/first-shard.gguf

# Embedded runner
snowllm --help

# Strixite conversion and server
strixite-convert-qwen4exp /path/to/Qwen3.8-Flash-Next /path/to/qwen4exp-strixw --int4-shared
strixite-server --model /path/to/qwen4exp-strixw --host 127.0.0.1 --port 18004 --kv-mode fp8 --mtp-draft 3
```

### Diffusion and local servers

```bash
# Stable Diffusion / Flux / SD3 / Wan
stable-diffusion --help
sd-cli --help
sd-server --host 127.0.0.1 --port 18008

# Shimmy
shimmy --help
shimmy serve --port 11434 --host 127.0.0.1
```

### RDNA, Vulkan, and Apple inference

```bash
# Colibri (Linux CPU/Vulkan, macOS Metal)
coli --help
coli setup
coli serve --model /path/to/model

# Hipfire (AMD RDNA/CDNA kernel packs)
hipfire --help
hipfire pull qwen3.8:27b-mq4-xts
hipfire serve 127.0.0.1:18011 --no-prewarm
hipfire profile

# ZINC (ROCm default, Vulkan with --with-vulkan)
zinc --version
zinc model pull qwen35-9b-q4k-m
zinc model use qwen35-9b-q4k-m
zinc serve --port 18009

# Infr (Linux Vulkan, macOS Metal/CPU)
infr --help
infr devices
infr serve unsloth/Qwen3-14B-GGUF:Q4_K_M

# Magnitude CLI
magnitude --help
magnitude hardware
magnitude models

# Mirai / uzu (macOS)
mirai --help
mirai server --model trymirai/Qwen3.5-4B-M

# Nib (AMD RDNA3 gfx1100)
nib --version
nib serve -m models/Inkling-2-Mini-NVFP4-Mixed.gguf --host 127.0.0.1 --port 4444
```

### NVIDIA Blackwell and DGX Spark

```bash
# Basalt (CUDA sm_120 on x86_64, sm_121 on DGX Spark)
basalt --help
basalt-probe --model /path/to/model.basalt
basalt serve --config "$(brew --prefix)/etc/basalt/basalt_config.json" --host 127.0.0.1
```

### Tiered, multimodal, and CUDA servers

```bash
# Strata
strata-cli --help
strata-cli --model qwen38 --host 127.0.0.1 --port 18006
strata-server --help
strata-q36 --help
strata-dsv41 --help

# Project Maya
maya-cli --help
maya-cli --model glm51 --host 127.0.0.1 --port 18005
maya-server --help
maya-vision --help

# Kyojin
kyojin-serve --help
kyojin-serve qwen -m /path/to/Qwen3.8-35B-A3B-EXL3 --mtp --port 18010
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
| `basalt` | `basalt serve --config ...` | `127.0.0.1:18012` | Config at `$(brew --prefix)/etc/basalt/basalt_config.json`; the shipped config uses `server.port` 18012 |
| `gufo` | `gufo serve` | `127.0.0.1:18001` | Logs to `$(brew --prefix)/var/log/gufo.log` |
| `gufo-ds41` | `gufo-ds41 serve` | `127.0.0.1:18003` | Logs to `$(brew --prefix)/var/log/gufo-ds41.log` |
| `hipfire` | `hipfire serve 127.0.0.1:18011 --no-prewarm` | `127.0.0.1:18011` | Loads the configured default model on demand; port uses the positional bind |
| `hyperqwen` | `hyperqwen-serve` | `127.0.0.1:18020` | Service sets `HYPERQWEN_PORT=18020` explicitly |
| `kyojin` | `kyojin-serve qwen` | `127.0.0.1:18010` | Starts the Qwen engine by default |
| `project-maya` | `maya-cli --host 127.0.0.1 --port 18005` | `127.0.0.1:18005` | Host and port set in the service block |
| `rulith-inference` | `rulith-server` | `127.0.0.1:18014` | Linux ROCm `gfx1151` `llama-server` endpoint |
| `shimmy` | `shimmy serve` | `127.0.0.1:11434` | Retains the upstream/Ollama-compatible port `11434` |
| `stable-diffusion-cpp` | `sd-server` | `127.0.0.1:18008` | Diffusion HTTP server |
| `strata` | `strata-cli --port 18006` | `127.0.0.1:18006` | The launcher defaults to loopback; the service changes the port |
| `strixite` | `strixite-server --config ...` | `127.0.0.1:18004` | Shipped config and service use port `18004` |
| `zinc` | `zinc serve --port 18009` | all interfaces on port `18009` | Upstream has no `--host` flag; configure an active model first |

`colibri`, `crucible-strix-halo`, `infr`, `libosmos`, `lucebox`, `magnitude`, `nib`, `qwenox`, `snowllm`, `strixolotl`, `uzu`, and `xolotl` have no service block and must be launched manually.

```bash
brew services list
brew services start gufo
brew services stop gufo
brew services restart gufo
brew services run gufo
brew services info gufo
```

Service logs live under `$(brew --prefix)/var/log/`. Where a service block defines a working directory, it is `$(brew --prefix)/var`.

## Service port registry

[`scripts/port_registry.json`](scripts/port_registry.json) is the single source of truth for every service's port, executable, and configurability. The tap reserves ports `18000-18099` for its own services; `shimmy` keeps the upstream/Ollama-compatible `11434` and `hyperqwen` keeps `18020`. A new or changed service must update the registry, the formula's `service` block, its caveats, and the generated table below in the same pull request.

The table between the generated markers is maintained from the registry. `zinc` is the documented exception: upstream exposes no `--host` flag and always binds `0.0.0.0`, so its service passes only `--port` and the registry records the limitation in its notes.

<!-- BEGIN GENERATED: port-registry -->
| Formula | Service executable | Default endpoint | Notes |
| :--- | :--- | :--- | :--- |
| [`gufo`](#gufo) | `gufo serve` | `127.0.0.1:18001` | Set with --host 127.0.0.1 --port 18001 in the service block. Upstream default is 8080. |
| [`gufo-ds41`](#gufo-ds41) | `gufo-ds41 serve` | `127.0.0.1:18003` | Set with --host 127.0.0.1 --port 18003 in the service block. Replaces gufo-franzmoca. Upstream default is 8080. |
| [`strixite`](#strixite) | `strixite-server` | `127.0.0.1:18004` | Configured by host/port in etc/strixite/strix_server.conf and overridden explicitly with --host 127.0.0.1 --port 18004 in the service block. Upstream default is 5300. |
| [`project-maya`](#project-maya) | `maya-cli` | `127.0.0.1:18005` | Set with --host 127.0.0.1 --port 18005 in the service block. maya-server upstream default is 8080. |
| [`strata`](#strata) | `strata-cli` | `127.0.0.1:18006` | Port changed to 18006 in the existing strata-cli service invocation. The launcher and server default to 127.0.0.1; that command shape exposes no --host flag, so this service relies on the default loopback bind. |
| [`stable-diffusion-cpp`](#stable-diffusion-cpp) | `sd-server` | `127.0.0.1:18008` | Set with --host 127.0.0.1 --port 18008 in the service block. Upstream default is 8080. |
| [`zinc`](#zinc) | `zinc serve` | `0.0.0.0:18009` | Set with --port 18009. Upstream has no --host flag and always binds 0.0.0.0, so the registry bind_host cannot be enforced for this service; use a host firewall or an isolating network namespace. |
| [`kyojin`](#kyojin) | `kyojin-serve qwen` | `127.0.0.1:18010` | Set with --host 127.0.0.1 --port 18010 in the service block; the service starts the qwen engine. Upstream default is 8000. |
| [`hipfire`](#hipfire) | `hipfire serve` | `127.0.0.1:18011` | Set with the documented positional bind 127.0.0.1:18011; hipfire serve has no --port flag. Upstream default is 11435. |
| [`basalt`](#basalt) | `basalt serve` | `127.0.0.1:18012` | Configured by server.port in etc/basalt/basalt_config.json; the service also passes --host 127.0.0.1 --port 18012. Upstream default is 8080. |
| [`rulith-inference`](#rulith-inference) | `rulith-server` | `127.0.0.1:18014` | Set with --host 127.0.0.1 --port 18014 in the service block. Serves the Linux ROCm gfx1151 llama-server endpoint. |
| [`hyperqwen`](#hyperqwen) | `hyperqwen-serve` | `127.0.0.1:18020` | Set explicitly to 18020 through HYPERQWEN_PORT in the service block; the wrapper passes the value to vLLM with --host 127.0.0.1 --port. Upstream default is 18020. |
| [`shimmy`](#shimmy) | `shimmy serve` | `127.0.0.1:11434` | Set with --host 127.0.0.1 --port 11434 in the service block. Retained because 11434 is the upstream/Ollama-compatible default. |
<!-- END GENERATED: port-registry -->

## Updating

```bash
brew update
brew outdated
brew upgrade
brew upgrade gufo
```

`brew update` refreshes the tap; `brew outdated` lists formulae with newer versions; `brew upgrade` upgrades everything; `brew upgrade <formula>` upgrades one formula. For GUI apps, use `brew upgrade --cask kokon` or `brew upgrade --cask hatchlight`, or let the application's built-in updater handle it. If you installed a non-default variant, reinstall it with the same options after the upgrade.

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
- **CUDA:** verify that `nvcc --version` works and that the toolkit is at `/usr/local/cuda` or pointed to by `HOMEBREW_CUDA_PATH`, `CUDA_HOME`, or `CUDA_PATH`. `basalt`'s prebuilt x86_64 archive needs the CUDA 13 runtime (`libcudart.so.13`, `libcublas.so.13`, `libcublasLt.so.13`).
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

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branch and pull-request flow, formula conventions, local verification commands, and CI requirements.

Changes land through pull requests; do not push directly to `main`. The publish workflow (`brew pr-pull`) is the only automation that merges reviewed bottles and ledger updates into `main`. The auto-publish workflow dispatches it only for green, same-repository pull requests labelled `autobump`; human pull requests remain manual.

### Local checks

```bash
brew style Formula/ Casks/ cmd/
brew audit --strict --online --tap=heretek-ai/tap
./scripts/test_local_tap.sh
python3 scripts/generate_readme.py --check
pytest tests/ -v
```

`./scripts/test_local_tap.sh` syncs tracked tap paths (including `Casks/`, `cmd/`, and `Brewfiles/`) into Homebrew's tap directory, runs `brew style` on formulae, casks, and commands, runs the strict audit across the tap, checks the generated README tables against the synced metadata, and executes the Python test suites. `pytest tests/ -v` runs the resolver, ledger, formula-update, and validation-harness tests directly.

`README.md` contains generated catalog, cask, port, and hardware tables between `<!-- BEGIN GENERATED: ... -->` markers. Do not edit those tables by hand. Run `python3 scripts/generate_readme.py --write` after changing formulae, casks, the ledger, or [`scripts/port_registry.json`](scripts/port_registry.json); `--check` fails with the stale section names when the README does not match the current metadata. The generator reads live `brew info --json=v2` output and works from any directory.

### CI and pull requests

- [`tests.yml`](.github/workflows/tests.yml) runs `brew test-bot` on macOS and Linux, including hosted CUDA and the self-hosted `stx-halo` ROCm gate. It builds bottles with the GHCR root URL `https://ghcr.io/v2/heretek-ai/tap`, runs the Python suites and ShellCheck, checks `brew style` for `Formula/`, `Casks/`, and `cmd/`, and verifies the generated README.
- Self-hosted hardware is restricted to same-repository pull requests, `main` pushes, and manual dispatches; fork pull requests never execute on it.
- After review, publish with the `publish` workflow (`brew pr-pull`) or locally:

```bash
brew pr-pull --tap=heretek-ai/tap --head-sha=<reviewed-head-sha> <pr-number>
```

Passing `--head-sha` makes the publish fail if the pull request head moves after review. The publish workflow also generates build provenance attestations.

### Formula updates and autobump

- Update the pinned revision in the formula and the matching entry in [`.github/upstream-pins.json`](.github/upstream-pins.json) together.
- `basalt` carries two stable artifacts: the source tag used by arm64 and the prebuilt x86_64 release archive. Review autobump changes against both URL/SHA256 pairs.
- The autobump workflow runs release and livecheck bumps every six hours and commit-tracking or rolling bumps weekly. Both paths run `brew bump --no-fork --open-pr --bump-synced --tap=heretek-ai/tap` or `scripts/update_formulae.py`, open a pull request labelled `autobump`, and require `brew test-bot` to pass.
- Configure the optional GitHub App with the repository variable `vars.APP_ID` and the secret `secrets.APP_PRIVATE_KEY`. The App needs Contents and Pull requests write access (and Issues write to manage the `autobump` label). Without it, the workflows fall back to `secrets.GITHUB_TOKEN`, but pull requests created with that token do not trigger `brew test-bot`; a maintainer must then rerun the tests before auto-publish can act.
- `auto-publish.yml` listens for `brew test-bot` completion and dispatches `publish.yml` only for successful, same-repository pull requests carrying the `autobump` label. It never publishes forks or unlabelled human pull requests.

### Adding or changing a formula

1. Add or edit the formula under [`Formula/`](Formula/).
2. Add the ledger entry and variant policy to [`.github/upstream-pins.json`](.github/upstream-pins.json).
3. Update the documented ports in [`scripts/port_registry.json`](scripts/port_registry.json) and run `python3 scripts/generate_readme.py --write`.
4. Run `brew style`, the strict online audit, the local tap script, and `pytest`.
5. Open a pull request and let `brew test-bot` and the self-hosted `stx-halo` gate validate it.

## License and attribution

The tap's own code and automation are licensed under the [MIT License](LICENSE). Each formula remains subject to its upstream project's license. The formula metadata reports:

| License | Formulae |
| :--- | :--- |
| `Apache-2.0` | `colibri`, `crucible-strix-halo`, `gufo`, `gufo-ds41`, `hipfire`, `lucebox`, `magnitude`, `nib`, `shimmy`, `snowllm` |
| `MIT` | `basalt`, `infr`, `kyojin`, `libosmos`, `rocm-runtime`, `rulith-inference`, `stable-diffusion-cpp`, `strixolotl`, `uzu`, `xolotl`, `zinc` |
| `AGPL-3.0-only` | `qwenox`, `strixite` |
| `:cannot_represent` | `cuda-runtime`, `hyperqwen`, `project-maya`, `strata` |

Casks do not carry a Homebrew license stanza in the same way as formulae. Upstream licensing is `AGPL-3.0` for `kokon` and `MIT` for `hatchlight`; consult each upstream repository for the full terms.

`:cannot_represent` means Homebrew's license metadata cannot express the upstream license; consult the upstream repository for the actual terms. The AGPL-3.0-only formulae carry the corresponding source-availability and distribution obligations.

Upstream projects and trademarks belong to their respective authors. Performance figures, model support, and hardware claims are upstream properties, not guarantees from this tap. Measure on your own hardware and review the upstream documentation before relying on a specific model, quantization, or backend.
