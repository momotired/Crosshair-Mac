#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT_DIR"

ARM64_BUILD="$ROOT_DIR/.build-arm64"
X86_64_BUILD="$ROOT_DIR/.build-x86_64"

swift build -c release --triple arm64-apple-macosx13.0 --build-path "$ARM64_BUILD"
swift build -c release --triple x86_64-apple-macosx13.0 --build-path "$X86_64_BUILD"

APP_DIR="$ROOT_DIR/build/Crosshair Mac.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
lipo -create \
    "$ARM64_BUILD/arm64-apple-macosx/release/CrosshairMac" \
    "$X86_64_BUILD/x86_64-apple-macosx/release/CrosshairMac" \
    -output "$MACOS_DIR/CrosshairMac"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CrosshairMac</string>
    <key>CFBundleIdentifier</key>
    <string>local.crosshairmac.app</string>
    <key>CFBundleName</key>
    <string>Crosshair Mac</string>
    <key>CFBundleDisplayName</key>
    <string>Crosshair Mac</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP_DIR"
echo "Created: $APP_DIR"
