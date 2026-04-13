#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Update Script
#
# Pulls the latest shared standards and wires any new rules, skills, or agents
# into the project. Safe to run repeatedly — never overwrites local overrides.
#
# Usage:
#   .standards/scripts/update.sh
# ============================================================================

set -euo pipefail

# Colors (disable if not a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN='' YELLOW='' RED='' BLUE='' BOLD='' NC=''
fi

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[SKIP]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

SUBMODULE_DIR=".standards"

RULES_LINKED=0
RULES_SKIPPED=0
SKILLS_LINKED=0
SKILLS_SKIPPED=0
AGENTS_LINKED=0
AGENTS_SKIPPED=0
STALE_REMOVED=0

# ============================================================================
# Verify we're in a git repo with the submodule
# ============================================================================

echo ""
echo -e "${BOLD}Aitronos Standards — Update${NC}"
echo "========================================"
echo ""

if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
  error "Not inside a git repository."
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

if [ ! -d "$SUBMODULE_DIR" ] && [ ! -f "$SUBMODULE_DIR/.git" ]; then
  error "$SUBMODULE_DIR not found. Run setup first: .standards/scripts/setup.sh"
  exit 1
fi

# ============================================================================
# Step 1 — Pull latest standards
# ============================================================================

echo -e "${BOLD}Step 1: Pull Latest Standards${NC}"

OLD_COMMIT=$(cd "$SUBMODULE_DIR" && git rev-parse --short HEAD)

# --no-pull: skip remote fetch (used by post-merge hook when submodule is already updated)
if [[ "${1:-}" != "--no-pull" ]]; then
  git submodule update --remote "$SUBMODULE_DIR" 2>/dev/null
else
  git submodule update --init "$SUBMODULE_DIR" 2>/dev/null
fi

NEW_COMMIT=$(cd "$SUBMODULE_DIR" && git rev-parse --short HEAD)

if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
  success "Already up to date ($OLD_COMMIT)"
else
  success "Updated $OLD_COMMIT -> $NEW_COMMIT"
  # Show what changed
  echo ""
  (cd "$SUBMODULE_DIR" && git log --oneline "$OLD_COMMIT".."$NEW_COMMIT" 2>/dev/null | head -10) || true
fi
echo ""

# ============================================================================
# Step 2 — Remove stale symlinks (pointing to deleted standards)
# ============================================================================

echo -e "${BOLD}Step 2: Clean Stale Symlinks${NC}"

