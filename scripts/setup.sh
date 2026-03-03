#!/usr/bin/env bash
# ============================================================================
# Aitronos Standards — Project Setup Script
#
# Automatically detects project type, creates config, and symlinks shared
# standards. No interactive prompts — everything is auto-detected.
#
# Usage:
#   .standards/scripts/setup.sh
# ============================================================================

set -euo pipefail

# Colors (disable if not a terminal)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN='' YELLOW='' RED='' BLUE='' BOLD='' NC=''
fi

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[SKIP]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

SUBMODULE_URL="https://github.com/Aitronos-Development/aitronos-standards.git"
SUBMODULE_DIR=".standards"
CONFIG_FILE="project.config.yaml"

RULES_LINKED=0
RULES_SKIPPED=0
SKILLS_LINKED=0
SKILLS_SKIPPED=0
AGENTS_LINKED=0
AGENTS_SKIPPED=0

# ============================================================================
# Auto-Detection Functions
# ============================================================================

detect_package_manager() {
  if [ -f "pnpm-lock.yaml" ]; then echo "pnpm"
  elif [ -f ".yarnrc.yml" ] || [ -f "yarn.lock" ]; then echo "yarn"
  elif [ -f "bun.lockb" ]; then echo "bun"
  elif [ -f "package-lock.json" ]; then echo "npm"
  elif [ -f "uv.lock" ] || [ -f "pyproject.toml" ]; then echo "uv"
  elif [ -f "Pipfile" ]; then echo "pipenv"
  elif [ -f "go.mod" ]; then echo "go mod"
  elif [ -f "Cargo.toml" ]; then echo "cargo"
  else echo "unknown"
  fi
}

detect_language() {
  if [ -f "tsconfig.json" ] || [ -f "tsconfig.app.json" ]; then echo "typescript"
  elif [ -f "package.json" ]; then echo "javascript"
  elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then echo "python"
  elif [ -f "go.mod" ]; then echo "go"
  elif [ -f "Cargo.toml" ]; then echo "rust"
  elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then echo "java"
  else echo "unknown"
  fi
}

detect_framework() {
  # Check package.json dependencies
  if [ -f "package.json" ]; then
    if grep -q '"vue"' package.json 2>/dev/null; then echo "vue"; return; fi
    if grep -q '"react"' package.json 2>/dev/null; then echo "react"; return; fi
    if grep -q '"next"' package.json 2>/dev/null; then echo "next.js"; return; fi
    if grep -q '"nuxt"' package.json 2>/dev/null; then echo "nuxt"; return; fi
    if grep -q '"svelte"' package.json 2>/dev/null; then echo "svelte"; return; fi
    if grep -q '"angular' package.json 2>/dev/null; then echo "angular"; return; fi
    if grep -q '"express"' package.json 2>/dev/null; then echo "express"; return; fi
  fi
  # Check Python
  if [ -f "pyproject.toml" ]; then
    if grep -q 'fastapi' pyproject.toml 2>/dev/null; then echo "fastapi"; return; fi
    if grep -q 'django' pyproject.toml 2>/dev/null; then echo "django"; return; fi
    if grep -q 'flask' pyproject.toml 2>/dev/null; then echo "flask"; return; fi
  fi
  # Check Go
  if [ -f "go.mod" ]; then
    if grep -q 'gin-gonic' go.mod 2>/dev/null; then echo "gin"; return; fi
    if grep -q 'fiber' go.mod 2>/dev/null; then echo "fiber"; return; fi
  fi
  echo "none"
}

detect_project_type() {
  local framework="$1"
  case "$framework" in
    vue|react|next.js|nuxt|svelte|angular) echo "frontend" ;;
    fastapi|django|flask|express|gin|fiber) echo "backend" ;;
    *)
      # Heuristic: if src/ has index.html or main.ts, likely frontend
      if [ -f "index.html" ] || [ -f "src/main.ts" ] || [ -f "src/index.tsx" ]; then
        echo "frontend"
      elif [ -d "app/" ] || [ -f "manage.py" ] || [ -f "main.go" ]; then
        echo "backend"
      else
        echo "library"
      fi
      ;;
  esac
}

detect_source_dir() {
  if [ -d "src" ]; then echo "src/"
  elif [ -d "app" ]; then echo "app/"
  elif [ -d "lib" ]; then echo "lib/"
  elif [ -d "pkg" ]; then echo "pkg/"
  else echo "."
  fi
}

detect_test_dir() {
  if [ -d "tests" ]; then echo "tests/"
  elif [ -d "test" ]; then echo "test/"
  elif [ -d "src/__tests__" ]; then echo "src/__tests__/"
  elif [ -d "__tests__" ]; then echo "__tests__/"
  elif [ -d "spec" ]; then echo "spec/"
  else echo "tests/"
  fi
}

