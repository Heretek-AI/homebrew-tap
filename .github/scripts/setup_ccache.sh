#!/usr/bin/env bash
# ==============================================================================
# setup_ccache.sh: Compiler Cache Provisioning for Homebrew Tap CI/CD Runners
# Configures high-performance ccache directory backed by RAM or fast runner SSD.
# ==============================================================================

set -Eeuo pipefail

CCACHE_SIZE="${1:-6G}"
BREW_CACHE_DIR="$(brew --cache 2>/dev/null || echo "${HOME}/.cache/Homebrew")"
CCACHE_DIR="${BREW_CACHE_DIR}/ccache"

echo "[*] Configuring ccache at ${CCACHE_DIR} (Target Size: ${CCACHE_SIZE})..."
mkdir -p "$CCACHE_DIR"

if [[ "$(uname -s)" == "Linux" ]]; then
  # On Linux runners, mount tmpfs if running as root or have passwordless sudo
  if [[ -w "/dev/shm" ]]; then
    SHM_CCACHE="/dev/shm/homebrew-ccache"
    mkdir -p "$SHM_CCACHE"
    # Sync from persistent ccache directory if exists
    if [[ -d "$CCACHE_DIR" && "$(ls -A "$CCACHE_DIR" 2>/dev/null)" ]]; then
      cp -a "${CCACHE_DIR}/." "$SHM_CCACHE/" 2>/dev/null || true
    fi
    CCACHE_DIR="$SHM_CCACHE"
  fi
fi

if command -v ccache >/dev/null 2>&1; then
  export CCACHE_DIR="$CCACHE_DIR"
  ccache --set-config="max_size=${CCACHE_SIZE}"
  ccache --set-config="compression=true"
  ccache --set-config="compression_level=6"
  ccache --set-config="sloppiness=time_macros,file_macro,include_file_mtime"
  ccache --zero-stats
  ccache --show-stats
fi

if [[ -n "${GITHUB_ENV:-}" && -w "$GITHUB_ENV" ]]; then
  echo "CCACHE_DIR=${CCACHE_DIR}" >> "$GITHUB_ENV"
  echo "HOMEBREW_HERETEK_CCACHE_DIR=${CCACHE_DIR}" >> "$GITHUB_ENV"
fi

echo "export CCACHE_DIR=\"${CCACHE_DIR}\""
echo "export HOMEBREW_HERETEK_CCACHE_DIR=\"${CCACHE_DIR}\""
