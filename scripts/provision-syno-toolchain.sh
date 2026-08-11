#!/usr/bin/env bash
# Download one DSM platform toolkit through Synology's pkgscripts-ng EnvDeploy
# mechanism.  This is intended for Linux CI hosts and avoids a multi-platform
# compiler image.
set -euo pipefail

PLATFORM=${1:?platform required}
DSM_VERSION=${2:-7.4}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PKGSCRIPTS_DIR=${PKGSCRIPTS_DIR:-"$ROOT/work/pkgscripts-ng-${DSM_VERSION}"}
ENV_ROOT="$ROOT/build_env/ds.${PLATFORM}-${DSM_VERSION}"
DEST="$ROOT/work/toolchains/${PLATFORM}"

command -v sudo >/dev/null || { echo 'sudo is required to run EnvDeploy' >&2; exit 2; }
if [[ ! -d "$PKGSCRIPTS_DIR/.git" ]]; then
  git clone --depth 1 --branch "DSM${DSM_VERSION}" https://github.com/SynologyOpenSource/pkgscripts-ng.git "$PKGSCRIPTS_DIR"
fi

pushd "$PKGSCRIPTS_DIR" >/dev/null
sudo ./EnvDeploy -q -v "$DSM_VERSION" -p "$PLATFORM"
popd >/dev/null

if [[ ! -d "$ENV_ROOT" ]]; then
  ENV_ROOT=$(find "$ROOT" -type d -path "*/build_env/ds.${PLATFORM}-${DSM_VERSION}" -print -quit)
fi
SOURCE_TOOLCHAIN="$ENV_ROOT/usr/local/x86_64-pc-linux-gnu"
[[ -x "$SOURCE_TOOLCHAIN/bin/x86_64-pc-linux-gnu-gcc" ]] || {
  echo "EnvDeploy did not provide an x86_64 toolchain for $PLATFORM" >&2
  exit 2
}
rm -rf "$DEST"
mkdir -p "$DEST"
sudo cp -a "$SOURCE_TOOLCHAIN/." "$DEST/"
sudo chown -R "$(id -u):$(id -g)" "$DEST"
printf '%s\n' "$DEST/bin"
