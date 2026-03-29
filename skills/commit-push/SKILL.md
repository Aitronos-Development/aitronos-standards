---
name: commit-push
description: Stage all changes (including submodules), commit with an auto-generated message, fix ALL pre-commit hook and compliance failures, and push. Handles submodules automatically. NEVER uses --no-verify.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, Agent
---

# Commit & Push

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling.

Stage all changes, generate contextual commit messages, **fix every compliance and hook failure**, and push to the remote — **including all submodules with pending changes**.

## ABSOLUTE RULES

1. **NEVER use `--no-verify`** — not on commit, not on push, not ever. If hooks fail, fix the code.
2. **NEVER skip or bypass compliance errors** — every error must be fixed before committing.
3. **Fix issues yourself** — don't ask the user to fix things. Read the error, find the file, fix it.
4. **No partial fixes** — the commit must pass all hooks and checks cleanly.

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

If hooks fail: read every error, fix every issue, re-stage and retry. Same fix loop as Step 8 below.

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

### Step 7: Pre-Commit Compliance Fix Loop

**Before attempting the commit**, proactively run compliance checks and fix everything:

```bash
{{config:commands.compliance.fast}}
```

If no compliance command is configured, skip to Step 8.

**Parse EVERY error from the output and fix it.** Common error categories:

#### Ruff Lint Errors (e.g., `F841 unused variable`, `E501 line too long`)
- Read the file at the reported line
- Fix the issue (remove unused variable, split long line, add missing import, etc.)
- These are code issues — fix the code

#### Forbidden Terms Errors (vendor names in public docs)
- Read the file, find the forbidden term
- Replace with the approved alternative (see vendor-terms rules)

#### Doc Accuracy Errors (endpoint not found in OpenAPI spec)
- If the endpoint exists in the codebase but is missing from OpenAPI: regenerate the spec
- If the doc references an endpoint that doesn't exist yet: remove or update the doc
- If the endpoint path in the doc is wrong: fix the path to match the actual route

#### File Size / Complexity Errors
- Split large files or functions as needed

#### Auth Pattern Errors
- Update to use `get_auth_context` instead of `get_current_user`

After fixing, re-run compliance:

```bash
{{config:commands.compliance.fast}}
```

**Repeat this fix loop until compliance reports 0 critical errors.** Maximum 5 iterations. If after 5 iterations there are still errors, list every remaining error and ask the user — but do NOT use `--no-verify`.

### Step 8: Commit (with Pre-commit Hook Fix Loop)

Attempt the commit:

```bash
git commit -m "[message]"
```

**If commit succeeds**: Continue to Step 9.

**If commit fails due to pre-commit hooks**:

Pre-commit hooks run a second layer of checks (ruff, formatting, trailing whitespace, etc.). When they fail:

1. **Read the FULL error output carefully.** Parse every single error message.

2. **For each error, fix it:**
   - Ruff lint error → read the file, fix the code
   - Ruff format → run `{{config:commands.lint.fix}}`
   - Trailing whitespace → the hook usually auto-fixes this, just re-stage
   - End of file fixer → the hook usually auto-fixes this, just re-stage
   - Merge conflict markers → you have leftover conflict markers, remove them
   - Large file detected → remove or gitignore the file
   - Compliance check errors → fix each one (see Step 7 categories above)

3. **Re-stage all changes** (hooks and your fixes may have modified files):
   ```bash
   git add -A
   ```

4. **Retry the commit** with the same message:
   ```bash
   git commit -m "[same message]"
   ```

5. **If it fails again**, read the NEW error output. It may be different errors now. Fix those too. Re-stage and retry.

6. **Repeat** until the commit succeeds. Maximum 5 attempts total. If after 5 attempts it still fails, list every remaining error and ask the user — but do NOT use `--no-verify`.

### Step 9: Push to Remote

```bash
git push
```

If push fails because there's no upstream branch:

```bash
git push --set-upstream origin $(git branch --show-current)
```

If push fails because `pre-commit` is not found (stale hook path):
- Reinstall hooks: `uv run pre-commit install` or fix the hook's Python path
- Then retry the push
- Do NOT use `--no-verify`

If push fails because remote has new commits:

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

Fixes applied:
  - [list any issues that were fixed during the process]
```

</workflow>

## Error Handling

- **Submodule push rejected**: Pull --rebase and retry. If conflicts, stop and report.
- **Parent push rejected**: Pull --rebase and retry. If conflicts, stop and report.
- **Compliance errors**: Fix every single one. Parse the error, read the file, fix it. Loop until clean.
- **Pre-commit hook errors**: Fix every single one. Parse the error, read the file, fix it. Loop until clean.
- **Stale pre-commit hook** (`pre-commit not found`): Reinstall hooks, do NOT use `--no-verify`.
- **No changes anywhere**: Exit early with a message.

## FORBIDDEN — Hard Bans

These are **never acceptable**, regardless of circumstances:

| Forbidden | Why | Do Instead |
|-----------|-----|------------|
| `--no-verify` on commit | Bypasses all quality checks | Fix the issues |
| `--no-verify` on push | Bypasses push hooks | Fix the issues or reinstall hooks |
| Committing with known errors | Ships broken code | Fix every error first |
| Asking user to fix lint/format | Wastes their time | You have the tools, fix it yourself |
| Skipping compliance "because pre-existing" | Pre-existing errors are still errors | Fix them or, if truly out of scope and unfixable, ask user |

## Important Notes

- **Submodules are always processed first** — their commits must be pushed before the parent repo can reference the new submodule commits
- Always use `git add -A` to stage everything (untracked, modified, deleted)
- Pre-commit hooks in most Aitronos projects run ruff (lint + format), trailing-whitespace, end-of-file-fixer, and other auto-fixers
- The most common hook failure pattern: hooks auto-fix files, which means the commit fails but the fixes are already applied — just re-stage and retry
- Maximum 5 commit attempts (per repo/submodule) — but you should be fixing issues between each attempt, not just retrying blindly
- If the user provides a custom message, use it exactly as given (for parent repo only)
- Never force-push — if push is rejected, report the issue
- **NEVER add Co-Authored-By, Signed-off-by, or any trailer that identifies an AI** — commits must use the user's git identity only, with no AI attribution in the git history
