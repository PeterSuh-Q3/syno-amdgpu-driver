#!/usr/bin/env bash
# Refresh package-owned scripts/helpers in an existing staged runtime and
# repackage it.  This avoids rebuilding Mesa when only SPK integration code
# changes.
set -euo pipefail

STAGE=${1:?staging root required}
PLATFORM=${2:?platform required}
DSM_VERSION=${3:?DSM version required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=/var/packages/syno-amdgpu-runtime/target
TOOLCHAIN=/opt/${PLATFORM}/bin/x86_64-pc-linux-gnu-gcc

[[ -d "$STAGE$PREFIX" ]] || { echo "Missing staged runtime: $STAGE$PREFIX" >&2; exit 2; }
[[ -x $TOOLCHAIN ]] || { echo "Synology toolchain missing for $PLATFORM" >&2; exit 2; }

mkdir -p "$STAGE$PREFIX/bin/helper"
"$TOOLCHAIN" -O2 -Wall -Wextra -Werror \
  "$ROOT/spk/package/bin/helper/amdgpu-path-helper.c" \
  -o "$STAGE$PREFIX/bin/helper/amdgpu-path-helper"
"$TOOLCHAIN" -O2 -Wall -Wextra -Werror \
  "$ROOT/spk/package/bin/helper/amdgpu-jellyfin-helper.c" \
  -o "$STAGE$PREFIX/bin/helper/amdgpu-jellyfin-helper"
chmod 0755 "$STAGE$PREFIX/bin/helper/amdgpu-path-helper" "$STAGE$PREFIX/bin/helper/amdgpu-jellyfin-helper"

install -Dm755 "$ROOT/scripts/verify-runtime.sh" "$STAGE$PREFIX/bin/verify-amdgpu-runtime"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-env" "$STAGE$PREFIX/bin/amdgpu-env"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-ffmpeg" "$STAGE$PREFIX/bin/amdgpu-ffmpeg"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-jellyfin-link.sh" "$STAGE$PREFIX/bin/amdgpu-jellyfin-link.sh"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-jellyfin-autoconfig.sh" "$STAGE$PREFIX/bin/amdgpu-jellyfin-autoconfig.sh"

"$ROOT/scripts/package-spk.sh" "$STAGE" "$PLATFORM" "$DSM_VERSION"
