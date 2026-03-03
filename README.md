# Aitronos Engineering Standards

Shared engineering standards for all Aitronos projects. Add this repo as a git submodule to any project for consistent rules, skills, and agents that work with Claude Code (and other AI coding tools).

Standards are universal — they apply to Python backends, TypeScript frontends, Go services, or anything else. Project-specific details (commands, paths, conventions) live in a `project.config.yaml` file in each consuming project.

---

## Setup Guide

### Step 1: Add the submodule

Run this in your project root:

```bash
git submodule add https://github.com/Aitronos-Development/aitronos-standards.git .standards
```

This creates a `.standards/` directory containing all shared rules, skills, agents, and the setup tooling.

### Step 2: Run the setup script

```bash
.standards/scripts/setup.sh
```

The script automatically:
- **Detects** your project type, language, framework, and package manager (from `package.json`, `pyproject.toml`, `go.mod`, etc.)
- **Creates** `project.config.yaml` with auto-detected values (test commands, lint commands, source directories)
- **Creates** `.claude/rules/`, `.claude/skills/`, and `.claude/agents/` directories
- **Symlinks** all shared standards into those directories
- **Skips** any files where a local override already exists

No interactive prompts — everything is auto-detected. Zero user input required.

### Step 3: Review and commit

```bash
# Review the auto-detected config and adjust if needed
cat project.config.yaml

# Commit everything
git add .standards .claude project.config.yaml
git commit -m "chore: add shared engineering standards"
```

That's it. Your project now has shared engineering standards.

After initial setup, the `/setup` skill is also available inside Claude Code (via the symlinked skill) for future re-runs when the standards repo adds new rules or skills.

## What's Included

### Rules

Rules are engineering standards that Claude Code loads automatically from `.claude/rules/`. Each rule is a standalone Markdown file.

| Rule | What It Covers |
|------|----------------|
| `branch-naming.md` | Branch naming conventions (feat/, fix/, hotfix/, etc.) |
| `code-organization.md` | No duplicate helpers -- extract shared utilities to dedicated modules |
| `compliance-thresholds.md` | File size limits, function complexity, line length, test coverage |
| `documentation-style.md` | Concise docstrings (1-5 lines), focus on "why" not "what" |
| `fast-commits.md` | Git aliases for fast commits that skip slow pre-commit hooks |
| `logging.md` | Never use print() in application code -- use proper logging |
| `planning.md` | Always check existing implementations before planning new features |
| `secrets-management.md` | Never hardcode secrets -- use .env locally, GitHub Secrets in CI/CD |
| `self-testable-code.md` | All code must be self-tested before shipping (real API calls, not just reading code) |
| `task-reference-comments.md` | No "Task X.Y:" comments -- use TODO/FIXME or proper comments |

### Skills

Skills are multi-step workflows that Claude Code can invoke. Each skill is a directory containing a `SKILL.md` file.

