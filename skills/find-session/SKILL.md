---
name: find-session
description: Search past Claude Code sessions by keyword, date, or topic. Use when you can't find a previous conversation and need the session ID to resume it.
disable-model-invocation: false
user-invocable: true
---

# Find Session

Search past Claude Code sessions and return the session ID for resuming.

## Usage

```
/find-session <search terms>
/find-session --recent 10
/find-session --all sharepoint oauth
```

## Process

<workflow>

### Step 1: Determine Session Directory

The session files live at:
```
~/.claude/projects/<encoded-cwd>/*.jsonl
```

Where `<encoded-cwd>` is the current working directory with `/` replaced by `-`.

Find the correct directory:
```bash
PROJECT_DIR=$(echo "$PWD" | sed 's|/|-|g; s|^-||')
SESSION_DIR="$HOME/.claude/projects/-${PROJECT_DIR}"
echo "Session dir: $SESSION_DIR"
ls "$SESSION_DIR"/*.jsonl 2>/dev/null | wc -l
```

If the user passes `--all`, also search ALL project directories under `~/.claude/projects/`.

### Step 2: Run the Search

Each `.jsonl` file is one session. Run this Python script to extract metadata and search. **Replace the three placeholders** before executing:

- `SESSION_DIR_PLACEHOLDER` — the session directory path from Step 1 (or `~/.claude/projects` if `--all`)
- `SEARCH_TERMS_PLACEHOLDER` — a Python list of the user's search keywords, e.g. `["knowledge", "connectors"]`. Use `[]` if no search terms.
- `RECENT_COUNT_PLACEHOLDER` — number of recent sessions to show (default `10` when no search terms given)
- `SEARCH_ALL_PLACEHOLDER` — `True` if `--all` flag was passed, `False` otherwise

```bash
python3 << 'PYEOF'
import json, os
from datetime import datetime

session_dir = os.path.expanduser("SESSION_DIR_PLACEHOLDER")
search_terms = SEARCH_TERMS_PLACEHOLDER
show_recent = RECENT_COUNT_PLACEHOLDER
search_all = SEARCH_ALL_PLACEHOLDER

# Collect session directories to scan
scan_dirs = []
if search_all:
    projects_root = os.path.expanduser("~/.claude/projects")
    for d in os.listdir(projects_root):
        full = os.path.join(projects_root, d)
        if os.path.isdir(full):
            scan_dirs.append(full)
else:
    scan_dirs.append(session_dir)

results = []
for sdir in scan_dirs:
    project_label = os.path.basename(sdir) if search_all else ""
    for fname in os.listdir(sdir):
        if not fname.endswith('.jsonl'): continue
        fpath = os.path.join(sdir, fname)
        mtime = os.path.getmtime(fpath)
        size = os.path.getsize(fpath)
        session_id = fname.replace('.jsonl', '')

        branch = ''
        user_messages = []
        try:
            with open(fpath) as f:
                for i, line in enumerate(f):
                    if i > 500: break
                    if len(user_messages) >= 5: break
                    try:
                        obj = json.loads(line.strip())
                        t = obj.get('type', '')

                        if not branch and obj.get('gitBranch'):
                            branch = obj['gitBranch']

                        if t == 'user':
                            msg = obj.get('message', {})
                            content = ''
                            if isinstance(msg, dict):
                                c = msg.get('content', '')
                                if isinstance(c, str):
                                    content = c
                                elif isinstance(c, list):
                                    for item in c:
                                        if isinstance(item, dict) and item.get('type') == 'text':
                                            content = item.get('text', '')
                                            break
                            if content and '<system-reminder>' not in content[:100] and len(content.strip()) > 15:
                                clean = content
                                for tag in ['<command-message>', '<command-name>', '<command-args>',
                                           '</command-message>', '</command-name>', '</command-args>',
                                           '<local-command-caveat>', '</local-command-caveat>',
                                           '<local-command-stdout>', '</local-command-stdout>']:
                                    clean = clean.replace(tag, ' ')
                                clean = ' '.join(clean.split())[:300]
                                if len(clean.strip()) > 15:
                                    user_messages.append(clean)
                    except:
                        pass
        except:
            pass

        results.append({
            'session_id': session_id,
            'mtime': mtime,
            'size': size,
            'branch': branch,
            'messages': user_messages,
            'project': project_label,
        })

results.sort(key=lambda x: x['mtime'], reverse=True)

if search_terms:
    scored = []
    for r in results:
        combined = ' '.join(r['messages']).lower()
        combined += ' ' + r['branch'].lower()
        score = sum(1 for term in search_terms if term.lower() in combined)
        if score > 0:
            scored.append((score, r))
    scored.sort(key=lambda x: (-x[0], -x[1]['mtime']))
    matched = [s[1] for s in scored]
else:
    matched = results[:show_recent]

if not matched:
    print("No sessions found matching your search.")
    print(f"Total sessions scanned: {len(results)}")
else:
    print(f"Found {len(matched)} matching session(s):\n")
    for r in matched[:15]:
        dt = datetime.fromtimestamp(r['mtime']).strftime('%Y-%m-%d %H:%M')
        size_str = f"{r['size']/1024/1024:.1f}MB" if r['size'] > 1024*1024 else f"{r['size']/1024:.0f}KB"
        proj = f"  project: {r['project']}" if r['project'] else ""
        print(f"  {dt}  {size_str:>8}  branch: {r['branch']}{proj}")
        print(f"  ID: {r['session_id']}")
        for j, m in enumerate(r['messages'][:3]):
            label = ">>>" if j == 0 else "   "
            print(f"  {label} {m[:150]}")
        print()

    print("---")
    print("To resume a session:")
    print("  claude --resume <session-id>")
PYEOF
```

### Step 3: Present Results

Format output as a clean list showing:
1. Date/time modified
2. Size (rough session length indicator)
3. Git branch
4. Session ID
5. First user message(s) — the most useful for identification

Always end with the resume command:
```
claude --resume <session-id>
```

### Step 4: Refine if Needed

If too many results or no results:
- **Too many**: Ask user to narrow with more specific terms or a date range
- **None found**: Try broader terms, or rerun with `--all` to search all projects
- **User wants to peek inside**: Read the first 50 lines of the specific `.jsonl` to show conversation flow

</workflow>

## Tips

- Large sessions (>5MB) are usually `/orchestrate` or long feature builds
- Session size correlates with conversation length
- The git branch often identifies the feature context
- First user message is the best identifier — it's what you actually said to start the session
- Use `--all` to search across every project, not just the current one
