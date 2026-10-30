#!/bin/sh
# Linux installer for LAAF. Installs per-user (no root): ./install.sh
# Uninstall: ./install.sh --uninstall
set -eu

DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DIR/laaf"
DESKTOP="$DIR/applications/laaf.desktop"
ICON="$DIR/icons/hicolor/scalable/apps/laaf.svg"
BIN="$HOME/.local/bin/laaf"

if [ "${1:-}" = "--uninstall" ]; then
	rm -rf "$APP_DIR"
	rm -f "$DESKTOP" "$ICON" "$BIN"
	echo "LAAF uninstalled. Save data in ~/.local/share/godot/app_userdata/LAAF was kept."
	exit 0
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$APP_DIR" "$(dirname "$DESKTOP")" "$(dirname "$ICON")" "$(dirname "$BIN")"
install -m 755 "$SRC/LAAF.x86_64" "$APP_DIR/LAAF.x86_64"
install -m 644 "$SRC/icon.svg" "$ICON"
ln -sf "$APP_DIR/LAAF.x86_64" "$BIN"

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=LAAF
Exec="$APP_DIR/LAAF.x86_64"
Icon=laaf
Categories=Game;
Terminal=false
EOF

command -v update-desktop-database >/dev/null && update-desktop-database "$(dirname "$DESKTOP")" 2>/dev/null || true
echo "LAAF installed. Launch it from your app menu or run: laaf"
