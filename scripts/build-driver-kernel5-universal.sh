#!/usr/bin/env bash
# Build one DSM 7.4 SPK containing all supported kernel-5.10.55 platform
# module bundles plus the shared AMD/i915 firmware and AMD userspace runtime.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DSM_VERSION=7.4
KERNEL_FLAVOR=kernel5.10.55
INTERNAL_PLATFORM=kernel5.10.55-universal
BASE_SPK=${BASE_SPK:-$ROOT/dist/syno-amdgpu-runtime-0.4.1-7.4-x86_64-kernel5.10.55.spk}
ASSET_ROOT=$ROOT/sources/driver-assets/26.9.12
DIST_DIR=${DIST_DIR:-$ROOT/dist}
PLATFORMS=(epyc7002 epyc7003 geminilakenk icelaked r1000nk v1000nk)
VERSION=$(sed -n 's/^version="\([^"]*\)"$/\1/p' "$ROOT/spk/INFO" | head -n 1)
OUTPUT=$DIST_DIR/syno-amdgpu-runtime-${VERSION}-${DSM_VERSION}-x86_64-${KERNEL_FLAVOR}.spk

[[ -n "$VERSION" ]] || { echo 'Missing package version in spk/INFO' >&2; exit 2; }
[[ -s "$BASE_SPK" ]] || { echo "Missing base runtime SPK: $BASE_SPK" >&2; exit 2; }
mkdir -p "$DIST_DIR"
[[ ! -e "$OUTPUT" ]] || { echo "Refusing to overwrite existing SPK: $OUTPUT" >&2; exit 2; }

# Ensure the canonical build matrix and the pinned DRM lock agree exactly.
matrix=$(awk '$1 !~ /^#/ && $2 == "7.4" { print $1 }' "$ROOT/build/ALL-PLATFORMS" | sort)
expected=$(printf '%s\n' "${PLATFORMS[@]}" | sort)
[[ "$matrix" == "$expected" ]] || {
  echo 'build/ALL-PLATFORMS no longer matches the six-platform kernel-5 target set.' >&2
  echo "Expected: ${PLATFORMS[*]}" >&2
  echo "Found: $(tr '\n' ' ' <<< "$matrix")" >&2
  exit 2
}

for platform in "${PLATFORMS[@]}"; do
  "$ROOT/scripts/fetch-driver-assets.sh" "$platform"
done

WORK=$(mktemp -d "$ROOT/work/driver-universal-k5.XXXXXX")
cleanup() {
  if [[ ${BUILD_OK:-0} == 1 ]]; then
    rm -rf "$WORK"
  else
    echo "Build workspace preserved for diagnosis: $WORK" >&2
  fi
}
trap cleanup EXIT
ASSEMBLY=$WORK/assembly
STAGE=$WORK/stage
PACK=$WORK/packaging
TARGET=$STAGE/var/packages/syno-amdgpu-runtime/target
mkdir -p "$TARGET"
mkdir -p "$ASSEMBLY"
tar -xf "$BASE_SPK" -C "$ASSEMBLY"
[[ -s "$ASSEMBLY/package.tgz" ]] || { echo 'Base SPK has no package.tgz' >&2; exit 2; }
tar -xzf "$ASSEMBLY/package.tgz" -C "$TARGET"

