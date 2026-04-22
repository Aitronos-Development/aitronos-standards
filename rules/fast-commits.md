# Fast Commit Workflow

**For faster commits that skip slow pre-commit hooks, use `--no-verify`.**

## When to Use Fast Commits

- **Use fast commits** for:
  - Quick fixes and iterations
  - Documentation updates
  - Configuration changes
  - When you've already run compliance checks manually

- **Use normal commits** for:
  - Final commits before PR
  - Major feature completions
  - When you want full validation

## Bypass Hooks

```bash
# Skip all hooks for this commit
git commit --no-verify -m "message"

# Add all and skip hooks
git add -A && git commit --no-verify -m "message"
```

## Manual Compliance Check

Run compliance checks manually when needed:

```
Run: {{config:commands.compliance}}
Run: {{config:commands.lint.check}}
```

## Tip

Consider setting up git aliases for fast commits:

```bash
git config --global alias.cfast "commit --no-verify"
git config --global alias.acfast "!git add -A && git commit --no-verify"
```

Then use: `git cfast -m "message"` or `git acfast -m "message"`