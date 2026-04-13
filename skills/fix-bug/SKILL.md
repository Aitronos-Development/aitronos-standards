---
name: fix-bug
description: Fix bugs from ClickUp tickets using TDD approach. Supports single tickets, batch processing, list/view fetching, and dry-run mode.
argument-hint: "<task-id | 'id1,id2,...' | list-id | view-id> [--dry-run]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, Task, AskUserQuestion, mcp__clickup__clickup_get_task, mcp__clickup__clickup_get_task_comments, mcp__clickup__clickup_update_task, mcp__clickup__clickup_create_task, mcp__clickup__clickup_create_task_comment, mcp__clickup__clickup_search, mcp__clickup__clickup_get_list
---

# Fix Bug Skill (Standards — All Projects)

**Purpose:** Systematically fix bugs from ClickUp tickets using a test-driven approach. Fetches bug details from ClickUp MCP, writes failing tests first, implements the fix, verifies all tests pass, adds regression tests, and updates ClickUp. Supports single tickets, batch processing, and dry-run mode.

---

## Input Modes

### Single Ticket (default)
Provide a single ClickUp task ID. Follows the full TDD workflow.

### Batch — Comma-Separated IDs
Provide `id1,id2,id3`. Fetches all in parallel, presents a summary table, asks which to process.

### Batch — ClickUp List ID
A purely numeric ID (e.g., `901234567890`). Fetches all tasks from the list with status filter (OPEN + IN PROGRESS by default).

