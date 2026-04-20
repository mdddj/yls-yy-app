#!/usr/bin/env bash
set -euo pipefail

APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-伊莉丝Codex账户监控助手}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-伊莉丝Codex账户监控助手}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-yls-yy-app}"
BUNDLE_ID="${BUNDLE_ID:-com.yls.codex-monitor}"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"
ICON_SOURCE_REL="${ICON_SOURCE_REL:-images/yls_logo.png}"
BUILD_ARCHS="${BUILD_ARCHS:-arm64 x86_64}"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_BUNDLE_NAME}.app"
APP_CONTENTS="$APP_DIR/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
PLIST_PATH="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/$ICON_SOURCE_REL"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICNS_PATH="$APP_RESOURCES/AppIcon.icns"
DMG_PATH="$DIST_DIR/${APP_BUNDLE_NAME}.dmg"

cd "$ROOT_DIR"

read -r -a BUILD_ARCH_ARRAY <<< "$BUILD_ARCHS"
if [[ "${#BUILD_ARCH_ARRAY[@]}" -eq 0 ]]; then
  echo "BUILD_ARCHS must contain at least one architecture" >&2
  exit 1
fi

SWIFT_BUILD_ARGS=(-c release)
for arch in "${BUILD_ARCH_ARRAY[@]}"; do
  SWIFT_BUILD_ARGS+=(--arch "$arch")
done

echo "Building release binary for architectures: ${BUILD_ARCH_ARRAY[*]}"
swift build "${SWIFT_BUILD_ARGS[@]}"

BINARY_PATH=""
if [[ "${#BUILD_ARCH_ARRAY[@]}" -gt 1 ]]; then
  UNIVERSAL_BINARY_PATH=".build/apple/Products/Release/$EXECUTABLE_NAME"
  if [[ -f "$UNIVERSAL_BINARY_PATH" ]]; then
    BINARY_PATH="$UNIVERSAL_BINARY_PATH"
  fi
fi

if [[ -z "$BINARY_PATH" ]]; then
  for arch in "${BUILD_ARCH_ARRAY[@]}"; do
    CANDIDATE=".build/${arch}-apple-macosx/release/$EXECUTABLE_NAME"
    if [[ -f "$CANDIDATE" ]]; then
      BINARY_PATH="$CANDIDATE"
      break
    fi
  done
fi

if [[ -z "$BINARY_PATH" && -f ".build/release/$EXECUTABLE_NAME" ]]; then
  BINARY_PATH=".build/release/$EXECUTABLE_NAME"
fi

if [[ -z "$BINARY_PATH" ]]; then
  echo "Release binary not found for architectures: ${BUILD_ARCH_ARRAY[*]}" >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Icon source not found: $ICON_SOURCE" >&2
  exit 1
fi

rm -rf "$APP_DIR" "$DMG_PATH" "$ICONSET_DIR"
rm -f "$DIST_DIR/${APP_BUNDLE_NAME}.zip"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"

cp "$BINARY_PATH" "$APP_MACOS/$EXECUTABLE_NAME"
chmod +x "$APP_MACOS/$EXECUTABLE_NAME"

mkdir -p "$ICONSET_DIR"
sips -s format png -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
rm -rf "$ICONSET_DIR"

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
hdiutil create \
  -volname "$APP_BUNDLE_NAME" \
  -srcfolder "$APP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "App bundle: $APP_DIR"
echo "DMG package: $DMG_PATH"
echo "Binary source: $BINARY_PATH"
echo "Packaged architectures: $(lipo -archs "$APP_MACOS/$EXECUTABLE_NAME")"
