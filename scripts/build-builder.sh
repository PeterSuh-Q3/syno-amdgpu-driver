#!/usr/bin/env bash
set -euo pipefail

DSM_VERSION=${1:-7.4}
case "$DSM_VERSION" in
  7.1|7.4) ;;
  *) echo "Supported builder profiles: 7.1, 7.4" >&2; exit 2 ;;
esac

ROOT=$(cd "$(dirname "$0")/.." && pwd)
docker build --build-arg "DSM_VERSION=$DSM_VERSION" \
  -t "syno-amdgpu-builder:$DSM_VERSION" \
  -f "$ROOT/docker/Dockerfile" "$ROOT"
