# Curated Brewfiles

These Brewfiles install a tested formula set for one hardware family from the
[Heretek-AI tap](https://github.com/Heretek-AI/homebrew-tap). Each file declares
selector trust for exactly the formulae it installs, so `brew bundle` does not
trust the whole tap.

| Brewfile | Target hardware | Notes |
| :--- | :--- | :--- |
| [`strix-halo.Brewfile`](strix-halo.Brewfile) | AMD Strix Halo / Ryzen AI Max (`gfx1151`) on Linux | Installs `rocm-runtime` and the Strix Halo engine set. |
| [`rdna3.Brewfile`](rdna3.Brewfile) | AMD RDNA3 (`gfx1100`, `gfx1101`, `gfx1102`) on Linux | Installs `rocm-runtime`, the `gfx1100` hipfire kernel pack, and RDNA3 code paths. |
| [`blackwell.Brewfile`](blackwell.Brewfile) | NVIDIA Blackwell (`sm_120`) and DGX Spark (`sm_121`) on Linux | Installs `cuda-runtime`, `basalt`, `hyperqwen`, and `lucebox`. |
| [`apple-silicon.Brewfile`](apple-silicon.Brewfile) | Apple Silicon macOS | Metal and CPU engines; no ROCm or CUDA runtime. |

## Usage

From the repository root:

```bash
brew bundle --file=Brewfiles/strix-halo.Brewfile
```

From elsewhere, use the absolute path or install the tap first:

```bash
brew bundle --file=/path/to/homebrew-tap/Brewfiles/rdna3.Brewfile
```

Check what a file would install without changing the system:

```bash
brew bundle list --file=Brewfiles/blackwell.Brewfile
```

Use `brew heretek recommend` to detect the GPU family and choose a Brewfile:

```bash
brew heretek recommend
```

## Notes

- `rocm-runtime` and `cuda-runtime` are keg-only shared runtimes. Engine
  formulae link against their `opt_lib` or `opt_prefix`; do not expect them on
  the default linker path.
- Options such as `--with-gfx1100` and `--with-gfx1201` select the hipfire
  kernel pack, while `--with-cuda`, `--with-rocm`, `--with-rdna4`, and
  `--with-vulkan` select a backend or target family. If a formula is already
  installed with a different variant, reinstall it with the same arguments.
  In a Brewfile, write `args` entries **without** the leading dashes, for
  example `brew "hipfire", args: ["with-gfx1100"]`; Homebrew Bundle adds the
  `--` prefix itself.
- Source builds still need the external toolchain: a ROCm SDK with `hipcc` for
  AMD options and a CUDA toolkit with `nvcc` for CUDA options. The runtime
  formulae provide shared libraries, not compilers.
- Run `brew untrust --formula heretek-ai/tap/<formula>` if you later remove an
  entry and want to drop its trust.
