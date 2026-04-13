#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Git Hook Installer
#
# Installs / repairs git hooks that enforce branch protection.
# Called automatically by post-merge and post-checkout hooks so that
# even if an AI agent deletes the hooks, they get recreated on the
# very next pull or branch switch.
#
# Usage:
#   .standards/scripts/git/install-hooks.sh
# ============================================================================

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"
STANDARDS_DIR="$REPO_ROOT/.standards"

mkdir -p "$HOOKS_DIR"

# ── pre-push hook ──────────────────────────────────────────────────────
PRE_PUSH="$HOOKS_DIR/pre-push"
EXPECTED_MARKER="# flowplate-branch-protection-v1"

needs_install=false
if [ ! -f "$PRE_PUSH" ]; then
	needs_install=true
elif ! grep -q "$EXPECTED_MARKER" "$PRE_PUSH" 2>/dev/null; then
	needs_install=true
fi

if $needs_install; then
	if [ -f "$STANDARDS_DIR/scripts/hooks/pre-push" ]; then
		cp "$STANDARDS_DIR/scripts/hooks/pre-push" "$PRE_PUSH"
	else
		cat > "$PRE_PUSH" << 'HOOK'
#!/usr/bin/env bash
# flowplate-branch-protection-v1
PROTECTED_BRANCHES="develop main master production"
remote="$1"
while read -r local_ref local_sha remote_ref remote_sha; do
	branch_name="${remote_ref#refs/heads/}"
	for protected in $PROTECTED_BRANCHES; do
		if [ "$branch_name" = "$protected" ]; then
			echo ""
			echo "BLOCKED: Direct push to '$protected' is not allowed."
			echo "Create a feature branch and open a PR instead."
			echo ""
			exit 1
		fi
	done
done
exit 0
HOOK
	fi
	chmod +x "$PRE_PUSH"
	echo "✓ Installed pre-push hook (branch protection)"
fi

# ── post-merge hook ────────────────────────────────────────────────────
POST_MERGE="$HOOKS_DIR/post-merge"
MERGE_MARKER="# flowplate-hook-repair-v1"

if [ ! -f "$POST_MERGE" ] || ! grep -q "$MERGE_MARKER" "$POST_MERGE" 2>/dev/null; then
	cat > "$POST_MERGE" << 'HOOK'
#!/usr/bin/env bash
# flowplate-hook-repair-v1
# Re-installs hooks after every pull/merge so they can't be silently removed.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ -x "$REPO_ROOT/.standards/scripts/git/install-hooks.sh" ]; then
	"$REPO_ROOT/.standards/scripts/git/install-hooks.sh" 2>/dev/null
elif [ -x "$REPO_ROOT/scripts/git/install-hooks.sh" ]; then
	"$REPO_ROOT/scripts/git/install-hooks.sh" 2>/dev/null
fi

# Chain to standards sync hook if present
if [ -x "$REPO_ROOT/.standards/scripts/hooks/post-merge" ]; then
	"$REPO_ROOT/.standards/scripts/hooks/post-merge"
fi
HOOK
	chmod +x "$POST_MERGE"
	echo "✓ Installed post-merge hook (auto-repair + standards sync)"
fi

# ── post-checkout hook ─────────────────────────────────────────────────
POST_CHECKOUT="$HOOKS_DIR/post-checkout"
CHECKOUT_MARKER="# flowplate-hook-repair-v1"

if [ ! -f "$POST_CHECKOUT" ] || ! grep -q "$CHECKOUT_MARKER" "$POST_CHECKOUT" 2>/dev/null; then
	cat > "$POST_CHECKOUT" << 'HOOK'
#!/usr/bin/env bash
# flowplate-hook-repair-v1
# Re-installs hooks on branch switch so they can't be silently removed.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if [ -x "$REPO_ROOT/.standards/scripts/git/install-hooks.sh" ]; then
	"$REPO_ROOT/.standards/scripts/git/install-hooks.sh" 2>/dev/null
elif [ -x "$REPO_ROOT/scripts/git/install-hooks.sh" ]; then
	"$REPO_ROOT/scripts/git/install-hooks.sh" 2>/dev/null
fi
HOOK
	chmod +x "$POST_CHECKOUT"
	echo "✓ Installed post-checkout hook (auto-repair)"
fi

echo "✓ All hooks verified"
