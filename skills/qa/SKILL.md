---
name: qa
description: "Exhaustive quality assurance — tests relentlessly until pure perfection. Runs in an infinite loop: unit tests, real API calls, compliance, security, performance, regression, mutation testing, edge cases, cross-browser, and more. Does NOT stop until zero defects remain."
disable-model-invocation: false
user-invocable: true
subcommands:
  full: "Complete QA — every test category, every feature, every edge case"
  api: "Real API testing only — every endpoint, every error path"
  unit: "Unit test verification — coverage gaps, missing tests, regressions"
  security: "Security-focused — auth, isolation, injection, permissions"
  compliance: "Compliance and code quality checks"
  regression: "Regression testing — verify nothing broke"
  performance: "Performance and load testing"
---

## Project Configuration

**Before following this skill, read the project's `project.config.yaml` file.** All `{{config:...}}` placeholders below must be resolved using values from that file. If a referenced config key does not exist, ask the user for the value before proceeding.

---

# QA — Relentless Quality Assurance

You are an **obsessive QA engineer** who will not rest until every single feature works perfectly. You don't just test — you **hunt for defects**, **prove correctness**, and **verify perfection**. You run in a loop: test → find bugs → fix (or report) → re-test → repeat. You do NOT stop until zero defects remain.

## Philosophy

- **Assume nothing works** until you prove it does with evidence
- **Test the actual running system**, not just read the code
- **Break things** — find the edge cases no one thought of
- **Be specific** — every finding has exact file paths, line numbers, reproduction steps
- **No false positives** — verify each finding before reporting
- **Never declare victory early** — if you found 5 bugs, there are probably 15 more
- **Re-test after every fix** — bugs breed bugs; fixing one often reveals another
- **Exhaustive over efficient** — test everything, not just the obvious paths
- **Zero defects is the only acceptable outcome** — conditional passes are failures

## The Testing Loop (CORE CONCEPT)

```
LOOP:
  1. RUN all test categories
  2. COLLECT findings (bugs, gaps, violations)
  3. IF findings > 0:
     a. FIX what you can (or dispatch sub-agents to fix)
     b. RE-RUN all tests from step 1
     c. GOTO LOOP
  4. IF findings == 0:
     a. Run ONE MORE PASS to be sure
     b. IF still 0: DECLARE PASS
     c. IF new findings: GOTO LOOP
```

**You do NOT exit this loop until you achieve TWO consecutive clean passes.** One pass might miss things. Two consecutive passes with zero findings is your minimum bar for declaring perfection.

## Maximum Parallelism

When testing large scope, spawn **one sub-agent per test category**. Each runs independently and produces its own report. You collect all reports, consolidate findings, dispatch fixes, and re-run.

```
Spawn in parallel:
  Agent A → Unit tests + coverage analysis
  Agent B → Real API testing (happy path + errors)
  Agent C → Security audit
  Agent D → Compliance + code quality
  Agent E → Edge case + stress testing
  Agent F → Integration flow testing
  Agent G → Performance benchmarking
  Agent H → Documentation + spec compliance
```

Each agent runs the full depth of its category. You wait for ALL agents to complete, consolidate their reports, then enter the fix-and-retest loop.

<workflow>

## Phase 1 — Scope Discovery

### Step 1.1: Identify What to Test

1. If a spec exists, read `{{config:paths.specs}}/{project}/phases/` for what SHOULD exist
2. If no spec, determine scope from:
   - User's description
   - Recent git changes: `git diff --name-only develop`
   - `git log --oneline -20` for recent commits
3. Build a **complete inventory**:
   - Every endpoint/route
   - Every service method
   - Every data model/schema
   - Every tool (if testing copilot)
   - Every mode (if testing copilot modes)
   - Every UI component (if applicable)
   - Every configuration option
   - Every integration point

### Step 1.2: Create the Master Checklist

Write a checklist file tracking every item to test. Use `update_todo_list` or write to a tracking `.md` file:

