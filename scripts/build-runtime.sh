#!/usr/bin/env bash
set -euo pipefail

ROOT=${ROOT:-/work}
PLATFORM=${PLATFORM:-epyc7002}
DSM_VERSION=${DSM_VERSION:-7.4}
PREFIX=/var/packages/syno-amdgpu-runtime/target
BUILD_ROOT=$ROOT/work/${PLATFORM}-${DSM_VERSION}
SOURCE_ROOT=$ROOT/sources
STAGE=$BUILD_ROOT/stage
CROSS_FILE=${CROSS_FILE:-$ROOT/work/profiles/${PLATFORM}-${DSM_VERSION}.ini}
COMPILE_JOBS=${COMPILE_JOBS:-$(nproc)}
TOOLCHAIN=${TOOLCHAIN_BIN:-/opt/${PLATFORM}/bin}

[[ -x $TOOLCHAIN/x86_64-pc-linux-gnu-gcc ]] || { echo "Synology toolchain missing" >&2; exit 1; }
[[ -x "$ROOT/scripts/llvm-config-synology-x64.sh" ]] || { echo "Missing LLVM config wrapper." >&2; exit 1; }
[[ -f "$CROSS_FILE" ]] || { echo "Missing cross file: $CROSS_FILE" >&2; exit 1; }
[[ -f "$ROOT/work/llvm-${PLATFORM}/lib/libLLVM.so.${LLVM_VERSION:-18.1}" ]] || { echo "Missing target libLLVM build." >&2; exit 1; }
[[ -f "$ROOT/work/llvm-${PLATFORM}/lib/libclangBasic.a" ]] || { echo "Missing target Clang libraries for Clover OpenCL." >&2; exit 1; }
command -v meson >/dev/null
command -v ninja >/dev/null
command -v cargo >/dev/null
mkdir -p "$BUILD_ROOT" "$SOURCE_ROOT" "$STAGE"
progress() {
  [[ -n ${STATUS_FILE:-} ]] || return 0
  local phase="$1"
  case "$phase" in
    libdrm) phase='2/5 libdrm'; case "$3" in configure) set -- "$1" "$2" '1/3 configure';; build) set -- "$1" "$2" '2/3 build';; install) set -- "$1" "$2" '3/3 install';; esac ;;
    libva) phase='3/5 libva'; case "$3" in configure) set -- "$1" "$2" '1/3 configure';; build) set -- "$1" "$2" '2/3 build';; install) set -- "$1" "$2" '3/3 install';; esac ;;
    mesa-prereqs) phase='4/5 mesa'; case "$3" in ocl-icd) set -- "$1" "$2" '1/6 ocl-icd';; zlib) set -- "$1" "$2" '2/6 zlib';; elfutils) set -- "$1" "$2" '3/6 elfutils';; SPIRV-Tools) set -- "$1" "$2" '4/6 SPIRV-Tools';; LLVMSPIRVLib) set -- "$1" "$2" '5/6 LLVMSPIRVLib';; esac ;;
    mesa) phase='4/5 mesa'; case "$3" in configure) set -- "$1" "$2" '6/6 configure';; install) set -- "$1" "$2" '6/6 install';; esac ;;
    amdgpu_top) phase='5/5 amdgpu_top'; case "$3" in cargo) set -- "$1" "$2" '1/2 cargo';; package) set -- "$1" "$2" '2/2 package';; esac ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$phase" "$2" "${3:-}" "$(date +%s)" > "$STATUS_FILE"
}

# Populate sources/ with the exact archives in build/versions.env, unpacked as
# libdrm/, libva/, mesa/, and amdgpu_top/. Release builds require locked hashes.
if [[ ${RELEASE:-0} == 1 ]] && grep -q ' TODO$' "$ROOT/build/sources.lock"; then
  echo "sources.lock is incomplete; refusing a release build" >&2
  exit 1
fi
for required in libdrm libva zlib elfutils mesa ocl-icd amdgpu_top SPIRV-Tools spirv-llvm-translator; do
  [[ -d $SOURCE_ROOT/$required ]] || { echo "missing source: $SOURCE_ROOT/$required" >&2; exit 1; }
