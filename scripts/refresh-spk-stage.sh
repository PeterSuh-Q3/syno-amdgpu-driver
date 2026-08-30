#!/usr/bin/env bash
# Refresh package-owned scripts/helpers in an existing staged runtime and
# repackage it.  This avoids rebuilding Mesa when only SPK integration code
# changes.
set -euo pipefail

STAGE=${1:?staging root required}
PLATFORM=${2:?platform required}
DSM_VERSION=${3:?DSM version required}
KERNEL_FLAVOR=${4:-${KERNEL_FLAVOR:-kernel5.10.55}}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PREFIX=/var/packages/syno-amdgpu-runtime/target
TOOLCHAIN=${TOOLCHAIN_BIN:-/opt/${PLATFORM}/bin}/x86_64-pc-linux-gnu-gcc

[[ -d "$STAGE$PREFIX" ]] || { echo "Missing staged runtime: $STAGE$PREFIX" >&2; exit 2; }
[[ -x $TOOLCHAIN ]] || { echo "Synology toolchain missing for $PLATFORM" >&2; exit 2; }

# amdgpu_top and its PATH-shim helper moved to the standalone
# https://github.com/PeterSuh-Q3/syno-amdgpu-top package - it never depended
# on Mesa/libva, so it no longer ships here. Remove any copy carried over
# from an older staged runtime.
rm -f "$STAGE$PREFIX/bin/amdgpu_top" "$STAGE$PREFIX/bin/helper/amdgpu-path-helper"

mkdir -p "$STAGE$PREFIX/bin/helper"
"$TOOLCHAIN" -O2 -Wall -Wextra -Werror \
  "$ROOT/spk/package/bin/helper/amdgpu-jellyfin-helper.c" \
  -o "$STAGE$PREFIX/bin/helper/amdgpu-jellyfin-helper"
"$TOOLCHAIN" -O2 -Wall -Wextra -Werror \
  "$ROOT/spk/package/bin/helper/amdgpu-plex-restore-helper.c" \
  -o "$STAGE$PREFIX/bin/helper/amdgpu-plex-restore-helper"
# Package lifecycle scripts run as the package account on DSM.  These narrow
# helpers are intentionally setuid-root so they can modify only the fixed
# third-party integration files and then clear their environment.
chown root:root "$STAGE$PREFIX/bin/helper/amdgpu-jellyfin-helper" "$STAGE$PREFIX/bin/helper/amdgpu-plex-restore-helper"
chmod 4755 "$STAGE$PREFIX/bin/helper/amdgpu-jellyfin-helper" "$STAGE$PREFIX/bin/helper/amdgpu-plex-restore-helper"

install -Dm755 "$ROOT/scripts/verify-runtime.sh" "$STAGE$PREFIX/bin/verify-amdgpu-runtime"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-env" "$STAGE$PREFIX/bin/amdgpu-env"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-ffmpeg" "$STAGE$PREFIX/bin/amdgpu-ffmpeg"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-ffprobe" "$STAGE$PREFIX/bin/amdgpu-ffprobe"
ln -sfn amdgpu-ffprobe "$STAGE$PREFIX/bin/ffprobe"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-jellyfin-link.sh" "$STAGE$PREFIX/bin/amdgpu-jellyfin-link.sh"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-jellyfin-autoconfig.sh" "$STAGE$PREFIX/bin/amdgpu-jellyfin-autoconfig.sh"

"$ROOT/scripts/package-spk.sh" "$STAGE" "$PLATFORM" "$DSM_VERSION" "$KERNEL_FLAVOR"
