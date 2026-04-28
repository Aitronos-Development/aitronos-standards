# No Implicit Branch Switching or Stashing

**AI agents (Claude Code, Cursor, Windsurf, sub-agents, automation, anything not the human) MUST NOT switch branches OR create stashes without explicit, in-conversation user confirmation. This is non-overridable.**

## Why

Silent branch switches and auto-stashes have repeatedly produced "branch mess":
- Commits made on the wrong branch (e.g. landing on `feat/auth-ui-polish` while the user expected `develop`)
- Detached HEAD states left behind by `git checkout <sha>` or by submodule operations
- WIP buried in stashes the user never asked for, then forgotten
- `git pull --autostash`, `git rebase --autostash`, `git stash`, and `git checkout <branch>` all qualify as silent state changes when triggered by an agent

Recovery from these states is expensive and risks losing work. The fix is prevention: never move branches or hide working-tree state without saying so first and getting a yes.

## The Rule

### Forbidden without explicit confirmation in the current turn

| Operation | Why it's restricted |
|---|---|
| `git checkout <branch>` / `git switch <branch>` | Changes which branch the next commit lands on |
| `git checkout <sha>` / `git switch --detach` | Creates detached HEAD |
| `git checkout <file>` against modified files | Discards user changes |
| `git stash` / `git stash push` | Hides working-tree state |
| `git stash pop` / `git stash apply` | Reapplies hidden state, may conflict |
| `git pull --autostash` | Implicit stash + pop around the pull |
| `git rebase --autostash` | Same — implicit stash + pop |
| `git pull` while working tree is dirty | May trigger merge or autostash silently |
| `git reset --hard` | Discards working tree |
| `git clean` | Discards untracked files |
| `git worktree add` / `git worktree remove` | Changes the worktree set |
| Submodule branch switches (`cd packages/ui-kit && git checkout …`) | Same rule applies to every submodule |

"Explicit confirmation" means the user said yes **in the current conversation** to **this specific action** (e.g. "yes, switch to develop"). A previous-turn approval does NOT extend to a new operation. A standing rule like "always work on develop" does NOT count as confirmation for the act of switching — the agent must still ask before executing the switch.

### Allowed without confirmation

- Read-only inspection: `git status`, `git log`, `git diff`, `git branch`, `git reflog`, `git show`, `git ls-tree`, `git rev-parse`, `git fetch` (does not modify working tree or current branch).
- Staging and committing **on the current branch** with the working-tree state the user already produced (`git add`, `git commit`).
- Pushing the current branch to its existing upstream (`git push`) — provided no branch switch or stash was needed to reach this state.

### Required workflow when a branch switch or stash is necessary

1. **Stop and report.** State exactly what is currently checked out, what the working tree looks like, and what operation would be needed.
2. **Propose the plan in plain language.** "I'd like to: (a) commit current changes on `<X>`, (b) checkout `<Y>`, (c) merge, (d) push." Include any stash/autostash steps.
3. **Wait for an explicit yes.** No partial / implicit / inferred consent. If the user replies with anything ambiguous, ask again.
4. **Execute only the confirmed steps.** Do not chain follow-on branch switches without re-confirming.
5. **Report each branch-changing step as it happens** so the user can interrupt.

### Special: pulling on a dirty working tree

If the agent wants to pull and the working tree has uncommitted changes:
- Do NOT use `--autostash`.
- Do NOT manually stash.
- Stop, report the dirty files, and ask the user to either commit, discard, or explicitly authorise a stash-and-pop sequence.

### Special: detached HEAD

If the agent finds itself or the user on a detached HEAD:
- Do not commit on it without confirmation — commits on a detached HEAD are easy to lose.
- Surface the situation, identify which named branch (if any) contains the current commit, and ask the user which branch the work should land on before doing anything else.

### Special: submodules

Every submodule (`packages/ui-kit`, `.standards`, etc.) is its own repository and this rule applies independently to each. Switching the submodule's branch — even just to "follow" the parent — requires the same explicit confirmation.

## What this rule does NOT restrict

- The human user switching branches themselves.
- The agent making and committing code changes on the branch the user is already on.
- The agent reading any git state.
- `git fetch` (does not modify HEAD or working tree).

## How to apply

When in doubt, ask. The cost of a one-line "should I switch to develop?" question is trivial; the cost of an unwanted branch switch can be hours of cleanup. Treat every checkout/stash/reset as a request for permission, not a step in a procedure.
