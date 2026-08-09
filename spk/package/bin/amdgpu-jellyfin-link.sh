#!/bin/sh
# Root-owned DSM privilege tool.  It only changes Jellyfin's fixed FFmpeg
# launch argument and preserves the original service script for uninstall.
set -eu

JELLYFIN_SETUP=/var/packages/jellyfin/scripts/service-setup
BACKUP=${JELLYFIN_SETUP}.pre-amdgpu-runtime.bak
STOCK=/var/packages/ffmpeg7/target/bin/ffmpeg
AMD=/var/packages/syno-amdgpu-runtime/target/bin/amdgpu-ffmpeg
AUTOCONFIG=/var/packages/syno-amdgpu-runtime/target/bin/amdgpu-jellyfin-autoconfig.sh

case "${1:-}" in
  patch)
    [ -f "$JELLYFIN_SETUP" ] || exit 0
    if grep -Fq -- "--ffmpeg $AMD" "$JELLYFIN_SETUP"; then
      exit 0
    fi
    grep -Fq -- "--ffmpeg $STOCK" "$JELLYFIN_SETUP" || exit 0
    [ -e "$BACKUP" ] || cp -p "$JELLYFIN_SETUP" "$BACKUP"
    sed -i "s#--ffmpeg $STOCK#--ffmpeg $AMD#g" "$JELLYFIN_SETUP"
    chown root:root "$JELLYFIN_SETUP" "$BACKUP"
    chmod 0755 "$JELLYFIN_SETUP" "$BACKUP"
    ;;
  restore)
    [ -f "$JELLYFIN_SETUP" ] || exit 0
    if grep -Fq -- "--ffmpeg $AMD" "$JELLYFIN_SETUP"; then
      if [ -f "$BACKUP" ]; then
        mv -f "$BACKUP" "$JELLYFIN_SETUP"
      else
        sed -i "s#--ffmpeg $AMD#--ffmpeg $STOCK#g" "$JELLYFIN_SETUP"
      fi
      chown root:root "$JELLYFIN_SETUP"
      chmod 0755 "$JELLYFIN_SETUP"
    fi
    ;;
  configure)
    [ -x "$AUTOCONFIG" ] && "$AUTOCONFIG"
    ;;
  *)
    echo "usage: amdgpu-jellyfin-link.sh {patch|restore|configure}" >&2
    exit 2
    ;;
esac
