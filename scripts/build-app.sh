#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcrun swift build --build-system native --scratch-path .build/stable -c release
BIN_DIR=$(xcrun swift build --build-system native --scratch-path .build/stable -c release --show-bin-path)
STAGING=$(mktemp -d /private/tmp/govee-studio-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Govee Studio.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/GoveeStudio" "$APP/Contents/MacOS/GoveeStudio"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GoveeStudio</string>
<key>CFBundleIdentifier</key><string>de.naiklas.goveestudio</string>
<key>CFBundleName</key><string>Govee Studio</string>
<key>CFBundleDisplayName</key><string>Govee Studio</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.8.1</string>
<key>CFBundleVersion</key><string>11</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSScreenCaptureUsageDescription</key><string>Govee Studio bestimmt lokal Bildschirmfarben für deine Leuchten. Es speichert und überträgt keine Bildschirmaufnahmen.</string>
<key>NSLocalNetworkUsageDescription</key><string>Govee Studio erkennt und steuert deine Govee-Leuchten direkt im lokalen Netzwerk.</string>
</dict></plist>
PLIST
if [[ ! -f .build/AppIcon.icns ]]; then
  xcrun swift scripts/make-icon.swift
  mkdir -p .build/AppIcon.iconset
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" .build/icon.png --out ".build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size*2))
    sips -z "$double" "$double" .build/icon.png --out ".build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns
fi
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Stable designated requirement keeps local privacy permissions across ad-hoc rebuilds.
codesign --force --sign - --identifier de.naiklas.goveestudio --requirements '=designated => identifier "de.naiklas.goveestudio"' "$APP"
codesign --verify --deep --strict "$APP"
mkdir -p dist
# Zip avoids File Provider adding FinderInfo to the app bundle in synced workspaces.
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/Govee-Studio.zip"
if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  ditto --norsrc "$APP" "$HOME/Applications/Govee Studio.app"
  codesign --verify --deep --strict "$HOME/Applications/Govee Studio.app"
  printf '%s\n' "Installed: $HOME/Applications/Govee Studio.app"
fi
printf '%s\n' "Packaged: $PWD/dist/Govee-Studio.zip"
