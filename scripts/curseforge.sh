#!/usr/bin/env bash
# Uploads the tag checked out to CurseForge, with the tag's PR list as its changelog.
# Needs CF_API_KEY in .env, and bash 4.3+ for release.sh (brew install bash).
#
# Usage: scripts/curseforge.sh [-d]    (-d builds without uploading)
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/changelog.sh

bash=bash
[ -x /opt/homebrew/bin/bash ] && bash=/opt/homebrew/bin/bash
exec "$bash" scripts/release.sh "$@"
