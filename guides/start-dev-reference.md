# start-dev.sh Reference Guide

Full implementation guide for the `start-dev.sh` standard. For the concise rule, see `../rules/start-dev.md`.

**Reference implementations:** Freddy.Backend (`start-dev.sh`), Flow-plate (`start-dev.sh`)

---

## Table of Contents

1. [Prerequisite Detection](#prerequisite-detection)
2. [Docker Management](#docker-management)
3. [Environment File Management](#environment-file-management)
4. [Database Setup](#database-setup)
5. [Credential Generation](#credential-generation)
6. [Server Start with Auto-Reload](#server-start-with-auto-reload)
7. [Interactive Mode](#interactive-mode)
8. [Freeze Mode](#freeze-mode)
9. [Branch Isolation](#branch-isolation)
10. [MCP Dev Server](#mcp-dev-server)
11. [AI Tool Rule Sync](#ai-tool-rule-sync)
12. [Graceful Shutdown](#graceful-shutdown)
13. [Skeleton Script](#skeleton-script)

---

## Prerequisite Detection

Detect missing tools at startup and offer to install them.

### Pattern

```bash
REQUIRED_TOOLS=("docker" "python3" "uv" "psql")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        MISSING_TOOLS+=("$tool")
    fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "Missing tools: ${MISSING_TOOLS[*]}"
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
        read -p "Install via Homebrew? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            brew install "${MISSING_TOOLS[@]}"
        fi
    else
        echo "Please install manually: ${MISSING_TOOLS[*]}"
        exit 1
    fi
fi
```

### Language-Specific Additions

- **Python**: Check for `uv`, `python3`, version >= 3.11
- **Node.js**: Check for `node`, `bun` or `npm`, version >= 18
- **Go**: Check for `go`, version >= 1.21
- **Rust**: Check for `cargo`, `rustc`

---

## Docker Management

### Auto-Start Docker Desktop (macOS)

```bash
if ! docker info &>/dev/null; then
    echo "Starting Docker Desktop..."
    open -a Docker
    # Wait for Docker to be ready
    local max_wait=60
    local waited=0
    while ! docker info &>/dev/null && [ $waited -lt $max_wait ]; do
        sleep 2
        waited=$((waited + 2))
    done
    if ! docker info &>/dev/null; then
        echo "ERROR: Docker failed to start within ${max_wait}s"
        exit 1
    fi
fi
```

### Start Containers

```bash
docker compose up -d
# Wait for health checks
docker compose exec db pg_isready --timeout=30
```

---

## Environment File Management

### Generate from Template

```bash
ENV_FILE=".env"
ENV_TEMPLATE=".env.example"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_TEMPLATE" ]; then
        cp "$ENV_TEMPLATE" "$ENV_FILE"
        echo "Created $ENV_FILE from template — review and update values"
    else
        echo "ERROR: No $ENV_FILE or $ENV_TEMPLATE found"
        exit 1
    fi
fi
```

### Validate Required Variables

```bash
REQUIRED_VARS=("DATABASE_URL" "SECRET_KEY")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^${var}=" "$ENV_FILE" || grep -q "^${var}=$" "$ENV_FILE"; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "WARNING: Missing or empty env vars: ${MISSING_VARS[*]}"
fi
```

---

## Database Setup

```bash
# Run migrations
echo "Running database migrations..."
uv run alembic upgrade head  # Python/SQLAlchemy
# OR: npx prisma migrate deploy  # Node.js/Prisma
# OR: go run ./cmd/migrate       # Go

# Seed if needed (check for marker or empty table)
if [ "$SEED_DATABASE" = "true" ] || [ -z "$(psql $DATABASE_URL -tAc 'SELECT 1 FROM users LIMIT 1' 2>/dev/null)" ]; then
    echo "Seeding database..."
    uv run python scripts/database/seed_database.py
fi
```

---

## Credential Generation

```bash
CRED_FILE=".dev-credentials"

generate_credentials() {
    # Project-specific: generate API key and access token
    uv run python scripts/development/get_dev_credentials.py > "$CRED_FILE"
    echo "Dev credentials written to $CRED_FILE"
}

if [ ! -f "$CRED_FILE" ]; then
    generate_credentials
fi
```

---

## Server Start with Auto-Reload

### Python/FastAPI

```bash
uv run uvicorn app.main:app \
    --host 0.0.0.0 \
    --port "${PORT:-8000}" \
    --reload \
    --reload-dir app/ &
SERVER_PID=$!
```

### Node.js

```bash
npx nodemon --watch src/ --ext ts,js --exec "npx tsx src/index.ts" &
SERVER_PID=$!
```

### Go

```bash
air -c .air.toml &
SERVER_PID=$!
```

---

## Interactive Mode

### Implementation Pattern

```bash
# Save terminal settings
ORIGINAL_STTY=$(stty -g)

# Set up raw mode for single-keypress input
setup_interactive() {
    stty -echo -icanon min 1 time 0
}

# Restore terminal on exit
restore_terminal() {
    stty "$ORIGINAL_STTY"
}

trap restore_terminal EXIT

# Main interactive loop
interactive_loop() {
    setup_interactive
    while true; do
        # Check for MCP notifications
        if [ -f ".dev-mcp-notify" ]; then
            cat ".dev-mcp-notify"
            rm ".dev-mcp-notify"
        fi

        # Read single keypress (with timeout for notification polling)
        if read -t 1 -n 1 key 2>/dev/null; then
            case "$key" in
                s) show_status ;;
                r) restart_server ;;
                l) toggle_log_level ;;
                f) toggle_freeze ;;
                t) trigger_reload ;;
                h) show_help ;;
                q) graceful_shutdown; exit 0 ;;
            esac
        fi
    done
}
```

### Required Key Handlers

| Key | Handler | Behavior |
|-----|---------|----------|
| `s` | `show_status` | Print server health, container status, port, freeze timer remaining |
| `r` | `restart_server` | Kill server process, restart with same args |
| `l` | `toggle_log_level` | Cycle through DEBUG/INFO/WARNING verbosity |
| `f` | `toggle_freeze` | Create/remove freeze marker file, start 15-min timer |
| `t` | `trigger_reload` | Briefly unfreeze, touch a source file, re-freeze |
| `h` | `show_help` | Print key map |
| `q` | `graceful_shutdown` | Two-stage shutdown, cleanup |

---

## Freeze Mode

Freeze mode suppresses file-change reloads during multi-file refactors. **Must auto-expire after 15 minutes.**

### Implementation

```bash
FREEZE_FILE=".dev-freeze"
FREEZE_MAX_SECONDS=900  # 15 minutes

toggle_freeze() {
    if [ -f "$FREEZE_FILE" ]; then
        rm "$FREEZE_FILE"
        echo "Auto-reload UNFROZEN"
    else
        echo "$(date +%s)" > "$FREEZE_FILE"
        echo "Auto-reload FROZEN (expires in 15 minutes)"
    fi
}

check_freeze_expiry() {
    if [ -f "$FREEZE_FILE" ]; then
        local frozen_at=$(cat "$FREEZE_FILE")
        local now=$(date +%s)
        local elapsed=$((now - frozen_at))
        if [ $elapsed -ge $FREEZE_MAX_SECONDS ]; then
            rm "$FREEZE_FILE"
            echo "Freeze auto-expired after 15 minutes"
        fi
    fi
}

get_freeze_remaining() {
    if [ -f "$FREEZE_FILE" ]; then
        local frozen_at=$(cat "$FREEZE_FILE")
        local now=$(date +%s)
        local remaining=$(( FREEZE_MAX_SECONDS - (now - frozen_at) ))
        if [ $remaining -gt 0 ]; then
            echo "$((remaining / 60))m $((remaining % 60))s remaining"
        fi
    fi
}

trigger_reload() {
    if [ ! -f "$FREEZE_FILE" ]; then
        echo "Not frozen — auto-reload is already active"
        return
    fi
    local frozen_at=$(cat "$FREEZE_FILE")
    rm "$FREEZE_FILE"
    touch app/main.py  # Trigger file watcher
    sleep 1
    echo "$frozen_at" > "$FREEZE_FILE"  # Re-freeze with original timestamp
    echo "One-shot reload triggered"
}
```

### Integration with Auto-Reload

The freeze file acts as a flag. The file watcher (uvicorn `--reload`, nodemon, air, etc.) should be configured to check for the freeze file and skip reloads when it exists. In practice, this is often implemented by:

1. **Wrapper approach**: A custom watcher script that checks the freeze file before forwarding file change events
2. **PID signal approach**: The freeze toggle sends SIGSTOP/SIGCONT to the watcher process
3. **Filter approach**: The watcher ignores changes while the freeze file exists (requires watcher support)

---

## Branch Isolation

The `--separate` flag enables parallel feature development by isolating containers and ports per branch.

### Implementation

```bash
if [[ "$*" == *"--separate"* ]]; then
    BRANCH=$(git branch --show-current | tr '/' '-')
    COMPOSE_PROJECT_NAME="${PROJECT_NAME}-${BRANCH}"
    PORT=$((8000 + $(echo "$BRANCH" | cksum | cut -d' ' -f1) % 1000))
    export COMPOSE_PROJECT_NAME PORT
    echo "Branch isolation: project=$COMPOSE_PROJECT_NAME port=$PORT"
fi
```

This gives each branch its own Docker containers and port, preventing conflicts.

---

## MCP Dev Server

### Architecture

The MCP dev server is a lightweight Python process that exposes project dev tools to AI coding assistants (Claude Code, Cursor, etc.) via the Model Context Protocol.

```
start-dev.sh
  ├── starts Docker, server, etc.
  └── starts MCP dev server (background daemon)
        ├── PID tracked in .dev-mcp-server.pid
        ├── Exposes tools: logs, credentials, API calls, freeze control
        └── Writes notifications to .dev-mcp-notify
```

### Starting the MCP Server

```bash
MCP_PID_FILE=".dev-mcp-server.pid"

start_mcp_server() {
    if [ -f "$MCP_PID_FILE" ] && kill -0 "$(cat "$MCP_PID_FILE")" 2>/dev/null; then
        echo "MCP dev server already running"
        return
    fi
    uv run python scripts/development/mcp_dev_server.py &
    echo $! > "$MCP_PID_FILE"
    echo "MCP dev server started (PID: $(cat "$MCP_PID_FILE"))"
}

stop_mcp_server() {
    if [ -f "$MCP_PID_FILE" ]; then
        kill "$(cat "$MCP_PID_FILE")" 2>/dev/null
        rm "$MCP_PID_FILE"
    fi
}
```

### Required Tool Endpoints

| Tool | Description |
|------|-------------|
| `get_backend_logs` / `tail_logs` | Read last N lines from service logs. Support `service` param (server, worker, etc.) and `lines`/`offset` for pagination. |
| `get_dev_credentials` | Return current dev API key and bearer token from `.dev-credentials`. |
| `call_api` | Proxy any API call with auto-injected auth headers. Params: endpoint, method, body, auth_type. |
| `test_api_connection` | Hit `/health` endpoint, return status. |
| `toggle_freeze` | Create/remove freeze file. Same as pressing `f`. |
| `trigger_reload` | One-shot reload while frozen. Same as pressing `t`. |
| `get_freeze_status` | Return frozen/unfrozen state and remaining time. |
| `get_current_status` | Aggregate status: server health, containers, port, freeze state, uptime. |

### Notification File

The MCP server can write messages to `.dev-mcp-notify` for display in the interactive loop:

```bash
# In MCP server (Python)
with open(".dev-mcp-notify", "a") as f:
    f.write("Freeze toggled via MCP tool\n")

# In interactive loop (bash)
if [ -f ".dev-mcp-notify" ]; then
    echo -e "\n📡 MCP: $(cat .dev-mcp-notify)"
    rm .dev-mcp-notify
fi
```

### AI Tool Configuration

**Claude Code** (`.claude/settings.json` or project MCP config):

```json
{
  "mcpServers": {
    "project-dev": {
      "command": "uv",
      "args": ["run", "python", "scripts/development/mcp_dev_server.py"],
      "cwd": "/path/to/project"
    }
  }
}
```

**Cursor** (`.cursor/mcp.json`):

```json
{
  "mcpServers": {
    "project-dev": {
      "command": "uv",
      "args": ["run", "python", "scripts/development/mcp_dev_server.py"]
    }
  }
}
```

---

## AI Tool Rule Sync

On startup, copy `.claude/rules/` content to other AI tools' rule directories so all tools share the same standards.

```bash
sync_ai_rules() {
    local source_dir=".claude/rules"
    if [ ! -d "$source_dir" ]; then
        return
    fi

    # Target directories for other AI tools
    local targets=(
        ".cursor/rules"
        ".kiro/steering"
        ".windsurfrules"
    )

    for target in "${targets[@]}"; do
        mkdir -p "$target"
        # Copy rules, resolving symlinks
        for rule in "$source_dir"/*.md; do
            [ -f "$rule" ] || continue
            local basename=$(basename "$rule")
            # Copy (resolving symlinks) — skip if target is newer
            cp -n "$(readlink -f "$rule" 2>/dev/null || echo "$rule")" "$target/$basename" 2>/dev/null
        done
    done
}
```

Add target directories to `.gitignore` if they're generated:

```
.cursor/rules/
.kiro/steering/
.windsurfrules/
```

---

## Graceful Shutdown

### Two-Stage Shutdown

```bash
graceful_shutdown() {
    echo "Shutting down..."

    # Stage 1: SIGTERM — give processes time to clean up
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    stop_mcp_server

    # Wait up to 5 seconds for graceful exit
    local waited=0
    while kill -0 "$SERVER_PID" 2>/dev/null && [ $waited -lt 5 ]; do
        sleep 1
        waited=$((waited + 1))
    done

    # Stage 2: SIGKILL if still running
    [ -n "$SERVER_PID" ] && kill -9 "$SERVER_PID" 2>/dev/null

    # Clean up temp/PID files
    rm -f ".dev-freeze" ".dev-mcp-server.pid" ".dev-mcp-notify"

    # Stop containers (optional — keep running for faster restart)
    # docker compose down

    restore_terminal
    echo "Shutdown complete"
}

trap graceful_shutdown SIGINT SIGTERM
```

---

## Skeleton Script

Copy this as a starting point for new projects. Customize the `REQUIRED_TOOLS`, `COMPOSE_FILE`, and server start command.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# start-dev.sh — Single entry point for local development
# ============================================================

PROJECT_NAME="my-project"
PORT="${PORT:-8000}"
FREEZE_FILE=".dev-freeze"
FREEZE_MAX_SECONDS=900
MCP_PID_FILE=".dev-mcp-server.pid"
CRED_FILE=".dev-credentials"
SERVER_PID=""
ORIGINAL_STTY=""

# ---- Prerequisites ----

REQUIRED_TOOLS=("docker" "python3" "uv")
MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    command -v "$tool" &>/dev/null || MISSING_TOOLS+=("$tool")
done
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "Missing: ${MISSING_TOOLS[*]}"
    if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
        read -p "Install via Homebrew? [Y/n] " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]] && brew install "${MISSING_TOOLS[@]}"
    else
        echo "Install manually: ${MISSING_TOOLS[*]}"; exit 1
    fi
fi

# ---- Flags ----

FORCE=false
SEPARATE=false
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        --separate) SEPARATE=true ;;
    esac
done

if $FORCE; then
    lsof -ti:"$PORT" | xargs kill -9 2>/dev/null || true
fi

if $SEPARATE; then
    BRANCH=$(git branch --show-current | tr '/' '-')
    COMPOSE_PROJECT_NAME="${PROJECT_NAME}-${BRANCH}"
    PORT=$((8000 + $(echo "$BRANCH" | cksum | cut -d' ' -f1) % 1000))
    export COMPOSE_PROJECT_NAME PORT
    echo "Branch isolation: project=$COMPOSE_PROJECT_NAME port=$PORT"
fi

# ---- Docker ----

if ! docker info &>/dev/null; then
    echo "Starting Docker Desktop..."
    open -a Docker 2>/dev/null || true
    for i in $(seq 1 30); do docker info &>/dev/null && break; sleep 2; done
    docker info &>/dev/null || { echo "Docker failed to start"; exit 1; }
fi
docker compose up -d

# ---- Environment ----

if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    cp .env.example .env
    echo "Created .env from template — review and update"
fi

# ---- AI Rule Sync ----

sync_ai_rules() {
    local src=".claude/rules"
    [ -d "$src" ] || return
    for target in ".cursor/rules" ".kiro/steering" ".windsurfrules"; do
        mkdir -p "$target"
        for f in "$src"/*.md; do
            [ -f "$f" ] || continue
            cp -n "$(readlink -f "$f" 2>/dev/null || echo "$f")" "$target/$(basename "$f")" 2>/dev/null || true
        done
    done
}
sync_ai_rules

# ---- Database ----

echo "Running migrations..."
# uv run alembic upgrade head  # Uncomment for Python/SQLAlchemy
# npx prisma migrate deploy    # Uncomment for Node.js/Prisma

# ---- Credentials ----

if [ ! -f "$CRED_FILE" ]; then
    echo "Generating dev credentials..."
    # uv run python scripts/development/get_dev_credentials.py > "$CRED_FILE"
    echo "# TODO: implement credential generation" > "$CRED_FILE"
fi

# ---- MCP Dev Server ----

start_mcp_server() {
    if [ -f "$MCP_PID_FILE" ] && kill -0 "$(cat "$MCP_PID_FILE")" 2>/dev/null; then return; fi
    # uv run python scripts/development/mcp_dev_server.py &
    # echo $! > "$MCP_PID_FILE"
    echo "# TODO: implement MCP dev server"
}
stop_mcp_server() {
    [ -f "$MCP_PID_FILE" ] && kill "$(cat "$MCP_PID_FILE")" 2>/dev/null; rm -f "$MCP_PID_FILE"
}
start_mcp_server

# ---- Server ----

start_server() {
    echo "Starting dev server on port $PORT..."
    # uv run uvicorn app.main:app --host 0.0.0.0 --port "$PORT" --reload --reload-dir app/ &
    # SERVER_PID=$!
    echo "# TODO: implement server start"
}
start_server

# ---- Freeze Mode ----

toggle_freeze() {
    if [ -f "$FREEZE_FILE" ]; then
        rm "$FREEZE_FILE"; echo "Auto-reload UNFROZEN"
    else
        date +%s > "$FREEZE_FILE"; echo "Auto-reload FROZEN (15 min expiry)"
    fi
}
check_freeze_expiry() {
    [ -f "$FREEZE_FILE" ] || return
    local elapsed=$(( $(date +%s) - $(cat "$FREEZE_FILE") ))
    [ $elapsed -ge $FREEZE_MAX_SECONDS ] && { rm "$FREEZE_FILE"; echo "Freeze auto-expired"; }
}
trigger_reload() {
    [ -f "$FREEZE_FILE" ] || { echo "Not frozen"; return; }
    local ts=$(cat "$FREEZE_FILE"); rm "$FREEZE_FILE"
    touch app/main.py; sleep 1; echo "$ts" > "$FREEZE_FILE"
    echo "One-shot reload triggered"
}

# ---- Shutdown ----

graceful_shutdown() {
    echo "Shutting down..."
    [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
    stop_mcp_server
    local w=0; while kill -0 "$SERVER_PID" 2>/dev/null && [ $w -lt 5 ]; do sleep 1; w=$((w+1)); done
    [ -n "$SERVER_PID" ] && kill -9 "$SERVER_PID" 2>/dev/null
    rm -f "$FREEZE_FILE" "$MCP_PID_FILE" ".dev-mcp-notify"
    [ -n "$ORIGINAL_STTY" ] && stty "$ORIGINAL_STTY"
    echo "Done"
}
trap graceful_shutdown SIGINT SIGTERM

# ---- Interactive Loop ----

show_status() {
    echo "=== Status ==="
    echo "Server PID: ${SERVER_PID:-not running}"
    echo "Port: $PORT"
    if [ -f "$FREEZE_FILE" ]; then
        local remaining=$(( FREEZE_MAX_SECONDS - ($(date +%s) - $(cat "$FREEZE_FILE")) ))
        echo "Freeze: ON ($((remaining/60))m $((remaining%60))s remaining)"
    else
        echo "Freeze: OFF"
    fi
    docker compose ps 2>/dev/null || true
}
show_help() {
    echo "Keys: s=status r=restart l=logs f=freeze t=trigger-reload h=help q=quit"
}

ORIGINAL_STTY=$(stty -g)
stty -echo -icanon min 1 time 0

echo ""
echo "Dev environment ready — press h for help"

while true; do
    check_freeze_expiry
    [ -f ".dev-mcp-notify" ] && { cat ".dev-mcp-notify"; rm ".dev-mcp-notify"; }
    if read -t 1 -n 1 key 2>/dev/null; then
        case "$key" in
            s) show_status ;;
            r) echo "Restarting..."; [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null; start_server ;;
            l) echo "Toggle log level (implement per project)" ;;
            f) toggle_freeze ;;
            t) trigger_reload ;;
            h) show_help ;;
            q) graceful_shutdown; exit 0 ;;
        esac
    fi
done
```

---

## Further Reading

- **Freddy.Backend** `start-dev.sh` — Full production implementation with workers, ngrok, OAuth, and MCP server
- **Flow-plate** `start-dev.sh` — Frontend-focused implementation with Next.js dev server
- MCP specification: https://modelcontextprotocol.io
