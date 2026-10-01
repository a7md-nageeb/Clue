#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Clue"
VERSION="$(awk '/^version:/{print $2}' pubspec.yaml)"
DMG_DIR="build/macos"
APP_PATH="$DMG_DIR/Build/Products/Release/${APP_NAME}.app"
DMG_STAGING="$DMG_DIR/dmg-staging"
DMG_TEMP="$DMG_DIR/${APP_NAME}-temp.dmg"
DMG_FINAL="$DMG_DIR/${APP_NAME}-${VERSION}.dmg"
BACKGROUND_SVG="dmg/background.svg"
BACKGROUND_PNG="dmg/background.png"

WINDOW_LEFT=100
WINDOW_TOP=100
WINDOW_WIDTH=540
WINDOW_HEIGHT=380
WINDOW_RIGHT=$((WINDOW_LEFT + WINDOW_WIDTH))
WINDOW_BOTTOM=$((WINDOW_TOP + WINDOW_HEIGHT))

echo "Building ${APP_NAME} ${VERSION} for macOS..."
flutter build macos --release

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing app bundle: $APP_PATH" >&2
  exit 1
fi

echo "Rendering DMG background..."
if [[ ! -f "$BACKGROUND_PNG" ]] || [[ "$BACKGROUND_SVG" -nt "$BACKGROUND_PNG" ]]; then
  qlmanage -t -s 2160 -o dmg "$BACKGROUND_SVG" >/dev/null 2>&1
  mv -f "dmg/background.svg.png" "$BACKGROUND_PNG"
fi

echo "Preparing DMG staging folder..."
rm -rf "$DMG_STAGING" "$DMG_TEMP"
mkdir -p "$DMG_STAGING/.background"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
cp "$BACKGROUND_PNG" "$DMG_STAGING/.background/background.png"
chflags hidden "$DMG_STAGING/.background" 2>/dev/null || true

echo "Creating writable disk image..."
hdiutil create \
  -srcfolder "$DMG_STAGING" \
  -volname "$APP_NAME" \
  -fs HFS+ \
  -format UDRW \
  -size 220m \
  "$DMG_TEMP" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP")"
MOUNT_DIR="$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -1)"
BACKGROUND_MOUNT_PATH="${MOUNT_DIR}/.background/background.png"

cleanup() {
  if [[ -n "${MOUNT_DIR:-}" ]] && mount | grep -q "$MOUNT_DIR"; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

sleep 2

echo "Styling Finder window..."
osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    delay 1
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {$WINDOW_LEFT, $WINDOW_TOP, $WINDOW_RIGHT, $WINDOW_BOTTOM}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set text size of viewOptions to 12
    set background picture of viewOptions to POSIX file "$BACKGROUND_MOUNT_PATH"
    set position of item "${APP_NAME}.app" of container window to {135, 205}
    set position of item "Applications" of container window to {405, 205}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
EOF

echo "Compressing DMG..."
hdiutil detach "$MOUNT_DIR" >/dev/null
MOUNT_DIR=""
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_FINAL" >/dev/null
rm -f "$DMG_TEMP"
rm -rf "$DMG_STAGING"

echo "Created $DMG_FINAL"
