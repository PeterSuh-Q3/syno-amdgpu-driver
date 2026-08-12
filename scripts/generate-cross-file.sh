#!/usr/bin/env bash
set -euo pipefail

PLATFORM=${1:?platform required}
DSM_VERSION=${2:?DSM version required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/work/profiles/${PLATFORM}-${DSM_VERSION}.ini"
TOOLCHAIN=${TOOLCHAIN_BIN:-"/opt/${PLATFORM}/bin"}
# The generated file is consumed by either the Docker builder or a host build.
# Use PATH lookup by default: the Docker image supplies rustc even when the VM
# host intentionally has no Rust toolchain installed.
RUSTC_BIN=${RUSTC_BIN:-rustc}
LLVM_CONFIG_BIN=${LLVM_CONFIG_BIN:-"$ROOT/scripts/llvm-config-synology-x64.sh"}

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
[binaries]
c = '${TOOLCHAIN}/x86_64-pc-linux-gnu-gcc'
cpp = '${TOOLCHAIN}/x86_64-pc-linux-gnu-g++'
rust = ['${RUSTC_BIN}', '--target', 'x86_64-unknown-linux-gnu', '-C', 'linker=${TOOLCHAIN}/x86_64-pc-linux-gnu-gcc']
ar = '${TOOLCHAIN}/x86_64-pc-linux-gnu-ar'
strip = '${TOOLCHAIN}/x86_64-pc-linux-gnu-strip'
pkgconfig = 'pkg-config'
llvm-config = '${LLVM_CONFIG_BIN}'

[properties]
needs_exe_wrapper = false

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
printf '%s\n' "$OUT"