done
"$ROOT/scripts/apply-rusticl-patches.sh" "$SOURCE_ROOT/mesa"

export PATH="$(dirname "$(command -v cargo)"):$TOOLCHAIN:$PATH"
export PKG_CONFIG_PATH="$STAGE$PREFIX/lib/pkgconfig"
# Do not let the Debian builder's host-only .pc files leak into a DSM target
# build (notably spirv-tools, whose headers are not in the target sysroot).
export PKG_CONFIG_LIBDIR="$STAGE$PREFIX/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$STAGE"
export LLVM_TARGET_ROOT="$ROOT/work/llvm-${PLATFORM}"
export LLVM_SOURCE_ROOT="$SOURCE_ROOT/llvm-project/llvm"
LLVM_ABI_VERSION=${LLVM_ABI_VERSION:-18.1}

# Clover's OpenCL compiler consumes libclc bitcode at build time and the
# resulting runtime loads the same files by its pkg-config libexec path.
mkdir -p "$STAGE$PREFIX/lib/clc" "$STAGE$PREFIX/lib/pkgconfig"
LIBCLC_DIR=${LIBCLC_DIR:-/usr/lib/clc}
if [[ ! -d "$LIBCLC_DIR" ]]; then
  LIBCLC_DIR=$(find /usr/lib -type d -path '*/clc' -print -quit || true)
fi
[[ -n "$LIBCLC_DIR" && -d "$LIBCLC_DIR" ]] || { echo 'libclc runtime files are required' >&2; exit 2; }
cp -a "$LIBCLC_DIR/." "$STAGE$PREFIX/lib/clc/"
cat > "$STAGE$PREFIX/lib/pkgconfig/libclc.pc" <<EOF
includedir=$PREFIX/include
libexecdir=$PREFIX/lib/clc

Name: libclc
Description: OpenCL C language implementation
Version: 14.0.6
Cflags: -I\${includedir}
Libs: -L\${libexecdir}
EOF

progress libdrm running configure
meson setup --wipe "$BUILD_ROOT/libdrm" "$SOURCE_ROOT/libdrm" --cross-file "$CROSS_FILE" --prefix="$PREFIX" \
  -Damdgpu=enabled -Dintel=disabled -Dradeon=enabled -Dnouveau=disabled -Dvmwgfx=disabled
ninja -C "$BUILD_ROOT/libdrm" -j"$COMPILE_JOBS"
progress libdrm running build
DESTDIR="$STAGE" ninja -C "$BUILD_ROOT/libdrm" install
progress libdrm running install

progress libva running configure
meson setup --wipe "$BUILD_ROOT/libva" "$SOURCE_ROOT/libva" --cross-file "$CROSS_FILE" --prefix="$PREFIX" \
  -Ddisable_drm=false -Dwith_glx=no -Dwith_wayland=no -Dwith_x11=no
ninja -C "$BUILD_ROOT/libva" -j"$COMPILE_JOBS"
progress libva running build
DESTDIR="$STAGE" ninja -C "$BUILD_ROOT/libva" install
progress libva running install

# ocl-icd is the generic OpenCL dispatch loader.  Mesa's Clover build
# provides an ICD, but FFmpeg's tonemap_opencl needs this loader to discover
# the packaged mesa.icd file through OCL_ICD_VENDORS.
progress mesa-prereqs running ocl-icd
OCL_ICD_BUILD="$BUILD_ROOT/ocl-icd"
OCL_ICD_SOURCE="$BUILD_ROOT/sources/ocl-icd"
rm -rf "$OCL_ICD_BUILD" "$OCL_ICD_SOURCE"
mkdir -p "$OCL_ICD_BUILD" "$(dirname "$OCL_ICD_SOURCE")"
cp -a "$SOURCE_ROOT/ocl-icd" "$OCL_ICD_SOURCE"
pushd "$OCL_ICD_SOURCE" >/dev/null
./bootstrap
popd >/dev/null
pushd "$OCL_ICD_BUILD" >/dev/null
CC=$TOOLCHAIN/x86_64-pc-linux-gnu-gcc \
  "$OCL_ICD_SOURCE/configure" --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu \
    --prefix="$PREFIX"
