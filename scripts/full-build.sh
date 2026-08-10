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

declare -a KEYS=() PIDS=()
while IFS=$'\t' read -r platform dsm _; do
  [[ -z ${platform:-} || $platform == \#* ]] && continue
  KEYS+=("${platform}-${dsm}")
done < "$PLATFORMS_FILE"
[[ ${#KEYS[@]} -gt 0 ]] || { echo 'No platforms selected' >&2; exit 2; }

for dsm in $(printf '%s\n' "${KEYS[@]}" | awk -F- '{print $NF}' | sort -u); do
  "$ROOT/scripts/build-builder.sh" "$dsm"
done

render() {
  printf '\033[2J\033[H'
  printf 'Synology AMDGPU multi-build  %s  (max %s concurrent)\n\n' "$(date '+%F %T')" "$BUILD_JOBS"
  printf '%-22s %-12s %-10s %s\n' PLATFORM PHASE STATE PROGRESS
  for key in "${KEYS[@]}"; do
    local phase=queued state=waiting count='-'
    if [[ -f "$STATE_DIR/$key.status" ]]; then IFS=$'\t' read -r phase state _ < "$STATE_DIR/$key.status" || true; fi
    local log="$LOG_DIR/$key.log"
    [[ -f $log ]] && count=$(grep -Eo '\[[0-9]+/[0-9]+\]' "$log" | tail -1 || true)
    printf '%-22s %-12s %-10s %s\n' "$key" "$phase" "$state" "${count:--}"
  done
}

launch() {
  local key=$1 platform=${1%-*} dsm=${1##*-}
  : > "$LOG_DIR/$key.log"
  STATUS_FILE="$STATE_DIR/$key.status" LOG_FILE="$LOG_DIR/$key.log" \
    "$ROOT/scripts/build-platform.sh" "$platform" "$dsm" &
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