PAYLOAD=$TARGET/share/syno-amdgpu-driver/driver-assets
mkdir -p "$PAYLOAD/firmware"
install -m 0644 "$ASSET_ROOT/firmwareamdgpu.tgz" "$PAYLOAD/firmware/firmware-amdgpu.tgz"
install -m 0644 "$ASSET_ROOT/firmwarei915.tgz" "$PAYLOAD/firmware/firmware-i915.tgz"
(
  cd "$PAYLOAD/firmware"
  shasum -a 256 firmware-amdgpu.tgz firmware-i915.tgz > SHA256SUMS
)
for platform in "${PLATFORMS[@]}"; do
  source_dir=$ASSET_ROOT
  asset=$(awk -v p="$platform" '$1 == p && $2 == "5.10.55" { print $3; found=1 } END { if (!found) exit 1 }' "$ROOT/build/driver-assets.lock") || {
    echo "No pinned kernel 5.10.55 DRM asset for $platform" >&2
    exit 2
  }
  dest=$PAYLOAD/$platform-${DSM_VERSION}-${KERNEL_FLAVOR}
  [[ -s "$source_dir/$asset" ]] || { echo "Missing fetched asset: $source_dir/$asset" >&2; exit 2; }
  mkdir -p "$dest"
  install -m 0644 "$source_dir/$asset" "$dest/drm-modules.tgz"
  printf 'platform=%s\ndsm=%s\nkernel=%s\nsource=%s\n' \
    "$platform" "$DSM_VERSION" "$KERNEL_FLAVOR" "$asset" > "$dest/target.conf"
  (
    cd "$dest"
    shasum -a 256 drm-modules.tgz > SHA256SUMS
  )
  tar -tzf "$dest/drm-modules.tgz" > "$WORK/$platform.modules"
  for required in amdgpu.ko drm.ko i915.ko i915-compat.ko; do
    grep -Fxq "$required" "$WORK/$platform.modules" || {
      echo "$platform DRM bundle is missing $required" >&2
      exit 1
    }
  done
done
install -m 0755 "$ROOT/spk/package/bin/helper/amdgpu-driver-assets" \
  "$TARGET/bin/helper/amdgpu-driver-assets"

mkdir -p "$PACK"
WORK_REL=${WORK#"$ROOT"/}
DIST_REL=${DIST_DIR#"$ROOT"/}
[[ "$DIST_REL" != "$DIST_DIR" ]] || { echo 'DIST_DIR must be inside the repository for the Docker build.' >&2; exit 2; }
docker run --rm -u 0 \
  -v "$ROOT:/work" \
  -e STAGE="/work/$WORK_REL/stage" \
  -e ASSEMBLY_DIR="/work/$WORK_REL/packaging" \
  -e DIST_DIR="/work/$DIST_REL" \
  --entrypoint /bin/bash dante90/syno-compiler:7.4 \
  -lc 'cd /work && install -d "$STAGE/var/packages/syno-amdgpu-runtime/target/bin/helper" && /opt/epyc7002/bin/x86_64-pc-linux-gnu-gcc -O2 -Wall -Wextra -Werror spk/package/bin/helper/amdgpu-driver-helper.c -o "$STAGE/var/packages/syno-amdgpu-runtime/target/bin/helper/amdgpu-driver-helper" && chown root:root "$STAGE/var/packages/syno-amdgpu-runtime/target/bin/helper/amdgpu-driver-helper" && chmod 4755 "$STAGE/var/packages/syno-amdgpu-runtime/target/bin/helper/amdgpu-driver-helper" && bash scripts/package-spk.sh "$STAGE" kernel5.10.55-universal 7.4 kernel5.10.55'

[[ -s "$OUTPUT" ]] || { echo "Expected universal SPK was not created: $OUTPUT" >&2; exit 1; }
info=$(tar -xOf "$OUTPUT" INFO)
grep -Fqx 'arch="epyc7002 epyc7003 geminilakenk icelaked r1000nk v1000nk"' <<< "$info" || {
  echo 'SPK INFO architecture list is incorrect.' >&2
  exit 1
}
package_list=$(tar -xOf "$OUTPUT" package.tgz | tar -tzf -)
for platform in "${PLATFORMS[@]}"; do
  grep -Fq "share/syno-amdgpu-driver/driver-assets/$platform-${DSM_VERSION}-${KERNEL_FLAVOR}/drm-modules.tgz" <<< "$package_list" || {
    echo "SPK is missing the $platform module bundle." >&2
    exit 1
  }
done
grep -Fq 'share/syno-amdgpu-driver/driver-assets/firmware/firmware-amdgpu.tgz' <<< "$package_list" || { echo 'SPK is missing shared AMD firmware.' >&2; exit 1; }
grep -Fq 'share/syno-amdgpu-driver/driver-assets/firmware/firmware-i915.tgz' <<< "$package_list" || { echo 'SPK is missing shared i915 firmware.' >&2; exit 1; }
echo "Verified universal kernel-5 SPK: $OUTPUT"
shasum -a 256 "$OUTPUT"
BUILD_OK=1
