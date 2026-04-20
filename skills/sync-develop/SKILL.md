---
name: sync-develop
description: Pull and merge the latest upstream changes from the main branch safely. Analyzes the remote, classifies every potential conflict, presents a proposed merge strategy for approval, then executes it — committing local work before merging, auto-resolving additive overlaps, and generating an alembic merge migration when two DB migration heads appear. NEVER stashes, NEVER force-pushes, NEVER runs destructive git commands without explicit approval.
disable-model-invocation: false
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Edit, AskUserQuestion, TaskCreate, TaskUpdate
---

# Sync Develop — Pull, Analyze, Propose, Execute

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines the main branch name, migration tool, and other project-specific details. Default main branch is `develop`. If the project uses a different name (`main`, `master`, `trunk`), use that instead.

Bring the local branch up to date with the remote main branch **safely**. The skill never touches your working tree destructively: it always commits or confirms before merging, classifies every overlapping file before acting, and asks for approval before executing any strategy that could produce a conflict.

## ABSOLUTE RULES

1. **NEVER `git stash`** — if the working tree is dirty, commit it or ask the user. Stashing hides work.
2. **NEVER `git reset --hard`, `git checkout .`, or `git clean -f`** — these destroy uncommitted work.
3. **NEVER `git push --force`** — this skill never pushes. It only pulls and merges locally.
4. **NEVER `--no-verify`** — if pre-commit hooks fail on the local commit, fix the code.
5. **NEVER execute a merge strategy without explicit user approval** when overlaps or migration head branching are detected.
6. **ALWAYS present a conflict classification** before proposing a strategy — the user needs to see what's actually conflicting.
7. **ALWAYS generate an alembic merge migration** (or the project's equivalent) when two migration heads appear after the merge.

## Usage

```
/sync-develop
/sync-develop main            # override main branch name
```

## Inputs

- Positional arg (optional): name of the main branch to sync against. Defaults to `develop`, or reads from `project.config.yaml` if present.

---

## Workflow

### Step 1 — Snapshot the current state

Read everything needed to reason about the merge **before** touching anything.

```bash
# Current branch + remote
git branch --show-current
git remote -v

# Dirty tree?
git status --short

# Fetch without merging
git fetch origin

# Ahead / behind
git log --oneline HEAD..origin/<main>      # commits remote has that we don't
git log --oneline origin/<main>..HEAD      # commits we have that remote doesn't
```

Create a task list with `TaskCreate` tracking: snapshot → commit-local → merge → migration-heads → verify → report.

### Step 2 — Classify the dirty tree

If `git status` shows modifications/untracked files, decide what to do with them **before** pulling.

1. List every modified/untracked file.
2. Get the diff of files that were modified locally: `git diff --stat` and `git diff` on changed files.
3. Determine intent: is this in-progress work that belongs on this branch? Or accidental edits?
4. If in-progress work on the correct branch → **commit it first** (Step 4 will do this with approval).
5. If the user is unsure → stop and ask with `AskUserQuestion`.

**Never stash.** If the user says "hold it aside" — suggest a new branch (`git switch -c wip/<name>`) instead.

### Step 3 — Classify overlaps and conflicts

This is the core of the skill. Before proposing a strategy, build an evidence-based conflict report.

#### 3a. List overlapping files

```bash
# Files the remote touches
git diff --name-only HEAD...origin/<main>

# Files you've touched (dirty + committed-but-unpushed)
git diff --name-only HEAD
git diff --name-only origin/<main>..HEAD
```

An **overlap** is any file that appears in both lists. Overlaps *may or may not* become real merge conflicts — git's recursive/ort merger auto-resolves most additive edits in different regions.

#### 3b. Classify each overlap

For each overlapping file, diff both sides and classify:

| Category | Description | Auto-resolvable? |
|---|---|---|
| **Identical edit** | Both sides made the same change | Yes (no-op merge) |
| **Additive, different region** | Both sides added content in different parts of the file (imports at different line ranges, new entries in different dict blocks) | **Usually yes** — git ort handles this |
| **Additive, adjacent lines** | Both sides added content within a few lines of each other | **Likely conflict** — git marks the block |
| **Overlapping edit, same lines** | Both sides modified the same line | **Definite conflict** — manual resolution |
| **Rename vs edit** | One side renamed, other edited | **Likely conflict** |
| **Delete vs edit** | One side deleted, other modified | **Conflict** — needs decision |

Commands for evidence:

```bash
git diff HEAD -- <file>                    # what you changed
git diff HEAD origin/<main> -- <file>      # what remote changed
git diff --check HEAD origin/<main>        # cheap conflict predictor
```

#### 3c. Check migration heads

This is project-specific but critical for Freddy/Aitronos projects using Alembic.

```bash
# Find your new migration(s)
grep -l "down_revision" alembic/versions/*.py | xargs grep -lE "^revision: str = '[a-f0-9]{12}'"

# Look at what the remote's migrations chain off of
for f in <new-remote-migration-files>; do
  git show origin/<main>:$f | grep -E "^(revision|down_revision)"
done

# Local new migration
grep -E "^(revision|down_revision)" alembic/versions/<your-new-migration>.py
```

If your local migration's `down_revision` matches a migration that the remote also built on top of → after merge there will be **two heads**, requiring `alembic merge heads`.

Non-Python projects: check whatever migration/schema tool is used (Prisma, Flyway, Sqitch, etc.) for equivalent branching.

### Step 4 — Propose a strategy (REQUIRES APPROVAL)

Use `AskUserQuestion` with a clear classification summary + proposed strategy. The question must show:

- Number of remote commits to pull
- Number of overlapping files and their classifications
- Presence of migration head branching (yes/no + head IDs)
- Recommended strategy (one of the three below)
- Alternative strategies with trade-offs

#### Strategy options (present all three when conflicts exist)

**Option 1 — Commit local → merge → fix migration (default / recommended):**
```bash
git add <files>
git commit -m "<message>"
git pull --no-rebase origin <main>
# if conflicts: resolve manually, git add, git merge --continue
# if migration heads: uv run alembic merge heads -m "merge <topic> heads"
```

Pros: preserves both histories, never rewrites commits, easiest to recover from.
Cons: produces a merge commit (some teams prefer linear history).

**Option 2 — Commit local → rebase onto origin:**
```bash
git add <files>
git commit -m "<message>"
git pull --rebase origin <main>
# if conflicts: resolve per commit, git add, git rebase --continue
# if migration heads: alembic merge after rebase completes
```

Pros: linear history.
Cons: rewrites local commit SHAs — bad if already pushed anywhere.

**Option 3 — Abort and report:**
Don't pull. Report the situation and let the user decide manually.

**If the tree is clean (no dirty files) AND no overlaps AND no migration branching** → fast-forward merge is safe without asking. Just run `git pull --ff-only` and report.

### Step 5 — Execute the approved strategy

Run the chosen strategy step-by-step, verifying each step:

1. **Commit local work** (if strategy chose it):
   - Stage explicit files by name — never `git add -A` / `git add .` (can pull in secrets).
   - Use a HEREDOC commit message that summarizes *what* and *why*.
   - Let pre-commit hooks run. If they fail → fix the code, re-stage, re-commit. **Never `--no-verify`**.

2. **Pull / merge / rebase** per strategy.

3. **If git reports conflicts**:
   - Read each conflicted file, resolve each `<<<<<<<` block based on intent (use diffs from Step 3 as context).
   - `git add <resolved-file>` for each.
   - `git merge --continue` or `git rebase --continue`.
   - If the merge gets too gnarly → `git merge --abort` / `git rebase --abort` and re-ask the user.

4. **Migration heads**:
   - `alembic heads` → confirm multiple heads.
   - `alembic merge heads -m "merge <topic-a> and <topic-b> heads"` → generates a no-op merge migration.
   - Verify only one head remains.
   - Stage + commit the merge migration with message `chore(alembic): merge <topic-a> and <topic-b> heads`.

### Step 6 — Verify

Run cheap smoke checks to confirm nothing is broken:

```bash
# Schema / migration sanity
uv run alembic heads                        # exactly one head
uv run alembic upgrade head                 # applies cleanly (skip if DB isn't running — note it)

# Import sanity (Python projects)
uv run python -c "from app.api.v1.routes import v1_router; print(len(v1_router.routes))"

# Ruff / format (cheap)
uvx ruff check . --quiet || true
```

Do NOT run the full test suite — that's outside this skill's scope. The goal is "merge didn't break imports or schema."

### Step 7 — Report

Summary to the user:

- Number of commits pulled.
- Number of files auto-merged vs manually resolved.
- Whether a migration merge migration was created (and its file path).
- Anything skipped (e.g., DB not running for `alembic upgrade`).
- Any follow-up the user should do (run tests, push, etc.).

**Do NOT push.** This skill never pushes. The user pushes when ready.

---

## Conflict Report Template

When presenting to the user in Step 4, use this format:

```
## Sync Plan — <branch> ← origin/<main>

**Remote:** <N> new commits
**Local:** <N> commits ahead + <dirty/clean> working tree

### Overlapping files (<N>)

| File | Local change | Remote change | Classification | Auto-resolvable |
|---|---|---|---|---|
| <path> | <brief> | <brief> | <category> | Yes/No |
| ... | | | | |

### Migration heads

After merge: <N> heads (<ids>). Merge migration needed: <Yes/No>.

### Proposed strategy

<name> — <one-sentence rationale>

### Risks

- <risk 1>
- <risk 2>
```

---

## Edge cases

### Submodules with dirty content

`git status` may show `docs/public-docs (modified content)`. Submodules follow the same rules:
- If the submodule's working tree is dirty → cd into it, snapshot and commit there first (or warn the user and leave it alone).
- Never auto-update submodule pointers during this skill — that's what `/commit-push` does.

### Multiple remote tags / branches

`git fetch` pulls tags and branches by default. That's fine. Ignore tags in the conflict analysis.

### Remote has force-pushed

Detect with `git log HEAD..origin/<main>` showing commits you thought were gone, or `git reflog` divergence. **Stop and ask the user** — never silently rewrite history by rebasing onto a force-pushed branch.

### You're on a feature branch, not the main branch

This skill targets the main branch (`develop` by default). If run from a feature branch:
- Default behavior: sync the feature branch with `origin/<feature-branch>` (not `origin/<main>`).
- If the user wants to pull main into the feature branch (`git pull origin <main>`), ask explicitly — that's a different operation.

### No upstream tracking

If `git branch -vv` shows no upstream → ask the user whether to set one with `-u` or bail.

---

## What this skill deliberately does NOT do

- Does not push (use `/commit-push` after).
- Does not run tests (run tests separately).
- Does not update submodules (use `/commit-push`).
- Does not cherry-pick (outside scope).
- Does not resolve conflicts silently without user awareness — if manual resolution is needed, it's surfaced.
- Does not stash, reset, clean, or force.