for dir in .claude/rules .claude/skills .claude/agents; do
  [ -d "$dir" ] || continue
  for link in "$dir"/*; do
    [ -L "$link" ] || continue
    if [ ! -e "$link" ]; then
      info "Removing stale symlink: $link"
      rm "$link"
      STALE_REMOVED=$((STALE_REMOVED + 1))
    fi
  done
done

if [ "$STALE_REMOVED" -eq 0 ]; then
  success "No stale symlinks found"
else
  success "Removed $STALE_REMOVED stale symlinks"
fi
echo ""

# ============================================================================
# Step 3 — Link new rules
# ============================================================================

echo -e "${BOLD}Step 3: Link New Rules${NC}"

if [ -d "$SUBMODULE_DIR/rules" ]; then
  for rule in "$SUBMODULE_DIR"/rules/*.md; do
    [ -f "$rule" ] || continue
    name="$(basename "$rule")"
    target=".claude/rules/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      RULES_SKIPPED=$((RULES_SKIPPED + 1))
    else
      ln -s "../../$SUBMODULE_DIR/rules/$name" "$target"
      success "NEW  $target"
      RULES_LINKED=$((RULES_LINKED + 1))
    fi
  done
fi

if [ "$RULES_LINKED" -eq 0 ]; then
  success "No new rules to link ($RULES_SKIPPED existing)"
else
  success "$RULES_LINKED new rules linked, $RULES_SKIPPED existing"
fi
echo ""

# ============================================================================
# Step 4 — Link new skills
# ============================================================================

echo -e "${BOLD}Step 4: Link New Skills${NC}"

if [ -d "$SUBMODULE_DIR/skills" ]; then
  for skill_dir in "$SUBMODULE_DIR"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"
    target=".claude/skills/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      SKILLS_SKIPPED=$((SKILLS_SKIPPED + 1))
    else
      ln -s "../../$SUBMODULE_DIR/skills/$name" "$target"
      success "NEW  $target"
      SKILLS_LINKED=$((SKILLS_LINKED + 1))
    fi
  done
fi

if [ "$SKILLS_LINKED" -eq 0 ]; then
  success "No new skills to link ($SKILLS_SKIPPED existing)"
else
  success "$SKILLS_LINKED new skills linked, $SKILLS_SKIPPED existing"
fi
echo ""

# ============================================================================
# Step 5 — Link new agents
# ============================================================================

echo -e "${BOLD}Step 5: Link New Agents${NC}"

if [ -d "$SUBMODULE_DIR/agents" ]; then
  for agent in "$SUBMODULE_DIR"/agents/*.md; do
    [ -f "$agent" ] || continue
    name="$(basename "$agent")"
    target=".claude/agents/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      AGENTS_SKIPPED=$((AGENTS_SKIPPED + 1))
    else
      ln -s "../../$SUBMODULE_DIR/agents/$name" "$target"
      success "NEW  $target"
      AGENTS_LINKED=$((AGENTS_LINKED + 1))
    fi
  done
fi

if [ "$AGENTS_LINKED" -eq 0 ]; then
  success "No new agents to link ($AGENTS_SKIPPED existing)"
else
  success "$AGENTS_LINKED new agents linked, $AGENTS_SKIPPED existing"
fi
echo ""

# ============================================================================
# Step 6 — Ensure PreCompact hook exists
# ============================================================================

echo -e "${BOLD}Step 6: Verify PreCompact Hook${NC}"

CLAUDE_SETTINGS=".claude/settings.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
  if grep -q "PreCompact" "$CLAUDE_SETTINGS" 2>/dev/null; then
    success "PreCompact hook already configured"
  else
    if command -v python3 > /dev/null 2>&1; then
      python3 -c "
import json
with open('$CLAUDE_SETTINGS') as f:
    settings = json.load(f)
settings.setdefault('hooks', {})['PreCompact'] = [{
    'matcher': '',
    'hooks': [{
        'type': 'command',
        'command': 'python3 .standards/scripts/orchestrator-state-snapshot.py'
    }]
}]
with open('$CLAUDE_SETTINGS', 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
" && success "Added PreCompact hook to $CLAUDE_SETTINGS" \
   || warn "Could not merge PreCompact hook — add manually (see SETUP.md)"
    else
      warn "python3 not found — add PreCompact hook manually (see SETUP.md)"
    fi
  fi
else
  warn "$CLAUDE_SETTINGS not found — run .standards/scripts/setup.sh first"
fi
echo ""

# ============================================================================
# Step 7 — Ensure post-merge git hook is installed
# ============================================================================

echo -e "${BOLD}Step 7: Verify Post-Merge Hook${NC}"

SUBMODULE_DIR=".standards"
GIT_HOOKS_DIR="$(git rev-parse --git-dir)/hooks"
POST_MERGE_HOOK="$GIT_HOOKS_DIR/post-merge"
MARKER="# aitronos-standards-post-merge"

if [ -f "$POST_MERGE_HOOK" ] && grep -q "$MARKER" "$POST_MERGE_HOOK" 2>/dev/null; then
  success "Post-merge hook already installed"
elif [ -f "$POST_MERGE_HOOK" ]; then
  cat >> "$POST_MERGE_HOOK" << HOOK

$MARKER
# Auto-sync standards after pull/merge
if [ -x ".standards/scripts/hooks/post-merge" ]; then
  .standards/scripts/hooks/post-merge
fi
HOOK
  success "Appended standards sync to existing post-merge hook"
else
  cat > "$POST_MERGE_HOOK" << HOOK
#!/usr/bin/env bash
$MARKER
# Auto-sync standards after pull/merge
if [ -x ".standards/scripts/hooks/post-merge" ]; then
  .standards/scripts/hooks/post-merge
fi
HOOK
  chmod +x "$POST_MERGE_HOOK"
  success "Created post-merge hook"
fi
echo ""

# ============================================================================
# Step 8 — Ensure prepare-commit-msg hook is installed (strip AI attribution)
# ============================================================================

echo -e "${BOLD}Step 8: Verify Prepare-Commit-Msg Hook${NC}"

PREPARE_COMMIT_HOOK="$GIT_HOOKS_DIR/prepare-commit-msg"
PREPARE_MARKER="# aitronos-standards-prepare-commit-msg"

if [ -f "$PREPARE_COMMIT_HOOK" ] && grep -q "$PREPARE_MARKER" "$PREPARE_COMMIT_HOOK" 2>/dev/null; then
  success "Prepare-commit-msg hook already installed"
elif [ -f "$PREPARE_COMMIT_HOOK" ]; then
  cat >> "$PREPARE_COMMIT_HOOK" << HOOK

$PREPARE_MARKER
# Strip AI attribution from commit messages (Co-Authored-By, Signed-off-by)
if [ -x ".standards/scripts/hooks/prepare-commit-msg" ]; then
  .standards/scripts/hooks/prepare-commit-msg "\$1" "\$2" "\$3"
fi
HOOK
  success "Appended AI attribution stripper to existing prepare-commit-msg hook"
else
  cat > "$PREPARE_COMMIT_HOOK" << HOOK
#!/usr/bin/env bash
$PREPARE_MARKER
# Strip AI attribution from commit messages (Co-Authored-By, Signed-off-by)
if [ -x ".standards/scripts/hooks/prepare-commit-msg" ]; then
  .standards/scripts/hooks/prepare-commit-msg "\$1" "\$2" "\$3"
fi
HOOK
  chmod +x "$PREPARE_COMMIT_HOOK"
  success "Created prepare-commit-msg hook (strips AI attribution from commits)"
fi
echo ""

# ============================================================================
# Step 9 — Ensure pre-push hook is installed (block mass file deletions)
# ============================================================================

echo -e "${BOLD}Step 9: Pre-Push Hook (mass-deletion guard)${NC}"

PRE_PUSH_HOOK="$GIT_HOOKS_DIR/pre-push"
PRE_PUSH_MARKER="# aitronos-standards-pre-push"

if [ -f "$PRE_PUSH_HOOK" ]; then
  if grep -q "$PRE_PUSH_MARKER" "$PRE_PUSH_HOOK" 2>/dev/null; then
    success "Pre-push hook already installed"
  else
    cat >> "$PRE_PUSH_HOOK" << HOOK

$PRE_PUSH_MARKER
# Block pushes that mass-delete files
if [ -x ".standards/scripts/hooks/pre-push" ]; then
  .standards/scripts/hooks/pre-push
fi
HOOK
    success "Appended mass-deletion guard to existing pre-push hook"
  fi
else
  cat > "$PRE_PUSH_HOOK" << HOOK
#!/usr/bin/env bash
$PRE_PUSH_MARKER
# Block pushes that mass-delete files
if [ -x ".standards/scripts/hooks/pre-push" ]; then
  .standards/scripts/hooks/pre-push
fi
HOOK
  chmod +x "$PRE_PUSH_HOOK"
  success "Created pre-push hook (blocks mass file deletions)"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "========================================"
echo -e "${BOLD}${GREEN}Update Complete!${NC}"
echo "========================================"
echo ""
echo "  Standards:  $OLD_COMMIT -> $NEW_COMMIT"
echo "  Rules:      $RULES_LINKED new, $RULES_SKIPPED existing"
echo "  Skills:     $SKILLS_LINKED new, $SKILLS_SKIPPED existing"
echo "  Agents:     $AGENTS_LINKED new, $AGENTS_SKIPPED existing"
echo "  Cleaned:    $STALE_REMOVED stale symlinks removed"
echo ""

TOTAL_NEW=$((RULES_LINKED + SKILLS_LINKED + AGENTS_LINKED))

if [ "$TOTAL_NEW" -gt 0 ] || [ "$OLD_COMMIT" != "$NEW_COMMIT" ]; then
  echo -e "${BOLD}Next steps:${NC}"
  echo "  git add .standards .claude"
  echo "  git commit -m \"chore: update shared engineering standards\""
  echo ""
fi
