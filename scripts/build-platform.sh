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
status() { printf '%s\t%s\t%s\n' "$1" "$2" "$(date +%s)" > "$STATUS_FILE"; }
trap 'status failed failed' ERR

"$ROOT/scripts/generate-cross-file.sh" "$PLATFORM" "$DSM_VERSION" >/dev/null
status llvm running
docker run --rm -u 0 -v "$ROOT:/work" -e PLATFORM -e DSM_VERSION \
  -e COMPILE_JOBS -e STATUS_FILE="/work/work/status/${KEY}.status" "$IMAGE" \
  bash /work/scripts/build-target-llvm.sh >> "$LOG_FILE" 2>&1
status runtime running
docker run --rm -u 0 -v "$ROOT:/work" -e PLATFORM -e DSM_VERSION \
  -e COMPILE_JOBS -e STATUS_FILE="/work/work/status/${KEY}.status" "$IMAGE" \
  bash /work/scripts/build-runtime.sh >> "$LOG_FILE" 2>&1
status complete success
