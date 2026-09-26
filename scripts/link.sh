#!/usr/bin/env bash
# Symlink this repo into a WoW client's AddOns folder so edits show up after /reload.
# Usage: scripts/link.sh [flavor]   (default: _classic_beta_; e.g. _retail_, _classic_era_)
set -euo pipefail

WOW_DIR="${WOW_DIR:-/Applications/World of Warcraft}"
FLAVOR="${1:-_classic_beta_}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ADDONS="$WOW_DIR/$FLAVOR/Interface/AddOns"
TARGET="$ADDONS/FadeUI"

[ -d "$WOW_DIR/$FLAVOR" ] || { echo "No WoW client at $WOW_DIR/$FLAVOR" >&2; exit 1; }
mkdir -p "$ADDONS"

if [ -L "$TARGET" ]; then
	rm "$TARGET"
elif [ -e "$TARGET" ]; then
	backup="$ADDONS/../FadeUI.bak.$(date +%Y%m%d%H%M%S)"
	echo "Moving existing $TARGET to $backup"
	mv "$TARGET" "$backup"
fi

ln -s "$REPO" "$TARGET"
echo "Linked $TARGET -> $REPO"
