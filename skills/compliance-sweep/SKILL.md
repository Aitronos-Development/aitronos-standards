---
name: compliance-sweep
description: "Full repository compliance cleanup — fixes ALL warnings and errors across code quality, documentation, and project structure. Runs the compliance suite, doc validators, and project structure checks, then automatically fixes everything found. The repo is PR-ready when done."
disable-model-invocation: false
user-invocable: true
---

# Compliance Sweep

Full project-wide compliance sweep. Finds and fixes **everything** — code quality warnings, documentation gaps, project structure issues, and validator bugs. When this skill finishes, the repo is clean and PR-ready.

This is the short-form, whole-repo equivalent of `/compliance-audit` (which audits a single domain with 8 deep agents). This skill trades the deep domain-level security/logic audit for breadth — it covers the entire codebase and fixes every compliance check the runner reports.

## When to Use

- Before creating a PR
- Regular codebase hygiene
- After a big feature lands and you want to clean up the mess
- When `scripts/compliance/runner.py` reports warnings you want to clear
- When doc validators report issues

## What This Fixes

| Category | Issues Fixed | Tool Used |
|----------|-------------|-----------|
| **Ruff lint/format** | Auto-fixable lint errors, formatting | `ruff check --fix`, `ruff format` |
| **Missing type annotations** | Return types on route handlers, param types | Manual edit |
| **`# noqa` / `# compliance: ignore`** | Remove suppressions, fix underlying issues | Manual edit |
| **Naming conventions** | snake_case violations, auto-fixable renames | Auto-fix + manual |
| **File size** | Files over 600 lines — split into modules | Manual refactor |
| **Complexity** | Functions over thresholds — extract helpers | Manual refactor |
| **Doc accuracy** | Missing `system_message`, undocumented params, schema mismatches, status code mismatches, missing auth headers in examples | Manual edit |
| **Doc forbidden terms** | Vendor names in public docs | Manual edit |
| **Doc quality** | Template conflicts, broken links | Manual edit |
| **Project structure** | Stray root files, misplaced configs | `mv` to correct locations |
| **Validator bugs** | Checks reporting FAILED with 0 issues | Fix validator scripts |

## Usage

```
/compliance-sweep
```

Or with options:
```
/compliance-sweep --check-only       # Report everything, fix nothing
/compliance-sweep --code-only        # Skip doc fixes, only fix code quality
/compliance-sweep --docs-only        # Skip code fixes, only fix documentation
```

<workflow>

### Step 1: Run Full Compliance Suite + Doc Validators

Run ALL checks in parallel to get the full picture. Capture all output.

**Compliance runner (all checks):**
```bash
{{config:commands.compliance.full}}
```

**Doc validators (run in parallel):**
```bash
python3 scripts/compliance/doc_accuracy_validator.py 2>&1
```
```bash
python3 scripts/compliance/doc_quality_validator.py 2>&1
```
```bash
python3 scripts/compliance/forbidden_terms_validator.py 2>&1
```
```bash
python3 scripts/compliance/doc_coverage_validator.py 2>&1
```

Read the generated reports from `compliance_reports/{date}/` to get structured violation data.

### Step 2: Triage and Plan

Parse all violations into a work plan. Categorize into **parallel work streams** that can be dispatched simultaneously:

| Stream | What | Approach |
|--------|------|----------|
| A — Auto-fix | Ruff lint/format, naming conventions, whitespace | Run auto-fix commands |
| B — Type annotations | Missing return types and param types | Batch by file, edit directly |
| C — Suppression cleanup | `# noqa` and `# compliance: ignore` comments | Read each, fix underlying issue, remove comment |
| D — Doc accuracy | Error format, params, examples, schemas | Batch by doc domain |
| E — Doc terms/quality | Forbidden terms, template conflicts, broken links | Search and replace |
| F — Project structure | Stray files, misplaced configs | Move files |
| G — Complexity/size | Large files, complex functions (if any over error threshold) | Refactor |

Present the plan as a summary table:

```
Compliance Cleanup Plan
━━━━━━━━━━━━━━━━━━━━━━━

Stream A — Auto-fix:           {N} issues (automated)
Stream B — Type annotations:   {N} issues across {M} files
Stream C — Suppression cleanup:{N} issues across {M} files
Stream D — Doc accuracy:       {N} issues across {M} docs
Stream E — Doc terms/quality:  {N} issues
Stream F — Project structure:  {N} files to move
Stream G — Complexity/size:    {N} issues (if any)

Total: {TOTAL} issues to fix
```

