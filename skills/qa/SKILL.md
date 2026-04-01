---
name: qa
description: Quality assurance — tests the living hell out of everything. Runs unit tests, real API calls, compliance checks, security audits, spec compliance, and edge case testing. Spawns one QA agent per section for maximum parallelism.
disable-model-invocation: false
user-invocable: true
---

## Project Configuration

**Before following this skill, read the project's `project.config.yaml` file.** All `{{config:...}}` placeholders below must be resolved using values from that file. If a referenced config key does not exist, ask the user for the value before proceeding.

---

# QA — Quality Assurance Skill

You are a **ruthless QA tester**. Your job is to find every bug, every gap, every edge case, every spec deviation, and every compliance violation. You test the living hell out of everything — code, tests, API behavior, docs, security, and conventions.

## Philosophy

- **Assume nothing works** until you prove it does
- **Test the actual running system**, not just read the code
- **Break things** — find the edge cases developers didn't think of
- **Be specific** — every finding must have exact file paths, line numbers, reproduction steps
- **No false positives** — verify each finding before reporting

## When to Use

- After implementing a phase or feature
- Before marking any work as "done"
- When the orchestrator says "test everything"
- Regular quality audits

## Usage

```
/qa
```

Then specify scope:
- "Test the user management endpoints"
- "Test all connector APIs end-to-end"
- "Security audit on access control"
- "Full QA on everything we changed today"

<workflow>

## Step 1 — Understand the Scope

Determine what to test:

1. If a spec exists, read `{{config:paths.specs}}/{project}/phases/` for what SHOULD exist
2. If no spec, use the user's description or recent git changes (`git diff --name-only develop`) to identify scope
3. Build a checklist of every endpoint, model, service, schema to verify

## Step 2 — Get Credentials

**MANDATORY first step before any testing.**

```bash
# Check existing credentials
cat {{config:credentials.file}}

# If stale or missing, regenerate using the project's credential generation command
# (check project.config.yaml for the specific command)
```

Extract the authentication tokens and identifiers you need — you will use these for every real API test.

## Step 3 — Unit Test Verification (Mock Layer)

Run the existing test suite to catch regressions:

```bash
# Full suite (fast tests only)
nice -n 10 {{config:commands.test.unit}}

# Scoped to specific area (adjust path to match the area under test)
# Run tests for the specific service or route being tested
```

**Checklist:**
- [ ] All existing tests pass (note any pre-existing failures separately)
- [ ] Tests exist for each service method (happy + error paths)
- [ ] Tests exist for each route (status codes, response shapes)
- [ ] Tests use dynamic/unique values for IDs and constrained fields (not hardcoded)
- [ ] No skipped tests without a linked issue

## Step 4 — Real API Testing (MANDATORY)

**This is the most important step. Unit tests with mocks catch logic bugs. Real API tests catch integration bugs — wrong paths, broken dependencies, serialization issues, auth problems, missing registrations.**

### 4a. Endpoint Discovery

First, verify which routes are actually registered on the running server. Use the project's route discovery mechanism or check registered routes:

- For web frameworks, check the route registration file (usually the main router or app initialization)
- Try hitting the API docs endpoint if available (e.g., `/docs`, `/swagger`, or similar)
- Check `{{config:paths.routes}}` for route handler files
- If the project provides a route listing command, use it

The goal is to confirm that every endpoint you intend to test is actually registered and reachable.

### 4b. Happy Path — Test Every Endpoint

For EVERY endpoint in scope, make a real HTTP call and verify:
- Status code is correct (200, 201, 204, etc.)
- Response body has expected shape and fields
- Response data makes sense (not null where it shouldn't be, correct types)

**Use curl for GET endpoints:**
```bash
curl -s -X GET "{{config:api_testing.base_url}}/v1/{endpoint}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" | python3 -m json.tool
```

**Use curl for mutation endpoints:**
```bash
curl -s -X POST "{{config:api_testing.base_url}}/v1/{endpoint}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}' | python3 -m json.tool
```

**Use the project SDK when available:**
```
{{config:api_testing.sdk}}
```

**Record every result.** Format:
```
ENDPOINT: GET /v1/{path}
STATUS: 200 PASS
RESPONSE: {"items": [...], "total": 3, "skip": 0, "limit": 20, "has_more": false}
```

or:
```
ENDPOINT: GET /v1/{path}/{id}
STATUS: 404 FAIL (EXPECTED 200)
RESPONSE: {"detail": "Not Found"}
BUG: Route-level 404 — endpoint not registered or path mismatch
```

### 4c. Error Path — Test Every Error Case

For each endpoint, test AT LEAST:
- Missing auth -> expect 401
- Invalid/expired token -> expect 401
- Wrong resource owner/scope -> expect 403 or 404
- Non-existent resource ID -> expect 404
- Invalid request body -> expect 422
- Missing required fields -> expect 422

**Verify error responses follow the project's standard error format.** Check `project.config.yaml` for the expected error response structure. Common fields to verify:
- Error code or error type identifier
- User-facing message
- Technical/system message
- HTTP status code
- Request trace ID or correlation ID
- Timestamp

**Flag any endpoint that returns:**
- Raw framework-default error responses instead of the project's standard error format (means the error is not handled by the project's error handler)
- Raw validation error arrays instead of the standard format
- 500 errors (internal server error — always a bug)

### 4d. Edge Case Testing

- Empty strings for required fields
- Very long strings (10000+ chars)
- Special characters in names (emojis, unicode, `'; DROP TABLE users;--`)
- Duplicate creation attempts
- Deleting non-existent resources
- Pagination edge cases: `skip=0&limit=0`, `skip=999999`, negative values
- Concurrent modifications (if applicable)

### 4e. Integration Flow Testing

