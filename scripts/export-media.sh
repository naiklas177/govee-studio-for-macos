#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p docs/media .local/media-frames
xcrun swift build --build-system native --scratch-path .build/stable -c release
BIN_DIR=$(xcrun swift build --build-system native --scratch-path .build/stable -c release --show-bin-path)
xcrun swiftc -O -D MEDIA_EXPORT -parse-as-library -I "$BIN_DIR/Modules" \
  Sources/GoveeStudio/*.swift "$BIN_DIR"/AmbienceCore.build/*.swift.o \
  scripts/ExportMedia.swift -o .local/export-media
.local/export-media
for name in prism-drift music-reactor; do
  ffmpeg -hide_banner -loglevel error -y -framerate 12 -i ".local/media-frames/$name-%03d.png" \
    -c:v libx264 -pix_fmt yuv420p -crf 22 -movflags +faststart -an "docs/media/$name.mp4"
  ffmpeg -hide_banner -loglevel error -y -i "docs/media/$name.mp4" \
    -filter_complex '[0:v]fps=12,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse' \
    -loop 0 "docs/media/$name.gif"
done
