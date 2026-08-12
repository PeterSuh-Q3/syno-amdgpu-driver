#!/usr/bin/env bash
# Repackage a released SPK after a package-integration-only change. The target
# Mesa/LLVM binaries remain untouched; only package-owned scripts are updated.
set -euo pipefail

INPUT=${1:?existing SPK required}
PLATFORM=${2:?platform required}
DSM_VERSION=${3:?DSM version required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE=syno-amdgpu-runtime
WORK="$ROOT/work/repackage-${PLATFORM}-${DSM_VERSION}"
STAGE="$WORK/stage"
TARGET="$STAGE/var/packages/$PACKAGE/target"

[[ -f "$INPUT" ]] || { echo "Missing input SPK: $INPUT" >&2; exit 2; }
rm -rf "$WORK"
mkdir -p "$WORK/assembly" "$TARGET"
tar -xf "$INPUT" -C "$WORK/assembly"
[[ -f "$WORK/assembly/package.tgz" ]] || { echo 'Input SPK has no package.tgz' >&2; exit 2; }
tar -xzf "$WORK/assembly/package.tgz" -C "$TARGET"

install -Dm755 "$ROOT/spk/package/bin/amdgpu-env" "$TARGET/bin/amdgpu-env"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-ffmpeg" "$TARGET/bin/amdgpu-ffmpeg"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-ffprobe" "$TARGET/bin/amdgpu-ffprobe"
ln -sfn amdgpu-ffprobe "$TARGET/bin/ffprobe"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-jellyfin-link.sh" "$TARGET/bin/amdgpu-jellyfin-link.sh"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-jellyfin-autoconfig.sh" "$TARGET/bin/amdgpu-jellyfin-autoconfig.sh"

"$ROOT/scripts/package-spk.sh" "$STAGE" "$PLATFORM" "$DSM_VERSION"