| Skill | What It Does |
|-------|--------------|
| `compliance-fix` | Detect and auto-fix compliance violations (lint, formatting, naming) |
| `orchestrate` | Detailed operational playbook for the orchestrator agent's four modes |
| `qa` | Quality assurance checks -- run tests, verify API responses, check coverage |
| `security-fix` | Detect and fix security issues (hardcoded secrets, SQL injection, etc.) |
| `setup` | Wire aitronos-standards into a new project (this repo's bootstrapper) |
| `tech-review` | Code review workflow -- architecture, patterns, error handling, tests |
| `tech-spec` | Create technical specifications for new features |
| `test-fix` | Diagnose and fix failing tests |

### Agents

Agents are persistent identities for Claude Code that define behavior across an entire session. Unlike skills (which are invoked once), agents shape Claude's behavior for the whole session — including after context compaction.

| Agent | What It Is |
|-------|------------|
| `orchestrator.md` | Team lead agent that delegates to sub-developers, never writes code itself. Supports four modes: spec, execute, tasks, and live. |

#### Launching the Orchestrator

```bash
# Start Claude Code as the orchestrator agent
claude --agent orchestrator
```

This loads the orchestrator identity for the entire session. The agent definition reloads from disk after every context compaction, so the identity survives even when conversation history is lost.

**How it works together:**
- The **agent definition** (`.claude/agents/orchestrator.md`) sets the persistent identity — who Claude is and what it can/can't do
- The **`/orchestrate` skill** is the operational playbook — detailed workflows for each mode (spec, execute, tasks, live)
- The **`PreCompact` hook** (configured in `.claude/settings.json`) snapshots active teams and tasks before context compaction, so the orchestrator can recover its working state

**Recommended `.claude/settings.json` hook** (add to your project):

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .standards/scripts/orchestrator-state-snapshot.py"
          }
        ]
      }
    ]
  }
}
```

Without `--agent`, you can still invoke `/orchestrate` as a one-off skill during any session.

## Project Configuration

Every project that uses these standards must have a `project.config.yaml` in its root. This file maps the universal standards to your specific project.

```yaml
# project.config.yaml — tells standards how YOUR project works

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

Skills and agents reference config values using `{{config:*}}` placeholders. For example, the orchestrator agent uses `{{config:commands.test.unit}}` instead of hardcoding `uv run pytest`.

See `project.config.example.yaml` for the full list of available fields with documentation.

## How It Works

```
your-project/
  .standards/                    <-- git submodule (this repo)
    rules/
      logging.md
      secrets-management.md
      ...
    skills/
      qa/SKILL.md
      tech-review/SKILL.md
      ...
    agents/
      orchestrator.md
    project.config.example.yaml
    scripts/setup.sh

  .claude/
    rules/
      logging.md            --> ../../.standards/rules/logging.md          (symlink)
      secrets-management.md --> ../../.standards/rules/secrets-management.md (symlink)
      my-custom-rule.md                                                     (local file)
    skills/
      qa/                   --> ../../.standards/skills/qa                 (symlink)
      tech-review/          --> ../../.standards/skills/tech-review        (symlink)
      my-custom-skill/                                                      (local dir)
    agents/
      orchestrator.md       --> ../../.standards/agents/orchestrator.md    (symlink)

  project.config.yaml            <-- your project-specific config
```

Claude Code reads from `.claude/rules/`, `.claude/skills/`, and `.claude/agents/`. The symlinks point back into the submodule, so you get shared standards without copying files. Local files and directories always take priority.

## Overriding Standards

To override any shared standard with a project-specific version:

1. **Delete the symlink** in `.claude/rules/`, `.claude/skills/`, or `.claude/agents/`
2. **Create a local file** (or directory) with the same name
3. Write your project-specific content

```bash
# Example: override the logging rule
rm .claude/rules/logging.md
# Now create your own version:
cat > .claude/rules/logging.md << 'EOF'
# Logging Rules (Project Override)
Use structlog for all logging in this project.
EOF
```

The setup script and skill both respect existing local files -- they never overwrite your overrides.

To revert to the shared standard, delete the local file and re-run setup (or manually recreate the symlink):

```bash
rm .claude/rules/logging.md
ln -s ../../.standards/rules/logging.md .claude/rules/logging.md
```

## Updating Standards

When the shared standards repo is updated, pull the changes into your project:

```bash
# Update the submodule to the latest version
git submodule update --remote .standards

# Commit the submodule pointer update
git add .standards
git commit -m "chore: update shared engineering standards"
```

New rules, skills, or agents added to the standards repo will NOT be automatically symlinked. Re-run the setup script to pick them up:

```bash
.standards/scripts/setup.sh
```

The script will create symlinks for any new standards while leaving your existing files (both symlinks and local overrides) untouched.

## Contributing

### Adding a New Rule

