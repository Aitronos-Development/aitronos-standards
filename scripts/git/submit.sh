#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Submit Branch
#
# Pushes the current branch and creates a PR to the default branch
# (if one doesn't already exist).
#
# Usage:
#   .standards/scripts/git/submit.sh                  # auto-title from branch
#   .standards/scripts/git/submit.sh "My PR title"    # custom title
#   scripts/git/submit.sh                             (if symlinked)
# ============================================================================

set -euo pipefail

CURRENT="$(git branch --show-current)"
DEFAULT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "develop")"

PROTECTED="$DEFAULT_BRANCH main master production"
for p in $PROTECTED; do
	if [ "$CURRENT" = "$p" ]; then
		echo "Error: You're on '$CURRENT'. Switch to a feature branch first."
		echo "  scripts/git/new-branch.sh feat my-feature"
		exit 1
	fi
done

if ! command -v gh > /dev/null 2>&1; then
	echo "Error: GitHub CLI (gh) is not installed."
	echo "  Install it: https://cli.github.com"
	exit 1
fi

echo "→ Pushing '$CURRENT'..."
git push -u origin "$CURRENT"

EXISTING_PR="$(gh pr list --head "$CURRENT" --base "$DEFAULT_BRANCH" --json number --jq '.[0].number' 2>/dev/null || true)"

if [ -n "$EXISTING_PR" ] && [ "$EXISTING_PR" != "null" ]; then
	PR_URL="$(gh pr view "$EXISTING_PR" --json url --jq '.url')"
	echo ""
	echo "✓ Branch pushed. PR already exists: $PR_URL"
	exit 0
fi

if [ $# -ge 1 ]; then
	TITLE="$1"
else
	TITLE="$(echo "$CURRENT" | sed 's|/|: |' | tr '-' ' ')"
fi

echo "→ Creating PR..."
PR_URL="$(gh pr create \
	--base "$DEFAULT_BRANCH" \
	--head "$CURRENT" \
	--title "$TITLE" \
	--body "Branch: \`$CURRENT\`" \
	--draft 2>&1 | tail -1)"

echo ""
echo "✓ PR created: $PR_URL"
echo "  When ready, mark it as ready for review in GitHub."
