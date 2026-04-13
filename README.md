# Aitronos Engineering Standards

Shared engineering standards for all Aitronos projects. Rules, skills, and agents that work with Claude Code (and other AI coding tools).

**First time?** See [SETUP.md](SETUP.md) for installation instructions.

---

## Quick Reference

### Rules

Rules are engineering standards loaded automatically from `.claude/rules/`. Each is a standalone Markdown file.

| Rule | What It Covers |
|------|----------------|
| `branch-naming.md` | Branch naming conventions (feat/, fix/, hotfix/, etc.) |
| `code-organization.md` | No duplicate helpers — extract shared utilities to dedicated modules |
| `compliance-thresholds.md` | File size limits, function complexity, line length, test coverage |
| `documentation-style.md` | Concise docstrings (1-5 lines), focus on "why" not "what" |
| `fast-commits.md` | Git aliases for fast commits that skip slow pre-commit hooks |
| `logging.md` | Never use print() in application code — use proper logging |
| `planning.md` | Always check existing implementations before planning new features |
| `secrets-management.md` | Never hardcode secrets — use .env locally, GitHub Secrets in CI/CD |
| `self-testable-code.md` | All code must be self-tested before shipping |
| `start-dev.md` | Every project must have a `start-dev.sh` — zero to running in one command |
| `task-reference-comments.md` | No "Task X.Y:" comments — use TODO/FIXME or proper comments |
| `vendor-terms.md` | Never expose third-party vendor names in public docs, API specs, or API-facing code |

### Skills

Skills are multi-step workflows invoked with `/skill-name` during a Claude Code session.

| Skill | How to invoke | What It Does |
|-------|---------------|--------------|
| `compliance-fix` | `/compliance-fix` | Detect and auto-fix compliance violations |
| `orchestrate` | `/orchestrate` | Orchestrator playbook — four modes for team-based development |
| `qa` | `/qa` | Quality assurance — tests, API verification, coverage, security |
| `security-fix` | `/security-fix` | Detect and fix security issues |
| `setup` | `/setup` | Re-run standards setup (add new symlinks after repo update) |
| `tech-review` | `/tech-review` | Code review workflow against a spec |
| `tech-spec` | `/tech-spec` | Create technical specifications for new features |
| `test-fix` | `/test-fix` | Diagnose and fix failing tests |

### Agents

Agents are persistent identities that shape Claude's behavior for an entire session — including after context compaction. Unlike skills (invoked once), agents define who Claude **is**.

| Agent | What It Is |
|-------|------------|
| `orchestrator` | Team lead that delegates to sub-developers, never writes code. Four modes: spec, execute, tasks, live. |

---

## Using the Orchestrator

The orchestrator is the primary agent for managing complex, multi-agent development work.

### Launch it

```bash
claude --agent orchestrator
```

This loads the orchestrator identity for the entire session. After context compaction, the identity reloads from disk automatically — the orchestrator never forgets what it is.

### Or invoke the skill

If you're already in a regular Claude Code session, invoke the orchestrator workflow as a one-off skill:

```
/orchestrate
```

### How the pieces fit together

| Component | What it does | Where it lives |
|-----------|-------------|----------------|
| **Agent definition** | Persistent identity — who Claude is, what it can/can't do | `.claude/agents/orchestrator.md` |
| **`/orchestrate` skill** | Operational playbook — detailed workflows for each mode | `.claude/skills/orchestrate/SKILL.md` |
| **PreCompact hook** | Snapshots active teams and tasks before context compaction | `.claude/settings.json` → runs `scripts/orchestrator-state-snapshot.py` |
| **Agent memory** | Learnings persisted across sessions | `.claude/agent-memory/orchestrator/` |

### Four modes

| Mode | When to use | What happens |
|------|-------------|--------------|
| **spec** | "Let's spec out X", "Create a spec for Y" | Deep research, create technical specifications |
| **execute** | "Execute phase N", "Implement the X spec" | Read spec, spawn developers, monitor, verify |
| **tasks** | "Fix these bugs", "Here are some tasks" | Parse items, create tasks, spawn developers immediately |
| **live** | Ongoing conversation, iterative requests | Real-time dispatch — research, delegate, iterate |

### Code write guardrail

A `PreToolUse` hook defined in the orchestrator's agent frontmatter **blocks** any `Edit` or `Write` to non-documentation files. If the orchestrator tries to modify a `.py`, `.ts`, `.tsx`, or other code file, the tool call is blocked (exit code 2) and Claude receives a message telling it to delegate to a developer agent instead.

**Allowed** (orchestrator can write directly):
- `.md`, `.mdc`, `.mdx`, `.txt`, `.yaml`, `.yml` files
- Files in `docs/`, `.claude/`, `.standards/`, `.specs/`, `.agent/`, `.kiro/`, `.cursor/` directories

**Blocked** (must delegate to a developer agent):
- Everything else — Python, TypeScript, JSON configs, Dockerfiles, etc.

The guardrail lives in `scripts/orchestrator-guardrail.sh` and only fires when running as the orchestrator agent. Normal Claude Code sessions are unaffected.

### Context compaction recovery

When context is compacted, the orchestrator recovers by:

1. Reading the **PreCompact hook snapshot** (injected automatically into fresh context)
2. Running **`TaskList`** to see current tasks, owners, and status
3. Checking **`ROADMAP.md`** for project phase progress
4. Reading **agent memory** for session notes