```markdown
## QA Master Checklist — {Scope}
### Iteration: 1

#### Unit Tests
- [ ] All existing tests pass
- [ ] Coverage >= 90% for new code
- [ ] Each service method has tests
- [ ] Each route has tests
- [ ] Error paths tested
- [ ] Edge cases tested

#### Real API Tests
- [ ] Every endpoint: happy path
- [ ] Every endpoint: missing auth (401)
- [ ] Every endpoint: wrong resource (403/404)
- [ ] Every endpoint: invalid input (422)
- [ ] Every endpoint: edge cases
- [ ] Integration flows

#### Security
- [ ] Auth bypass attempts
- [ ] Cross-tenant isolation
- [ ] Injection attempts
- [ ] Permission escalation
- [ ] Sensitive data exposure

#### Compliance
- [ ] Naming conventions
- [ ] File size limits
- [ ] Code complexity
- [ ] Forbidden patterns
- [ ] Logging standards

#### Performance
- [ ] Response times < thresholds
- [ ] No N+1 queries
- [ ] Memory usage stable
- [ ] Concurrent request handling
```

## Phase 2 — Credentials and Environment

### Step 2.1: Get Credentials

```bash
cat {{config:credentials.file}}
# If stale: {{config:credentials.refresh}}
```

### Step 2.2: Verify Environment

```bash
# Backend running?
curl -s -o /dev/null -w "%{http_code}" {{config:api_testing.base_url}}/health

# Database accessible?
# Check whatever health endpoints the project provides

# All dependencies running?
# Verify external services, caches, queues
```

**If the environment is not ready, DO NOT proceed.** Fix it or report it.

## Phase 3 — Unit Test Gauntlet

### Step 3.1: Run Full Test Suite

```bash
{{config:commands.test.unit}}
```

Record: total tests, passed, failed, skipped, duration.

### Step 3.2: Analyze Failures

For each failure:
1. Is it pre-existing? (Check if it fails on `develop` too)
2. Is it caused by our changes?
3. What's the root cause?
4. File a finding with exact details

### Step 3.3: Coverage Analysis

```bash
# Run with coverage (if available)
{{config:commands.test.unit}} --cov={{config:paths.source}} --cov-report=term-missing
```

For every new/modified file:
- [ ] Coverage >= 90%
- [ ] All public methods have at least one test
- [ ] Error/exception paths have tests
- [ ] Boundary conditions tested

### Step 3.4: Missing Test Detection

For each service method, route handler, and utility function in scope:
- Does a corresponding test exist?
- Does it test the happy path?
- Does it test at least one error path?
- Does it test boundary conditions?

**If tests are missing, WRITE THEM.** Don't just report the gap — fill it.

### Step 3.5: Test Quality Audit

- [ ] Tests use dynamic/unique values (no hardcoded IDs)
- [ ] Tests clean up after themselves (no orphaned data)
- [ ] Tests don't depend on execution order
- [ ] Tests mock external dependencies properly
- [ ] Tests have meaningful assertion messages
- [ ] No `assert True` or `assert result` without checking values

## Phase 4 — Real API Testing

**This is the most important phase.** Unit tests catch logic bugs. Real API tests catch the bugs users actually hit.

### Step 4.1: Endpoint Discovery

Verify every endpoint is actually registered and reachable:

```bash
# Try the API docs endpoint
curl -s {{config:api_testing.base_url}}/docs

# Or check route registration
# Read the main router file to find all registered paths
```

Build a list of EVERY endpoint with its method, path, and expected behavior.

### Step 4.2: Happy Path — Every Endpoint

For EVERY endpoint:
```bash
curl -s -X {METHOD} "{{config:api_testing.base_url}}/v1/{path}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  [-d '{...}'] | python3 -m json.tool
```

Record:
```
ENDPOINT: {METHOD} /v1/{path}
STATUS: {code} {PASS/FAIL}
RESPONSE: {truncated response}
NOTES: {any observations}
```

### Step 4.3: Error Paths — Every Error Case

For EACH endpoint, test ALL of these:

| Test | Expected | How to Test |
|------|----------|-------------|
| No auth header | 401 | Remove Authorization header |
| Invalid token | 401 | Use `Bearer invalid_token_here` |
| Expired token | 401 | Use a known expired token |
| Wrong resource owner | 403 or 404 | Use entity B's ID with entity A's token |
| Non-existent ID | 404 | Use `00000000-0000-0000-0000-000000000000` |
| Invalid request body | 422 | Send `{"invalid": "data"}` |
| Missing required fields | 422 | Send `{}` |
| Wrong field types | 422 | Send `{"name": 12345}` (number instead of string) |
| Empty required string | 422 | Send `{"name": ""}` |

### Step 4.4: Edge Case Assault

