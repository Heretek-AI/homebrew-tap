# syntax=docker/dockerfile:1

FROM nvidia/cuda:13.5.0-devel-ubuntu24.04 AS cuda

FROM ghcr.io/homebrew/brew:main

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cmake \
        git \
        ninja-build \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY --from=cuda /usr/local/cuda-13.5 /usr/local/cuda-13.5

ENV CUDA_HOME=/usr/local/cuda-13.5 \
    CUDAToolkit_ROOT=/usr/local/cuda-13.5 \
    PATH=/usr/local/cuda-13.5/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/cuda-13.5/lib64:/usr/local/cuda-13.5/lib

USER linuxbrew
WORKDIR /home/linuxbrew
