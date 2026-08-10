#!/usr/bin/env bash
set -euo pipefail

DSM_VERSION=${1:-7.4}
PLATFORM=${2:-epyc7002}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILDER_IMAGE=${BUILDER_IMAGE:-syno-amdgpu-builder:${DSM_VERSION}}

if [[ $PLATFORM != epyc7002 || ( $DSM_VERSION != 7.1 && $DSM_VERSION != 7.4 ) ]]; then
  echo "Supported profiles: epyc7002 DSM 7.1 and 7.4." >&2
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
