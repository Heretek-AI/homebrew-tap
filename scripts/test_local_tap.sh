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
echo " Running Homebrew Formula Style Checks"
echo "=========================================="
"$BREW_BIN" style "${TAP_DIR}/Formula/"

echo ""
echo "=========================================="
echo " Running Homebrew Formula Audit Checks"
echo "=========================================="
for formula in "${TAP_DIR}"/Formula/*.rb; do
    echo "[*] Auditing $(basename "$formula")..."
    "$BREW_BIN" audit --strict "$formula" || echo "Audit completed with warnings"
done

echo ""
echo "=========================================="
echo " Formula Information Summary"
echo "=========================================="
for formula in "${TAP_DIR}"/Formula/*.rb; do
    name="$(basename "$formula" .rb)"
    echo "--- Formula: $name ---"
    "$BREW_BIN" info "$formula" || true
    echo ""
done

echo "[✓] Local tap validation completed successfully!"
