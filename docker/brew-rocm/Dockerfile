# syntax=docker/dockerfile:1

FROM ghcr.io/homebrew/brew:main

ARG ROCM_VERSION=10.3.0a20261126
ARG ROCM_FAMILY=gfx1151
ARG ROCM_SHA256=874371b060a4ea2a8be617aee1107e7703628e28609642f706a691a690524abd

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
        ninja-build \
        pkg-config \
        python3 \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

USER linuxbrew

# Homebrew's superenv filters -I flags outside the Homebrew prefix. Extract the
# SDK under the prefix and expose it through the conventional /opt/rocm path so
# Homebrew formulae can keep using -I/opt/rocm/include.
RUN curl -fsSL -o /tmp/rocm.tar.gz \
        "https://nightly.repo.amd.com/rocm/core/tarball/therock-dist-linux-${ROCM_FAMILY}-${ROCM_VERSION}.tar.gz" \
    && echo "${ROCM_SHA256}  /tmp/rocm.tar.gz" | sha256sum -c - \
    && mkdir -p /home/linuxbrew/.linuxbrew/rocm-sdk \
    && tar -xzf /tmp/rocm.tar.gz -C /home/linuxbrew/.linuxbrew/rocm-sdk \
    && rm -f /tmp/rocm.tar.gz

USER root

RUN ln -s /home/linuxbrew/.linuxbrew/rocm-sdk /opt/rocm \
    && test -f /opt/rocm/include/hip/hip_runtime_api.h \
    && test -x /opt/rocm/bin/hipcc

ENV ROCM_PATH=/home/linuxbrew/.linuxbrew/rocm-sdk \
    HIP_PATH=/home/linuxbrew/.linuxbrew/rocm-sdk \
    HOMEBREW_ROCM_PATH=/home/linuxbrew/.linuxbrew/rocm-sdk \
    ROCM_KPACK_PATH=/home/linuxbrew/.linuxbrew/rocm-sdk/.kpack \
    PATH=/home/linuxbrew/.linuxbrew/rocm-sdk/bin:/home/linuxbrew/.linuxbrew/rocm-sdk/llvm/bin:$PATH \
    LD_LIBRARY_PATH=/home/linuxbrew/.linuxbrew/rocm-sdk/lib:/home/linuxbrew/.linuxbrew/rocm-sdk/lib/rocm_sysdeps/lib

USER linuxbrew
WORKDIR /home/linuxbrew
