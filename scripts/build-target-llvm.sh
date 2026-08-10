#!/usr/bin/env bash
# Build the DSM-ABI LLVM/Clang libraries used by radeonsi and Clover.
set -euo pipefail

ROOT=/work
PLATFORM=${PLATFORM:-epyc7002}
LLVM_VERSION=${LLVM_VERSION:-18.1.8}
LLVM_ABI_VERSION=${LLVM_ABI_VERSION:-18.1}
SOURCE="$ROOT/sources/llvm-project/llvm"
BUILD="$ROOT/work/llvm-${PLATFORM}"
TOOLCHAIN=/opt/${PLATFORM}/bin
COMPILE_JOBS=${COMPILE_JOBS:-$(nproc)}

[[ -x "$TOOLCHAIN/x86_64-pc-linux-gnu-gcc" ]] || { echo "Synology toolchain missing for $PLATFORM" >&2; exit 2; }
[[ -d $SOURCE && -d "$ROOT/sources/llvm-project/clang" ]] || {
  echo "llvm-project source (including clang) is required" >&2; exit 1;
}

# Clover links the target Clang component libraries (clangBasic, clangAST,
# clangCodeGen, ...).  LLVM alone is sufficient for radeonsi but not OpenCL.
cmake -S "$SOURCE" -B "$BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_C_COMPILER="$TOOLCHAIN/x86_64-pc-linux-gnu-gcc" \
  -DCMAKE_CXX_COMPILER="$TOOLCHAIN/x86_64-pc-linux-gnu-g++" \
  -DLLVM_TARGETS_TO_BUILD=AMDGPU \
  -DLLVM_ENABLE_PROJECTS=clang \
  -DLLVM_BUILD_LLVM_DYLIB=ON -DLLVM_LINK_LLVM_DYLIB=ON \
  -DLLVM_ENABLE_RTTI=ON -DLLVM_BUILD_TOOLS=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_LIBXML2=ON \
  -DLLVM_ENABLE_ZLIB=ON -DLLVM_ENABLE_ZSTD=ON
ninja -C "$BUILD" -j"$COMPILE_JOBS"

test -f "$BUILD/lib/libLLVM.so.${LLVM_ABI_VERSION}" || {
  echo "target libLLVM was not produced" >&2; exit 1;
}
test -f "$BUILD/lib/libclangBasic.a" || {
  echo "target Clang libraries were not produced" >&2; exit 1;
}
