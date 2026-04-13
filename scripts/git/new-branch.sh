#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Create Feature Branch
#
# Creates a new branch off the latest default branch, pushes it upstream.
#
# Usage:
#   .standards/scripts/git/new-branch.sh feat my-feature
#   .standards/scripts/git/new-branch.sh fix login-bug
#   scripts/git/new-branch.sh feat my-feature       (if symlinked)
#
# Valid types: feat, fix, hotfix, refactor, docs, chore, test
# ============================================================================

set -euo pipefail

VALID_TYPES="feat fix hotfix refactor docs chore test"

if [ $# -lt 2 ]; then
	echo "Usage: $0 <type> <name>"
	echo "  type: one of: $VALID_TYPES"
	echo "  name: short kebab-case description (e.g. add-user-auth)"
	echo ""
	echo "Examples:"
	echo "  $0 feat new-dashboard"
	echo "  $0 fix login-redirect"
	exit 1
fi

TYPE="$1"
shift
NAME="$(echo "$*" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')"

valid=false
for t in $VALID_TYPES; do
	if [ "$TYPE" = "$t" ]; then
		valid=true
		break
	fi
done

if ! $valid; then
	echo "Error: Invalid type '$TYPE'. Must be one of: $VALID_TYPES"
	exit 1
fi

BRANCH="${TYPE}/${NAME}"

# Detect default branch
DEFAULT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "develop")"

echo "→ Fetching latest $DEFAULT_BRANCH..."
git fetch origin "$DEFAULT_BRANCH" --quiet

echo "→ Creating branch '$BRANCH' from origin/$DEFAULT_BRANCH..."
git checkout -b "$BRANCH" "origin/$DEFAULT_BRANCH"

echo "→ Pushing branch upstream..."
git push -u origin "$BRANCH" --quiet

echo ""
echo "✓ Branch '$BRANCH' created and pushed."
echo "  Make your changes, then run: scripts/git/submit.sh"