### Batch — ClickUp View ID
An alphanumeric ID with hyphens (e.g., `8cjpp7y-35792`). Fetches all tasks from the view (uses ClickUp's own filters — preferred for pre-filtered views).

### Ad-hoc Bug Report (no ticket ID) — MANDATORY TICKET CREATION
When the input does NOT match a ClickUp task ID, list ID, or view ID — i.e., the user pastes a bug description, error message, screenshot, or any informal bug report:

**CRITICAL: ALWAYS create a ClickUp ticket FIRST, before any investigation or code changes.** This is non-negotiable — every bug must be tracked.

1. **Create a ClickUp ticket immediately** using `mcp__clickup__clickup_create_task`:
   - List ID: `901212755408` (Freddy Backlog)
   - Derive name from the bug description (concise, descriptive, e.g., "Image-only messages rejected without text content")
   - Set description with reproduction steps, expected vs actual behavior, and any screenshots/context the user provided
   - Set priority based on severity (urgent for blockers, high for bugs, normal for minor issues)
   - Assign to the current user (`80432583` = Phillip)
   - Add relevant tags (`backend`, `frontend`, `chat-interface`, `api`, etc.)
   - Task type: `Bug`
2. **Return the ticket ID and URL** to the user immediately — confirm the ticket was created before proceeding
3. **Proceed with the normal fix-bug pipeline** using the newly created ticket

**Do NOT skip ticket creation** even if:
- The bug seems trivial
- The fix is obvious
- The user says "quick fix"
- ClickUp MCP is not connected (inform the user and ask them to authenticate first)

### --dry-run Flag
When present: all ClickUp updates are skipped (no comments, no status changes). Fixes are still applied and tested locally.

---

## Execution Pipeline

```
FETCH → ANALYZE → TEST (RED) → FIX (GREEN) → HARDEN (REFACTOR) → UPDATE CLICKUP → REPORT
```

**Every phase is mandatory. No skipping. No reordering.**

---

## Phase 1 — Gather Context

### 1.0 Parse Input

Determine input type from $ARGUMENTS:
- **Single task ID** → proceed to 1.1
- **Comma-separated IDs** → fetch all in parallel via Task tool, present summary, ask user
- **List ID** (purely numeric) → use `mcp__clickup__clickup_get_list` to fetch tasks, filter OPEN + IN PROGRESS
- **View ID** (alphanumeric with hyphens) → use `mcp__clickup__clickup_search` to fetch from the view
- **Anything else** (bug description, error message, screenshot context, plain text) → **Ad-hoc bug report: create ClickUp ticket FIRST** (see Ad-hoc Bug Report section above), then proceed to 1.1 with the new ticket ID
- **`--dry-run`** → set DRY_RUN=true, strip from arguments

### 1.1 Fetch ClickUp Ticket

1. Use `mcp__clickup__clickup_get_task` with the task ID
2. Read: title, description, attachments, tags, priority, assignees, status
3. Fetch comments with `mcp__clickup__clickup_get_task_comments` for additional context
4. Present a **bug summary**:
   - **Title**: ticket title
   - **Description**: what's broken
   - **Priority**: urgency level
   - **Tags**: relevant areas
   - **Reproduction**: steps if available from description/comments

### 1.2 Locate Affected Code

1. Search the codebase using `Grep` and `Glob` based on the bug description and tags
2. Read all files involved in the bug's code path
3. Trace the **full execution flow** — from entry point through to the output
4. Identify the **root cause**:
   - Which file(s) contain the bug
   - Which function(s) are involved
   - Expected vs actual behavior
5. Present root cause analysis to the user and **wait for confirmation** before proceeding

### 1.2b Reproduction Escalation (Local → Staging → Production)

**If the bug cannot be reproduced locally, DO NOT stop. Escalate to remote environments:**

1. **Local first** — Run tests against `http://localhost:8000`. If bug reproduces, proceed to Phase 2.
2. **If local doesn't reproduce** → Test on **staging** (`https://api.staging.aitronos.com`):
   - Get staging credentials: `mcp__freddy-dev__get_dev_credentials(environment="staging")`
   - Run the same reproduction tests against staging
   - Test with multiple models (gpt-4o, gpt-4.1-mini, gpt-4.1-nano, gemini-2.0-flash)
   - Test with tool calls (connectors, web search, image gen) AND plain text
   - Use streaming mode — check for `response.completed` + `[DONE]` markers
3. **If staging doesn't reproduce** → Test on **production** (`https://api.aitronos.com`):
   - Get production credentials: `mcp__freddy-dev__get_dev_credentials(environment="production")`
   - Run the same test matrix
4. **If no environment reproduces** → The bug is likely resolved. Comment on ticket with full test matrix showing all environments/models tested and mark as Ready for Testing.

**Always test with an assistant attached** (`assistant_id` param) — many features (tools, system instructions, frequency_penalty) only activate with an assistant context.

**Test matrix for streaming bugs must include:**
- At least 3 different models
- Tool calls (connector connect, web search)
- Long responses (500+ events)
- Both streaming and non-streaming modes
- All three environments if local doesn't reproduce

### 1.3 Present Batch Summary (batch mode only)

```
Found N tickets (filtered: OPEN + IN PROGRESS):

| # | ID       | Title                    | Status      | Priority |
|---|----------|--------------------------|-------------|----------|
| 1 | abc123   | Login button broken      | open        | high     |
| 2 | def456   | API timeout on upload    | in progress | medium   |
```

Ask: **"Which tickets should I fix? (all / specific numbers / cancel)"** via `AskUserQuestion`.

---

## Phase 2 — Write Failing Tests (RED)

**CRITICAL: Tests MUST be written BEFORE any fix is implemented.**

### 2.1 Determine Test Location

Follow the project's existing test conventions:
- Check for `tests/`, `src/__tests__/`, `test/`, or similar directories
- Match existing test file naming patterns (e.g., `test_*.py`, `*.spec.ts`, `*_test.go`)
- Place tests alongside related test files for the affected module

### 2.2 Write the Bug-Reproducing Test

1. Create a test (or add to existing file) that **directly reproduces the bug**
2. The test MUST:
   - Set up the exact conditions described in the bug
   - Assert the **expected (correct)** behavior
   - **FAIL** against the current (buggy) code
3. Use descriptive test names that explain the expected behavior
4. Mock external dependencies — follow patterns in existing test files

### 2.3 Verify Tests Fail

1. Run the test using the project's test runner
2. Confirm the bug-reproducing test(s) **FAIL**
3. If tests pass (bug not reproduced), revisit root cause analysis
4. Show the user the failing test output

---

## Phase 3 — Implement the Fix (GREEN)

### 3.1 Make the Minimal Fix

1. Fix ONLY the root cause — no refactoring, no cleanup, no feature additions
2. Keep the change as small and focused as possible
3. Do NOT modify test files during this phase

### 3.2 Verify Tests Pass

1. Run the specific test file — ALL tests must pass, including the previously failing one
2. If any test fails, adjust the fix (NOT the tests) until green
3. Show the user the passing test output

### 3.3 Run Full Test Suite

1. Run the project's full test suite
2. Ensure no regressions — all existing tests must still pass
3. If regressions are found, fix them without breaking the bug fix

---

## Phase 4 — Harden with Regression Tests (REFACTOR)

### 4.1 Add Comprehensive Tests Around the Fix

After the fix is verified, add tests to **secure the area**:

1. **Edge cases** — boundary values, empty states, null/undefined inputs
2. **Related scenarios** — similar code paths that could have the same bug
3. **Integration points** — how the fixed code interacts with upstream/downstream
4. **State transitions** — various orderings that could trigger the bug
5. **Error handling** — what happens when dependencies fail

### 4.2 Verify All New Tests Pass

1. Run the specific test file — all new tests must pass
2. Run the full suite again to confirm no regressions

---

## Phase 5 — Update ClickUp & Report

**If `--dry-run` was specified:** Skip 5.1 and 5.3. Still present the fix for user verification (5.2).

### 5.1 Present Fix to User for Verification

**CRITICAL: NEVER post comments, update status, or make ANY ClickUp changes without explicit user approval.**

Present to the user:
1. **Root cause** — what was wrong
2. **Fix** — what was changed (file diffs)
3. **Tests** — count and descriptions of all tests added
4. **Test results** — final test run output
5. **How to verify** — exact steps the user can take to manually confirm the fix
6. **Proposed ClickUp comment** — show the draft comment text for user review

Ask via `AskUserQuestion`:
- "Fix confirmed — works correctly, post comment and update ticket"
- "Fix confirmed — but I'll handle ClickUp myself"
- "Still broken — needs more work"
- "Partially fixed — see my notes"

If the user says it's NOT working:
- Do NOT update the ticket
- Ask what's still broken
- Return to Phase 3 to iterate

### 5.2 Comment on ClickUp Ticket (ONLY after user approval)

**NEVER post a comment without the user explicitly saying to do so.**

Only after the user approves both the fix AND the comment, use `mcp__clickup__clickup_create_task_comment` to post:

```
## Bug Fix Summary

**Root Cause:** [1-2 sentence explanation]

**Fix:** [what was changed and why]

**Files Changed:**
- `path/to/file` — [what changed]

**Tests Added:**
- [test description 1]
- [test description 2]

**Verification:** All tests passing (X total, Y new)
```

### 5.3 Update ClickUp Ticket Status (ONLY after user approval)

**NEVER update ticket status without the user explicitly saying to do so.**

1. Use `mcp__clickup__clickup_update_task` to move the ticket to the next status (typically peer review / code review / testing)
2. If unsure of the exact status name, check available statuses from the task data first
3. Inform the user: "Ticket [ID] moved to [status]."

---

## Batch Summary (batch mode only)

After processing all selected tickets, present a final summary:

```
## Bug Fix Run Complete

| Ticket | Title | Root Cause | Fix | Tests Added | ClickUp Updated |
|--------|-------|------------|-----|-------------|-----------------|
| abc123 | Login broken | Event binding timing | Move to lifecycle hook | 4 | Yes |
| def456 | API timeout | Missing validation | Add guard clause | 2 | Yes |
| ghi789 | CSS glitch | Wrong token | Replace token | 1 | Dry run |
```

---

## ClickUp Status Pipeline Reference

| Category | Statuses |
|----------|----------|
| Backlog | OPEN, IN ROADMAP, PLANNED |
| Active | IN PROGRESS, UNIT / SELF TESTING, IN PEER REVIEW, READY FOR TESTING, IN TESTING |
| Review | DEMO READY, BLOCKED |
| Done | READY FOR DEPLOYMENT, IN PRE-PROD, IN PROD DEPLOYMENT |
| Closed | TESTED & CLOSED |

**Agent processes:** OPEN + IN PROGRESS only (by default)
**After fix:** Move to next review status (with user approval)

---

## Rules

1. **NEVER skip Phase 2** — Tests must be written before the fix. No exceptions.
2. **NEVER modify tests to make them pass** — If a test fails after the fix, the fix is wrong, not the test.
3. **Minimal changes only** — Fix the bug. Don't refactor surrounding code.
4. **Mock external dependencies** — Tests must not make real API calls or depend on external state.
5. **Follow existing patterns** — Match the project's test style, naming conventions, and file organization.
6. **Show your work** — Present test output at each phase so the user can verify.
7. **NEVER touch ClickUp without explicit user approval** — No comments, no status changes, no assignments without the user saying to do it. Always show the draft first and wait for approval.
8. **One ticket at a time** — In batch mode, process tickets sequentially to maintain clarity.
9. **Default status filter** — Only fetch OPEN + IN PROGRESS tickets unless user explicitly requests all.
10. **Dry-run respects boundaries** — `--dry-run` skips ALL ClickUp mutations (comments + status updates).
11. **Root cause first** — Always present the root cause and get user confirmation before writing any code.
12. **Report is mandatory** — In batch mode, always present the final summary table after all tickets.
