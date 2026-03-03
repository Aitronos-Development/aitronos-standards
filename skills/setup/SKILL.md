---
name: setup
description: Set up Aitronos shared engineering standards in a project. Adds submodule, creates config, wires symlinks.
user-invocable: true
disable-model-invocation: false
---

# Setup Aitronos Standards

You are setting up the Aitronos shared engineering standards in a project. Follow every step carefully. Ask the user for input when indicated.

## Prerequisites

Confirm you are in a git repository root. Run:

```bash
git rev-parse --show-toplevel
```

If this fails, tell the user they must be in a git repo and stop.

## Step 1 — Add the Standards Submodule

Check if `.standards/` already exists:

```bash
test -d .standards && echo "EXISTS" || echo "MISSING"
```

If MISSING, add the submodule:

```bash
git submodule add https://github.com/Aitronos-Development/aitronos-standards.git .standards
```

If EXISTS, make sure it is initialized:

```bash
git submodule update --init .standards
```

## Step 2 — Create project.config.yaml

Check if `project.config.yaml` exists in the project root:

```bash
test -f project.config.yaml && echo "EXISTS" || echo "MISSING"
```

If MISSING, copy the example:

```bash
cp .standards/project.config.example.yaml project.config.yaml
```

If EXISTS, tell the user it already exists and skip to Step 3.

## Step 3 — Gather Project Information

Ask the user the following questions. Use their answers to fill in `project.config.yaml`.

1. **Project name** — What is this project called? (e.g., "Freddy.Backend")
2. **Project type** — Is this a `backend`, `frontend`, `fullstack`, `library`, or `cli`?
3. **Language** — Primary language? (e.g., `python`, `typescript`, `go`)
4. **Framework** — Primary framework? (e.g., `fastapi`, `vue`, `next.js`, `gin`)
5. **Package manager** — What package manager? (e.g., `uv`, `npm`, `pnpm`, `yarn`, `go mod`)
6. **Source directory** — Where is the main source code? (e.g., `app/`, `src/`, `cmd/`)
7. **Test directory** — Where are tests? (e.g., `tests/`, `__tests__/`, `test/`)
8. **Test command** — How do you run unit tests? (e.g., `uv run pytest tests/ -x`, `npm test`)
9. **Lint command** — How do you lint? (e.g., `uvx ruff check .`, `npm run lint`)
10. **Dev server command** — How do you start the dev server? (e.g., `./start-dev.sh`, `npm run dev`)
11. **Credentials file** — Where are dev credentials stored? (e.g., `.dev-credentials`, `.env.local`, or "none")

After the user answers, edit `project.config.yaml` to fill in all the values. Use the Edit tool to replace the example values with the user's answers.

## Step 4 — Create Claude Code Directories

Create the required directories if they do not exist:

```bash
mkdir -p .claude/rules .claude/skills .claude/agents
```

## Step 5 — Symlink Rules

For each `.md` file in `.standards/rules/`, create a symlink in `.claude/rules/` — but only if no local file with that name already exists.

List the available rules:

```bash
ls .standards/rules/*.md
```

For each rule file (e.g., `.standards/rules/logging.md`), check and link:

```bash
for rule in .standards/rules/*.md; do
  name=$(basename "$rule")
  target=".claude/rules/$name"
  if [ -e "$target" ]; then
    echo "SKIP (local exists): $target"
  else
    ln -s "../../.standards/rules/$name" "$target"
    echo "LINKED: $target -> $rule"
  fi
done
```

## Step 6 — Symlink Skills

For each directory in `.standards/skills/` (except `setup/`), create a symlink in `.claude/skills/` — but only if no local directory with that name already exists.

```bash
for skill_dir in .standards/skills/*/; do
  name=$(basename "$skill_dir")
  if [ "$name" = "setup" ]; then
    continue
  fi
  target=".claude/skills/$name"
  if [ -e "$target" ]; then
    echo "SKIP (local exists): $target"
  else
    ln -s "../../.standards/skills/$name" "$target"
    echo "LINKED: $target -> $skill_dir"
  fi
done
```

## Step 7 — Symlink Agents

Create a symlink for the orchestrator agent if no local file exists:

```bash
for agent in .standards/agents/*.md; do
  name=$(basename "$agent")
  target=".claude/agents/$name"
  if [ -e "$target" ]; then
    echo "SKIP (local exists): $target"
  else
    ln -s "../../.standards/agents/$name" "$target"
    echo "LINKED: $target -> $agent"
  fi
done
```

## Step 8 — Verify Setup

Run verification:

```bash
echo "=== Symlinked Rules ==="
ls -la .claude/rules/ | grep " -> "

echo ""
echo "=== Symlinked Skills ==="
ls -la .claude/skills/ | grep " -> "

echo ""
echo "=== Symlinked Agents ==="
ls -la .claude/agents/ | grep " -> "

echo ""
echo "=== Config File ==="
test -f project.config.yaml && echo "project.config.yaml EXISTS" || echo "project.config.yaml MISSING"

echo ""
echo "=== Submodule ==="
test -d .standards/.git -o -f .standards/.git && echo ".standards submodule EXISTS" || echo ".standards submodule MISSING"
```

## Step 9 — Report

Present a summary to the user:

```
Setup Complete!

Submodule:  .standards/ (aitronos-standards)
Config:     project.config.yaml
Rules:      X linked, Y skipped (local override)
Skills:     X linked, Y skipped (local override)
Agents:     X linked, Y skipped (local override)

Next steps:
1. Review project.config.yaml and adjust any values
2. Commit the changes: git add .standards .claude project.config.yaml && git commit -m "chore: add shared engineering standards"
3. Override any standard by deleting the symlink and creating a local file with the same name
```

## Important Notes

- The `setup` skill itself is NOT symlinked into projects (it lives in `.standards/skills/setup/` only)
- Symlinks use relative paths (`../../.standards/...`) so they work regardless of where the repo is cloned
- Local files always take priority over symlinked standards — this is how projects override shared rules
- If the user wants to update standards later, they run `git submodule update --remote .standards`