If `--check-only` was passed, stop here.

### Step 3: Auto-Fix Pass (Stream A)

Run automated fixes first — they're fast and reduce the manual work count:

```bash
# Format code
uvx ruff format .

# Fix auto-fixable lint issues
uvx ruff check . --fix

# Run the compliance auto-fix
{{config:commands.compliance.fast}} --auto-fix 2>&1
```

Re-run the compliance runner in fast mode to see what remains:
```bash
{{config:commands.compliance.fast}}
```

Update the work plan — remove anything that was auto-fixed.

### Step 4: Parallel Manual Fixes (Streams B–G)

Dispatch **parallel agents** to handle each stream simultaneously. Each agent works directly in the main working directory (NO worktrees, NO orchestrator).

**IMPORTANT**: Use `mode: "bypassPermissions"` for all fix agents. Do NOT use `isolation: "worktree"` — changes must land in the main working tree.

#### Agent B: Type Annotation Fixer

**Task**: Add missing return type annotations to route handlers and missing parameter type annotations.

**Instructions for agent**:
1. Read the error patterns report from `compliance_reports/{date}/json/error_patterns_violations.json`
2. Filter for violations containing "missing return type annotation" or "missing type annotation"
3. For each file, read the function signature and add the correct type
4. For route handlers: use the response model from the decorator, or `dict` / `Response` / `JSONResponse` as appropriate
5. For parameters: infer from usage or use `Any` as last resort
6. Do NOT add types to functions that don't need them (private helpers with obvious types)

#### Agent C: Suppression Cleanup

**Task**: Remove `# noqa` and `# compliance: ignore` comments by fixing the underlying issues.

**Instructions for agent**:
1. Read the error patterns report for violations containing "noqa" or "compliance: ignore"
2. For each suppression:
   - Read the line and surrounding context
   - Determine what the suppression is hiding (unused import, line too long, type error, etc.)
   - Fix the underlying issue (remove unused import, break long line, fix type, etc.)
   - Remove the suppression comment
3. If the suppression is genuinely needed (rare — e.g., intentional unused import for re-export), convert to a specific `# noqa: XXXX` with the exact error code and add a brief comment explaining why

#### Agent D: Doc Accuracy Fixer

**Task**: Fix all documentation accuracy violations.

**Instructions for agent**:
1. Read `compliance_reports/{date}/json/doc_accuracy_violations.json` for the full violation list
2. Fix each violation type:
   - **ERROR_MISSING_FIELD**: Add missing fields to error response JSON blocks. Every error response MUST have: `code`, `message`, `system_message`, `type`, `status`, `details`, `trace_id`, `timestamp`
   - **MISSING_PARAMETER**: Add undocumented parameters from the OpenAPI spec. Read `openapi.json` for the correct param names, types, and descriptions
   - **EXAMPLE_EXTRA_FIELD / EXAMPLE_MISSING_REQUIRED_FIELD**: Update response examples to match spec schema
   - **STATUS_CODE_MISMATCH**: Fix response tab status codes to match spec
   - **CODE_EXAMPLE_***: Fix HTTP methods and paths in cURL/Python/JS examples
   - **UNKNOWN_ERROR_CODE**: Replace with valid codes from `app/core/error_codes.py`
   - **INVALID_ERROR_TYPE**: Use correct type values: `client_error`, `authentication_error`, `authorization_error`, `server_error`, `validation_error`, `rate_limit_error`
   - **Missing auth headers**: Add `X-API-Key` or `Authorization: Bearer` headers to code examples
