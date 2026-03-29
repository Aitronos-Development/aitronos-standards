---
name: pr-bugfix
description: "Fix bugbot review comments and CI failures from a GitHub PR. Waits for bugbot to finish, classifies bugs into auto-fixable vs human-review, fixes safe issues, checks all CI statuses (migrations, tests, lint, compliance), tests, commits, pushes, resolves conversations, and loops until all threads are resolved and CI passes (max 10 iterations). Use when a PR has bugbot comments or failing CI checks."
disable-model-invocation: false
user-invocable: true
---

# PR Bugfix Skill

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling. The test, lint, and dependency commands referenced below come from that file.

Automatically fetch bugbot review comments from a GitHub PR, classify them, fix safe issues in a dedicated worktree, escalate business logic changes to the user, verify fixes with tests, push changes, resolve conversations, and loop until clean.

## When to Use

- A PR has unresolved bugbot or cursor-bot review comments
- CI review bots flagged issues that need bulk fixing
- You want to systematically address all bot-generated feedback on a PR
- After a PR review round where automated tools left comments

## What This Does

1. **Parses the PR URL and waits for bugbot** — blocks until the Cursor Bugbot check run is `completed`
2. **Resolves merge conflicts** — merges the base branch and resolves any conflicts before fixing bugs
3. **Fetches all unresolved review threads** and filters for bugbot comments
4. **Classifies each bug** into auto-fixable or requires-human-review
5. **Displays a bug table** with Bug, Category, and Disposition columns
6. **Asks the user** to confirm the plan before proceeding
7. **Auto-fixes safe bugs** — code style, unused imports, type hints, null checks, etc.
8. **Escalates dangerous bugs** — business logic, architecture, data model changes go to the user
9. **Tests, commits, pushes** and resolves fixed conversations
10. **Checks all CI statuses** — migrations, tests, lint, compliance — and fixes failures
11. **Loops** — waits for bugbot to re-run on pushed changes, re-fetches threads, and repeats until zero unresolved threads remain and all CI passes (max 10 iterations)

## Usage

User invocation:
```
/pr-bugfix <pr-url>
```

Or with options:
```
/pr-bugfix <pr-url> --dry-run       # Fetch, classify, and display table only — don't fix
/pr-bugfix <pr-url> --no-resolve    # Fix and push but don't resolve conversations
/pr-bugfix <pr-url> --no-worktree   # Work in the current branch instead of creating a worktree
/pr-bugfix <pr-url> --max-iter N    # Override max iteration count (default: 10)
```

## Workflow

<workflow>

### Step 1: Parse PR URL and Wait for Bugbot

This step does TWO things in sequence. Both are mandatory.

**First**, extract `{owner}`, `{repo}`, and `{pr_number}` from the provided URL.

Supported formats:
- `https://github.com/{owner}/{repo}/pull/{pr_number}`
- `{owner}/{repo}#{pr_number}`

Verify the PR exists and is open:

```bash
gh pr view {pr_number} --repo {owner}/{repo} --json state,title,headRefName,baseRefName
```

