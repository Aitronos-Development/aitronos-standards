# Setup Guide

How to add Aitronos Engineering Standards to a new project.

## Step 1: Add the submodule

```bash
git submodule add https://github.com/Aitronos-Development/aitronos-standards.git .standards
```

This creates a `.standards/` directory containing all shared rules, skills, agents, and setup tooling.

## Step 2: Run the setup script

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

## Step 3: Review and commit

```bash
# Review the auto-detected config and adjust if needed
cat project.config.yaml

# Commit everything
git add .standards .claude project.config.yaml
git commit -m "chore: add shared engineering standards"
```

## Step 4: Configure the PreCompact hook (recommended)

Add this to your `.claude/settings.json` to enable orchestrator state recovery across context compaction:

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

If you already have a `settings.json`, merge the `hooks` key into your existing config.

## Step 5: Verify

```bash
# Check that symlinks are in place
ls -la .claude/rules/
ls -la .claude/skills/
ls -la .claude/agents/

# Check that project config exists
cat project.config.yaml
```

That's it. Your project now has shared engineering standards.

## How it wires together

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
    scripts/
      setup.sh
      update.sh
      orchestrator-guardrail.sh
      orchestrator-state-snapshot.py

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
    settings.json                  <-- PreCompact hook config

  project.config.yaml              <-- your project-specific config
```

Claude Code reads from `.claude/rules/`, `.claude/skills/`, and `.claude/agents/`. The symlinks point back into the submodule, so you get shared standards without copying files.

## Updating standards

When the shared standards repo has new or updated content:

```bash
.standards/scripts/update.sh
```

This pulls the latest submodule, removes stale symlinks, creates symlinks for any new rules/skills/agents, and ensures the PreCompact hook is configured.

```bash
# Then commit the update
git add .standards .claude
git commit -m "chore: update shared engineering standards"
```

The update script never overwrites local overrides.

## Removing standards

```bash
git submodule deinit .standards
git rm .standards
rm -rf .git/modules/.standards
find .claude -type l -delete    # Remove broken symlinks
git commit -m "chore: remove shared engineering standards"
```
