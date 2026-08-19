#!/usr/bin/env bash
set -euo pipefail

STAGE=${1:?staging root required}
PLATFORM=${2:?platform required}
DSM_VERSION=${3:?DSM version required}
KERNEL_FLAVOR=${4:-kernel5.10.55}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE=syno-amdgpu-runtime
OUT=$ROOT/dist
ASSEMBLY=$ROOT/work/spk-${PLATFORM}-${DSM_VERSION}
# kvmx64 is Synology's virtual-platform identifier and must remain in INFO's
# arch field.  Use the clearer CPU-architecture suffix for the distributable
# filename so it is not mistaken for a hardware model.
case "$PLATFORM" in
  kvmx64)
    FILE_ARCH=x86_64
    # This is the portable DSM 7.4 x86_64 runtime build.  The runtime is
    # userspace-only; kernel compatibility remains the responsibility of each
    # platform's separately managed amdgpu.ko package.
    PACKAGE_ARCHES='apollolake avoton braswell broadwell broadwellnk broadwellnkv2 broadwellntbap bromolow denverton epyc7002 epyc7003 epyc7003ntb geminilake geminilakenk icelaked kvmx64 purley r1000 r1000nk v1000 v1000nk'
    ;;
  *)
    FILE_ARCH=$PLATFORM
    PACKAGE_ARCHES=$PLATFORM
    ;;
esac

case "$KERNEL_FLAVOR" in
  kernel5.10.55|kernel4.4.x) ;;
  *) echo "Unsupported kernel flavor: $KERNEL_FLAVOR" >&2; exit 2 ;;
esac

rm -rf "$ASSEMBLY"
mkdir -p "$ASSEMBLY/scripts" "$ASSEMBLY/conf"
cp "$ROOT/spk/INFO" "$ASSEMBLY/INFO"
# The same source metadata template is used for every toolchain target.  DSM
# uses INFO\'s arch field during installation, so replace the template value
# with the platform actually being packaged.
sed -i -E "s/^arch=\"[^\"]*\"$/arch=\"$PACKAGE_ARCHES\"/" "$ASSEMBLY/INFO"
VERSION=$(sed -n 's/^version="\([^"]*\)"$/\1/p' "$ASSEMBLY/INFO" | head -n 1)
[[ -n $VERSION ]] || { echo 'Missing package version in INFO' >&2; exit 2; }
cp "$ROOT/spk/scripts/"* "$ASSEMBLY/scripts/"
cp "$ROOT/spk/conf/"* "$ASSEMBLY/conf/"
case "$KERNEL_FLAVOR" in
  kernel4.4.x)
    # Kernel 4.4's backported AMDGPU scheduler can fault when amdgpu_top
    # closes its DRM context. Keep the binary for explicit diagnostics, but
    # do not expose it through /usr/bin or invoke it from package lifecycle.
    cat > "$ASSEMBLY/scripts/postinst" <<'EOF'
#!/bin/sh
set -eu
RUNTIME=/var/packages/syno-amdgpu-runtime/target
test -c /dev/dri/renderD128 || echo "Warning: no AMD DRM render node found yet." >&2
test -x "$RUNTIME/bin/amdgpu_top"
echo "Notice: kernel 4.4 runtime keeps amdgpu_top as an experimental diagnostic tool; it is not registered in PATH." >&2
"$RUNTIME/bin/helper/amdgpu-jellyfin-helper" patch
"$RUNTIME/bin/helper/amdgpu-jellyfin-helper" configure
"$RUNTIME/bin/helper/amdgpu-jellyfin-helper" restart
# Kernel 4.4's backported AMDGPU scheduler is not stable when a media
# process closes a VA-API DRM context.  Do not inject the Plex runtime here.
EOF
    chmod 0755 "$ASSEMBLY/scripts/postinst"
    # start-stop-status normally self-heals the /usr/bin/amdgpu_top shim on
    # every package start; kernel 4.4 must never create that shim, so ship a
    # copy without the self-heal step instead of the shared spk/scripts one.
    cat > "$ASSEMBLY/scripts/start-stop-status" <<'EOF'
#!/bin/sh
case "${1:-}" in
  start|status) exit 0 ;;
  stop) exit 0 ;;
  log) exit 1 ;;
  *) exit 1 ;;
esac
EOF
    chmod 0755 "$ASSEMBLY/scripts/start-stop-status"
    sed -i -E 's#^description=".*"$#description="AMD VA-API, RADV Vulkan, and monitoring runtime for DSM (kernel 4.4: amdgpu_top experimental)."#' "$ASSEMBLY/INFO"
    ;;
esac
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
SPK="$OUT/${PACKAGE}-${VERSION}-${DSM_VERSION}-${FILE_ARCH}-${KERNEL_FLAVOR}.spk"
tar -C "$ASSEMBLY" -cf "$SPK" "${members[@]}"
echo "Built $SPK"
