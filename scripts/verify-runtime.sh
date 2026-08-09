#!/bin/sh
set -eu

RUNTIME_ROOT=${RUNTIME_ROOT:-/var/packages/syno-amdgpu-runtime/target}
RENDER_NODE=${RENDER_NODE:-/dev/dri/renderD128}

test -c "$RENDER_NODE"
test -f "$RUNTIME_ROOT/lib/radeonsi_drv_video.so"
test -f "$RUNTIME_ROOT/lib/libvulkan_radeon.so"
test -f "$RUNTIME_ROOT/etc/vulkan/icd.d/radeon_icd.x86_64.json"

export LD_LIBRARY_PATH="$RUNTIME_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LD_PRELOAD="$RUNTIME_ROOT/lib/libdrm.so.2:$RUNTIME_ROOT/lib/libva.so.2:$RUNTIME_ROOT/lib/libva-drm.so.2${LD_PRELOAD:+:$LD_PRELOAD}"
export LIBVA_DRIVERS_PATH="$RUNTIME_ROOT/lib/dri"
export LIBVA_DRIVER_NAME=radeonsi
export VK_ICD_FILENAMES="$RUNTIME_ROOT/etc/vulkan/icd.d/radeon_icd.x86_64.json"

"$RUNTIME_ROOT/bin/vainfo" --display drm --device "$RENDER_NODE"
"$RUNTIME_ROOT/bin/vulkaninfo" --summary