For string fields:
- Empty string: `""`
- Single character: `"a"`
- Very long string: `"a" * 10000`
- Unicode: `"日本語テスト"`
- Emojis: `"🎉🔥💀"`
- HTML: `"<script>alert('xss')</script>"`
- SQL injection: `"'; DROP TABLE users;--"`
- Path traversal: `"../../etc/passwd"`
- Null bytes: `"hello\x00world"`
- Newlines: `"line1\nline2"`

For numeric fields:
- Zero: `0`
- Negative: `-1`
- Very large: `999999999999`
- Float precision: `0.1 + 0.2`
- NaN/Infinity (if JSON allows)

For pagination:
- `skip=0&limit=0`
- `skip=-1`
- `limit=-1`
- `skip=999999999`
- `limit=999999999`

For IDs:
- Valid UUID format but non-existent
- Invalid UUID format: `"not-a-uuid"`
- Empty string: `""`
- SQL injection in ID: `"1 OR 1=1"`

### Step 4.5: Integration Flow Testing

Test realistic multi-step user flows:

```
FLOW 1: Full CRUD Lifecycle
  1. Create resource → 201, record ID
  2. Get resource by ID → 200, verify fields
  3. List resources → 200, verify new resource appears
  4. Update resource → 200, verify changes
  5. Get resource again → 200, verify update persisted
  6. Delete resource → 204
  7. Get resource again → 404 (verify actually deleted)
  8. List resources → 200, verify resource gone

FLOW 2: Parent-Child Relationships
  1. Create parent → 201
  2. Create child under parent → 201
  3. List children of parent → 200, verify child
  4. Move child to different parent → 200
  5. List children of original parent → 200, verify empty
  6. Delete parent → verify cascade behavior

FLOW 3: Concurrent Operations
  1. Create resource A
  2. In parallel: Update A + Read A → no race condition
  3. In parallel: Delete A + Read A → proper error handling
```

### Step 4.6: State Verification

After EVERY mutation (create/update/delete):
- Re-read the resource to verify the change actually persisted
- Check related resources for consistency
- Verify audit trails/logs if applicable

## Phase 5 — Security Testing

### Step 5.1: Authentication

- [ ] Missing auth header → 401
- [ ] Invalid token → 401
- [ ] Expired token → 401
- [ ] Malformed token → 401
- [ ] Token for deleted user → 401
- [ ] Token with wrong scope → 403

### Step 5.2: Authorization / Isolation

- [ ] User A cannot access User B's resources
- [ ] Regular user cannot access admin endpoints
- [ ] Read-only user cannot mutate resources
- [ ] Deleted/deactivated user cannot access anything

### Step 5.3: Injection

- [ ] SQL injection in query parameters
- [ ] SQL injection in request body fields
- [ ] XSS in stored strings (check if rendered)
- [ ] Command injection (if any shell exec paths)
- [ ] Path traversal in file/resource IDs
- [ ] LDAP injection (if applicable)

### Step 5.4: Data Exposure

- [ ] Responses don't leak internal IDs/paths
- [ ] Error messages don't reveal stack traces
- [ ] Sensitive fields are redacted in logs
- [ ] API keys/tokens not in URLs
- [ ] No CORS misconfiguration

## Phase 6 — Compliance and Code Quality

### Step 6.1: Automated Checks

```bash
{{config:commands.compliance}}
{{config:commands.lint.check}}
```

### Step 6.2: Manual Code Review Checklist

For EVERY file changed/added:

**Naming:**
- [ ] Functions use snake_case (Python) or camelCase (TypeScript)
- [ ] Classes use PascalCase
- [ ] Constants use UPPER_SNAKE_CASE
- [ ] File names match content

**Structure:**
- [ ] Functions < 50 lines (prefer < 30)
- [ ] Files < 500 lines (prefer < 300)
- [ ] No deeply nested logic (max 3 levels)
- [ ] No dead code
- [ ] No commented-out code
- [ ] No TODO without issue reference

**Error Handling:**
- [ ] All exceptions caught and handled
- [ ] Custom exceptions used (not bare Exception)
- [ ] Error messages are helpful
- [ ] No silent exception swallowing

**Logging:**
- [ ] Appropriate log levels
- [ ] No sensitive data in logs
- [ ] Structured logging format
- [ ] No print statements

**Type Safety:**
- [ ] All function parameters typed
- [ ] All return types specified
- [ ] No `Any` types without justification

## Phase 7 — Performance Testing

### Step 7.1: Response Time

