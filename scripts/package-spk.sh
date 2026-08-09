#!/usr/bin/env bash
set -euo pipefail

STAGE=${1:?staging root required}
PLATFORM=${2:?platform required}
DSM_VERSION=${3:?DSM version required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE=syno-amdgpu-runtime
OUT=$ROOT/dist
ASSEMBLY=$ROOT/work/spk-${PLATFORM}-${DSM_VERSION}

[[ $PLATFORM == epyc7002 && $DSM_VERSION == 7.4 ]] || { echo "unsupported profile" >&2; exit 2; }
rm -rf "$ASSEMBLY"
mkdir -p "$ASSEMBLY/scripts" "$ASSEMBLY/conf"
cp "$ROOT/spk/INFO" "$ASSEMBLY/INFO"
cp "$ROOT/spk/scripts/"* "$ASSEMBLY/scripts/"
cp "$ROOT/spk/conf/"* "$ASSEMBLY/conf/"
tar -C "$STAGE/var/packages/$PACKAGE" -czf "$ASSEMBLY/package.tgz" target
mkdir -p "$OUT"
tar -C "$ASSEMBLY" -czf "$OUT/${PACKAGE}-${DSM_VERSION}-${PLATFORM}.spk" .
echo "Built $OUT/${PACKAGE}-${DSM_VERSION}-${PLATFORM}.spk"
