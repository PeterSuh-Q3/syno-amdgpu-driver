#!/usr/bin/env bash
# Build the common DSM 7.4 x86_64 runtime builder image.
set -euo pipefail

DSM_VERSION=${1:-7.4}
[[ $DSM_VERSION == 7.4 ]] || { echo 'Supported builder profile: 7.4' >&2; exit 2; }

ROOT=$(cd "$(dirname "$0")/.." && pwd)
docker build --build-arg "DSM_VERSION=$DSM_VERSION" \
  -t "syno-amdgpu-builder:$DSM_VERSION" \
  -f "$ROOT/docker/Dockerfile" "$ROOT"