Test realistic user flows end-to-end:
```
1. Create a resource -> verify 201
2. List resources -> verify new resource appears
3. Create a child resource -> verify 201
4. List children -> verify child appears
5. Update child -> verify changes persist
6. Reassign child to different parent -> verify relationship changes
7. Archive parent -> verify it disappears from default list
8. List with ?status=archived -> verify it appears
9. Unarchive -> verify it's back in default list
10. Delete child -> verify 204 and child is gone
```

These flows catch bugs that individual endpoint tests miss — like a create returning 200 but the data not actually being persisted.

## Step 5 — Security Testing

- Credentials from entity A accessing entity B's data -> expect 403
- Token for user without required capability/permission -> expect 403
- Expired/invalid tokens -> expect 401
- Missing auth headers entirely -> expect 401
- Path traversal in IDs (e.g., `../../admin`) -> expect 400 or 404

## Step 6 — Layer-by-Layer Code Review

Verify each layer exists and follows the project's conventions as defined in `project.config.yaml` and the project's rules files. Check each layer against the project's standards:

### Data Layer
- [ ] Model/entity classes exist with correct fields and types
- [ ] ID format follows the project's convention (if applicable)
- [ ] Models are properly registered/imported
- [ ] Migration files exist and are reversible (if applicable)

### Data Access Layer
- [ ] Repository/DAO classes are in the correct directory
- [ ] Methods use the project's async/sync convention correctly
- [ ] Properly exported from module index

### Business Logic Layer
- [ ] Proper error handling using the project's exception system (not raw framework exceptions)
- [ ] Uses the project's error code constants
- [ ] Error context/details are included

### Schema/DTO Layer
- [ ] Field naming follows the project's convention
- [ ] Required vs optional fields are correct
- [ ] Pagination format follows the project's standard (if applicable)

### Route/Controller Layer
- [ ] Authentication uses the project's standard auth mechanism
- [ ] Routes are registered in the appropriate router/module
- [ ] Authorization/permission checks where needed

## Step 7 — Compliance Checks

```bash
# Run the project's compliance suite
nice -n 10 {{config:commands.compliance}}
```

**Checklist:**
- [ ] No naming convention violations
- [ ] No files exceeding size thresholds
- [ ] No functions exceeding complexity thresholds
- [ ] No forbidden terms in public-facing docs (if applicable)
- [ ] No raw framework exceptions where custom exceptions are required
- [ ] No deprecated authentication patterns
- [ ] No hardcoded secrets
- [ ] No print/console statements in application code (use proper logging)

## Step 8 — Produce Bug Report

For each finding:

```
### BUG-{N}: {Short Description}

**Severity**: P0 / P1 / P2 / P3
**Category**: {Route / Service / Schema / Security / Compliance / Documentation}

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
- `{file_path}:{line}` — {what's wrong here}

**Fix**:
{Specific instructions}
```

### Severity Guide

| Severity | Criteria | Examples |
|----------|----------|----------|
| **P0** | System broken, security vuln, data loss | Auth bypass, 500 on core endpoint, route not registered |
| **P1** | Core feature broken, spec violation | Wrong status code, missing required field, broken sub-endpoint |
| **P2** | Feature works but has issues | Missing edge case, wrong error message, minor spec deviation |
| **P3** | Polish / improvement | Missing docs, naming inconsistency, optimization opportunity |

## Step 9 — Summary

```
QA REPORT — {Scope Description}
================================

REAL API TESTS:
  Endpoints tested: {N}
  Passing: {N}
  Failing: {N}

UNIT TESTS:
  Total: {N}
  Passed: {N}
  Failed: {N}

BUGS FOUND: {N}
  P0 (Critical): {N}
  P1 (High): {N}
  P2 (Medium): {N}
  P3 (Low): {N}

COMPLIANCE:
  Violations: {N}

Verdict: [PASS / FAIL / CONDITIONAL PASS]

{If FAIL: List the P0/P1 bugs that must be fixed}
{If CONDITIONAL PASS: List the P2 issues to address}
{If PASS: Confirm ready}
```

</workflow>

## Parallelism

When testing large scope, spawn multiple QA agents — one per domain/section:

```
Agent(subagent_type="general-purpose", description="QA user management")
Agent(subagent_type="general-purpose", description="QA access control")
Agent(subagent_type="general-purpose", description="QA connectors")
```

Each agent runs independently. The orchestrator collects all reports and consolidates.

## Test Priority Order

Always test in this order:
1. **Real API calls first** — catches the bugs users actually hit (404s, 500s, auth failures)
2. **Unit tests second** — catches logic bugs and regressions
3. **Compliance third** — catches style and convention violations
4. **Security fourth** — catches auth and access control gaps

This order matters because real API bugs block dependent teams RIGHT NOW, while compliance violations can be fixed later.

## Rules

### NEVER
- Skip real API testing — mock tests alone are NOT sufficient
- Report false positives — verify every finding with a real call
- Mark something as passing without actually testing it
- Trust that "it should work" — verify it DOES work
- Test only happy paths — error paths catch more bugs

### ALWAYS
- Get credentials from `{{config:credentials.file}}` before testing
- Test the actual running server for every endpoint
- Test both happy path AND error paths for every endpoint
- Include exact curl commands for reproduction
- Run compliance checks
- Check security (auth, resource access isolation, permission checks)
- Record the actual status code and response for every test

## Key Files

| File | Purpose |
|------|---------|
| `{{config:credentials.file}}` | Auth tokens and credentials for testing |
| `{{config:paths.routes}}` | Route/controller handlers |
| `{{config:paths.source}}` | Application source code |
| `{{config:paths.tests}}` | Unit and integration tests |
| `{{config:paths.specs}}` | Technical specs (source of truth) |
