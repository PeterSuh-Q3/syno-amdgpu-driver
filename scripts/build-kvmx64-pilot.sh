#!/usr/bin/env bash
# Build the DSM 7.4 kvmx64 runtime pilot with the requested compiler threads.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
COMPILE_JOBS=${COMPILE_JOBS:-12}

exec env \
  PLATFORMS_FILE="$ROOT/build/ALL-PLATFORMS-kvmx64-pilot" \
  BUILD_JOBS=1 \
  COMPILE_JOBS="$COMPILE_JOBS" \
  "$ROOT/scripts/full-build.sh"
