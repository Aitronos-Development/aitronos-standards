---
name: commit-push
description: Stage all changes (including submodules), commit with an auto-generated message, fix any pre-commit hook failures, and push. Handles submodules, compliance issues, and hook failures automatically.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# Commit & Push

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling.

Stage all changes, generate contextual commit messages, handle pre-commit hook failures automatically, and push to the remote — **including all submodules with pending changes**.

## When to Use

- You want to commit and push your work in one step
- You want compliance/lint issues caught and fixed before the commit lands
- You want submodule changes committed and pushed alongside the parent repo

## Usage

```
/commit-push
/commit-push fix auth token expiry bug
```

If the user provides a message after the command, use that as the commit message for the **parent repo**. Submodules get their own auto-generated messages based on their changes.

## Workflow

<workflow>

### Step 1: Detect Submodules with Changes

Check `.gitmodules` for registered submodules, then check each for uncommitted or unpushed changes:

```bash
git submodule foreach --quiet 'if [ -n "$(git status --porcelain)" ] || [ -n "$(git log @{u}.. 2>/dev/null)" ]; then echo "$sm_path"; fi'
```

Also check the parent repo for dirty submodule pointers:

```bash
git diff --name-only | grep -E '^\.'  # e.g., .standards, docs/public-docs
git status --short
```

### Step 2: Commit & Push Each Dirty Submodule

For EACH submodule with uncommitted changes, process it **before** the parent repo:

#### 2a. Enter the submodule directory

```bash
cd <submodule-path>
```

#### 2b. Analyze changes

```bash
git status
git diff --stat
git log --oneline -5
```

#### 2c. Stage all changes

```bash
git add -A
```

#### 2d. Generate a commit message

- Use conventional commit format matching the submodule's recent commit style
- Be specific about what changed in this submodule
- Keep it concise (1-2 lines)

#### 2e. Commit (with hook handling)

```bash
git commit -m "[message]"
```

If hooks fail: re-stage and retry (same logic as Step 6 below, max 3 attempts).

#### 2f. Push the submodule

```bash
git push
```

If push is rejected because remote has newer commits:

```bash
git pull --rebase && git push
```

If there are rebase conflicts, report them and stop — do NOT continue to the parent repo.

#### 2g. Return to parent repo root

```bash
cd <project-root>
```

**Report** each submodule result as you go: `✓ .standards — [hash] [message]`

### Step 3: Check Parent Repo for Changes

```bash
git status --porcelain
```

If empty (and no submodule pointer changes), report "No changes to commit." and stop.

### Step 4: Analyze Parent Changes

```bash
git status
git diff --stat
git diff --cached --stat
git log --oneline -5
```

### Step 5: Generate Parent Commit Message

If the user provided a message, use it. Otherwise generate one:

- Use conventional commit format: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `style:`
- Be specific about what changed
- Keep it concise (1-2 lines max)
- Match the style of recent commits in the repo
- If submodule pointers were updated, mention it (e.g., "update .standards submodule")

### Step 6: Stage All Changes

```bash
git add -A
```

This stages everything including updated submodule pointers.

### Step 7: Run Compliance Checks (if configured)

If the project has compliance/lint commands configured:

```bash
{{config:commands.compliance.fast}}
```

If there are violations:
1. **Auto-fix** what can be fixed:
   ```bash
   {{config:commands.lint.fix}}
   {{config:commands.lint.format}}
   ```
2. **Manually fix** remaining issues
3. **Re-run compliance** to confirm zero errors
4. **Re-stage** after fixes:
   ```bash
   git add -A
   ```

### Step 8: Commit (with Pre-commit Hook Handling)

Attempt the commit:

```bash
git commit -m "[message]"
```

**If commit succeeds**: Report success and continue to Step 9.

**If commit fails due to pre-commit hooks**:

Pre-commit hooks (ruff, formatting, trailing whitespace, etc.) may auto-fix files. When this happens:

1. Report: "Pre-commit hooks made fixes, re-staging..."

2. Re-stage all changes (hooks may have modified files):
   ```bash
   git add -A
   ```

3. Retry the commit with the same message:
   ```bash
   git commit -m "[same message]"
   ```

4. If it fails again, run the project's compliance/lint fix:
   ```bash
   {{config:commands.compliance}}
   {{config:commands.lint.fix}}
   {{config:commands.lint.format}}
   ```

5. Re-stage and retry:
   ```bash
   git add -A
   git commit -m "[same message]"
   ```

6. If it still fails after 3 attempts total, report the remaining errors to the user and stop.

### Step 9: Push to Remote

```bash
git push
```

If push fails because there's no upstream branch:

```bash
git push --set-upstream origin $(git branch --show-current)
```

If push fails for other reasons (e.g., rejected because remote has new commits):

```bash
git pull --rebase && git push
```

If rebase conflicts occur, report them to the user and stop.

### Step 10: Summary

Report the full result:

```
Committed and pushed:

Submodules:
  ✓ .standards — [hash] [message]
  ✓ docs/public-docs — [hash] [message]
  ○ (no changes)

Parent repo ([branch]):
  [commit hash] [commit message]
  [N files changed, X insertions, Y deletions]
```

</workflow>

## Error Handling

- **Submodule push rejected**: Pull --rebase and retry. If conflicts, stop and report.
- **Parent push rejected**: Pull --rebase and retry. If conflicts, stop and report.
- **Unfixable compliance errors**: List remaining issues and ask the user how to proceed. Do not commit with known errors unless the user explicitly approves.
- **No changes anywhere**: Exit early with a message.

## Important Notes

- **Submodules are always processed first** — their commits must be pushed before the parent repo can reference the new submodule commits
- Always use `git add -A` to stage everything (untracked, modified, deleted)
- Pre-commit hooks in most Aitronos projects run ruff (lint + format), trailing-whitespace, end-of-file-fixer, and other auto-fixers
- The most common hook failure pattern: hooks auto-fix files, which means the commit fails but the fixes are already applied — just re-stage and retry
- Never skip hooks (`--no-verify`) — always fix the underlying issues
- Maximum 3 commit attempts before giving up (per repo/submodule)
- If the user provides a custom message, use it exactly as given (for parent repo only)
- Never force-push — if push is rejected, report the issue
- **NEVER add Co-Authored-By, Signed-off-by, or any trailer that identifies an AI** — commits must use the user's git identity only, with no AI attribution in the git history
