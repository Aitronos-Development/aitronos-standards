---
name: commit-push
description: Stage all changes, run compliance checks, fix any issues, commit, and push. Use when you want a one-command commit-and-push workflow.
disable-model-invocation: false
user-invocable: true
---

# Commit & Push Skill

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling.

Stage all changes, run compliance and type checks, fix any issues found, then commit and push.

## When to Use

- You want to commit and push your work in one step
- You want compliance/lint/type issues caught and fixed before the commit lands

## Usage

User invocation:
```
/commit-push <commit message>
```

Or without a message (will be prompted):
```
/commit-push
```

## Workflow

<workflow>

### Step 1: Check for Changes

```bash
git status --porcelain
```

If no changes exist, inform the user and stop.

### Step 2: Stage All Changes

```bash
git add -A
```

### Step 3: Run Type Checking

```bash
npx tsc --noEmit
```

If there are type errors, fix them. Re-run until clean.

### Step 4: Run Compliance Checks

```bash
{{config:commands.compliance.fast}}
```

If there are violations:
1. **Auto-fix** what can be fixed (formatting, linting, imports):
   ```bash
   {{config:commands.lint.fix}}
   ```
2. **Manually fix** remaining issues (naming, complexity, file size, etc.)
3. **Re-run compliance** to confirm zero errors

Repeat until compliance passes with 0 errors.

### Step 5: Re-stage After Fixes

If any files were modified during fix steps:

```bash
git add -A
```

### Step 6: Commit

If the user provided a commit message, use it. Otherwise, generate a conventional commit message based on the staged changes.

```bash
git commit -m "<message>"
```

Use conventional commit prefixes: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `style:`, `test:`.

### Step 7: Push

```bash
git push
```

If the branch has no upstream, set it:

```bash
git push --set-upstream origin <current-branch>
```

### Step 8: Summary

Report:
- **Branch**: which branch was pushed
- **Commit**: the short SHA and message
- **Fixes applied**: list any compliance/type issues that were auto-fixed
- **Files changed**: count of files in the commit

</workflow>

## Error Handling

- **Merge conflicts on push**: Inform the user; do not force-push.
- **Unfixable compliance errors**: List remaining issues and ask the user how to proceed. Do not commit with known errors unless the user explicitly approves.
- **No changes**: Exit early with a message.

## Notes

- This skill respects the project's compliance and lint configuration
- It never force-pushes — if push is rejected, it reports the issue
- For UI Kit changes (in `packages/ui-kit/`), remind the user that the submodule has its own git repo and needs separate commit/push
