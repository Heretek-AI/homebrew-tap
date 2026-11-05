#!/usr/bin/env bash
# ==============================================================================
# resolve_rocm_sdk.sh: Dynamic AMD ROCm TheRock Multi-Arch / APU SDK Resolver
#
# Queries AMD ROCm nightly index, resolves the latest 10.1.0a+ release for the
# specified GPU architecture family, manages local tarball caches via HTTP ETag,
# unpacks into a unified prefix, and exports compiler / toolchain environment vars.
# ==============================================================================

set -Eeuo pipefail

DEFAULT_PRIMARY_INDEX="https://nightly.repo.amd.com/rocm/core/tarball/"
DEFAULT_LEGACY_INDEX="https://rocm.nightlies.amd.com/tarball-multi-arch/"

FAMILY="gfx1151"
CHANNEL="nightly"
MIN_VERSION="10.1.0"
MAX_VERSION=""
PREFIX="/opt/rocm-nightly"
CACHE_DIR="${HOME}/.cache/rocm-nightly"
RESOLVE_ONLY="false"
OUTPUT_JSON="false"
INDEX_FILE=""
INDEX_URLS=()

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --family <name>        GPU target family (multiarch, gfx1151, gfx1150, gfx110X-all, gfx90a, gfx94X-dcgpu) [default: gfx1151]
  --channel <channel>    Release channel (nightly, bkc) [default: nightly]
  --min-version <ver>    Minimum ROCm semantic version to accept [default: 10.1.0]
  --max-version <ver>    Optional maximum ROCm semantic version upper bound
  --prefix <path>        Installation prefix directory [default: /opt/rocm-nightly]
  --cache-dir <path>     Directory to cache downloaded tarballs and manifests [default: ~/.cache/rocm-nightly]
  --index-url <url>      Override index URL (can be specified multiple times; checked in order)
  --index-file <file>    Path to local HTML index file (for offline testing / fixtures)
  --resolve-only         Only query and resolve the newest matching tarball without downloading
  --json                 Output resolved metadata as JSON
  -h, --help             Show this help message
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --family)
      FAMILY="$2"; shift 2 ;;
    --channel)
      CHANNEL="$2"; shift 2 ;;
    --min-version)
      MIN_VERSION="$2"; shift 2 ;;
    --max-version)
      MAX_VERSION="$2"; shift 2 ;;
    --prefix)
      PREFIX="$2"; shift 2 ;;
    --cache-dir)
      CACHE_DIR="$2"; shift 2 ;;
    --index-url)
      INDEX_URLS+=("$2"); shift 2 ;;
    --index-file)
      INDEX_FILE="$2"; shift 2 ;;
    --resolve-only)
      RESOLVE_ONLY="true"; shift ;;
    --json)
      OUTPUT_JSON="true"; shift ;;
    -h|--help)
      usage ;;
    *)
      echo "::error::Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

