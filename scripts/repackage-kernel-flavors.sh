#!/usr/bin/env bash
# Produce both DSM kernel-policy packages from one already-built userspace SPK.
# No Mesa/LLVM recompilation is performed.
set -euo pipefail

INPUT=${1:?existing x86_64 SPK required}
PLATFORM=${2:-kvmx64}
DSM_VERSION=${3:-7.4}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

"$ROOT/scripts/repackage-existing-spk.sh" "$INPUT" "$PLATFORM" "$DSM_VERSION" kernel5.10.55
"$ROOT/scripts/repackage-existing-spk.sh" "$INPUT" "$PLATFORM" "$DSM_VERSION" kernel4.4.x
