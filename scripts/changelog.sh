#!/usr/bin/env bash
# Writes CHANGELOG.md for a release tag from GitHub's generated release notes: the
# tag's PRs, grouped by label (.github/release.yml), each with the issues it fixes.
# The packager uses it as the GitHub release body and the CurseForge changelog
# (manual-changelog in .pkgmeta).
#
# Usage: scripts/changelog.sh [tag]    (default: the tag checked out)
set -euo pipefail
cd "$(dirname "$0")/.."

tag=${1:-$(git describe --tags --exact-match)}
prev=$(git describe --tags --abbrev=0 "$tag^")

# GitHub's notes list PRs only, so each PR's line also gets the issues it closes
# (by "Closes #40" in its description, or linked to it): ", fixes #40".
add_fixes() {
	local line fixes re='/pull/([0-9]+)\)$'
	while IFS= read -r line; do
		if [[ $line =~ $re ]]; then
			fixes=$(gh pr view "${BASH_REMATCH[1]}" --json closingIssuesReferences \
				--jq '[.closingIssuesReferences[] | "[#\(.number)](\(.url))"] | join(", ")')
			if [ -n "$fixes" ]; then line="$line, fixes $fixes"; fi
		fi
		printf '%s\n' "$line"
	done
}

# Drop GitHub's "generated using" comment, and turn bare PR and compare URLs into
# markdown links, since CurseForge doesn't link bare URLs.
gh api "repos/{owner}/{repo}/releases/generate-notes" \
	-f tag_name="$tag" -f previous_tag_name="$prev" --jq .body \
	| sed -E \
		-e '/^<!--.*-->$/d' \
		-e 's|https://github\.com/[^ ]+/pull/([0-9]+)|[#\1](&)|g' \
		-e 's|https://github\.com/[^ ]+/compare/([^ ]+)|[\1](&)|g' \
	| sed '/./,$!d' | add_fixes > CHANGELOG.md

echo "Wrote CHANGELOG.md for $tag (since $prev)"
