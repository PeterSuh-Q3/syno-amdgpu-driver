#!/usr/bin/env bash
set -euo pipefail

ROOT=/work
PLATFORM=${PLATFORM:-epyc7002}
DSM_VERSION=${DSM_VERSION:-7.4}
PREFIX=/var/packages/syno-amdgpu-runtime/target
BUILD_ROOT=$ROOT/work/${PLATFORM}-${DSM_VERSION}
SOURCE_ROOT=$ROOT/sources
STAGE=$BUILD_ROOT/stage
CROSS_FILE=$ROOT/build/${PLATFORM}-${DSM_VERSION}.ini

[[ $PLATFORM == epyc7002 && $DSM_VERSION == 7.4 ]] || { echo "unsupported profile" >&2; exit 2; }
[[ -x /opt/${PLATFORM}/bin/x86_64-pc-linux-gnu-gcc ]] || { echo "Synology toolchain missing" >&2; exit 1; }
[[ -x "$ROOT/scripts/llvm-config-${PLATFORM}.sh" ]] || { echo "Missing LLVM config wrapper for ${PLATFORM}." >&2; exit 1; }
[[ -f "$ROOT/work/llvm-${PLATFORM}/lib/libLLVM.so.${LLVM_VERSION:-18.1}" ]] || { echo "Missing target libLLVM build." >&2; exit 1; }
command -v meson >/dev/null
command -v ninja >/dev/null
command -v cargo >/dev/null
mkdir -p "$BUILD_ROOT" "$SOURCE_ROOT" "$STAGE"

# Populate sources/ with the exact archives in build/versions.env, unpacked as
# libdrm/, libva/, mesa/, and amdgpu_top/. Release builds require locked hashes.
if [[ ${RELEASE:-0} == 1 ]] && grep -q ' TODO$' "$ROOT/build/sources.lock"; then
  echo "sources.lock is incomplete; refusing a release build" >&2
  exit 1
fi
for required in libdrm libva zlib elfutils mesa amdgpu_top; do
  [[ -d $SOURCE_ROOT/$required ]] || { echo "missing source: $SOURCE_ROOT/$required" >&2; exit 1; }
done

export PATH="/opt/${PLATFORM}/bin:$PATH"
export PKG_CONFIG_PATH="$STAGE$PREFIX/lib/pkgconfig"
# Do not let the Debian builder's host-only .pc files leak into a DSM target
# build (notably spirv-tools, whose headers are not in the target sysroot).
export PKG_CONFIG_LIBDIR="$STAGE$PREFIX/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$STAGE"
export LLVM_TARGET_ROOT="$ROOT/work/llvm-${PLATFORM}"

meson setup --wipe "$BUILD_ROOT/libdrm" "$SOURCE_ROOT/libdrm" --cross-file "$CROSS_FILE" --prefix="$PREFIX" \
  -Damdgpu=enabled -Dintel=disabled -Dradeon=enabled -Dnouveau=disabled -Dvmwgfx=disabled
ninja -C "$BUILD_ROOT/libdrm"
DESTDIR="$STAGE" ninja -C "$BUILD_ROOT/libdrm" install

meson setup --wipe "$BUILD_ROOT/libva" "$SOURCE_ROOT/libva" --cross-file "$CROSS_FILE" --prefix="$PREFIX" \
  -Ddisable_drm=false -Dwith_glx=no -Dwith_wayland=no -Dwith_x11=no
ninja -C "$BUILD_ROOT/libva"
DESTDIR="$STAGE" ninja -C "$BUILD_ROOT/libva" install

ZLIB_BUILD="$BUILD_ROOT/zlib"
rm -rf "$ZLIB_BUILD"
mkdir -p "$ZLIB_BUILD"
pushd "$ZLIB_BUILD" >/dev/null
CHOST=x86_64-pc-linux-gnu CC=/opt/${PLATFORM}/bin/x86_64-pc-linux-gnu-gcc \
  "$SOURCE_ROOT/zlib/configure" --prefix="$PREFIX" --shared
make -j"$(nproc)"
DESTDIR="$STAGE" make install
popd >/dev/null