detect_test_command() {
  local pkg_mgr="$1" lang="$2"
  # Check package.json scripts
  if [ -f "package.json" ]; then
    if grep -q '"test"' package.json 2>/dev/null; then
      echo "${pkg_mgr} test"
      return
    fi
    # Check for vitest/jest directly
    if grep -q '"vitest"' package.json 2>/dev/null; then echo "${pkg_mgr} vitest run"; return; fi
    if grep -q '"jest"' package.json 2>/dev/null; then echo "${pkg_mgr} jest"; return; fi
  fi
  case "$lang" in
    python) echo "uv run pytest tests/ -x -q --tb=short" ;;
    go) echo "go test ./..." ;;
    rust) echo "cargo test" ;;
    *) echo "" ;;
  esac
}

detect_lint_command() {
  local pkg_mgr="$1" lang="$2"
  if [ -f "package.json" ]; then
    if grep -q '"lint"' package.json 2>/dev/null; then echo "${pkg_mgr} lint"; return; fi
    if grep -q '"eslint"' package.json 2>/dev/null; then echo "${pkg_mgr} eslint src"; return; fi
  fi
  case "$lang" in
    python) echo "uvx ruff check ." ;;
    go) echo "golangci-lint run" ;;
    rust) echo "cargo clippy" ;;
    *) echo "" ;;
  esac
}

detect_dev_command() {
  local pkg_mgr="$1"
  # Check for start-dev.sh first
  if [ -f "start-dev.sh" ]; then echo "./start-dev.sh"; return; fi
  # Check package.json
  if [ -f "package.json" ]; then
    if grep -q '"dev"' package.json 2>/dev/null; then echo "${pkg_mgr} dev"; return; fi
    if grep -q '"start"' package.json 2>/dev/null; then echo "${pkg_mgr} start"; return; fi
  fi
  echo ""
}

detect_build_command() {
  local pkg_mgr="$1"
  if [ -f "package.json" ]; then
    if grep -q '"build"' package.json 2>/dev/null; then echo "${pkg_mgr} build"; return; fi
  fi
  if [ -f "Dockerfile" ]; then echo "docker build ."; return; fi
  echo ""
}

detect_credentials_file() {
  if [ -f ".dev-credentials" ]; then echo ".dev-credentials"
  elif [ -f ".env.local" ]; then echo ".env.local"
  elif [ -f ".env" ]; then echo ".env"
  else echo ""
  fi
}

detect_run_prefix() {
  local pkg_mgr="$1"
  case "$pkg_mgr" in
    pnpm) echo "pnpm" ;;
    yarn) echo "yarn" ;;
    bun) echo "bun" ;;
    npm) echo "npx" ;;
    *) echo "$pkg_mgr" ;;
  esac
}

# ============================================================================
# Step 0 — Verify git repo
# ============================================================================

echo ""
echo -e "${BOLD}Aitronos Standards — Project Setup${NC}"
echo "========================================"
echo ""

if ! git rev-parse --show-toplevel > /dev/null 2>&1; then
  error "Not inside a git repository. Please run this from your project root."
  exit 1
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"
info "Project root: $PROJECT_ROOT"
echo ""

# ============================================================================
# Step 1 — Add submodule
# ============================================================================

echo -e "${BOLD}Step 1: Standards Submodule${NC}"

if [ -d "$SUBMODULE_DIR" ] || [ -f "$SUBMODULE_DIR/.git" ]; then
  success "$SUBMODULE_DIR already exists — updating"
  git submodule update --init "$SUBMODULE_DIR" 2>/dev/null || true
else
  info "Adding submodule: $SUBMODULE_URL -> $SUBMODULE_DIR"
  git submodule add "$SUBMODULE_URL" "$SUBMODULE_DIR"
  success "Submodule added"
fi
echo ""

# ============================================================================
# Step 2 — Auto-detect project and create config
# ============================================================================

echo -e "${BOLD}Step 2: Project Configuration (auto-detected)${NC}"

if [ -f "$CONFIG_FILE" ]; then
  success "$CONFIG_FILE already exists — skipping"
else
  # Auto-detect everything
  proj_name="$(basename "$PROJECT_ROOT")"
  proj_pkgmgr="$(detect_package_manager)"
  proj_lang="$(detect_language)"
  proj_framework="$(detect_framework)"
  proj_type="$(detect_project_type "$proj_framework")"
  proj_source="$(detect_source_dir)"
  proj_tests="$(detect_test_dir)"
  proj_run="$(detect_run_prefix "$proj_pkgmgr")"
  proj_test_cmd="$(detect_test_command "$proj_run" "$proj_lang")"
  proj_lint_cmd="$(detect_lint_command "$proj_run" "$proj_lang")"
  proj_dev_cmd="$(detect_dev_command "$proj_run")"
  proj_build_cmd="$(detect_build_command "$proj_run")"
  proj_creds="$(detect_credentials_file)"

  info "Detected: $proj_name ($proj_lang / $proj_framework / $proj_pkgmgr)"

  cat > "$CONFIG_FILE" << YAML
# Aitronos Standards — Project Configuration
# Auto-generated by setup.sh on $(date +%Y-%m-%d)
# Review and adjust values as needed.

project:
  name: "$proj_name"
  type: "$proj_type"
  language: "$proj_lang"
  framework: "$proj_framework"
  package_manager: "$proj_pkgmgr"