make -j"$COMPILE_JOBS"
DESTDIR="$STAGE" make install
popd >/dev/null

ZLIB_BUILD="$BUILD_ROOT/zlib"
progress mesa-prereqs running zlib
rm -rf "$ZLIB_BUILD"
mkdir -p "$ZLIB_BUILD"
pushd "$ZLIB_BUILD" >/dev/null
CHOST=x86_64-pc-linux-gnu CC=$TOOLCHAIN/x86_64-pc-linux-gnu-gcc \
  "$SOURCE_ROOT/zlib/configure" --prefix="$PREFIX" --shared
make -j"$COMPILE_JOBS"
DESTDIR="$STAGE" make install
popd >/dev/null

# radeonsi requires libelf.  Build only elfutils' libelf component so the
# runtime stays focused on GPU userspace rather than the full elfutils suite.
ELF_BUILD="$BUILD_ROOT/elfutils"
progress mesa-prereqs running elfutils
rm -rf "$ELF_BUILD"
mkdir -p "$ELF_BUILD"
pushd "$ELF_BUILD" >/dev/null
CC=$TOOLCHAIN/x86_64-pc-linux-gnu-gcc \
  CXX=$TOOLCHAIN/x86_64-pc-linux-gnu-g++ \
  CPPFLAGS="-I$STAGE$PREFIX/include" LDFLAGS="-L$STAGE$PREFIX/lib" \
  "$SOURCE_ROOT/elfutils/configure" --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu \
    --prefix="$PREFIX" --disable-debuginfod --disable-libdebuginfod --disable-demangler
# libelf links elfutils' internal libeu archive, which must be built first.
make -C lib -j"$COMPILE_JOBS"
make -C libelf -j"$COMPILE_JOBS"
DESTDIR="$STAGE" make -C libelf install
# `make -C libelf install` does not install the generated pkg-config metadata;
# Mesa discovers libelf through this file during its cross configuration.
install -Dm644 "$ELF_BUILD/config/libelf.pc" "$STAGE$PREFIX/lib/pkgconfig/libelf.pc"
popd >/dev/null

SPIRV_TOOLS_BUILD="$BUILD_ROOT/spirv-tools"
progress mesa-prereqs running SPIRV-Tools
cmake -S "$SOURCE_ROOT/SPIRV-Tools" -B "$SPIRV_TOOLS_BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_C_COMPILER="$TOOLCHAIN/x86_64-pc-linux-gnu-gcc" \
  -DCMAKE_CXX_COMPILER="$TOOLCHAIN/x86_64-pc-linux-gnu-g++" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DSPIRV_WERROR=OFF \
  -DSPIRV_TOOLS_BUILD_STATIC=ON
ninja -C "$SPIRV_TOOLS_BUILD" -j"$COMPILE_JOBS"
DESTDIR="$STAGE" ninja -C "$SPIRV_TOOLS_BUILD" install

SPIRV_LLVM_BUILD="$BUILD_ROOT/spirv-llvm"
progress mesa-prereqs running LLVMSPIRVLib
cmake -S "$SOURCE_ROOT/spirv-llvm-translator" -B "$SPIRV_LLVM_BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_C_COMPILER="$TOOLCHAIN/x86_64-pc-linux-gnu-gcc" \
  -DCMAKE_CXX_COMPILER="$TOOLCHAIN/x86_64-pc-linux-gnu-g++" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" -DLLVM_DIR="$LLVM_TARGET_ROOT/lib/cmake/llvm" \
  -DLLVM_SPIRV_INCLUDE_TESTS=OFF
ninja -C "$SPIRV_LLVM_BUILD" -j"$COMPILE_JOBS"
DESTDIR="$STAGE" ninja -C "$SPIRV_LLVM_BUILD" install

