#!/usr/bin/env bash
# A host-executable llvm-config facade for Mesa cross builds.  The actual
# llvm-config produced for DSM cannot run on the Debian build host.
set -euo pipefail

: "${LLVM_TARGET_ROOT:?LLVM_TARGET_ROOT must name the target LLVM build}"
LLVM_VERSION=${LLVM_VERSION:-18.1.8}
SOURCE_ROOT=${LLVM_SOURCE_ROOT:-/work/sources/llvm-project/llvm}
INCLUDEDIR="$SOURCE_ROOT/include"
GENERATED_INCLUDEDIR="$LLVM_TARGET_ROOT/include"
LIBDIR="$LLVM_TARGET_ROOT/lib"

for arg in "$@"; do
  case "$arg" in
    --version) printf '%s\n' "$LLVM_VERSION" ;;
    --prefix) printf '%s\n' "$LLVM_TARGET_ROOT" ;;
    --includedir) printf '%s\n' "$INCLUDEDIR" ;;
    --libdir) printf '%s\n' "$LIBDIR" ;;
    --cppflags|--cxxflags) printf '%s\n' "-I$INCLUDEDIR -I$GENERATED_INCLUDEDIR" ;;
    --ldflags) printf '%s\n' "-L$LIBDIR" ;;
    --libfiles) printf '%s\n' "$LIBDIR/libLLVM.so.$LLVM_VERSION" ;;
    --libs|--libs=*) printf '%s\n' '-lLLVM' ;;
    --system-libs) printf '%s\n' '-lz -lm -ldl -lpthread' ;;
    --shared-mode) printf '%s\n' 'shared' ;;
    --has-rtti) printf '%s\n' 'NO' ;;
    # Meson checks requested component names against this list before using
    # --libfiles.  They are all provided by the monolithic shared libLLVM.
    --components) printf '%s\n' 'amdgpu bitreader bitwriter core coverage engine executionengine instcombine instrumentation ipo irreader linker lto mcdisassembler mcjit native objcarcopts option profiledata scalaropts transformutils coroutines frontendopenmp windowsdriver' ;;
    --link-shared|--ignore-libllvm) ;;
    *) ;;
  esac
done
