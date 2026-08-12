#!/usr/bin/env bash
set -euo pipefail

STAGE=${1:?staging root required}
PLATFORM=${2:?platform required}
DSM_VERSION=${3:?DSM version required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE=syno-amdgpu-runtime
OUT=$ROOT/dist
ASSEMBLY=$ROOT/work/spk-${PLATFORM}-${DSM_VERSION}
# kvmx64 is Synology's virtual-platform identifier and must remain in INFO's
# arch field.  Use the clearer CPU-architecture suffix for the distributable
# filename so it is not mistaken for a hardware model.
case "$PLATFORM" in
  kvmx64) FILE_ARCH=x86_64 ;;
  *)      FILE_ARCH=$PLATFORM ;;
esac

rm -rf "$ASSEMBLY"
mkdir -p "$ASSEMBLY/scripts" "$ASSEMBLY/conf"
cp "$ROOT/spk/INFO" "$ASSEMBLY/INFO"
# The same source metadata template is used for every toolchain target.  DSM
# uses INFO\'s arch field during installation, so replace the template value
# with the platform actually being packaged.
sed -i -E "s/^arch=\"[^\"]*\"$/arch=\"$PLATFORM\"/" "$ASSEMBLY/INFO"
VERSION=$(sed -n 's/^version="\([^"]*\)"$/\1/p' "$ASSEMBLY/INFO" | head -n 1)
[[ -n $VERSION ]] || { echo 'Missing package version in INFO' >&2; exit 2; }
cp "$ROOT/spk/scripts/"* "$ASSEMBLY/scripts/"
cp "$ROOT/spk/conf/"* "$ASSEMBLY/conf/"
for icon in PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG; do
  [[ -f "$ROOT/spk/$icon" ]] && cp "$ROOT/spk/$icon" "$ASSEMBLY/$icon"
done
# DSM extracts package.tgz into the appstore directory linked as target/.
# Archive the target contents, not the target directory itself.
tar -C "$STAGE/var/packages/$PACKAGE/target" -czf "$ASSEMBLY/package.tgz" .
CHECKSUM=$(md5sum "$ASSEMBLY/package.tgz" | awk '{print $1}')
EXTRACT_SIZE=$(du -sk "$STAGE/var/packages/$PACKAGE" | awk '{print $1}')
{
  printf 'extractsize="%s"\n' "$EXTRACT_SIZE"
  printf 'create_time="%s"\n' "$(date +%Y%m%d-%H:%M:%S)"
  printf 'checksum="%s"\n' "$CHECKSUM"
  for icon in PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG; do
    [[ -f "$ASSEMBLY/$icon" ]] || continue
    key=${icon%.PNG}
    key=$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')
    printf '%s="%s"\n' "$key" "$(base64 < "$ASSEMBLY/$icon" | tr -d '\n')"
  done
} >> "$ASSEMBLY/INFO"
mkdir -p "$OUT"
# DSM SPK is an uncompressed tar archive with unprefixed top-level members.
members=(INFO package.tgz scripts conf)
for icon in PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG; do
  [[ -f "$ASSEMBLY/$icon" ]] && members+=("$icon")
done
SPK="$OUT/${PACKAGE}-${VERSION}-${DSM_VERSION}-${FILE_ARCH}.spk"
tar -C "$ASSEMBLY" -cf "$SPK" "${members[@]}"
echo "Built $SPK"
