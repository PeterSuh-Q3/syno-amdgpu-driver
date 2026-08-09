#!/usr/bin/env bash
set -euo pipefail

DSM_VERSION=${1:-7.4}
PLATFORM=${2:-epyc7002}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILDER_IMAGE=${BUILDER_IMAGE:-syno-amdgpu-builder:${DSM_VERSION}}

if [[ $DSM_VERSION != 7.4 || $PLATFORM != epyc7002 ]]; then
  echo "This initial build profile only supports DSM 7.4 epyc7002." >&2
  exit 2
fi

SUDO=()
docker info >/dev/null 2>&1 || SUDO=(sudo)
"${SUDO[@]}" docker run --rm -t -u 0 \
  -v "$ROOT:/work" \
  -e PLATFORM -e DSM_VERSION \
  -e LLVM_CONFIG="${LLVM_CONFIG:-}" \
  "$BUILDER_IMAGE" \
  bash /work/scripts/build-runtime.sh
