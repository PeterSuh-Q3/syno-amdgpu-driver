#!/usr/bin/env bash
# Download and unpack the exact upstream sources used by the runtime build.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCHIVE_DIR=${ARCHIVE_DIR:-"$ROOT/archives"}
SOURCE_DIR=${SOURCE_DIR:-"$ROOT/sources"}

# shellcheck source=../build/versions.env
source "$ROOT/build/versions.env"

fetch() {
  local name=$1 url=$2 archive=$3 destination=$4
  mkdir -p "$ARCHIVE_DIR" "$SOURCE_DIR/$destination"
  if [[ ! -f "$ARCHIVE_DIR/$archive" ]]; then
    curl --fail --location --retry 3 --retry-delay 2 --output "$ARCHIVE_DIR/$archive" "$url"
  fi
  local expected
  expected=$(awk -v archive="$archive" '$1 == archive { print $2 }' "$ROOT/build/sources.lock")
  if [[ -n "$expected" && "$expected" != TODO ]]; then
    echo "$expected  $ARCHIVE_DIR/$archive" | sha256sum -c -
  fi
  if [[ -z $(find "$SOURCE_DIR/$destination" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
    tar -xf "$ARCHIVE_DIR/$archive" -C "$SOURCE_DIR/$destination" --strip-components=1
  fi
  printf 'Prepared %s\n' "$name"
}

fetch libdrm "$LIBDRM_URL" "libdrm-${LIBDRM_VERSION}.tar.xz" libdrm
fetch libva "$LIBVA_URL" "libva-${LIBVA_VERSION}.tar.bz2" libva
fetch mesa "$MESA_URL" "mesa-${MESA_VERSION}.tar.xz" mesa
fetch amdgpu_top "$AMDGPU_TOP_URL" "amdgpu_top-${AMDGPU_TOP_VERSION}.tar.gz" amdgpu_top
fetch llvm "$LLVM_URL" "llvm-project-${LLVM_VERSION}.src.tar.xz" llvm-project
fetch elfutils "$ELFUTILS_URL" "elfutils-${ELFUTILS_VERSION}.tar.bz2" elfutils
fetch zlib "$ZLIB_URL" "zlib-${ZLIB_VERSION}.tar.gz" zlib
fetch ocl-icd "$OCL_ICD_URL" "ocl-icd-${OCL_ICD_VERSION}.tar.gz" ocl-icd
fetch SPIRV-Tools "$SPIRV_TOOLS_URL" "SPIRV-Tools-${SPIRV_TOOLS_VERSION}.tar.gz" SPIRV-Tools
fetch spirv-llvm-translator "$SPIRV_LLVM_TRANSLATOR_URL" "SPIRV-LLVM-Translator-${SPIRV_LLVM_TRANSLATOR_VERSION}.tar.gz" spirv-llvm-translator