# radeonsi requires libelf.  Build only elfutils' libelf component so the
# runtime stays focused on GPU userspace rather than the full elfutils suite.
ELF_BUILD="$BUILD_ROOT/elfutils"
rm -rf "$ELF_BUILD"
mkdir -p "$ELF_BUILD"
pushd "$ELF_BUILD" >/dev/null
CC=/opt/${PLATFORM}/bin/x86_64-pc-linux-gnu-gcc \
  CXX=/opt/${PLATFORM}/bin/x86_64-pc-linux-gnu-g++ \
  CPPFLAGS="-I$STAGE$PREFIX/include" LDFLAGS="-L$STAGE$PREFIX/lib" \
  "$SOURCE_ROOT/elfutils/configure" --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu \
    --prefix="$PREFIX" --disable-debuginfod --disable-libdebuginfod --disable-demangler
# libelf links elfutils' internal libeu archive, which must be built first.
make -C lib -j"$(nproc)"
make -C libelf -j"$(nproc)"
DESTDIR="$STAGE" make -C libelf install
# `make -C libelf install` does not install the generated pkg-config metadata;
# Mesa discovers libelf through this file during its cross configuration.
install -Dm644 "$ELF_BUILD/config/libelf.pc" "$STAGE$PREFIX/lib/pkgconfig/libelf.pc"
popd >/dev/null

meson setup --wipe "$BUILD_ROOT/mesa" "$SOURCE_ROOT/mesa" --cross-file "$CROSS_FILE" --prefix="$PREFIX" \
  -Dgallium-drivers=radeonsi -Dvulkan-drivers=amd -Dgallium-va=enabled -Dgallium-vdpau=disabled \
  -Dplatforms=[] -Dglx=disabled -Dcpp_rtti=false -Dllvm=enabled -Dshared-llvm=enabled \
  -Dvideo-codecs=all
ninja -C "$BUILD_ROOT/mesa"
DESTDIR="$STAGE" ninja -C "$BUILD_ROOT/mesa" install

# Mesa and its drivers link to the target ABI's shared LLVM.  Ship it inside
# the package rather than relying on an absent DSM system LLVM installation.
install -Dm755 "$LLVM_TARGET_ROOT/lib/libLLVM.so.${LLVM_VERSION:-18.1}" "$STAGE$PREFIX/lib/libLLVM.so.${LLVM_VERSION:-18.1}"
ln -sfn "libLLVM.so.${LLVM_VERSION:-18.1}" "$STAGE$PREFIX/lib/libLLVM.so"

# This upstream feature opens the staged libdrm at runtime, avoiding a DSM
# global-library change and allowing the SPK to carry its own ABI-matched copy.
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=/opt/${PLATFORM}/bin/x86_64-pc-linux-gnu-gcc
export RUSTFLAGS="-C link-arg=-Wl,-rpath,\$ORIGIN/../lib"
pushd "$SOURCE_ROOT/amdgpu_top" >/dev/null
cargo build --release --target x86_64-unknown-linux-gnu --no-default-features --features dynamic_loading_package
install -Dm755 target/x86_64-unknown-linux-gnu/release/amdgpu_top "$STAGE$PREFIX/bin/amdgpu_top"
popd >/dev/null

# DSM applies root ownership and setuid only to the explicitly declared
# privilege tool.  It creates/removes the fixed /usr/bin/amdgpu_top shim.
mkdir -p "$STAGE$PREFIX/bin/helper"
/opt/${PLATFORM}/bin/x86_64-pc-linux-gnu-gcc -O2 -Wall -Wextra -Werror \
  "$ROOT/spk/package/bin/helper/amdgpu-path-helper.c" \
  -o "$STAGE$PREFIX/bin/helper/amdgpu-path-helper"
chmod 0755 "$STAGE$PREFIX/bin/helper/amdgpu-path-helper"

install -Dm755 "$ROOT/scripts/verify-runtime.sh" "$STAGE$PREFIX/bin/verify-amdgpu-runtime"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-env" "$STAGE$PREFIX/bin/amdgpu-env"
install -Dm755 "$ROOT/spk/package/bin/amdgpu-ffmpeg" "$STAGE$PREFIX/bin/amdgpu-ffmpeg"
mkdir -p "$STAGE$PREFIX/etc/vulkan/icd.d"
cp "$ROOT/spk/package/etc/vulkan/icd.d/radeon_icd.x86_64.json" "$STAGE$PREFIX/etc/vulkan/icd.d/"
"$ROOT/scripts/package-spk.sh" "$STAGE" "$PLATFORM" "$DSM_VERSION"
