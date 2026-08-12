#!/usr/bin/env bash
# Build one DSM platform.  Intended to be launched by full-build.sh.
set -euo pipefail

PLATFORM=${1:?platform required}
DSM_VERSION=${2:?DSM version required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
KEY="${PLATFORM}-${DSM_VERSION}"
STATUS_FILE=${STATUS_FILE:-"$ROOT/work/status/${KEY}.status"}
LOG_FILE=${LOG_FILE:-"$ROOT/logs/${KEY}.log"}
IMAGE=${BUILDER_IMAGE:-"syno-amdgpu-builder:${DSM_VERSION}"}
COMPILE_JOBS=${COMPILE_JOBS:-$(nproc)}

mkdir -p "$(dirname "$STATUS_FILE")" "$(dirname "$LOG_FILE")"
status() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "${3:--}" "$(date +%s)" > "$STATUS_FILE"; }
trap 'status failed failed -' ERR

LLVM_CONFIG_BIN=$([[ ${BUILD_BACKEND:-docker} == host ]] && printf '%s' "$ROOT/scripts/llvm-config-synology-x64.sh" || printf '%s' '/work/scripts/llvm-config-synology-x64.sh') \
TOOLCHAIN_BIN=${TOOLCHAIN_BIN:-"/opt/${PLATFORM}/bin"} \
  "$ROOT/scripts/generate-cross-file.sh" "$PLATFORM" "$DSM_VERSION" >/dev/null
status '1/5 llvm' running '1/3 configure'
status '1/5 llvm' running '2/3 ninja'
if [[ ${BUILD_BACKEND:-docker} == host ]]; then
  : "${TOOLCHAIN_BIN:?TOOLCHAIN_BIN is required for BUILD_BACKEND=host}"
  ROOT="$ROOT" TOOLCHAIN_BIN="$TOOLCHAIN_BIN" PLATFORM="$PLATFORM" DSM_VERSION="$DSM_VERSION" \
    COMPILE_JOBS="$COMPILE_JOBS" STATUS_FILE="$STATUS_FILE" \
    bash "$ROOT/scripts/build-target-llvm.sh" >> "$LOG_FILE" 2>&1
else
  docker run --rm -u 0 -v "$ROOT:/work" \
    -e "PLATFORM=$PLATFORM" -e "DSM_VERSION=$DSM_VERSION" \
    -e "COMPILE_JOBS=$COMPILE_JOBS" -e STATUS_FILE="/work/work/status/${KEY}.status" "$IMAGE" \
    bash /work/scripts/build-target-llvm.sh >> "$LOG_FILE" 2>&1
fi
status '1/5 llvm' running '3/3 verify'
if [[ ${BUILD_BACKEND:-docker} == host ]]; then
  ROOT="$ROOT" TOOLCHAIN_BIN="$TOOLCHAIN_BIN" PLATFORM="$PLATFORM" DSM_VERSION="$DSM_VERSION" \
    COMPILE_JOBS="$COMPILE_JOBS" STATUS_FILE="$STATUS_FILE" \
    bash "$ROOT/scripts/build-runtime.sh" >> "$LOG_FILE" 2>&1
else
  docker run --rm -u 0 -v "$ROOT:/work" \
    -e "PLATFORM=$PLATFORM" -e "DSM_VERSION=$DSM_VERSION" \
    -e "COMPILE_JOBS=$COMPILE_JOBS" -e STATUS_FILE="/work/work/status/${KEY}.status" "$IMAGE" \
    bash /work/scripts/build-runtime.sh >> "$LOG_FILE" 2>&1
fi
status complete success done
