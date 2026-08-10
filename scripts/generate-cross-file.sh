#!/usr/bin/env bash
set -euo pipefail

PLATFORM=${1:?platform required}
DSM_VERSION=${2:?DSM version required}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/work/profiles/${PLATFORM}-${DSM_VERSION}.ini"
TOOLCHAIN="/opt/${PLATFORM}/bin"

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
[binaries]
c = '${TOOLCHAIN}/x86_64-pc-linux-gnu-gcc'
cpp = '${TOOLCHAIN}/x86_64-pc-linux-gnu-g++'
rust = ['/root/.cargo/bin/rustc', '--target', 'x86_64-unknown-linux-gnu', '-C', 'linker=${TOOLCHAIN}/x86_64-pc-linux-gnu-gcc']
ar = '${TOOLCHAIN}/x86_64-pc-linux-gnu-ar'
strip = '${TOOLCHAIN}/x86_64-pc-linux-gnu-strip'
pkgconfig = 'pkg-config'
llvm-config = '/work/scripts/llvm-config-synology-x64.sh'

[properties]
needs_exe_wrapper = false

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF
printf '%s\n' "$OUT"