For each endpoint, measure response time:
```bash
time curl -s -o /dev/null -w "%{time_total}" "{{config:api_testing.base_url}}/v1/{endpoint}" \
  -H "Authorization: Bearer $TOKEN"
```

Thresholds:
- GET list endpoints: < 500ms
- GET single resource: < 200ms
- POST/PUT mutations: < 1000ms
- DELETE: < 500ms

### Step 7.2: Load Pattern

```bash
# Rapid sequential requests (10 in a row)
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "%{time_total}\n" "{{config:api_testing.base_url}}/v1/{endpoint}" \
    -H "Authorization: Bearer $TOKEN"
done
```

Check: response times should not degrade significantly under light load.

### Step 7.3: Memory/Resource Leaks

- [ ] No file handles left open
- [ ] No database connections leaked
- [ ] No unbounded caches
- [ ] No memory growth over repeated requests

## Phase 8 — Documentation and Spec Compliance

### Step 8.1: Spec Compliance

If specs exist, verify EVERY requirement:
- [ ] All endpoints from the spec are implemented
- [ ] All fields from the spec exist
- [ ] All business rules from the spec are enforced
- [ ] All error codes from the spec are returned
- [ ] All status codes match the spec

### Step 8.2: API Documentation

- [ ] All endpoints have docstrings/descriptions
- [ ] Request/response schemas are documented
- [ ] Error responses are documented
- [ ] Examples are provided and accurate

## Phase 9 — Regression Testing

### Step 9.1: Verify No Regressions

```bash
# Run the FULL test suite, not just our area
{{config:commands.test.unit}}
```

- [ ] All pre-existing tests still pass
- [ ] No new deprecation warnings introduced
- [ ] No new linter warnings introduced

### Step 9.2: Cross-Feature Verification

- [ ] Features that depend on our changes still work
- [ ] Shared utilities we modified don't break other callers
- [ ] Database schema changes don't break existing queries

## Phase 10 — The Fix-and-Retest Loop

This is where most QA processes fail. They find bugs, report them, and move on. **We don't do that.**

### Step 10.1: Triage Findings

Sort all findings by severity:
- **P0 (Critical)**: System broken, security vulnerability, data loss
- **P1 (High)**: Core feature broken, spec violation
- **P2 (Medium)**: Feature works but has issues
- **P3 (Low)**: Polish, naming, documentation

### Step 10.2: Fix P0/P1 Issues

For each P0/P1 finding:
1. **Fix it yourself** (if simple) or **dispatch a sub-agent** (if complex)
2. **Write a regression test** that would have caught it
3. **Verify the fix** with the same test that found the bug
4. **Check for collateral damage** — did the fix break something else?

### Step 10.3: Fix P2 Issues

Same process, lower priority. Fix all P2s before declaring done.

### Step 10.4: Document P3 Issues

P3s (polish) can be documented for later but don't block the QA pass.

### Step 10.5: RE-RUN EVERYTHING

After all fixes:
```
→ Run full unit test suite
→ Re-run all API tests
→ Re-run security tests
→ Re-run compliance checks
→ Re-run performance tests
```

**If ANY new findings appear, go back to Step 10.1.** The loop continues until TWO consecutive clean passes.

## Phase 11 — Final Report

```
╔══════════════════════════════════════════════════════════════╗
║                    QA REPORT — {Scope}                       ║
║                    Iteration: {N} (FINAL)                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  UNIT TESTS:                                                 ║
║    Total: {N}    Passed: {N}    Failed: 0    Skipped: {N}    ║
║    Coverage: {N}%                                            ║
║                                                              ║
║  REAL API TESTS:                                             ║
║    Endpoints tested: {N}                                     ║
║    Happy path: {N}/{N} PASS                                  ║
║    Error paths: {N}/{N} PASS                                 ║
║    Edge cases: {N}/{N} PASS                                  ║
║    Integration flows: {N}/{N} PASS                           ║
║                                                              ║
║  SECURITY:                                                   ║
║    Auth tests: {N}/{N} PASS                                  ║
║    Isolation tests: {N}/{N} PASS                             ║
║    Injection tests: {N}/{N} PASS                             ║
║                                                              ║
║  COMPLIANCE:                                                 ║
║    Violations: 0                                             ║
║    Lint warnings: 0                                          ║
║                                                              ║
║  PERFORMANCE:                                                ║
║    All endpoints within thresholds: YES                      ║
║                                                              ║
║  BUGS FOUND AND FIXED:                                       ║
║    P0: {N} found, {N} fixed                                  ║
║    P1: {N} found, {N} fixed                                  ║
║    P2: {N} found, {N} fixed                                  ║
║    P3: {N} documented                                        ║
║                                                              ║
║  ITERATIONS TO PERFECTION: {N}                               ║
║  CONSECUTIVE CLEAN PASSES: 2                                 ║
║                                                              ║
║  VERDICT: ✅ PURE PERFECTION                                 ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

The ONLY acceptable verdict is **PURE PERFECTION** (2 consecutive clean passes with 0 findings).

</workflow>

## Bug Report Format

For each finding:

```
### BUG-{N}: {Short Description}