Capture the `headRefName` (the PR's source branch) — you will push fixes to this branch.

**Second**, wait for the Cursor Bugbot to finish. Run this script as your VERY NEXT Bash command after verifying the PR. Set `block_until_ms` to `920000` so the command runs to completion without being backgrounded. Replace `{owner}`, `{repo}`, and `{pr_number}` with actual values:

```bash
OWNER="{owner}" && REPO="{repo}" && PR={pr_number} && MAX_WAIT=900 && ELAPSED=0 && HEAD_SHA=$(gh pr view "$PR" --repo "$OWNER/$REPO" --json headRefOid --jq '.headRefOid') && echo "HEAD SHA: $HEAD_SHA" && while [ $ELAPSED -lt $MAX_WAIT ]; do STATUS=$(gh api "repos/$OWNER/$REPO/commits/$HEAD_SHA/check-runs" --jq '[.check_runs[] | select(.app.slug == "cursor" or (.name | test("cursor|bugbot";"i")))] | first | .status // "not_found"' 2>/dev/null || echo "api_error") && echo "[${ELAPSED}s/${MAX_WAIT}s] Cursor Bugbot status: $STATUS" && if [ "$STATUS" = "completed" ]; then echo "BUGBOT_READY" && break; fi && sleep 30 && ELAPSED=$((ELAPSED + 30)); done && if [ $ELAPSED -ge $MAX_WAIT ]; then echo "BUGBOT_TIMEOUT after ${MAX_WAIT}s"; fi
```

**You MUST run this command and wait for it to finish before doing ANYTHING else.**

- Output says `BUGBOT_READY` → proceed to Step 2
- Output says `BUGBOT_TIMEOUT` → ask the user: "Bugbot did not complete in 15 min. Wait longer, proceed, or abort?"
- Status is `not_found` on every poll → ask: "No Cursor Bugbot check run found. Proceed or abort?"

**WARNING**: If you skip this wait and go straight to fetching threads, you WILL find 0 unresolved threads (because the bugbot hasn't posted them yet) and incorrectly conclude there is nothing to fix. This has happened before. Do not repeat it.

### Step 1b: Resolve Merge Conflicts

Check if the PR has merge conflicts with the base branch:

```bash
gh pr view {pr_number} --repo {owner}/{repo} --json mergeable --jq '.mergeable'
```

If the result is `"CONFLICTING"`:

1. **Fetch and merge the base branch**:
   ```bash
   git fetch origin {baseRefName}
   git merge origin/{baseRefName} --no-edit
   ```

2. **If merge conflicts exist**, resolve them:
   - For each conflicting file, read the file and find conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
   - Analyze both sides of the conflict to understand the intent
   - Prefer the more complete/recent version; if both add new code, keep both
   - Remove all conflict markers
   - Run the linter on each resolved file

3. **Commit and push** the merge resolution:
   ```bash
   git add -A
   git commit --no-verify -m "merge: resolve conflicts with {baseRefName}"
   git push --no-verify origin HEAD:{headRefName}
   ```

4. **Wait for bugbot to re-run** on the new merge commit using the same polling command from Step 1. The bugbot must complete on the post-merge HEAD before proceeding.

If the result is `"MERGEABLE"` or `"UNKNOWN"`, skip this step.

### Step 2: Create Worktree

Skip this step if `--no-worktree` is specified.

```bash
git fetch origin {headRefName}
git worktree add ../worktrees/fix-bugbot-{pr_number} origin/{headRefName}
cd ../worktrees/fix-bugbot-{pr_number}
```

Install dependencies in the worktree:

```bash
{{config:commands.deps.sync}}
```

If `--no-worktree` is specified:

```bash
git checkout {headRefName}
git pull origin {headRefName}
```

### Step 3: Begin Iteration Loop

Initialize iteration tracking:
- `iteration = 1`
- `max_iterations = 10` (or value from `--max-iter`)

**Loop starts here.** Each iteration fetches threads, fixes, pushes, resolves, then re-checks.

### Step 4: Fetch and Classify Bugbot Threads

Use the GitHub GraphQL API to fetch all review threads:

```bash
gh api graphql -f query='
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          startLine
          diffSide
          comments(first: 10) {
            nodes {
              body
              author {
                login
              }
              url
            }
          }
        }
      }
    }
  }
}' -f owner='{owner}' -f repo='{repo}' -F pr={pr_number}
```

**Filter:**
1. Keep only threads where `isResolved` is `false`
2. Keep only threads where at least one comment author matches a known bugbot login (e.g., `cursor-bot`, `cursor[bot]`, `github-actions[bot]`, or similar review bot patterns)
3. If no bugbot author is obvious, ask the user which author login to filter by

**If zero unresolved bugbot threads remain → exit the loop and go to Step 10 (Summary).**

**Classify each thread** by analyzing the comment body. Assign one of two dispositions:

**AUTO-FIX** — safe to fix automatically:
- Unused imports or variables
- Missing or incorrect type hints
- Code style / formatting violations
- Missing null/undefined checks
- Deprecated API usage (when replacement is clear)
- Missing error handling (adding guards, not changing flow)
- Simple logic bugs (off-by-one, wrong operator, typos)
- Security issues with obvious fix (hardcoded secret → env var)

**HUMAN-REVIEW** — requires human decision:
- Business logic changes (altering how a feature works)
- Architecture changes (moving code, changing patterns, restructuring)
- Data model changes (database schema, API contract changes)
- Removal or replacement of significant code blocks
- Changes that affect multiple services or modules
- Performance trade-offs (caching strategy, query optimization)
- Anything where the "right fix" is ambiguous or opinion-based

### Step 5: Display Bug Table

Present all bugs in a structured table:

```
Iteration {iteration}/{max_iterations} — Found {N} unresolved bugbot threads:

| #  | Bug                                          | Category          | Disposition  |
|----|----------------------------------------------|-------------------|--------------|
| 1  | `app/services/auth.py:42` — Unused import    | Unused import     | AUTO-FIX     |
| 2  | `app/api/routes/users.py:87` — Missing type   | Type hint         | AUTO-FIX     |
| 3  | `app/services/billing.py:156` — Rework retry  | Business logic    | HUMAN-REVIEW |
| 4  | `app/core/config.py:23` — Hardcoded timeout   | Security          | AUTO-FIX     |
| 5  | `app/services/sync.py:201` — Change arch      | Architecture      | HUMAN-REVIEW |

AUTO-FIX:     {X} bugs (will be fixed automatically)
HUMAN-REVIEW: {Y} bugs (require your decision)
```

If `--dry-run` is specified, stop here.

**Ask the user to confirm** before proceeding:
- "Proceed with auto-fixing {X} bugs? The {Y} HUMAN-REVIEW items will be presented individually for your decision."
- Wait for user confirmation.

### Step 6: Fix Auto-Fixable Bugs

Process each AUTO-FIX thread sequentially:

For each bug:

1. **Read the file** at the referenced path and line range. Include surrounding context (at least 20 lines before and after).

2. **Apply the fix** following the project's conventions as defined in `project.config.yaml` and any project-specific rules.

3. **Run the linter/formatter** immediately:
   ```bash
   {{config:commands.lint.fix}}
   ```

4. **Run targeted tests** for the affected area:
   ```bash
   {{config:commands.test.unit}} -k "test_{affected_module}"
   ```

5. **If tests fail** because of the fix, revise it. If the failure is pre-existing, note it and continue. Never leave a fix that breaks existing tests.

6. **Track the mapping** — record which `thread_id` was fixed.

### Step 7: Handle Human-Review Bugs

For each HUMAN-REVIEW thread, present it individually to the user:

```
HUMAN-REVIEW #{N}: {file_path}:{line}

Category: {category}
Bugbot says: {full comment body}

Code context:
  {10-20 lines of code around the flagged line}

Options:
  1. Provide fix instructions (tell me what to do)
  2. Skip this one (leave unresolved)
  3. It's actually safe to auto-fix (reclassify)
```

Based on user response:
- **Option 1**: Apply the user's instructions, test, and track for resolution
- **Option 2**: Skip — do not fix or resolve this thread
- **Option 3**: Reclassify as AUTO-FIX and apply the fix

### Step 8: Verify, Commit, and Push

After all fixes for this iteration are applied:

1. **Full test suite**:
   ```bash
   {{config:commands.test.unit}}
   ```

2. **Compliance checks** (if configured):
   ```bash
   {{config:commands.compliance.fast}}
   ```

3. **Lint check**:
   ```bash
   {{config:commands.lint.check}}
   ```

If any failures, identify which fix caused it, revise, and re-verify.

**Commit and push:**

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix: resolve bugbot issues from PR #{pr_number} (iteration {iteration})

Auto-fixed:
- {file_path}:{line} — {short description}
- {file_path}:{line} — {short description}

Human-reviewed:
- {file_path}:{line} — {short description}

Skipped: {K} threads (HUMAN-REVIEW, user chose to skip)

EOF
)"
```

```bash
git push origin HEAD:{headRefName}
```

### Step 9: Resolve Conversations and Loop

For each successfully fixed thread, resolve the conversation:

```bash
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread {
      isResolved
    }
  }
}' -f threadId='{thread_id}'
```

If `--no-resolve` is specified, skip resolution but still loop.

**Iteration report:**

```
Iteration {iteration}/{max_iterations} complete:
  Resolved:      {N} threads
  Skipped:       {M} threads (user chose to skip)
  Failed:        {K} threads (API error)
  Remaining:     {R} unresolved bugbot threads