3. Standard error response format:
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "User-friendly message",
    "system_message": "Technical message for developers",
    "type": "client_error",
    "status": 400,
    "details": {},
    "trace_id": "req_abc123xyz",
    "timestamp": "2025-12-22T15:30:00Z"
  }
}
```

#### Agent E: Doc Terms and Quality Fixer

**Task**: Fix forbidden term violations and doc quality issues.

**Instructions for agent**:
1. Fix forbidden terms: Replace vendor names (Composio, Airbyte, Fivetran, Qdrant) with approved alternatives per `.claude/rules/forbidden-terms-in-public-docs.md`
2. Fix template syntax conflicts
3. Fix broken links
4. Preserve forbidden terms inside API URLs, property names, operationIds, and code example URLs that reference real endpoints

#### Agent F: Project Structure Fixer

**Task**: Move misplaced files to correct locations.

**Instructions for agent**:
1. Move stray markdown files from root to `docs/` (except README.md, LICENSE.md, CHANGELOG.md, CONTRIBUTING.md, WARP.md)
2. Verify `.gitignore` entries for flagged files that should be ignored
3. Clean up any `.DS_Store` or other OS artifacts
4. Do NOT move config files that legitimately belong at root (`codecov.yml`, `project.config.yaml`, `package.json`, etc.) — instead, if the validator flags these incorrectly, note them for Step 6

#### Agent G: Complexity/Size Fixer (only if needed)

**Task**: Refactor files over 1000 lines (error threshold) and functions over error thresholds.

**Instructions for agent** (only spawn if violations exist):
1. Read the complexity/file size reports
2. For files over 1000 lines: split into logical modules, update imports
3. For functions over 120 lines: extract helper functions
4. For functions with >8 parameters: group into dataclass/TypedDict
5. Run tests after each refactor to ensure nothing breaks

### Step 5: Verify Fixes

After all agents complete, run the full suite again:

```bash
# Full compliance
{{config:commands.compliance.full}}

# Doc validators
python3 scripts/compliance/doc_accuracy_validator.py 2>&1
python3 scripts/compliance/doc_quality_validator.py 2>&1
python3 scripts/compliance/forbidden_terms_validator.py 2>&1
python3 scripts/compliance/doc_coverage_validator.py 2>&1

# Tests — make sure nothing is broken
{{config:commands.test.unit}}
```

### Step 6: Fix Remaining Issues (Loop)

If the verification step still shows issues:

```
LOOP (max 3 iterations):
  1. Parse remaining violations
  2. Fix them directly (small batches — use Edit tool, not agents)
  3. Re-run the relevant validators
  4. IF zero issues → BREAK
  5. ELSE → continue loop
```

**CRITICAL**: Do NOT stop and ask the user. Fix everything to completion. The skill is authorized to run autonomously until clean.

### Step 7: Final Report

Present the results:

```
Compliance Cleanup Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━

Before:
  Code quality warnings:  {N}
  Doc accuracy warnings:  {N}
  Project structure:      {N}
  Total:                  {TOTAL}

After:
  Code quality warnings:  {N}  ({-delta})
  Doc accuracy warnings:  {N}  ({-delta})
  Project structure:      {N}  ({-delta})
  Total:                  {TOTAL}

Fixed: {FIXED} issues
Remaining: {REMAINING} (with details if any)

Tests: {PASS}/{TOTAL} passing
```

If anything remains unfixed, explain WHY (e.g., "3 warnings are false positives from the validator flagging legitimate root config files") and whether the validator itself should be updated.

</workflow>

## Rules

- **Fix everything** — warnings AND errors. The goal is zero issues, not just zero errors.
- **Never use worktrees** — all changes must land in the main working directory.
- **Never pause to ask** — run to completion autonomously.
- **Run tests after fixes** — ensure nothing is broken before reporting done.
- **Don't over-refactor** — fix what the compliance checks flag, don't rewrite working code.
- **Preserve behavior** — type annotations and doc fixes must not change runtime behavior.
- **Batch intelligently** — group fixes by file to minimize Edit tool calls.
- **Report honestly** — if something can't be fixed (validator bug, false positive), say so clearly.

## Difference from Other Skills

| Skill | Scope | Depth | Fixes? |
|-------|-------|-------|--------|
| `/compliance-fix` | DEPRECATED — redirects here | — | — |
| `/compliance-audit` | Single domain | Deep (8 agents, security, logic, tests) | Yes, with re-audit loop |
| `/update-docs` | Documentation only | Deep (4 validators) | Yes |
| **`/compliance-sweep`** | **Entire repository** | **Broad (all checks, all validators)** | **Yes, everything** |

This skill is the "make it all green" button. It doesn't do deep security auditing or logic analysis — use `/compliance-audit` for that. It does make every compliance check pass and every warning disappear.
