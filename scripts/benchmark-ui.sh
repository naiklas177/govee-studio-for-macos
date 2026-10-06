#!/bin/bash
# Build an offline benchmark; run the resulting executable with
# hybrid|audio|screen|idle [synthetic-screenshot.png]. No installed app changes.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mkdir -p .local
# Match the shipping app's build system and optimization level.
xcrun swift build --build-system native --scratch-path .build/ui-benchmark -c release -j 4
BIN_DIR=$(xcrun swift build --build-system native --scratch-path .build/ui-benchmark -c release --show-bin-path)
SOURCE_DIR=Sources/GoveeStudio
OUTPUT=.local/benchmark-ui
if [[ $# -gt 0 ]]; then
  BASELINE_DIR=$(mktemp -d "$PWD/.local/ui-baseline.XXXXXX")
  trap 'rm -rf "$BASELINE_DIR"' EXIT
  git archive "$1" Sources/GoveeStudio | tar -x -C "$BASELINE_DIR"
  SOURCE_DIR="$BASELINE_DIR/Sources/GoveeStudio"
  OUTPUT=.local/benchmark-ui-baseline
fi
xcrun swiftc -O -D MEDIA_EXPORT -parse-as-library -I "$BIN_DIR/Modules" \
  "$SOURCE_DIR"/*.swift "$BIN_DIR"/AmbienceCore.build/*.swift.o \
  scripts/BenchmarkUI.swift -o "$OUTPUT"
printf 'Offline benchmark: %s/%s\n' "$PWD" "$OUTPUT"
