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

RUN curl -fsSL -o /tmp/rocm.tar.gz \
        "https://nightly.repo.amd.com/rocm/core/tarball/therock-dist-linux-${ROCM_FAMILY}-${ROCM_VERSION}.tar.gz" \
    && echo "${ROCM_SHA256}  /tmp/rocm.tar.gz" | sha256sum -c - \
    && mkdir -p /opt/rocm \
    && tar -xzf /tmp/rocm.tar.gz -C /opt/rocm \
    && rm -f /tmp/rocm.tar.gz

ENV ROCM_PATH=/opt/rocm \
    HIP_PATH=/opt/rocm \
    ROCM_KPACK_PATH=/opt/rocm/.kpack \
    PATH=/opt/rocm/bin:/opt/rocm/llvm/bin:$PATH \
    LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib/rocm_sysdeps/lib

USER linuxbrew
WORKDIR /home/linuxbrew