**Severity**: P0 / P1 / P2 / P3
**Category**: Route / Service / Schema / Security / Compliance / Performance / Documentation
**Iteration Found**: {N}
**Status**: OPEN / FIXED / DOCUMENTED

**What's Wrong**:
{Detailed description}

**Reproduction**:
```bash
curl -s -X GET "{{config:api_testing.base_url}}/v1/..." \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

**Expected**: {status code} with {response shape}
**Actual**: {status code} with {actual response}

**Files**:
- `{file_path}:{line}` — {what's wrong}

**Fix Applied** (if fixed):
{What was changed and why}

**Regression Test Added**:
{Test name and file path}
```

## Severity Guide

| Severity | Criteria | Examples | Action |
|----------|----------|----------|--------|
| **P0** | System broken, security vuln, data loss | Auth bypass, 500 on core endpoint | FIX IMMEDIATELY |
| **P1** | Core feature broken, spec violation | Wrong status code, missing field | FIX BEFORE PASS |
| **P2** | Feature works but has issues | Wrong error message, minor deviation | FIX BEFORE PASS |
| **P3** | Polish / improvement | Naming inconsistency, docs gap | DOCUMENT |

## Rules — Non-Negotiable

### NEVER
- Skip real API testing — mock tests alone are NOT sufficient
- Report false positives — verify every finding with a real call
- Mark something as passing without actually testing it
- Trust that "it should work" — verify it DOES work
- Test only happy paths — error paths catch more bugs
- Declare done after one pass — minimum TWO consecutive clean passes
- Stop testing when you're tired — you're a machine, you don't get tired
- Accept "conditional pass" — the only pass is pure perfection

### ALWAYS
- Get credentials before testing
- Test the actual running server
- Test both happy path AND error paths
- Include exact reproduction steps
- Run compliance checks
- Check security
- Fix bugs (or dispatch sub-agents to fix them)
- Re-test after every fix
- Write regression tests for every bug found
- Produce the final report with complete statistics

## Invoking from the Orchestrator

When the orchestrator spawns QA agents:

```
Agent(subagent_type="general-purpose", description="QA — unit tests + coverage", prompt="
  Run /qa unit on {scope}.
  Run all tests, analyze coverage, identify gaps, write missing tests.
  Do not stop until coverage >= 90% and all tests pass.
")

Agent(subagent_type="general-purpose", description="QA — real API testing", prompt="
  Run /qa api on {scope}.
  Test every endpoint: happy path, error paths, edge cases, integration flows.
  Do not stop until every endpoint passes every test category.
")

Agent(subagent_type="general-purpose", description="QA — security audit", prompt="
  Run /qa security on {scope}.
  Test auth, isolation, injection, permissions, data exposure.
  Do not stop until zero security findings.
")
```

Each agent runs independently. The orchestrator collects reports and enters the fix-retest loop.

## Test Priority Order

1. **Real API calls** — catches bugs users actually hit (404s, 500s, auth failures)
2. **Unit tests** — catches logic bugs and regressions
3. **Security** — catches auth and access control gaps
4. **Integration flows** — catches cross-feature bugs
5. **Edge cases** — catches boundary condition bugs
6. **Compliance** — catches style and convention violations
7. **Performance** — catches latency and resource issues
8. **Documentation** — catches spec deviations

## Key Files

| File | Purpose |
|------|---------|
| `{{config:credentials.file}}` | Auth tokens and credentials |
| `{{config:paths.routes}}` | Route/controller handlers |
| `{{config:paths.source}}` | Application source code |
| `{{config:paths.tests}}` | Unit and integration tests |
| `{{config:paths.specs}}` | Technical specs (source of truth) |
