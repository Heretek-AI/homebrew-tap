#!/usr/bin/env bash
set -euo pipefail

# test_local_tap.sh: Validate the tap against Homebrew style, audit and tests.
# Only tracked tap paths are synced into Homebrew's tap directory; untracked
# workspace directories are never copied or deleted.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BREW_BIN="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}/bin/brew"

if [[ ! -x "${BREW_BIN}" ]]
then
  BREW_BIN="$(command -v brew || true)"
fi

if [[ -z "${BREW_BIN}" ]] || [[ ! -x "${BREW_BIN}" ]]
then
  echo "[-] Error: brew command not found in PATH or /home/linuxbrew/.linuxbrew/bin/brew" >&2
  exit 1
fi

TAP_INSTALL_PATH="$("${BREW_BIN}" --repository)/Library/Taps/heretek-ai/homebrew-tap"
if [[ ! -d "${TAP_INSTALL_PATH}" ]]
then
  "${BREW_BIN}" tap heretek-ai/tap
fi

echo "=========================================="
echo " 1. Syncing tracked tap files"
echo "=========================================="
TAP_PATHS=(
  ".github"
  "Brewfiles"
  "Casks"
  "Formula"
  "LICENSE"
  "README.md"
  ".gitignore"
  "cmd"
  "scripts"
  "tests"
  "utils"
)

for path in "${TAP_PATHS[@]}"
do
  [[ -e "${TAP_DIR}/${path}" ]] || continue
  mkdir -p "$(dirname "${TAP_INSTALL_PATH}/${path}")"
  if [[ -d "${TAP_DIR}/${path}" ]]
  then
    rsync -a --delete \
      --exclude='__pycache__' \
      --exclude='*.pyc' \
      --exclude='.pytest_cache' \
      --exclude='.ruff_cache' \
      "${TAP_DIR}/${path}/" "${TAP_INSTALL_PATH}/${path}/"
  else
    cp -a "${TAP_DIR}/${path}" "${TAP_INSTALL_PATH}/${path}"
  fi
done

echo ""
echo "=========================================="
echo " 2. Running Homebrew formula, cask and command style checks"
echo "=========================================="
shopt -s nullglob
formulae=("${TAP_DIR}"/Formula/*.rb)
casks=("${TAP_DIR}"/Casks/*.rb)
commands=("${TAP_DIR}"/cmd/*.rb)
shopt -u nullglob

if [[ "${#formulae[@]}" -eq 0 ]]
then
  echo "[-] Error: no Formula/*.rb files found" >&2
  exit 1
fi

if [[ "${#commands[@]}" -eq 0 ]]
then
  echo "[-] Error: no cmd/*.rb external commands found" >&2
  exit 1
fi

echo "Discovered ${#formulae[@]} formulae, ${#casks[@]} casks and ${#commands[@]} commands."
# Style the synced tap copy, not the checkout. When both a checkout and an
# installed copy exist, Homebrew's cross-file RuboCop cops see the same
# constants and methods twice and report false duplicate/reassignment errors.
"${BREW_BIN}" style "${TAP_INSTALL_PATH}/Formula/" "${TAP_INSTALL_PATH}/cmd/"
if [[ "${#casks[@]}" -gt 0 ]]
then
  "${BREW_BIN}" style "${TAP_INSTALL_PATH}/Casks/"
fi

echo ""
echo "=========================================="
echo " 3. Running Homebrew strict audit"
echo "=========================================="
# `--tap` audits both formulae and casks in the synced tap. Run the cask
# audit explicitly as well: Homebrew skips cask audits on non-macOS hosts.
"${BREW_BIN}" audit --strict --tap=heretek-ai/tap
if [[ "${#casks[@]}" -gt 0 ]]
then
  "${BREW_BIN}" audit --cask --strict --tap=heretek-ai/tap
fi

echo ""
echo "=========================================="
echo " 4. Running Python unit tests"
echo "=========================================="
(
  cd "${TAP_DIR}"
  python3 -m unittest discover -s tests/ -v
  if python3 -c 'import pytest' >/dev/null 2>&1
  then
    python3 -m pytest tests/ -q
  else
    echo "[*] pytest not installed; skipped pytest suite."
  fi
)

echo ""
echo "=========================================="
echo " 5. Verifying generated README against synced tap metadata"
echo "=========================================="
(
  cd "${TAP_INSTALL_PATH}"
  python3 scripts/generate_readme.py --check
)

echo ""
echo "[✓] Local tap validation completed successfully!"