1. Create a new `.md` file in `rules/` (e.g., `rules/error-handling.md`)
2. Write the rule following the existing pattern: clear title, rationale, correct/incorrect examples
3. Keep rules universal -- no project-specific commands or paths (use `{{config:*}}` placeholders if needed)
4. Submit a pull request

### Adding a New Skill

1. Create a new directory in `skills/` (e.g., `skills/my-skill/`)
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`, `user-invocable`)
3. Write the step-by-step instructions the skill should follow
4. Reference project config with `{{config:*}}` instead of hardcoded values
5. Submit a pull request

### Modifying Existing Standards

1. Edit the file in this repo
2. All consuming projects will pick up the change on their next `git submodule update --remote`
3. Be careful with breaking changes -- projects may depend on current behavior

### Guidelines

- Standards must be **language-agnostic** where possible (use config placeholders)
- Standards must be **self-contained** (each rule/skill works independently)
- Write for **AI coding tools** (Claude Code, Cursor, Windsurf) as the primary audience
- Include **correct and incorrect examples** in rules
- Keep rules **concise** -- aim for one page of content

## Repository Structure

```
aitronos-standards/
  agents/
    orchestrator.md             # Team lead agent definition
  rules/
    branch-naming.md            # Branch naming conventions
    code-organization.md        # Code organization and DRY principles
    compliance-thresholds.md    # File size, complexity, coverage limits
    documentation-style.md      # Docstring style guidelines
    fast-commits.md             # Fast commit workflow with hook bypass
    logging.md                  # Logging over print() in application code
    planning.md                 # Check existing code before planning new features
    secrets-management.md       # Secrets management (.env, GitHub Secrets)
    self-testable-code.md       # Self-testing requirements for all code
    task-reference-comments.md  # No task references in comments
  skills/
    compliance-fix/SKILL.md     # Auto-fix compliance violations
    orchestrate/SKILL.md        # Orchestrator operational playbook
    qa/SKILL.md                 # Quality assurance workflow
    security-fix/SKILL.md       # Security issue detection and fixing
    setup/SKILL.md              # Project setup bootstrapper
    tech-review/SKILL.md        # Code review workflow
    tech-spec/SKILL.md          # Technical specification creation
    test-fix/SKILL.md           # Test diagnosis and fixing
  scripts/
    setup.sh                    # Shell-based project setup (no Claude Code needed)
  project.config.example.yaml  # Example configuration with full documentation
  README.md                     # This file
```

## FAQ

**Q: Do I need Claude Code to use this?**
No. The `scripts/setup.sh` script works without Claude Code. However, the rules, skills, and agents are designed primarily for AI coding tools that read from `.claude/` directories. The rules are also useful as human-readable engineering guidelines.

**Q: What happens if I don't create a project.config.yaml?**
Skills and agents that reference `{{config:*}}` placeholders will not know your project-specific commands and paths. The rules (which are static guidelines) will still work fine.

**Q: Can I use this with Cursor or Windsurf instead of Claude Code?**
The rules are plain Markdown and work with any tool that reads from a rules directory. You may need to adjust the directory names (e.g., `.cursor/rules/` instead of `.claude/rules/`). The setup script currently targets Claude Code directories only.

**Q: What if the submodule URL changes?**
Update the submodule remote: `git submodule set-url .standards <new-url>` then `git submodule update --remote .standards`.

**Q: Can different projects use different versions of the standards?**
Yes. The submodule pointer in each project pins to a specific commit. Each project updates independently via `git submodule update --remote`. You can also pin to a tag or branch.

**Q: How do I remove the standards from a project?**
```bash
git submodule deinit .standards
git rm .standards
rm -rf .git/modules/.standards
# Remove symlinks (they'll be broken now)
find .claude -type l -delete
git commit -m "chore: remove shared engineering standards"
```

**Q: Do rules accumulate or override each other?**
Each rule is independent. They do not inherit from or override other rules. If two rules conflict, the project-specific local override takes precedence over the symlinked shared version.
