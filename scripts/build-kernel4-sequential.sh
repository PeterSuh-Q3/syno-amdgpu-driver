#!/usr/bin/env bash
# Build the remaining DSM 7.4 kernel-4.4 platforms one at a time.
# Each build gets all requested compiler threads; geminilake is already released.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLATFORMS_FILE=${PLATFORMS_FILE:-"$ROOT/build/ALL-PLATFORMS-kernel4"}
COMPILE_JOBS=${COMPILE_JOBS:-12}

exec env \
  PLATFORMS_FILE="$PLATFORMS_FILE" \
  BUILD_JOBS=1 \
  COMPILE_JOBS="$COMPILE_JOBS" \
  "$ROOT/scripts/full-build.sh"
