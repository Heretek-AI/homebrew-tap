# Toolchain images

These images are CI toolchains for building and testing the formulae in this
tap. They are not user-facing or supported runtime images.

## Images

| Image | Contents |
| --- | --- |
| `ghcr.io/heretek-ai/brew-rocm` | Homebrew on Linux with a pinned TheRock ROCm nightly SDK extracted to `/opt/rocm` |
| `ghcr.io/heretek-ai/brew-cuda` | Homebrew on Linux with the CUDA 13.5 toolkit copied from the NVIDIA devel image |

Both images run as the `linuxbrew` user and use `/home/linuxbrew` as the
working directory. The ROCm image sets `ROCM_PATH`, `HIP_PATH`,
`ROCM_KPACK_PATH`, `PATH`, and `LD_LIBRARY_PATH`; the CUDA image sets
`CUDA_HOME`, `CUDAToolkit_ROOT`, `PATH`, and `LD_LIBRARY_PATH`.

## Build locally

```sh
docker build -t brew-rocm:local docker/brew-rocm
docker build -t brew-cuda:local docker/brew-cuda
```

The ROCm image pins the gfx1151 nightly tarball by version and SHA256. Override
all three build arguments together when testing another family or build:

```sh
docker build \
  --build-arg ROCM_VERSION=10.3.0a20261126 \
  --build-arg ROCM_FAMILY=gfx1151 \
  --build-arg ROCM_SHA256=874371b060a4ea2a8be617aee1107e7703628e28609642f706a691a690524abd \
  -t brew-rocm:local docker/brew-rocm
```

## Published tags

The `Toolchain images` workflow only builds when files under `docker/` or the
workflow itself change. On pushes to `main` it publishes:

- `ghcr.io/heretek-ai/brew-rocm:10.3.0a20261126`
- `ghcr.io/heretek-ai/brew-rocm:main`
- `ghcr.io/heretek-ai/brew-rocm:sha-<short-sha>`
- `ghcr.io/heretek-ai/brew-cuda:13.5.0`
- `ghcr.io/heretek-ai/brew-cuda:main`
- `ghcr.io/heretek-ai/brew-cuda:sha-<short-sha>`

Pull requests build without pushing. There is deliberately no floating
`latest` tag.