This is why the PreCompact hook matters — without it, the orchestrator can recover from agent definition + task list, but the hook makes it faster by providing an immediate state summary.

---

## Project Configuration

Every project needs a `project.config.yaml` to map standards to its specific commands and paths.

```yaml
project:
  name: "My.Backend"
  type: "backend"
  language: "python"
  framework: "fastapi"
  package_manager: "uv"

commands:
  test:
    unit: "uv run pytest tests/ -x"
  lint:
    check: "uvx ruff check ."
  dev:
    start: "./start-dev.sh"

paths:
  source: "app/"
  tests: "tests/"
```

Skills and agents reference these values with `{{config:*}}` placeholders (e.g., `{{config:commands.test.unit}}`).

See `project.config.example.yaml` for the full list of fields.

---

## Updating Standards

### Automatic (recommended)

A **post-merge git hook** is installed by `setup.sh`. After any `git pull` or `git merge` that updates the `.standards` submodule, the hook automatically:
1. Initializes and checks out the new submodule commit
2. Removes stale symlinks (pointing to deleted standards)
3. Creates symlinks for any **new** rules, skills, or agents
4. Ensures the PreCompact hook and post-merge hook are configured

No manual steps needed — just commit the updated submodule pointer:
```bash
git add .standards .claude
git commit -m "chore: update shared engineering standards"
```

### Manual

To pull updates explicitly (e.g., before the submodule pointer is committed upstream):

```bash
.standards/scripts/update.sh
```

This does the same as the automatic hook, plus fetches the latest remote commit.

It never overwrites local overrides — existing files and symlinks are left untouched.

---

## Overriding Standards

To replace any shared standard with a project-specific version:

1. Delete the symlink in `.claude/rules/`, `.claude/skills/`, or `.claude/agents/`
2. Create a local file (or directory) with the same name

```bash
rm .claude/rules/logging.md
cat > .claude/rules/logging.md << 'EOF'
# Logging Rules (Project Override)
Use structlog for all logging in this project.
EOF
```

To revert, delete the local file and re-run `.standards/scripts/setup.sh`.

---

## Contributing

### Adding a rule

1. Create a `.md` file in `rules/`
2. Follow the existing pattern: clear title, rationale, correct/incorrect examples
3. Keep it universal — use `{{config:*}}` placeholders, no project-specific values

### Adding a skill

1. Create a directory in `skills/` with a `SKILL.md` file
2. Add YAML frontmatter: `name`, `description`, `user-invocable`
3. Reference config with `{{config:*}}` instead of hardcoded values

### Adding an agent

1. Create a `.md` file in `agents/`
2. Add YAML frontmatter: `name`, `description`, and optional `memory`, `model`
3. Define the agent's identity, capabilities, and boundaries

### Guidelines

- Standards must be **language-agnostic** where possible
- Standards must be **self-contained** (each works independently)
- Write for **AI coding tools** as the primary audience
- Keep rules **concise** — aim for one page

---

## Repository Structure

```
aitronos-standards/
  agents/
    orchestrator.md             # Team lead agent definition
  guides/
    start-dev-reference.md        # Full start-dev.sh implementation guide with skeleton
    vendor-terms-validators.md    # Two-layer vendor term enforcement setup guide
  rules/
    branch-naming.md
    code-organization.md
    compliance-thresholds.md
    documentation-style.md
    fast-commits.md
    logging.md
    planning.md
    secrets-management.md
    self-testable-code.md
    start-dev.md
    task-reference-comments.md
    vendor-terms.md
  skills/
    compliance-fix/SKILL.md
    orchestrate/SKILL.md
    qa/SKILL.md
    security-fix/SKILL.md
    setup/SKILL.md
    tech-review/SKILL.md
    tech-spec/SKILL.md
    test-fix/SKILL.md
  scripts/
    setup.sh                    # First-time project setup
    update.sh                   # Pull latest standards and wire new symlinks
    orchestrator-guardrail.sh   # PreToolUse hook — blocks code writes in orchestrator mode
    orchestrator-state-snapshot.py  # PreCompact hook — snapshots state before compaction
    hooks/
      post-merge                # Auto-syncs standards after git pull/merge
  project.config.example.yaml
  SETUP.md                      # Installation guide
  README.md                     # This file
```

## FAQ

**Q: Do I need Claude Code to use this?**
No. The `scripts/setup.sh` script works standalone. The rules are also useful as human-readable engineering guidelines. However, skills and agents are designed for Claude Code.

**Q: What happens if I don't create a project.config.yaml?**
Skills and agents that reference `{{config:*}}` placeholders won't know your project-specific commands. Rules (static guidelines) still work fine.

**Q: Can I use this with Cursor or Windsurf?**
Rules are plain Markdown and work with any tool that reads from a rules directory. You may need to adjust directory names (e.g., `.cursor/rules/`). The setup script currently targets Claude Code directories only.

**Q: Can different projects use different versions?**
Yes. The submodule pointer pins to a specific commit. Each project updates independently.

**Q: How does the post-merge hook work?**
`setup.sh` installs a git hook at `.git/hooks/post-merge`. After `git pull`, it checks if `.standards` changed. If so, it runs `update.sh --no-pull` to sync new symlinks without re-fetching. The hook delegates to `.standards/scripts/hooks/post-merge`, so the logic updates when you pull new standards.

**Q: What if I already have a post-merge hook?**
The setup script appends to existing hooks instead of overwriting. It uses a `# aitronos-standards-post-merge` marker to avoid duplicate entries.
