#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
MESA_SOURCE=${1:?Mesa source directory required}
PATCH_FILE="$ROOT/patches/0001-rusticl-jellyfin-amd-vendor.patch"

[[ -f "$MESA_SOURCE/src/gallium/frontends/rusticl/api/device.rs" ]] || {
  echo "not a Mesa source tree: $MESA_SOURCE" >&2
  exit 2
}

if patch -d "$MESA_SOURCE" -p1 --dry-run < "$PATCH_FILE" >/dev/null; then
  patch -d "$MESA_SOURCE" -p1 < "$PATCH_FILE"
elif patch -d "$MESA_SOURCE" -p1 -R --dry-run < "$PATCH_FILE" >/dev/null; then
  echo "Rusticl Jellyfin compatibility patch is already applied."
else
  echo "Rusticl patch does not match this Mesa source tree." >&2
  exit 1
fi