commands:
  test:
    unit: "$proj_test_cmd"
    integration: ""
    e2e: ""
  lint:
    check: "$proj_lint_cmd"
    fix: ""
  compliance:
    fast: ""
    full: ""
  dev:
    start: "$proj_dev_cmd"
  deps:
    install: "$proj_pkgmgr install"
    sync: "$proj_pkgmgr install"
  migrations:
    generate: ""
    apply: ""
  build:
    dev: ""
    prod: "$proj_build_cmd"

paths:
  source: "$proj_source"
  tests: "$proj_tests"
  specs: "docs/.specs/"
  public_docs: ""
  routes: ""
  schemas: ""
  services: ""
  models: ""
  repositories: ""
  migrations: ""

credentials:
  file: "$proj_creds"
  refresh: ""
  variables: []

api_testing:
  base_url: "http://localhost:8000"
  health_endpoint: "/health"
  auth_header: "Authorization"
  auth_format: "Bearer {token}"
  api_key_header: ""
  sdk:
    package: ""
    import: ""

conventions:
  auth: "bearer_only"
  errors: "custom_exceptions"
  ids: "uuid"
  pagination: "cursor"
  database: ""
  response: "flat"
YAML

  success "Created $CONFIG_FILE (auto-detected)"
  info "Review the config and adjust any values that don't look right"
fi
echo ""

# ============================================================================
# Step 3 — Create directories
# ============================================================================

echo -e "${BOLD}Step 3: Create Claude Code Directories${NC}"

for dir in .claude/rules .claude/skills .claude/agents; do
  if [ -d "$dir" ]; then
    success "$dir exists"
  else
    mkdir -p "$dir"
    success "Created $dir"
  fi
done
echo ""

# ============================================================================
# Step 4 — Symlink rules
# ============================================================================

echo -e "${BOLD}Step 4: Link Shared Rules${NC}"

if [ -d "$SUBMODULE_DIR/rules" ]; then
  for rule in "$SUBMODULE_DIR"/rules/*.md; do
    [ -f "$rule" ] || continue
    name="$(basename "$rule")"
    target=".claude/rules/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      warn "$target (local file exists)"
      RULES_SKIPPED=$((RULES_SKIPPED + 1))
    else
      ln -s "../../$SUBMODULE_DIR/rules/$name" "$target"
      success "$target"
      RULES_LINKED=$((RULES_LINKED + 1))
    fi
  done
else
  warn "No rules directory in $SUBMODULE_DIR"
fi
echo ""

# ============================================================================
# Step 5 — Symlink skills
# ============================================================================

echo -e "${BOLD}Step 5: Link Shared Skills${NC}"

if [ -d "$SUBMODULE_DIR/skills" ]; then
  for skill_dir in "$SUBMODULE_DIR"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "$skill_dir")"

    target=".claude/skills/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      warn "$target (local directory exists)"
      SKILLS_SKIPPED=$((SKILLS_SKIPPED + 1))
    else
      ln -s "../../$SUBMODULE_DIR/skills/$name" "$target"
      success "$target"
      SKILLS_LINKED=$((SKILLS_LINKED + 1))
    fi
  done
else
  warn "No skills directory in $SUBMODULE_DIR"
fi
echo ""

# ============================================================================
# Step 6 — Symlink agents
# ============================================================================

echo -e "${BOLD}Step 6: Link Shared Agents${NC}"

if [ -d "$SUBMODULE_DIR/agents" ]; then
  for agent in "$SUBMODULE_DIR"/agents/*.md; do
    [ -f "$agent" ] || continue
    name="$(basename "$agent")"
    target=".claude/agents/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
      warn "$target (local file exists)"
      AGENTS_SKIPPED=$((AGENTS_SKIPPED + 1))
    else
      ln -s "../../$SUBMODULE_DIR/agents/$name" "$target"
      success "$target"
      AGENTS_LINKED=$((AGENTS_LINKED + 1))
    fi
  done
else
  warn "No agents directory in $SUBMODULE_DIR"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "========================================"
echo -e "${BOLD}${GREEN}Setup Complete!${NC}"
echo "========================================"
echo ""
echo "  Submodule:  $SUBMODULE_DIR"
echo "  Config:     $CONFIG_FILE"
echo "  Rules:      $RULES_LINKED linked, $RULES_SKIPPED skipped (local override)"
echo "  Skills:     $SKILLS_LINKED linked, $SKILLS_SKIPPED skipped (local override)"
echo "  Agents:     $AGENTS_LINKED linked, $AGENTS_SKIPPED skipped (local override)"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo "  1. Review $CONFIG_FILE and adjust any auto-detected values"
echo "  2. Commit the changes:"
echo "     git add .standards .claude $CONFIG_FILE"
echo "     git commit -m \"chore: add shared engineering standards\""
echo "  3. To override a shared standard, delete the symlink and create"
echo "     a local file with the same name"
echo "  4. To update standards later:"
echo "     git submodule update --remote .standards"
echo ""
