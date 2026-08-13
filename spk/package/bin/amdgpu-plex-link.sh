#!/bin/sh
# Reversible, process-scoped AMD runtime integration for the official Plex
# Media Server SPK.  Do not alter the Plex server's own linker environment:
# only its child "Plex Transcoder" receives the Mesa/libva stack.
set -eu

RUNTIME=/var/packages/syno-amdgpu-runtime/target
PLEX=/var/packages/PlexMediaServer/target
TRANSCODER="$PLEX/Plex Transcoder"
BACKUP="${TRANSCODER}.pre-amdgpu-runtime.bak"
MARKER='# Synology AMDGPU Runtime Plex Transcoder wrapper'
RESTART_MARKER=/var/packages/syno-amdgpu-runtime/var/plex-restart-required

mark_restart() {
  mkdir -p "$(dirname "$RESTART_MARKER")"
  : > "$RESTART_MARKER"
}

case "${1:-}" in
  patch)
    # Plex is optional.  A missing or newly upgraded package is not an error.
    [ -x "$TRANSCODER" ] || exit 0
    if grep -Fq "$MARKER" "$TRANSCODER" 2>/dev/null; then
      exit 0
    fi
    # Never overwrite a previous backup: an unexpected Plex update must be
    # handled by reinstalling/upgrading this runtime, not by guessing.
    [ ! -e "$BACKUP" ] || exit 0
    mv "$TRANSCODER" "$BACKUP"
    cat > "$TRANSCODER" <<EOF
#!/bin/sh
$MARKER
exec "$RUNTIME/bin/amdgpu-env" "$BACKUP" "\$@"
EOF
    chown PlexMediaServer:PlexMediaServer "$TRANSCODER" "$BACKUP"
    chmod 0755 "$TRANSCODER" "$BACKUP"
    mark_restart
    ;;
  restore)
    [ -f "$TRANSCODER" ] || exit 0
    if grep -Fq "$MARKER" "$TRANSCODER" 2>/dev/null && [ -e "$BACKUP" ]; then
      rm -f "$TRANSCODER"
      mv "$BACKUP" "$TRANSCODER"
      chown PlexMediaServer:PlexMediaServer "$TRANSCODER"
      chmod 0755 "$TRANSCODER"
      mark_restart
    fi
    ;;
  restart)
    [ -e "$RESTART_MARKER" ] || exit 0
    [ -d /var/packages/PlexMediaServer ] || { rm -f "$RESTART_MARKER"; exit 0; }
    if /usr/syno/bin/synopkg restart PlexMediaServer; then
      rm -f "$RESTART_MARKER"
    else
      echo "Warning: Plex restart was not completed; restart it manually." >&2
    fi
    ;;
  *)
    echo "usage: amdgpu-plex-link.sh {patch|restore|restart}" >&2
    exit 2
    ;;
esac
