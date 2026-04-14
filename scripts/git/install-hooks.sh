#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Git Hook Installer
#
# Installs / repairs git hooks that prevent accidental code loss.
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
EXPECTED_MARKER="# aitronos-safe-push-v1"

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
# aitronos-safe-push-v1
set -euo pipefail
remote="$1"
while read -r local_ref local_oid remote_ref remote_oid; do
	[ "$local_oid" = "0000000000000000000000000000000000000000" ] && continue
	branch_name="${remote_ref#refs/heads/}"
	git fetch "$remote" "$branch_name" --quiet 2>/dev/null || true
	REMOTE_HEAD="$(git rev-parse "refs/remotes/$remote/$branch_name" 2>/dev/null || true)"
	if [ -n "$REMOTE_HEAD" ] && [ "$REMOTE_HEAD" != "$local_oid" ]; then
		if ! git merge-base --is-ancestor "$REMOTE_HEAD" "$local_oid" 2>/dev/null; then
			echo "BLOCKED: Remote has commits you don't have. Run: git pull --rebase origin $branch_name"
			exit 1
		fi
	fi
	git tag "backup/${branch_name}/$(date -u +%Y%m%d-%H%M%S)" "$local_oid" 2>/dev/null || true
done
exit 0
HOOK
	fi
	chmod +x "$PRE_PUSH"
	echo "✓ Installed pre-push hook (safe-push: fetch check + auto-backup)"
fi

# ── post-merge hook ────────────────────────────────────────────────────
POST_MERGE="$HOOKS_DIR/post-merge"
MERGE_MARKER="# aitronos-hook-repair-v1"

if [ ! -f "$POST_MERGE" ] || ! grep -q "$MERGE_MARKER" "$POST_MERGE" 2>/dev/null; then
	cat > "$POST_MERGE" << 'HOOK'
#!/usr/bin/env bash
# aitronos-hook-repair-v1
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
	echo "✓ Installed post-merge hook (auto-repair)"
fi

# ── post-checkout hook ─────────────────────────────────────────────────
POST_CHECKOUT="$HOOKS_DIR/post-checkout"
CHECKOUT_MARKER="# aitronos-hook-repair-v1"

if [ ! -f "$POST_CHECKOUT" ] || ! grep -q "$CHECKOUT_MARKER" "$POST_CHECKOUT" 2>/dev/null; then
	cat > "$POST_CHECKOUT" << 'HOOK'
#!/usr/bin/env bash
# aitronos-hook-repair-v1
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
