#!/usr/bin/env bash
# Installs Clue for the current user and adds it to the app launcher.
# Run from the extracted bundle: ./install.sh
set -euo pipefail

APP_ID="com.forgottenthings.forgotten_things"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/opt/clue"
APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

if [[ "$SOURCE_DIR" != "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  cp -a "$SOURCE_DIR/." "$INSTALL_DIR/"
fi

mkdir -p "$APPS_DIR" "$ICON_DIR"
cp "$INSTALL_DIR/data/app_icon.png" "$ICON_DIR/$APP_ID.png"

rm -f "$APPS_DIR/clue.desktop"
cat > "$APPS_DIR/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Clue
Exec=$INSTALL_DIR/forgotten_things
Icon=$APP_ID
Categories=Utility;
Terminal=false
StartupWMClass=$APP_ID
EOF

update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true

echo "Clue installed to $INSTALL_DIR. Find it in your app launcher."
