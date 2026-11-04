#!/bin/sh
# Exports the game and builds both installers into build/:
#   build/LAAF-<version>-windows-setup.exe   (needs makensis: apt install nsis)
#   build/LAAF-<version>-linux.tar.gz        (extract, then run ./install.sh)
# Requires Godot 4.7 export templates (Editor > Manage Export Templates).
# Override the Godot command with GODOT=/path/to/godot.
# The Groq key goes into the release only: taken from GROQ_API_KEY or this machine's user://groq_key.txt, written to a
# gitignored file for the export and removed afterwards. It is never in the repo, but it can be extracted from a build.
set -eu
cd "$(dirname "$0")/.."

if [ -z "${GODOT:-}" ]; then
	if command -v godot >/dev/null; then GODOT=godot
	else GODOT="flatpak run org.godotengine.Godot"; fi
fi
VERSION="${VERSION:-$(git describe --tags --always 2>/dev/null || echo 0.0.0)}"

KEY="${GROQ_API_KEY:-}"
for f in "$HOME/.var/app/org.godotengine.Godot/data/godot/app_userdata/LAAF/groq_key.txt" \
		"$HOME/.local/share/godot/app_userdata/LAAF/groq_key.txt"; do
	if [ -z "$KEY" ] && [ -f "$f" ]; then KEY="$(cat "$f")"; fi
done
if [ -z "$KEY" ]; then
	echo "No Groq key: set GROQ_API_KEY or user://groq_key.txt" >&2
	exit 1
fi
trap 'rm -f groq_release_key.txt' EXIT
(umask 077; printf '%s\n' "$KEY" > groq_release_key.txt)

rm -rf build
mkdir -p build/windows build/linux
$GODOT --headless --path . --export-release "Windows Desktop" build/windows/LAAF.exe
$GODOT --headless --path . --export-release "Linux" build/linux/LAAF.x86_64

makensis -V2 -DVERSION="$VERSION" installer/laaf.nsi

PKG="LAAF-$VERSION-linux"
mkdir -p "build/$PKG"
cp build/linux/LAAF.x86_64 icon.svg installer/install.sh "build/$PKG/"
tar -czf "build/$PKG.tar.gz" -C build "$PKG"

ls -lh build/*.exe build/*.tar.gz