```

**Loop decision:**
- If remaining == 0 → **do not exit yet**. The pushed fixes may trigger a new bugbot run that finds new issues. Proceed to the re-verification step below.
- If iteration >= max_iterations → exit loop, go to Step 10 with warning
- Otherwise → proceed to re-verification below

**Re-verification: Wait for bugbot to re-run after push (BLOCKING)**

After pushing, the bugbot re-triggers on the new HEAD. Run the **exact same bugbot-wait bash command from Step 1** again (it picks up the new HEAD SHA automatically). Wait for it to print `BUGBOT_READY` before continuing.

Once the bugbot re-run is confirmed complete:
- Increment iteration
- Go back to **Step 5** to re-fetch threads
- If Step 4 finds zero unresolved threads → the PR is genuinely clean, proceed to Step 9b
- If Step 4 finds new threads → the pushed fixes introduced new issues, continue fixing

### Step 9b: Check All CI Statuses

After all bugbot threads are resolved (or after each iteration's push), check **all** CI check statuses on the PR — not just bugbot:

```bash
gh pr checks {pr_number} --repo {owner}/{repo}
```

**If all checks pass** → proceed to Step 10 (Final Summary).

**If any checks fail**, investigate each failing check:

1. **Get the failure logs**:
   ```bash
   gh run view {run_id} --repo {owner}/{repo} --log-failed 2>&1 | tail -80
   ```

2. **Classify the failure**:

   | Failure Type | Action |
   |---|---|
   | **test-migrations** — column/table already exists | Make migration idempotent (add `_col_exists`/`_table_exists` guards) |
   | **test-migrations** — SQL syntax error | Fix the migration SQL |
   | **test** — unit/integration test failure caused by this PR's changes | Fix the code or test |
   | **test** — cancelled (dependency on another failing check) | Fix the root cause check first |
   | **lint / compliance** — formatting or compliance violation | Run `{{config:commands.lint.fix}}` and `{{config:commands.compliance.fast}}` |
   | **test** — pre-existing failure unrelated to PR | Note it and skip |

3. **Fix, commit, and push** the CI fix:
   ```bash
   git add -A
   git commit --no-verify -m "fix: resolve CI failures (iteration {iteration})"
   git push --no-verify origin HEAD:{headRefName}
   ```

4. **Wait for CI to re-run** — poll all checks until they complete:
   ```bash
   gh pr checks {pr_number} --repo {owner}/{repo} --watch
   ```
   If `--watch` is not available, poll manually every 30 seconds using `gh pr checks`.

5. **If fixes introduce new bugbot threads**, loop back to Step 4.

6. **If CI still fails after fix attempt**, report the remaining failures to the user and ask whether to continue or abort.

**This step is critical** — bugbot threads being resolved does NOT mean the PR is ready to merge. All CI checks must also pass.

### Step 10: Final Summary

```
PR BUGFIX COMPLETE — PR #{pr_number}
=====================================

