#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Sync Branch
#
# Rebases the current feature branch on the latest default branch.
# Auto-stashes uncommitted changes and restores them after.
#
# Usage:
#   .standards/scripts/git/sync.sh
#   scripts/git/sync.sh                 (if symlinked)
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

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
	echo "→ Stashing uncommitted changes..."
	git stash push -u -m "auto-stash before sync $(date -u +%Y-%m-%dT%H:%MZ)"
	STASHED=true
else
	STASHED=false
fi

echo "→ Fetching latest $DEFAULT_BRANCH..."
git fetch origin "$DEFAULT_BRANCH" --quiet

echo "→ Rebasing '$CURRENT' onto origin/$DEFAULT_BRANCH..."
if ! git rebase "origin/$DEFAULT_BRANCH"; then
	echo ""
	echo "╔══════════════════════════════════════════════════════════╗"
	echo "║  Rebase conflict detected!                              ║"
	echo "║                                                         ║"
	echo "║  Fix conflicts, then:                                   ║"
	echo "║    git add <resolved-files>                             ║"
	echo "║    git rebase --continue                                ║"
	echo "║                                                         ║"
	echo "║  Or abort and keep your branch as-is:                   ║"
	echo "║    git rebase --abort                                   ║"
	echo "╚══════════════════════════════════════════════════════════╝"
	exit 1
fi

if $STASHED; then
	echo "→ Restoring stashed changes..."
	git stash pop
fi

echo ""
echo "✓ '$CURRENT' is up to date with $DEFAULT_BRANCH."
