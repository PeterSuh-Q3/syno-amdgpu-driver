#!/bin/sh
# One-time, conservative VA-API defaults for the SynoCommunity Jellyfin SPK.
# Called only by the package's compiled setuid helper; never overwrite a
# hardware acceleration choice the administrator already made.
set -eu

ROOT=/var/packages/syno-amdgpu-runtime/target
CFG=/var/packages/jellyfin/var/config/encoding.xml
STAMP=/var/packages/jellyfin/var/config/.amdgpu-runtime-autoconf
FFMPEG=$ROOT/bin/amdgpu-ffmpeg

[ -f "$CFG" ] && [ -x "$FFMPEG" ] || exit 0
[ -e "$STAMP" ] && exit 0

CURRENT=$(sed -n 's#.*<HardwareAccelerationType>\([^<]*\)</HardwareAccelerationType>.*#\1#p' "$CFG" | head -1)
if [ -n "$CURRENT" ] && [ "$CURRENT" != none ]; then
  : > "$STAMP"
  exit 0
fi

OWNER=$(stat -c '%U:%G' "$CFG" 2>/dev/null || true)
jfset() {
  sed -i \
    -e "s#<$1 */>#<$1>$2</$1>#" \
    -e "s#<$1 [^>]*/>#<$1>$2</$1>#" \
    -e "s#<$1>[^<]*</$1>#<$1>$2</$1>#" "$CFG"
}

jfset HardwareAccelerationType vaapi
jfset VaapiDevice /dev/dri/renderD128
jfset EnableHardwareEncoding true
jfset AllowHevcEncoding true
jfset AllowAv1Encoding false
jfset EnableDecodingColorDepth10Hevc true
jfset EnableDecodingColorDepth10Vp9 false
jfset EncoderAppPathDisplay "$FFMPEG"

awk '
  function emit() {
    print "  <HardwareDecodingCodecs>"
    print "    <string>h264</string>"
    print "    <string>vc1</string>"
    print "    <string>mpeg2video</string>"
    print "    <string>mpeg4</string>"
    print "    <string>vp8</string>"
    print "    <string>hevc</string>"
    print "    <string>vp9</string>"
    print "  </HardwareDecodingCodecs>"
  }
  /<HardwareDecodingCodecs *\/>/ { emit(); next }
  /<HardwareDecodingCodecs>/ { emit(); skip = 1; next }
  skip && /<\/HardwareDecodingCodecs>/ { skip = 0; next }
  skip { next }
  { print }
' "$CFG" > "$CFG.amdgpu-tmp"
mv -f "$CFG.amdgpu-tmp" "$CFG"
chown "$OWNER" "$CFG" "$STAMP" 2>/dev/null || true
chmod 0644 "$CFG"
: > "$STAMP"
chown "$OWNER" "$STAMP" 2>/dev/null || true