Iterations:       {iteration}/{max_iterations}
Total resolved:   {total_resolved} threads
Total skipped:    {total_skipped} threads (HUMAN-REVIEW, user skipped)
Total failed:     {total_failed} threads
Remaining:        {remaining} unresolved bugbot threads
CI status:        {all_pass | N failing}

{If remaining > 0 and iteration >= max_iterations:
  "Max iterations reached. {remaining} threads still unresolved.
   Re-run /pr-bugfix to continue, or address remaining items manually."}

{If remaining == 0 and CI all pass:
  "All bugbot threads resolved and all CI checks pass.
   PR is clean and ready to merge."}

{If remaining == 0 and CI has failures:
  "All bugbot threads resolved but {N} CI checks still failing:
   - {check_name}: {failure reason}
   Address remaining CI failures manually or re-run /pr-bugfix."}

Commits pushed:   {N} commits to branch {headRefName}
```

</workflow>

## Bug Classification Reference

### AUTO-FIX Categories

| Category | Signals in Comment | Fix Strategy |
|----------|-------------------|--------------|
| Unused import | "imported but unused", "unused import" | Remove the import |
| Unused variable | "assigned but never used", "unused variable" | Remove or use the variable |
| Type hint | "incompatible type", "missing return type", "missing annotation" | Add or correct type annotations |
| Null safety | "possibly null", "optional access", "may be None" | Add null checks or guard clauses |
| Code style | "naming convention", "line too long", "whitespace" | Reformat following project conventions |
| Deprecated API | "deprecated", "use X instead" | Replace with the recommended alternative |
| Error handling | "bare except", "unhandled exception", "missing error" | Add specific exception handling |
| Security (simple) | "hardcoded secret", "hardcoded password" | Move to config/env var |

### HUMAN-REVIEW Categories

| Category | Signals in Comment | Why Human Needed |
|----------|-------------------|-----------------|
| Business logic | "should instead", "logic should be", "rework", "redesign" | Changes how the feature behaves |
| Architecture | "move to", "restructure", "extract into", "split this" | Changes code organization or patterns |
| Data model | "schema change", "add column", "migration", "API contract" | Affects database or API consumers |
| Performance | "optimize", "cache", "N+1 query", "batch" | Trade-offs between approaches |
| Multi-service | References multiple services, "coupling", "dependency" | Cross-cutting changes need coordination |
| Ambiguous | Comment is unclear or suggests multiple approaches | "Right fix" is opinion-based |

## Rules

### NEVER
- Skip or shortcut the bugbot wait (Step 2) — resolved threads from a previous run do NOT mean the current run is done
- Fetch threads before the bugbot check run shows `completed` on the current HEAD commit
- Auto-fix a HUMAN-REVIEW bug without explicit user approval
- Resolve a PR conversation without actually fixing the underlying issue
- Push code that fails tests or lint checks
- Skip the verification step — every fix must be validated
- Modify files unrelated to the bugbot comments
- Force-push to the branch — always use regular push
- Exceed max iterations without stopping
- Proceed without user confirmation after displaying the bug table

### ALWAYS
- Wait for bugbot to finish before starting
- Classify every bug before fixing anything
- Present the bug table and get user confirmation
- Escalate HUMAN-REVIEW items individually with full context
- Run tests after each fix to catch regressions early
- Preserve the project's code style and conventions
- Track which thread IDs map to which fixes
- Loop until all threads are resolved or max iterations reached
- Report a clear summary after each iteration and at the end

## Worktree Cleanup

After all iterations are done and the user has verified the fixes:

```bash
cd {original_repo_root}
git worktree remove ../worktrees/fix-bugbot-{pr_number}
```

Only clean up when the user confirms — don't auto-delete.

## Integration

This skill works with:
- GitHub GraphQL API and REST API via `gh` CLI
- GitHub check runs API (for bugbot status polling)
- Git worktrees (for isolated fix branches)
- Project test suite (as defined in `project.config.yaml`)
- Project linter and formatter
- Project compliance checks

## Notes

- The `gh` CLI must be authenticated (`gh auth status`) before running this skill
- GraphQL thread IDs are opaque strings — don't try to parse or construct them
- Classify ambiguous bugbot comments as HUMAN-REVIEW when uncertain
- For PRs with 100+ review threads, use cursor-based pagination in the GraphQL query
- Check `project.config.yaml` for project-specific commands
