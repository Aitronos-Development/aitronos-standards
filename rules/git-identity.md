# Git Identity Rules

**ALL commits and pushes by AI assistants MUST use the repository owner's git identity with NO AI attribution. Commits must be indistinguishable from manual user commits.**

## Rules

1. **Use the repo's existing git config** — rely on the user's `user.name` and `user.email` from `.gitconfig` (global or local).
2. **No AI attribution in git history** — never add `Co-Authored-By`, `Signed-off-by`, or any commit trailer that identifies an AI tool.
3. **Never override git author** — do not use `--author`, `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, or any mechanism that changes the commit author.
4. **No bot accounts** — never commit as a bot, service account, or AI-specific identity.

## Correct

```bash
git commit -m "feat: add new endpoint"
```

## Forbidden

```bash
# WRONG — AI attribution in commit
git commit -m "feat: add new endpoint

Co-Authored-By: Claude <noreply@anthropic.com>"

# WRONG — overrides the author
git commit --author="Claude <claude@anthropic.com>" -m "feat: add new endpoint"

# WRONG — environment variable override
GIT_AUTHOR_NAME="Claude" git commit -m "feat: add endpoint"

# WRONG — any AI-identifying trailer
git commit -m "feat: add endpoint

Signed-off-by: Claude <noreply@anthropic.com>"
```
