#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Sync Branch
#
# Rebases the current feature branch on the latest default branch.
# Refuses to run with uncommitted changes — commit or stash them yourself
# first. This is deliberate: silent auto-stashing has caused lost work when
# `git stash pop` hit a conflict and the stash was forgotten.
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

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]; then
	echo ""
	echo "╔══════════════════════════════════════════════════════════╗"
	echo "║  Working tree is dirty — sync aborted.                  ║"
	echo "║                                                         ║"
	echo "║  Commit your work, or stash it yourself:                ║"
	echo "║    git stash push -u -m \"wip\"                         ║"
	echo "║                                                         ║"
	echo "║  Then re-run sync. Restore later with:                  ║"
	echo "║    git stash pop                                        ║"
	echo "╚══════════════════════════════════════════════════════════╝"
	exit 1
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

echo ""
echo "✓ '$CURRENT' is up to date with $DEFAULT_BRANCH."
