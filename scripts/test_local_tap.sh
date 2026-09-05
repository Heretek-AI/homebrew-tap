#!/usr/bin/env bash
set -euo pipefail

# test_local_tap.sh: Test formulas locally against Homebrew audit and style checks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BREW_BIN="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/bin/brew"

if [ ! -x "$BREW_BIN" ]; then
    BREW_BIN="$(command -v brew || true)"
fi

if [ -z "$BREW_BIN" ] || [ ! -x "$BREW_BIN" ]; then
    echo "[-] Error: brew command not found in PATH or /home/linuxbrew/.linuxbrew/bin/brew" >&2
    exit 1
fi

echo "=========================================="
echo " 1. Running Homebrew Formula Style Checks"
echo "=========================================="
"$BREW_BIN" style "${TAP_DIR}/Formula/"

echo ""
echo "=========================================="
echo " 2. Syncing Local Tap clone"
echo "=========================================="
TAP_INSTALL_PATH="$("$BREW_BIN" --repository)/Library/Taps/heretek-ai/homebrew-tap"
if [ -d "$TAP_INSTALL_PATH" ]; then
    rsync -av --delete --exclude='.git' "${TAP_DIR}/" "$TAP_INSTALL_PATH/"
fi

echo ""
echo "=========================================="
echo " 3. Running Homebrew Tap Audit Checks"
echo "=========================================="
"$BREW_BIN" audit --tap=heretek-ai/tap

echo ""
echo "=========================================="
echo " 4. Formula Information Summary"
echo "=========================================="
for formula in cachy-llama rocmfpx ciru-rocmfpx kingjones-rocmfpx engramhalo q38rocm ember llama-ai stable-diffusion-cpp; do
    echo "--- Formula: heretek-ai/tap/${formula} ---"
    "$BREW_BIN" info "heretek-ai/tap/${formula}"
    echo ""
done

echo "[✓] Local tap validation completed successfully!"
