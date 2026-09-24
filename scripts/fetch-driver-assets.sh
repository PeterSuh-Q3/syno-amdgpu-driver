#!/usr/bin/env bash
set -euo pipefail

PLATFORM=${1:?usage: fetch-driver-assets.sh <DSM-7.4-platform>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOCK=$ROOT/build/driver-assets.lock
DEST=$ROOT/sources/driver-assets/26.9.12
TMP="$DEST/.download.$$"

mkdir -p "$DEST"
trap 'rm -rf "$TMP"' EXIT
mkdir -m 700 "$TMP"

hash_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

fetch_checked() {
  local name=$1 expected=$2 url=$3 output="$TMP/$1"
  if [[ -f "$DEST/$name" ]] && [[ $(hash_file "$DEST/$name") == "$expected" ]]; then
    printf 'verified existing %s\n' "$name"
    return
  fi
  if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
    --retry 2 --retry-all-errors --retry-delay 1 "$url" -o "$output" 2>"$TMP/curl.err"; then
    case "$url" in
      https://github.com/*/releases/download/*)
        command -v jq >/dev/null || { cat "$TMP/curl.err" >&2; echo 'jq is required for the GitHub release API fallback.' >&2; return 1; }
        repo=$(sed -E 's#https://github.com/([^/]+/[^/]+)/releases/download/.*#\1#' <<< "$url")
        tag=$(sed -E 's#https://github.com/[^/]+/[^/]+/releases/download/([^/]+)/.*#\1#' <<< "$url")
        api="https://api.github.com/repos/$repo/releases/tags/$tag"
        asset_id=$(curl --fail --location --silent --show-error "$api" | jq -r --arg n "$name" '.assets[] | select(.name == $n) | .id' | head -n 1)
        [[ "$asset_id" =~ ^[0-9]+$ ]] || { cat "$TMP/curl.err" >&2; echo "GitHub release asset not found: $name" >&2; return 1; }
        curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
          --retry 3 --retry-all-errors --retry-delay 1 \
          -H 'Accept: application/octet-stream' \
          "https://api.github.com/repos/$repo/releases/assets/$asset_id" -o "$output"
        ;;
      *) cat "$TMP/curl.err" >&2; return 1 ;;
    esac
  fi
  [[ $(hash_file "$output") == "$expected" ]] || {
    echo "SHA-256 mismatch: $name" >&2
    return 1
  }
  tar -tzf "$output" > "$TMP/$name.list"
  awk 'BEGIN { bad=0 } /^\// || /(^|\/)\.\.(\/|$)/ { bad=1 } END { exit bad }' "$TMP/$name.list" || {
    echo "Unsafe archive path in $name" >&2
    return 1
  }
  mv "$output" "$DEST/$name"
  rm -f "$TMP/$name.list"
  printf 'downloaded and verified %s\n' "$name"
}

row=$(awk -v p="$PLATFORM" '$1 == p && $1 !~ /^#/ { print; found=1 } END { if (!found) exit 1 }' "$LOCK") || {
  echo "Unsupported DSM 7.4 platform: $PLATFORM" >&2
  exit 2
}
read -r _ kernel archive digest url <<< "$row"
fetch_checked "$archive" "$digest" "$url"

for name in firmwareamdgpu.tgz firmwarei915.tgz; do
  row=$(awk -v n="$name" '$1 == n && $1 !~ /^#/ { print; found=1 } END { if (!found) exit 1 }' "$LOCK")
  read -r _ digest url <<< "$row"
  fetch_checked "$name" "$digest" "$url"
done

module_list=$(tar -tzf "$DEST/$archive")
case "$kernel" in
  5.10.55) required_modules=(amdgpu.ko drm.ko i915.ko i915-compat.ko) ;;
  4.4.302) required_modules=(amdgpu.ko i915.ko) ;;
  *) echo "Unsupported kernel asset in lock: $kernel" >&2; exit 2 ;;
esac
for required in "${required_modules[@]}"; do
  grep -Fxq "$required" <<< "$module_list" || {
    echo "Expected complete DRM module bundle is missing $required" >&2
    exit 1
  }
done
printf 'Ready: DSM 7.4 %s kernel %s assets at %s\n' "$PLATFORM" "$kernel" "$DEST"
