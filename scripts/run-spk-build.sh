#!/usr/bin/env bash
set -euo pipefail

DSM_VERSION=${1:-7.4}
PLATFORM=${2:-epyc7002}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILDER_IMAGE=${BUILDER_IMAGE:-syno-amdgpu-builder:${DSM_VERSION}}

"$ROOT/scripts/generate-cross-file.sh" "$PLATFORM" "$DSM_VERSION" >/dev/null

SUDO=()
docker info >/dev/null 2>&1 || SUDO=(sudo)
"${SUDO[@]}" docker run --rm -t -u 0 \
  -v "$ROOT:/work" \
  -e PLATFORM -e DSM_VERSION \
  -e COMPILE_JOBS="${COMPILE_JOBS:-}" \
  -e LLVM_CONFIG="${LLVM_CONFIG:-}" \
  "$BUILDER_IMAGE" \
  bash /work/scripts/build-runtime.sh
