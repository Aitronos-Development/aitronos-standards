#!/bin/bash
# Orchestrator guardrail — blocks Write/Edit to non-documentation files.
# Only runs when defined in the orchestrator agent's hooks (agent frontmatter),
# so no agent detection logic needed.
#
# Exit codes:
#   0 = allow the tool call
#   2 = block the tool call (feedback sent to Claude via stderr)

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')

# Only gate file-writing tools
if [[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "NotebookEdit" ]]; then
  exit 0
fi

# No file path — let Claude Code handle the error
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Allow documentation and spec files
case "$FILE_PATH" in
  *.md|*.mdc|*.mdx|*.txt|*.yaml|*.yml)
    exit 0
    ;;
esac

# Allow files in known documentation/spec directories
# Match both relative (.claude/...) and absolute (*/.../.claude/...) paths
case "$FILE_PATH" in
  docs/*|*/docs/*|.specs/*|*/.specs/*|.claude/*|*/.claude/*|.standards/*|*/.standards/*|.agent/*|*/.agent/*|.kiro/*|*/.kiro/*|.cursor/*|*/.cursor/*)
    exit 0
    ;;
esac

# Block everything else
cat >&2 << EOF
ORCHESTRATOR GUARDRAIL: You are the orchestrator — you do not write application code.

Blocked: $TOOL_NAME on $FILE_PATH

What to do instead:
1. Spawn a developer agent (general-purpose subagent) to make this change
2. Tell the developer WHAT to change and WHERE to look
3. Wait for the developer to complete, then verify the result

If you believe this file should be allowed, it may need to be added to the
guardrail allowlist in .standards/scripts/orchestrator-guardrail.sh
EOF

exit 2
