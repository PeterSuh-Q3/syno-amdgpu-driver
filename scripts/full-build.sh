#!/usr/bin/env bash
# Parallel, resume-capable DSM runtime builder.  Platform list format:
# PLATFORM<TAB>DSM_VERSION (build/ALL-PLATFORMS).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PLATFORMS_FILE=${PLATFORMS_FILE:-"$ROOT/build/ALL-PLATFORMS"}
BUILD_JOBS=${BUILD_JOBS:-2}
STATE_DIR="$ROOT/work/status"
LOG_DIR="$ROOT/logs"
mkdir -p "$STATE_DIR" "$LOG_DIR"
[[ -f $PLATFORMS_FILE ]] || { echo "Missing platform list: $PLATFORMS_FILE" >&2; exit 2; }
(( BUILD_JOBS >= 1 && BUILD_JOBS <= 2 )) || { echo 'BUILD_JOBS must be 1 or 2' >&2; exit 2; }
COMPILE_JOBS=${COMPILE_JOBS:-$(( $(nproc) / BUILD_JOBS ))}
(( COMPILE_JOBS >= 1 )) || { echo 'COMPILE_JOBS must be at least 1' >&2; exit 2; }
export COMPILE_JOBS

declare -a KEYS=() PIDS=()

# Keep platform builders in their own process groups.  This prevents an
# interrupted dashboard (Ctrl-C/OOM) from leaving orphaned Ninja jobs that
# would be counted outside BUILD_JOBS on the next invocation.
cleanup() {
  local pid
  for pid in "${PIDS[@]:-}"; do
    kill -TERM -- "-$pid" 2>/dev/null || true
  done
}
trap cleanup INT TERM EXIT
# Shell's default IFS deliberately accepts either tabs or spaces.  This keeps
# ALL-PLATFORMS compatible with hand-edited lists and mshell-style files.
while read -r platform dsm _; do
  [[ -z ${platform:-} || $platform == \#* ]] && continue
  [[ -n ${dsm:-} ]] || { echo "Invalid platform entry (missing DSM version): $platform" >&2; exit 2; }
  KEYS+=("${platform}-${dsm}")
done < "$PLATFORMS_FILE"
[[ ${#KEYS[@]} -gt 0 ]] || { echo 'No platforms selected' >&2; exit 2; }

# A previous interrupted run may have left terminal status files behind.
# Rebuild invocation owns the dashboard, so start every listed platform as
# queued and avoid displaying stale progress from an older run.
for key in "${KEYS[@]}"; do
  rm -f "$STATE_DIR/$key.status"
done

for dsm in $(printf '%s\n' "${KEYS[@]}" | awk -F- '{print $NF}' | sort -u); do
  "$ROOT/scripts/build-builder.sh" "$dsm"
done

render() {
  printf '\033[2J\033[H'
  printf 'Synology AMDGPU multi-build  %s  (max %s concurrent, -j%s each)\n\n' "$(date '+%F %T')" "$BUILD_JOBS" "$COMPILE_JOBS"
  printf '%-22s %-16s %-18s %-10s %s\n' PLATFORM PHASE DETAIL STATE PROGRESS
  for key in "${KEYS[@]}"; do
    local phase=queued state=waiting detail='-' count='-'
    if [[ -f "$STATE_DIR/$key.status" ]]; then IFS=$'\t' read -r phase state detail _ < "$STATE_DIR/$key.status" || true; fi
    local log="$LOG_DIR/$key.log"
    [[ -f "$STATE_DIR/$key.status" && -f $log ]] && count=$(grep -Eo '\[[0-9]+/[0-9]+\]' "$log" | tail -1 || true)
    printf '%-22s %-16s %-18s %-10s %s\n' "$key" "$phase" "$detail" "$state" "${count:--}"
  done
}

launch() {
  local key=$1 platform=${1%-*} dsm=${1##*-}
  : > "$LOG_DIR/$key.log"
  STATUS_FILE="$STATE_DIR/$key.status" LOG_FILE="$LOG_DIR/$key.log" \
    setsid "$ROOT/scripts/build-platform.sh" "$platform" "$dsm" &
  PIDS+=("$!")
}

next=0
while (( next < ${#KEYS[@]} || ${#PIDS[@]} > 0 )); do
  while (( next < ${#KEYS[@]} && ${#PIDS[@]} < BUILD_JOBS )); do launch "${KEYS[$next]}"; ((next+=1)); done
  render
  sleep 2
  alive=()
  for pid in "${PIDS[@]}"; do kill -0 "$pid" 2>/dev/null && alive+=("$pid") || wait "$pid" || true; done
  PIDS=("${alive[@]}")
done
render
printf '\nLogs: %s\nStatus: %s\n' "$LOG_DIR" "$STATE_DIR"
