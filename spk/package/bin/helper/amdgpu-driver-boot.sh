#!/bin/sh
# DSM kernel-4 boot hook: load AMDGPU with the required Renoir opt-in.
set -eu

case "${1:-start}" in
  start|"") ;;
  stop) exit 0 ;;
  *) exit 1 ;;
esac

case "$(uname -r)" in
  4.4.302*) ;;
  *) exit 0 ;;
esac

if [ -d /sys/module/amdgpu ]; then
  exp_hw_support=$(cat /sys/module/amdgpu/parameters/exp_hw_support 2>/dev/null || true)
  if [ "$exp_hw_support" != 1 ]; then
    # DSM may have auto-loaded the module through PCI modalias before this
    # hook. Reinsert it only if the normal, non-forced unload is safe.
    /sbin/modprobe -r amdgpu || {
      logger -t syno-amdgpu-runtime 'Cannot replace incorrectly loaded AMDGPU module; it is still in use.' 2>/dev/null || true
      exit 1
    }
  else
    /sbin/modprobe i915 || exit 1
    exit 0
  fi
fi

/sbin/modprobe amdgpu exp_hw_support=1 || {
  logger -t syno-amdgpu-runtime 'Failed to load AMDGPU with exp_hw_support=1.' 2>/dev/null || true
  exit 1
}
/sbin/modprobe i915 || {
  logger -t syno-amdgpu-runtime 'Failed to load i915.' 2>/dev/null || true
  exit 1
}

