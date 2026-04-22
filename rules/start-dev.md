# start-dev.sh Standard

## Core Principle
**Every Aitronos project MUST have a `start-dev.sh` at the root. Running `./start-dev.sh` takes a developer from zero to a running dev environment — no manual steps.**

## Required Capabilities

### Prerequisites
- Detect missing tools (runtime, database CLI, Docker, etc.)
- On macOS: offer Homebrew batch install for all missing tools
- On Linux: print manual install instructions
- Fail fast with a clear message if critical tools are missing

### Docker Management
- Auto-start Docker Desktop if not running (macOS)
- Start required containers (database, cache, queue, etc.)
- Wait for containers to be healthy before proceeding

### Environment Setup
- Generate `.env` from template if missing
- Validate required environment variables are set
- Warn on stale or incomplete `.env` files

### Database
- Run migrations automatically
- Seed development data if needed

### Credentials
- Generate dev credentials (API key, access token)
- Write to `.dev-credentials` for easy access by scripts and AI tools

### Server
- Start the dev server with auto-reload (file watcher on source directory)
- Print the local URL and any other access info on startup

### Interactive Mode
Single-keypress commands during runtime:

| Key | Action |
|-----|--------|
| `s` | Show status (server health, containers, ports, freeze timer) |
| `r` | Restart the server |
| `l` | Toggle log verbosity |
| `f` | Freeze/unfreeze auto-reload |
| `t` | Trigger one-shot reload while frozen |
| `h` | Show help |
| `q` | Quit (graceful shutdown) |

### Freeze Mode
- `f` toggles freeze on/off — suppresses file-change reloads while frozen
- **MUST auto-expire after 15 minutes** — a forgotten freeze is a silent time sink
- `s` (status) shows remaining freeze time
- `t` triggers a single reload without unfreezing

### Graceful Shutdown
- Two-stage: SIGTERM first, SIGKILL after timeout
- Clean up temp files, PID files, and containers started by the script
- Trap SIGINT/SIGTERM so Ctrl+C is clean

### Flags
- `--force` — kill existing processes on the port before starting
- `--separate` — branch-isolated containers and ports (for parallel feature work)

### MCP Dev Server
- Auto-start a local MCP server that exposes dev tools to AI coding assistants
- Track PID in `.dev-mcp-server.pid`, stop on script exit
- Support `.dev-mcp-notify` file for MCP-to-interactive-loop notifications

### AI Tool Rule Sync
- On startup, sync `.claude/rules/` to other AI tools' rule directories:
  - Cursor: `.cursor/rules/`
  - Kiro: `.kiro/steering/`
  - Windsurf: `.windsurfrules/`
- Ensures all AI coding tools share the same engineering standards

## Required MCP Tools

Every project's MCP dev server must expose these tools:

| Tool | Purpose |
|------|---------|
| `get_backend_logs` / `tail_logs` | Read service logs |
| `get_dev_credentials` | Retrieve dev API keys and tokens |
| `call_api` | Call any project API with auto-auth |
| `test_api_connection` | Quick health check |
| `toggle_freeze` | Freeze/unfreeze auto-reload |
| `trigger_reload` | One-shot reload while frozen |
| `get_freeze_status` | Check freeze state |
| `get_current_status` | Dev environment status summary |

## Project-Specific Additions

Projects will add their own capabilities (workers, ngrok tunnels, frontend dev servers, OAuth flows, etc.). The requirements above are the **mandatory baseline**.

## Reference

See `.standards/guides/start-dev-reference.md` for the full implementation guide and copy-paste skeleton script.