#!/usr/bin/env bash
set -euo pipefail

APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-伊莉丝Codex账户监控助手}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-伊莉丝Codex账户监控助手}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-yls-yy-app}"
BUNDLE_ID="${BUNDLE_ID:-com.yls.codex-monitor}"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_BUNDLE_NAME}.app"
APP_CONTENTS="$APP_DIR/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
PLIST_PATH="$APP_CONTENTS/Info.plist"
ZIP_PATH="$DIST_DIR/${APP_BUNDLE_NAME}.zip"

cd "$ROOT_DIR"

swift build -c release

rm -rf "$APP_DIR" "$ZIP_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cp ".build/release/$EXECUTABLE_NAME" "$APP_MACOS/$EXECUTABLE_NAME"
chmod +x "$APP_MACOS/$EXECUTABLE_NAME"

cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" || true
fi

mkdir -p "$DIST_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "App bundle: $APP_DIR"
echo "Zip package: $ZIP_PATH"
