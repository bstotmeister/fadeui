#!/usr/bin/env bash
# Puts the addon folder (FadeUI/) into a WoW client's AddOns folder so edits show up after /reload.
# On macOS it's a symlink to the working tree. On Windows, run from WSL, the game can't follow a
# link into WSL, so the folder is copied instead: run this again after each change, then /reload.
# Usage: scripts/link.sh [flavor]   (default: _forever_; e.g. _retail_, _classic_era_)
set -euo pipefail

if grep -qi microsoft /proc/version 2>/dev/null; then
	copy=1
	WOW_DIR="${WOW_DIR:-/mnt/c/Program Files (x86)/World of Warcraft}"
else
	copy=""
	WOW_DIR="${WOW_DIR:-/Applications/World of Warcraft}"
fi
FLAVOR="${1:-_forever_}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$REPO/FadeUI"
ADDONS="$WOW_DIR/$FLAVOR/Interface/AddOns"
TARGET="$ADDONS/FadeUI"
# In a copy this script made, the folder it was copied from. Another copy is moved aside once.
MARK=".copied-from"

[ -d "$WOW_DIR/$FLAVOR" ] || { echo "No WoW client at $WOW_DIR/$FLAVOR" >&2; exit 1; }
mkdir -p "$ADDONS"

if [ -L "$TARGET" ]; then
	rm "$TARGET"
elif [ -e "$TARGET" ] && ! { [ -n "$copy" ] && [ -f "$TARGET/$MARK" ]; }; then
	backup="$ADDONS/../FadeUI.bak.$(date +%Y%m%d%H%M%S)"
	echo "Moving existing $TARGET to $backup"
	mv "$TARGET" "$backup"
fi

if [ -z "$copy" ]; then
	ln -s "$SOURCE" "$TARGET"
	echo "Linked $TARGET -> $SOURCE"
	exit 0
fi

mkdir -p "$TARGET"
printf '%s\n' "$SOURCE" >"$TARGET/$MARK"
if command -v rsync >/dev/null; then
	rsync -rt --delete --exclude "$MARK" "$SOURCE/" "$TARGET/"
else
	find "$TARGET" -mindepth 1 -maxdepth 1 ! -name "$MARK" -exec rm -rf {} +
	cp -R "$SOURCE/." "$TARGET/"
fi
echo "Copied $SOURCE to $TARGET. Run this again after a change, then /reload."
