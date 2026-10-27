#!/usr/bin/env bash
# Installs the pinned Godot editor binary (Linux x86_64) and prints its path.
# Usage: scripts/install_godot.sh            -> installs if missing, prints binary path
# Env:   GODOT_HOME (default: ~/.local/share/legend-arrow/godot)
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_ZIP_SHA256="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"

GODOT_HOME="${GODOT_HOME:-$HOME/.local/share/legend-arrow/godot}"
BIN="$GODOT_HOME/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64"

if [[ ! -x "$BIN" ]]; then
  mkdir -p "$GODOT_HOME/${GODOT_VERSION}"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "Downloading $GODOT_URL" >&2
  curl -sSLf --retry 4 --retry-delay 2 -o "$tmp/$GODOT_ZIP" "$GODOT_URL"
  echo "$GODOT_ZIP_SHA256  $tmp/$GODOT_ZIP" | sha256sum -c - >&2
  unzip -q -o "$tmp/$GODOT_ZIP" -d "$GODOT_HOME/${GODOT_VERSION}"
  chmod +x "$BIN"
fi

"$BIN" --version >&2
echo "$BIN"
