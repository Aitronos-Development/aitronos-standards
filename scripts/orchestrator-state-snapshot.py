"""Snapshot orchestrator state before context compaction.

Called by the PreCompact hook in .claude/settings.json.
Output is injected into Claude's fresh context after compaction.
"""

import glob
import json
import os
import pathlib

tasks_root = os.path.expanduser("~/.claude/tasks")
teams_root = os.path.expanduser("~/.claude/teams")


def is_uuid(name: str) -> bool:
    return len(name) == 36 and name.count("-") == 4


# Show named teams (skip UUID-named stale ones)
if os.path.isdir(teams_root):
    named = [d for d in os.listdir(teams_root) if not is_uuid(d)]
    if named:
        pass
    else:
        pass

# Show non-completed tasks from named team dirs only
if os.path.isdir(tasks_root):
    for team_dir in sorted(pathlib.Path(tasks_root).iterdir()):
        name = team_dir.name
        if is_uuid(name):
            continue
        tasks = []
        for f in team_dir.glob("*.json"):
            try:
                t = json.loads(f.read_text())
                if t.get("status") != "completed":
                    tasks.append(t)
            except Exception:
                pass
        if tasks:
            for t in tasks:
                status = t.get("status", "?")
                subject = t.get("subject", "?")
                owner = t.get("owner", "unassigned")

# Show ROADMAP if exists
for rm in glob.glob("docs/.specs/*/ROADMAP.md"):
    with open(rm) as f:
        for i, _line in enumerate(f):
            if i >= 25:
                break