if [[ ${#INDEX_URLS[@]} -eq 0 ]]; then
  INDEX_URLS=("$DEFAULT_PRIMARY_INDEX" "$DEFAULT_LEGACY_INDEX")
fi

mkdir -p "$CACHE_DIR"

PYTHON_CMD="python3"
if ! command -v python3 >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
  else
    echo "::error::python3 is required to parse ROCm index metadata" >&2
    exit 1
  fi
fi

# ------------------------------------------------------------------------------
# 1. Fetch index and parse candidate files
# ------------------------------------------------------------------------------
RESOLVED_INDEX_URL=""
INDEX_CONTENT=""

if [[ -n "$INDEX_FILE" ]]; then
  if [[ ! -f "$INDEX_FILE" ]]; then
    echo "::error::Specified index file not found: $INDEX_FILE" >&2
    exit 1
  fi
  INDEX_CONTENT="$(cat "$INDEX_FILE")"
  RESOLVED_INDEX_URL="file://$INDEX_FILE"
else
  for test_url in "${INDEX_URLS[@]}"; do
    if content=$(curl -fsSL --retry 3 --connect-timeout 10 "$test_url" 2>/dev/null); then
      if [[ -n "$content" ]]; then
        INDEX_CONTENT="$content"
        RESOLVED_INDEX_URL="$test_url"
        break
      fi
    fi
  done
fi

if [[ -z "$INDEX_CONTENT" ]]; then
  echo "::error::Failed to retrieve ROCm index from any configured endpoint." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# 2. Extract, filter, and sort newest tarball matching constraints
# ------------------------------------------------------------------------------
PARSE_SCRIPT=$(cat <<'EOF'
import sys, re, json

family = sys.argv[1]
channel = sys.argv[2]
min_ver = sys.argv[3]
max_ver = sys.argv[4] if len(sys.argv) > 4 else ""

content = sys.stdin.read()

# 1. Try parsing embedded JSON: const files = [...];
file_names = []
m = re.search(r'const\s+files\s*=\s*(\[.*?\])\s*;', content, re.DOTALL)
if m:
    try:
        entries = json.loads(m.group(1))
        file_names = [e.get("name", "") for e in entries if isinstance(e, dict)]
    except Exception:
        pass

# 2. Fallback to extracting all tar.gz matches
if not file_names:
    file_names = list(set(re.findall(r'therock-dist-linux-[A-Za-z0-9_.\-+]+?\.tar\.gz', content)))

# Regex pattern matching linux distro tarballs for target family
# Examples:
#   therock-dist-linux-gfx1151-10.3.0a20261105.tar.gz
#   therock-dist-linux-multiarch-10.1.0a20260811+bkc.20260820.tar.gz
pattern = re.compile(
    r'^therock-dist-linux-' + re.escape(family) +
    r'-(\d+)\.(\d+)\.(\d+)(a|rc)(\d{8})(?:\+bkc\.(\d{8}))?\.tar\.gz$'
)

candidates = []

def parse_semver(v_str):
    parts = [int(p) for p in re.findall(r'\d+', v_str)]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])

min_semver = parse_semver(min_ver)
max_semver = parse_semver(max_ver) if max_ver else None

for name in file_names:
    if "-tests-" in name:
        continue
    mat = pattern.match(name)
    if not mat:
        continue

    maj, minor, patch, stage, stamp, bkc_stamp = mat.groups()
    semver = (int(maj), int(minor), int(patch))

    if semver < min_semver:
        continue
    if max_semver and semver > max_semver:
        continue

    is_bkc = bool(bkc_stamp)
    if channel == "nightly" and is_bkc:
        continue
    elif channel == "bkc" and not is_bkc:
        continue

    stage_rank = 0 if stage == "a" else 1
    sort_key = (semver[0], semver[1], semver[2], stage_rank, int(stamp), int(bkc_stamp or 0))

    candidates.append({
        "name": name,
        "version": f"{maj}.{minor}.{patch}{stage}",
        "build_stamp": stamp,
        "bkc_stamp": bkc_stamp or "",
        "sort_key": sort_key
    })

if not candidates:
    sys.exit(2)

candidates.sort(key=lambda x: x["sort_key"])
winner = candidates[-1]

print(json.dumps({
    "filename": winner["name"],
    "version": winner["version"],
    "build_stamp": winner["build_stamp"],
    "bkc_stamp": winner["bkc_stamp"],
    "candidate_count": len(candidates)
}))
EOF
)

PARSED_RESULT=$(echo "$INDEX_CONTENT" | "$PYTHON_CMD" -c "$PARSE_SCRIPT" "$FAMILY" "$CHANNEL" "$MIN_VERSION" "$MAX_VERSION" || true)

if [[ -z "$PARSED_RESULT" ]]; then
  echo "::error::No matching ROCm SDK tarball found for family='$FAMILY', min_version='$MIN_VERSION', channel='$CHANNEL'" >&2
  exit 1
fi

TARBALL_NAME=$("$PYTHON_CMD" -c "import sys, json; print(json.loads(sys.argv[1])['filename'])" "$PARSED_RESULT")
ROCM_VERSION=$("$PYTHON_CMD" -c "import sys, json; print(json.loads(sys.argv[1])['version'])" "$PARSED_RESULT")
BUILD_STAMP=$("$PYTHON_CMD" -c "import sys, json; print(json.loads(sys.argv[1])['build_stamp'])" "$PARSED_RESULT")

# Clean base URL ending in /
BASE_URL="${RESOLVED_INDEX_URL%/}/"
DOWNLOAD_URL="${BASE_URL}${TARBALL_NAME}"

# ------------------------------------------------------------------------------
# 3. Query remote metadata (ETag, Content-Length, Last-Modified)
# ------------------------------------------------------------------------------
REMOTE_ETAG=""
REMOTE_SIZE=""
REMOTE_LAST_MODIFIED=""

if [[ "$RESOLVED_INDEX_URL" =~ ^http ]]; then
  HEADERS=$(curl -sI -L --retry 3 --connect-timeout 10 "$DOWNLOAD_URL" 2>/dev/null || true)
  REMOTE_ETAG=$(echo "$HEADERS" | grep -i '^etag:' | head -n1 | awk '{print $2}' | tr -d '\r"' || true)
  REMOTE_SIZE=$(echo "$HEADERS" | grep -i '^content-length:' | head -n1 | awk '{print $2}' | tr -d '\r' || true)
  REMOTE_LAST_MODIFIED=$(echo "$HEADERS" | grep -i '^last-modified:' | head -n1 | cut -d':' -f2- | sed 's/^[ \t]*//' | tr -d '\r' || true)
fi

AGE_DAYS=0
if [[ "$BUILD_STAMP" =~ ^[0-9]{8}$ ]]; then
  CURRENT_YEAR=$(date -u +%Y)
  CURRENT_MONTH=$(date -u +%m)
  CURRENT_DAY=$(date -u +%d)
  CURRENT_SEC=$(date -u -d "${CURRENT_YEAR}-${CURRENT_MONTH}-${CURRENT_DAY}" +%s 2>/dev/null || date -u -j -f "%Y%m%d" "${CURRENT_YEAR}${CURRENT_MONTH}${CURRENT_DAY}" +%s 2>/dev/null || echo 0)
  STAMP_SEC=$(date -u -d "${BUILD_STAMP:0:4}-${BUILD_STAMP:4:2}-${BUILD_STAMP:6:2}" +%s 2>/dev/null || date -u -j -f "%Y%m%d" "$BUILD_STAMP" +%s 2>/dev/null || echo 0)
  if [[ "$CURRENT_SEC" -gt 0 && "$STAMP_SEC" -gt 0 ]]; then
    DIFF_SEC=$(( CURRENT_SEC - STAMP_SEC ))
    AGE_DAYS=$(( DIFF_SEC / 86400 ))
  fi
fi

if [[ "$OUTPUT_JSON" == "true" || "$RESOLVE_ONLY" == "true" ]]; then
  RESOLVE_JSON=$("$PYTHON_CMD" -c "
import sys, json
data = {
    'index_url': sys.argv[1],
    'family': sys.argv[2],
    'filename': sys.argv[3],
    'url': sys.argv[4],
    'version': sys.argv[5],
    'build_stamp': sys.argv[6],
    'etag': sys.argv[7],
    'size': int(sys.argv[8]) if sys.argv[8].isdigit() else 0,
    'last_modified': sys.argv[9],
    'age_days': int(sys.argv[10])
}
print(json.dumps(data, indent=2))
" "$RESOLVED_INDEX_URL" "$FAMILY" "$TARBALL_NAME" "$DOWNLOAD_URL" "$ROCM_VERSION" "$BUILD_STAMP" "$REMOTE_ETAG" "${REMOTE_SIZE:-0}" "$REMOTE_LAST_MODIFIED" "$AGE_DAYS")
fi

if [[ "$RESOLVE_ONLY" == "true" ]]; then
  if [[ "$OUTPUT_JSON" == "true" ]]; then
    echo "$RESOLVE_JSON"
  else
    echo "Resolved ROCm SDK: $TARBALL_NAME from $DOWNLOAD_URL ($BUILD_STAMP)"
  fi
  exit 0
fi

# Warn if legacy index was used or age is suspicious
if [[ "$RESOLVED_INDEX_URL" == *"$DEFAULT_LEGACY_INDEX"* ]]; then
  echo "::warning::ROCm SDK resolved from legacy index endpoint: $RESOLVED_INDEX_URL"
fi
if [[ $AGE_DAYS -gt 3 ]]; then
  echo "::warning::Latest ROCm SDK nightly build is $AGE_DAYS days old ($BUILD_STAMP)"
fi

# ------------------------------------------------------------------------------
# 4. Cache & Download Handling
# ------------------------------------------------------------------------------
TARGET_TARBALL="${CACHE_DIR}/${TARBALL_NAME}"
MANIFEST_FILE="${PREFIX}/.therock-manifest.json"

NEEDS_DOWNLOAD="true"
if [[ -f "$TARGET_TARBALL" ]]; then
  if [[ -n "$REMOTE_ETAG" && -f "${TARGET_TARBALL}.etag" ]]; then
    CACHED_ETAG=$(cat "${TARGET_TARBALL}.etag")
    if [[ "$CACHED_ETAG" == "$REMOTE_ETAG" ]]; then
      NEEDS_DOWNLOAD="false"
    fi
  elif [[ -z "$REMOTE_ETAG" ]]; then
    NEEDS_DOWNLOAD="false"
  fi
fi

ALREADY_INSTALLED="false"
if [[ -d "$PREFIX" && -f "$MANIFEST_FILE" ]]; then
  INSTALLED_FILENAME=$("$PYTHON_CMD" -c "import sys, json; print(json.load(open(sys.argv[1])).get('filename', ''))" "$MANIFEST_FILE" 2>/dev/null || true)
  INSTALLED_ETAG=$("$PYTHON_CMD" -c "import sys, json; print(json.load(open(sys.argv[1])).get('etag', ''))" "$MANIFEST_FILE" 2>/dev/null || true)
  if [[ "$INSTALLED_FILENAME" == "$TARBALL_NAME" ]]; then
    if [[ -z "$REMOTE_ETAG" || "$INSTALLED_ETAG" == "$REMOTE_ETAG" ]]; then
      ALREADY_INSTALLED="true"
    fi
  fi
fi

if [[ "$ALREADY_INSTALLED" == "true" ]]; then
  echo "ROCm SDK $TARBALL_NAME is already provisioned at $PREFIX"
else
  if [[ "$NEEDS_DOWNLOAD" == "true" ]]; then
    echo "Downloading $TARBALL_NAME from $DOWNLOAD_URL..."
    TMP_DOWNLOAD="${TARGET_TARBALL}.tmp"
    curl -fL --retry 5 --retry-all-errors -C - -o "$TMP_DOWNLOAD" "$DOWNLOAD_URL"
    mv "$TMP_DOWNLOAD" "$TARGET_TARBALL"
    if [[ -n "$REMOTE_ETAG" ]]; then
      echo "$REMOTE_ETAG" > "${TARGET_TARBALL}.etag"
    fi
  else
    echo "Using cached tarball: $TARGET_TARBALL"
  fi

  echo "Unpacking $TARGET_TARBALL into $PREFIX..."
  SUDO=""
  if [[ ! -w "$(dirname "$PREFIX")" && "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    fi
  fi

  $SUDO mkdir -p "$PREFIX"
  TAR_OPTS=("-xzf" "$TARGET_TARBALL" "-C" "$PREFIX")
  if command -v pigz >/dev/null 2>&1; then
    TAR_OPTS=("--use-compress-program=pigz" "-xf" "$TARGET_TARBALL" "-C" "$PREFIX")
  fi

  $SUDO tar "${TAR_OPTS[@]}"

  # Write installation manifest
  TMP_MANIFEST=$(mktemp)
  "$PYTHON_CMD" -c "
import sys, json
data = {
    'filename': sys.argv[1],
    'version': sys.argv[2],
    'build_stamp': sys.argv[3],
    'etag': sys.argv[4],
    'index_url': sys.argv[5],
    'family': sys.argv[6]
}
with open(sys.argv[7], 'w') as f:
    json.dump(data, f, indent=2)
" "$TARBALL_NAME" "$ROCM_VERSION" "$BUILD_STAMP" "$REMOTE_ETAG" "$RESOLVED_INDEX_URL" "$FAMILY" "$TMP_MANIFEST"

  $SUDO mv "$TMP_MANIFEST" "$MANIFEST_FILE"
fi

# ------------------------------------------------------------------------------
# 5. Toolchain Path Normalization
# ------------------------------------------------------------------------------
SUDO=""
if [[ ! -w "$PREFIX" && "$(id -u)" -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi
fi

# Symlink llvm directory if under lib/llvm
if [[ -d "${PREFIX}/lib/llvm" && ! -d "${PREFIX}/llvm" ]]; then
  $SUDO ln -sfn "${PREFIX}/lib/llvm" "${PREFIX}/llvm"
elif [[ -d "${PREFIX}/llvm" && ! -d "${PREFIX}/lib/llvm" ]]; then
  $SUDO mkdir -p "${PREFIX}/lib"
  $SUDO ln -sfn "${PREFIX}/llvm" "${PREFIX}/lib/llvm"
fi

# Ensure bin directory exists
$SUDO mkdir -p "${PREFIX}/bin"

CLANGXX=""
for candidate in \
  "${PREFIX}/llvm/bin/clang++" \
  "${PREFIX}/lib/llvm/bin/clang++" \
  "${PREFIX}/bin/amdclang++" \
  "${PREFIX}/bin/clang++"; do
  if [[ -x "$candidate" ]]; then
    CLANGXX="$candidate"
    break
  fi
done

if [[ -n "$CLANGXX" ]]; then
  [[ ! -e "${PREFIX}/bin/hipcc" ]] && $SUDO ln -sf "$CLANGXX" "${PREFIX}/bin/hipcc" || true
  [[ ! -e "${PREFIX}/bin/amdclang++" ]] && $SUDO ln -sf "$CLANGXX" "${PREFIX}/bin/amdclang++" || true
fi

# ------------------------------------------------------------------------------
# 6. Export Environment Variables
# ------------------------------------------------------------------------------
HIP_CLANG_PATH="${PREFIX}/llvm/bin"
[[ ! -d "$HIP_CLANG_PATH" && -d "${PREFIX}/lib/llvm/bin" ]] && HIP_CLANG_PATH="${PREFIX}/lib/llvm/bin"

EXPORT_ENV=(
  "ROCM_PATH=${PREFIX}"
  "HIP_PATH=${PREFIX}"
  "HOMEBREW_ROCM_PATH=${PREFIX}"
  "HIP_CLANG_PATH=${HIP_CLANG_PATH}"
)

if [[ -n "$CLANGXX" ]]; then
  EXPORT_ENV+=("CMAKE_HIP_COMPILER=${CLANGXX}")
fi

LIB_PATHS=()
for p in "${PREFIX}/lib" "${PREFIX}/lib64" "${PREFIX}/llvm/lib"; do
  [[ -d "$p" ]] && LIB_PATHS+=("$p")
done
LD_SEARCH=$(IFS=:; echo "${LIB_PATHS[*]}")
EXPORT_ENV+=("LD_LIBRARY_PATH=${LD_SEARCH}:\${LD_LIBRARY_PATH:-}")

if [[ -n "${GITHUB_ENV:-}" && -w "$GITHUB_ENV" ]]; then
  for env_line in "${EXPORT_ENV[@]}"; do
    echo "$env_line" >> "$GITHUB_ENV"
  done
  echo "${PREFIX}/bin" >> "$GITHUB_PATH"
  echo "$HIP_CLANG_PATH" >> "$GITHUB_PATH"
fi

if [[ "$OUTPUT_JSON" == "true" ]]; then
  echo "$RESOLVE_JSON"
else
  cat <<ENV_OUTPUT
# ROCm Environment configured successfully:
export ROCM_PATH="${PREFIX}"
export HIP_PATH="${PREFIX}"
export HOMEBREW_ROCM_PATH="${PREFIX}"
export HIP_CLANG_PATH="${HIP_CLANG_PATH}"
export PATH="${PREFIX}/bin:${HIP_CLANG_PATH}:\$PATH"
export LD_LIBRARY_PATH="${LD_SEARCH}:\${LD_LIBRARY_PATH:-}"
ENV_OUTPUT
fi