progress mesa running configure
meson setup --wipe "$BUILD_ROOT/mesa" "$SOURCE_ROOT/mesa" --cross-file "$CROSS_FILE" --prefix="$PREFIX" \
  --buildtype=release -Ddebug=false \
  -Dgallium-drivers=radeonsi -Dvulkan-drivers=amd -Dgallium-va=enabled -Dgallium-vdpau=disabled \
  -Dgallium-opencl=icd -Dgallium-rusticl=true -Dstatic-libclc=all -Dplatforms=[] -Dglx=disabled \
  -Dcpp_rtti=true -Dllvm=enabled -Dshared-llvm=enabled -Dvideo-codecs=all
ninja -C "$BUILD_ROOT/mesa" -j"$COMPILE_JOBS"
DESTDIR="$STAGE" ninja -C "$BUILD_ROOT/mesa" install
progress mesa running install

# Mesa and its drivers link to the target ABI's shared LLVM.  Ship it inside
# the package rather than relying on an absent DSM system LLVM installation.
install -Dm755 "$LLVM_TARGET_ROOT/lib/libLLVM.so.${LLVM_ABI_VERSION}" "$STAGE$PREFIX/lib/libLLVM.so.${LLVM_ABI_VERSION}"
ln -sfn "libLLVM.so.${LLVM_ABI_VERSION}" "$STAGE$PREFIX/lib/libLLVM.so"
# Mesa's Clover OpenCL ICD links against Clang's monolithic C++ library.
install -Dm755 "$LLVM_TARGET_ROOT/lib/libclang-cpp.so.${LLVM_ABI_VERSION}" "$STAGE$PREFIX/lib/libclang-cpp.so.${LLVM_ABI_VERSION}"
ln -sfn "libclang-cpp.so.${LLVM_ABI_VERSION}" "$STAGE$PREFIX/lib/libclang-cpp.so"
test -f "$STAGE$PREFIX/lib/libRusticlOpenCL.so.1.0.0" || { echo "Rusticl OpenCL library was not installed" >&2; exit 1; }
ln -sfn "libRusticlOpenCL.so.1.0.0" "$STAGE$PREFIX/lib/libRusticlOpenCL.so"
ln -sfn "libRusticlOpenCL.so.1.0.0" "$STAGE$PREFIX/lib/libRusticlOpenCL.so.1"
mkdir -p "$STAGE$PREFIX/etc/OpenCL/rusticl-vendors"
printf '%s\n' 'libRusticlOpenCL.so.1' > "$STAGE$PREFIX/etc/OpenCL/rusticl-vendors/rusticl.icd"
if [[ -d "$LLVM_TARGET_ROOT/lib/clang/18/include" ]]; then
  mkdir -p "$STAGE$PREFIX/lib/clang/18"
  cp -a "$LLVM_TARGET_ROOT/lib/clang/18/include" "$STAGE$PREFIX/lib/clang/18/"
fi

# This upstream feature opens the staged libdrm at runtime, avoiding a DSM
# global-library change and allowing the SPK to carry its own ABI-matched copy.
export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=$TOOLCHAIN/x86_64-pc-linux-gnu-gcc
export RUSTFLAGS="-C link-arg=-Wl,-rpath,\$ORIGIN/../lib"
progress amdgpu_top running cargo
pushd "$SOURCE_ROOT/amdgpu_top" >/dev/null
CARGO_BUILD_JOBS="$COMPILE_JOBS" CARGO_TARGET_DIR="$BUILD_ROOT/cargo-target" cargo build --release --target x86_64-unknown-linux-gnu --no-default-features --features dynamic_loading_package
install -Dm755 "$BUILD_ROOT/cargo-target/x86_64-unknown-linux-gnu/release/amdgpu_top" "$STAGE$PREFIX/bin/amdgpu_top"
progress amdgpu_top running package
popd >/dev/null

# DSM applies root ownership and setuid only to the explicitly declared
# privilege tool.  Refresh these integration files immediately before
# packaging so package-only updates remain reproducible.
mkdir -p "$STAGE$PREFIX/etc/vulkan/icd.d"
cp "$ROOT/spk/package/etc/vulkan/icd.d/radeon_icd.x86_64.json" "$STAGE$PREFIX/etc/vulkan/icd.d/"
"$ROOT/scripts/refresh-spk-stage.sh" "$STAGE" "$PLATFORM" "$DSM_VERSION"
progress complete success
