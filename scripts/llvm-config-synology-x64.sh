#!/usr/bin/env bash
# Host-executable llvm-config facade for x86_64 Synology cross builds.  The
# target llvm-config cannot run on the Debian build host.
set -euo pipefail

: "${LLVM_TARGET_ROOT:?LLVM_TARGET_ROOT must name the target LLVM build}"
LLVM_VERSION=${LLVM_VERSION:-18.1.8}
LLVM_ABI_VERSION=${LLVM_ABI_VERSION:-18.1}
SOURCE_ROOT=${LLVM_SOURCE_ROOT:-/work/sources/llvm-project/llvm}
INCLUDEDIR="$SOURCE_ROOT/include"
GENERATED_INCLUDEDIR="$LLVM_TARGET_ROOT/include"
CLANG_INCLUDEDIR="$(dirname "$SOURCE_ROOT")/clang/include"
CLANG_GENERATED_INCLUDEDIR="$LLVM_TARGET_ROOT/tools/clang/include"
LIBDIR="$LLVM_TARGET_ROOT/lib"

for arg in "$@"; do
  case "$arg" in
    --version) printf '%s\n' "$LLVM_VERSION" ;;
    --prefix) printf '%s\n' "$LLVM_TARGET_ROOT" ;;
    --includedir) printf '%s\n' "$INCLUDEDIR" ;;
    --libdir) printf '%s\n' "$LIBDIR" ;;
    --cppflags|--cxxflags) printf '%s\n' "-I$INCLUDEDIR -I$GENERATED_INCLUDEDIR -I$CLANG_INCLUDEDIR -I$CLANG_GENERATED_INCLUDEDIR" ;;
    --ldflags) printf '%s\n' "-L$LIBDIR" ;;
    --libfiles) printf '%s\n' "$LIBDIR/libLLVM.so.$LLVM_ABI_VERSION" ;;
    --libs|--libs=*) printf '%s\n' '-lLLVM' ;;
    --system-libs) printf '%s\n' '-lz -lm -ldl -lpthread' ;;
    --shared-mode) printf '%s\n' shared ;;
    --has-rtti) printf '%s\n' YES ;;
    --components) printf '%s\n' 'amdgpu bitreader bitwriter core coverage engine executionengine instcombine instrumentation ipo irreader linker lto mcdisassembler mcjit native objcarcopts option profiledata scalaropts transformutils coroutines frontendopenmp frontenddriver frontendhlsl libdriver target windowsdriver' ;;
    --link-shared|--ignore-libllvm) ;;
  esac
done
