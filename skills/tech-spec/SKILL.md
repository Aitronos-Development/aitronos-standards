---
name: tech-spec
description: Create detailed technical execution specs for a project phase. Explores codebase, identifies existing implementations, creates subphase documents with exact file paths, schemas, and test plans. Never writes code — only specs.
disable-model-invocation: false
user-invocable: true
---

# Technical Specification Creator

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling. Use `{{config:...}}` placeholders below as references to values defined there. For project-specific conventions (auth patterns, error handling, ID formats, database patterns), read `project.config.yaml`.

You create **detailed technical execution specs** that sub-developers follow to implement features. You NEVER write application code — only specification documents.

## When to Use

- Breaking a requirements spec or phase into implementable subphases
- Creating technical execution documents for sub-developers
- Speccing out database changes, API endpoints, services, and repositories
- Documenting business logic, error codes, and test plans

## Usage

```
/tech-spec
```

Then describe what needs speccing:
- "Spec out phase 2 — departments with hierarchy"
- "Create subphase docs for the knowledge slices feature"
- "Break down the audit logging phase into implementable steps"

<workflow>

## Step 1 — Deep Context Gathering

Before writing any spec, gather information exhaustively. **Ask more questions than you think you need.** It's always cheaper to clarify upfront than to rewrite code later.

### 1a. Read Everything Available

1. **Read the requirements** — look in `{{config:paths.specs}}` for the relevant project
2. **Read the overview** — read `{{config:paths.specs}}/{project}/overview.md` for project summary
3. **Read the roadmap** — read `{{config:paths.specs}}/{project}/ROADMAP.md` for project progress and cross-phase dependencies
4. **Read context files** — frontend interfaces, mock data, API contracts in `{{config:paths.specs}}/{project}/notes/`
5. **Explore the codebase** — use the Agent tool with `subagent_type=Explore` to find existing models, repos, services, routes
6. **Check existing specs** — see what's already been planned in `{{config:paths.specs}}/{project}/phases/`
7. **Check notes** — read `{{config:paths.specs}}/{project}/notes/` for decisions, concerns, and reference material

Never guess — always verify what exists. Mark existing components with `[EXISTS]` in your specs.

### 1b. Ask Questions Aggressively

Use `AskUserQuestion` liberally. Ask about:

**Architecture:**
- Does the existing model need to be extended or replaced?
- How should new features coexist with existing endpoints?
- What ID prefix should new entities use?
- How should data migration work for existing records?
- What's the rollback strategy if this phase fails mid-deploy?

**Business Logic:**
- What are the edge cases? (empty lists, null values, concurrent modifications)
- What are the authorization rules? Who can read/write/delete?
- What should happen when dependent entities are deleted?
- Are there rate limits or quotas?

**Data:**
- What's the expected data volume? (affects indexing, pagination, caching strategy)
- What fields need to be searchable/sortable/filterable?
- Are there any fields that need encryption or special handling?

**Integration:**
- How does this interact with existing features?
- Are there frontend expectations for response shape?
- Does this need to work with the SDK? What methods should exist?

**Testing:**
- What are the critical user flows to test?
- What error scenarios should be covered?
- Are there performance requirements (latency, throughput)?

### 1c. Create Notes

If context gathering reveals information that should be preserved (frontend contracts, API behavior discovered through exploration, decisions made in conversation), create notes files:

```
{{config:paths.specs}}/{project}/notes/{topic}.md
```

Notes are reference documents — they capture facts, not plans. Examples:
- `api-behavior.md` — quirks discovered about a third-party API
- `frontend-contract.md` — expected response shapes from the frontend team
- `migration-considerations.md` — data migration challenges for existing records

## Step 2 — Resolve Ambiguity

Before writing specs, resolve ALL open questions:

1. Compare the requirements against what exists in the codebase
2. Identify architectural decisions (new table vs alter existing, coexistence vs replacement)
3. Use `AskUserQuestion` for every open question — don't assume
4. Document all decisions in `{{config:paths.specs}}/{project}/notes/decisions.md`

**Do NOT proceed to Step 3 with unresolved questions.** If you're unsure about something, ask. If the user says "your call", document your reasoning in the decision log.

## Step 3 — Update Project-Level Files

Before writing the phase spec, update (or create) the two root-level project files:

### overview.md — Project Summary

```
{{config:paths.specs}}/{project}/overview.md
```

A high-level summary of the entire project. Created once, updated when scope changes. Must include:

```markdown
# {Project Name} — Overview

## What This Document Is

{One paragraph: what this project is about, why we're building it, who it's for.}

## What We're Building

{2-3 paragraphs summarizing the full scope of the project — what exists today, what's being added, key technical approach.}

## Phase Plan

| Phase | Name | What It Unlocks |
|-------|------|----------------|
| 1 | {Name} | {What the user gets after this phase} |
| 2 | {Name} | {What the user gets} |
| ... | ... | ... |

## Notes Directory

The `notes/` folder contains reference material: decisions, concerns, API research, frontend contracts, etc.
```

### ROADMAP.md — Live Progress Tracker

```
{{config:paths.specs}}/{project}/ROADMAP.md
```

The single source of truth for where we are. Update after every phase starts, completes, or hits a blocker.

```markdown
# {Project Name} — Roadmap

## Progress

| Phase | Name | Status | Dependencies | Subphases | Notes |
|-------|------|--------|-------------|-----------|-------|
| 1 | Roles & Permissions | Done | — | 1.1–1.4 | |
| 2 | Departments | Done | Phase 1 | 2.1–2.5 | |
| 9 | Connectors | In Progress | Phase 6 | 9a–9d | 9d executing |
| 10 | Spaces | Not Started | Phase 6, 8 | — | |

## Dependency Graph

Phase 1 (Roles) --> Phase 2 (Departments) --> Phase 10 (Spaces)
       |                    |
       +--> Phase 8 (Access Control) <-- Phase 6 (Slices)

## Current Focus

{What's actively being worked on}

## Blockers

- None currently
```

### notes/ — Decisions, Concerns, and Reference Material

Decisions and concerns go in the `notes/` directory — they're reference material, not primary project documents.

```
{{config:paths.specs}}/{project}/notes/decisions.md    — Architectural decision log
{{config:paths.specs}}/{project}/notes/concerns.md     — Risk register (open/resolved)
{{config:paths.specs}}/{project}/notes/{topic}.md      — Any other reference material
```

**decisions.md** — Log every architectural decision:

```markdown
# Architectural Decisions

## D-001: Unified access_grants table (Phase 8)
**Date**: 2025-12-15
**Context**: Need access control for slices, stores, and assistants
**Decision**: Single `access_grants` table with `entity_type` discriminator
**Rationale**: Simpler queries, consistent API, easier to add new entity types later
**Alternatives considered**: Separate per-entity grant tables
```

**concerns.md** — Track anything that could go wrong:

```markdown
# Concerns & Risk Register

## Open

### C-012: Migration performance on large orgs
**Phase**: 10 (Spaces)
**Severity**: Medium
**Description**: Space creation migration needs to touch every org.
**Mitigation**: Batch processing with LIMIT/OFFSET.

## Resolved

### C-005: Cross-org data leakage
**Resolution**: Added service-layer workspace_id filtering.
**Date resolved**: 2026-03-02
```

## Step 4 — Create the Phase Spec

For each phase, create a directory with subphase files directly under `phases/`:

```
{{config:paths.specs}}/{project}/phases/phase-N-{name}/
├── README.md           — Overview, strategy, rollback plan, sizing, success criteria
├── N.1-{name}.md       — First subphase (usually database schema)
├── N.2-{name}.md       — Second subphase (usually repository/service)
├── N.3-{name}.md       — Third subphase (usually endpoints)
├── ...
└── N.X-tests.md        — Final subphase (ALWAYS tests & real API verification)
```

### README.md Template

Every phase README MUST include all of the following sections:

```markdown
# Phase N — {Name} (Technical Execution)

## Goal

{One paragraph: what this phase achieves and why it matters.}

## Dependencies

- Phase X ({name}) — {what we need from it}
- Phase Y ({name}) — {what we need from it}

## Existing Codebase State

| Component | Status | File Path |
|-----------|--------|-----------|
| {Model} | [EXISTS] | `{{config:paths.models}}/{file}` |
| {Repository} | [MISSING] | `{{config:paths.repositories}}/{file}` |
| {Service} | [MISSING] | `{{config:paths.services}}/{domain}/{file}` |
| {Route} | [MISSING] | `{{config:paths.routes}}/{file}` |
| {Schema} | [MISSING] | `{{config:paths.schemas}}/{file}` |

## Architectural Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D-{N} | {What was decided} | {Why} |

(Also logged in `notes/decisions.md`)

## Strategy

{2-3 paragraphs describing the overall approach:}
- How does this integrate with existing code?
- What's the build order and why?
- What are the risky parts and how do we mitigate them?

## Rollback Plan

If this phase needs to be reverted after partial or full deployment:

1. **Database**: {How to reverse migrations. Are migrations reversible? Any data migration concerns?}
2. **Code**: {Which files to revert. Any shared code that other phases now depend on?}
3. **Data**: {Any data created during this phase that needs cleanup? Orphaned records?}
4. **Dependencies**: {Will reverting this break other phases that were built on top of it?}

**Point of no return**: {Describe any step after which rollback becomes difficult or impossible.}

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| {What could go wrong} | High / Medium / Low | {How to prevent or handle it} |

## Sizing Estimate

- **New files**: ~{N} files
- **Modified files**: ~{N} files
- **Estimated new code**: ~{N} lines
- **New DB tables**: {N} ({names})
- **New endpoints**: {N}
- **Team size recommendation**: {1-3 developers}

## Subphases

| # | Name | Dependencies | Risk | Est. Lines |
|---|------|-------------|------|------------|
| N.1 | Database Schema | None | Low | ~150 |
| N.2 | Repository & Service | N.1 | Medium | ~400 |
| N.3 | Endpoints | N.2 | Low | ~300 |
| N.X | Tests & Verification | N.3 | Low | ~500 |

## Endpoint Summary

| Method | Path | Status | Auth |
|--------|------|--------|------|
| GET | `/v1/organizations/{org_id}/...` | NEW | Per project conventions |
| POST | `/v1/organizations/{org_id}/...` | NEW | Per project conventions |

## Database Tables

{Full table definitions with column types, constraints, indexes}

## Key Business Rules

{Numbered list of critical business logic}

## Authorization

{Who can do what — capabilities, ownership rules, defaults}

## Success Criteria

- [ ] {Specific, testable criterion}
- [ ] {Another criterion}
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Real API verification confirms all endpoints work
- [ ] Compliance checks pass
- [ ] Public API documentation created for all endpoints (if applicable)
- [ ] ROADMAP.md updated with phase status
```

### Subphase Document Template

Every subphase document MUST include all of the following sections:

```markdown
# Subphase N.X — {Name}

## Goal

{One sentence.}

## Dependencies

- {N.Y} — {what we need from it}

## Risk Level

{High / Medium / Low} — {One sentence explaining why}

## Stop Conditions

{When should execution STOP and escalate to the user?}
- If {specific condition}, STOP and report to orchestrator
- If {another condition}, STOP — do not proceed

## Files

### New Files
| File | Purpose |
|------|---------|
| `{{config:paths.models}}/{name}` | {Model} |

### Modified Files
| File | Change |
|------|--------|
| `{{config:paths.models}}/__init__` | Import new model |

## Database Changes

{Full table definition OR "None"}

```sql
CREATE TABLE {name} (
    id VARCHAR(255) PRIMARY KEY,  -- prefix: "{prefix}_"
    ...
);

CREATE INDEX idx_{name}_{field} ON {name} ({field});
```

## Schemas

```python
class {Name}Create(BaseModel):
    """Request schema for creating a {name}."""
    field: str = Field(..., description="...")
    optional_field: str | None = Field(None, description="...")

class {Name}Response(BaseModel):
    """Response schema for a {name}."""
    id: str
    field: str
    created_at: datetime
    updated_at: datetime
```

## Repository Methods

```python
class {Name}Repository:
    async def create(self, ...) -> {Name}:
        """Create a new {name}."""

    async def get_by_id(self, id: str) -> {Name} | None:
        """Get {name} by ID."""

    async def list_by_org(
        self, org_id: str, *, skip: int = 0, limit: int = 50
    ) -> tuple[list[{Name}], int]:
        """List {names} for organization. Returns (items, total)."""
```

## Service Methods

```python
class {Name}Service:
    async def create_{name}(self, ...) -> {Name}:
        """
        Create a new {name}.

        Business logic:
        1. Validate input
        2. Check for duplicates
        3. Create record
        4. Return created {name}

        Raises:
        - ConflictException if name already exists
        - ValidationException if {condition}
        """

    async def get_{name}(self, id: str, org_id: str) -> {Name}:
        """
        Get {name} by ID.

        Raises:
        - ResourceNotFoundException if not found
        - AuthorizationException if wrong org
        """
```

## Endpoint Specifications

### `GET /v1/organizations/{org_id}/{resource}`

**Auth**: Per project conventions (see `project.config.yaml`)
**Query params**: `skip` (int, default 0), `limit` (int, default 50, max 100)

**Response 200**:
```json
{
    "items": [...],
    "total": 42,
    "skip": 0,
    "limit": 50,
    "has_more": false
}
```

**Error responses**:
| Status | Code | When |
|--------|------|------|
| 401 | AUTHENTICATION_REQUIRED | Missing/invalid auth |
| 403 | ORGANIZATION_ACCESS_DENIED | Wrong org |

### `POST /v1/organizations/{org_id}/{resource}`

**Auth**: Per project conventions (see `project.config.yaml`)

**Request body**:
```json
{
    "name": "string (required)",
    "description": "string (optional)"
}
```

**Response 201**:
```json
{
    "id": "{prefix}_abc123",
    "name": "...",
    "created_at": "2025-01-15T10:30:00Z"
}
```

**Error responses**:
| Status | Code | When |
|--------|------|------|
| 401 | AUTHENTICATION_REQUIRED | Missing/invalid auth |
| 403 | INSUFFICIENT_PERMISSIONS | Missing capability |
| 409 | {NAME}_ALREADY_EXISTS | Duplicate name |
| 422 | INVALID_{FIELD} | Validation failure |

## Business Logic

{Step-by-step numbered logic for each endpoint. Be extremely specific.}

1. Validate request body against schema
2. Check user has required capability
3. Verify org_id matches auth context
4. Check for existing record with same name
5. Create record with generated ID (prefix: `{prefix}_`)
6. Return created record

## Error Code Additions

Add new error codes per project conventions (see `project.config.yaml` for error code locations and patterns).

## Rollback

{How to revert this specific subphase if needed:}
- Revert files: {list}
- Migration: run `{{config:commands.migrations.downgrade}}` to target revision
- Data cleanup: {any orphaned data?}

## Public API Documentation

Create public API docs per project conventions (see `project.config.yaml` for documentation paths and templates).
```

### Test Subphase Template (N.X-tests.md)

The final subphase is ALWAYS tests. It must be the most detailed subphase in the spec.

```markdown
# Subphase N.X — Tests & Verification

## Goal

Comprehensive testing: unit tests, integration tests, real API verification, and compliance checks.

## Prerequisites

- All previous subphases (N.1–N.{X-1}) complete

## Unit Tests — Service Layer

### `{{config:paths.tests}}/unit/services/{domain}/test_{name}_service_pure.py`

Test the service layer with mocked repositories. Every method, every branch.

```python
# Happy path
test_create_{name}_success()
test_get_{name}_success()
test_list_{names}_returns_paginated()
test_update_{name}_success()
test_delete_{name}_success()

# Error paths
test_create_{name}_duplicate_raises_conflict()
test_get_{name}_not_found_raises()
test_get_{name}_wrong_org_raises()
test_update_{name}_not_found_raises()
test_delete_{name}_not_found_raises()

# Business logic edge cases
test_{specific_business_rule}()
test_{another_edge_case}()
```

## Unit Tests — Repository Layer

### `{{config:paths.tests}}/unit/repositories/test_{name}_repo_pure.py`

Test repository methods with test database session (rollback, no commit).

```python
test_create_and_get()
test_list_with_pagination()
test_list_with_filters()
test_update_fields()
test_soft_delete()
```

## Unit Tests — Route Layer

### `{{config:paths.tests}}/unit/routes/test_{name}_pure.py`

Test route handlers with mocked service. Verify status codes, response shapes, error formats.

```python
# Status codes
test_list_returns_200()
test_get_returns_200()
test_create_returns_201()
test_update_returns_200()
test_delete_returns_204()

# Error responses
test_get_not_found_returns_404()
test_create_invalid_returns_422()
test_create_duplicate_returns_409()
test_missing_auth_returns_401()
test_wrong_org_returns_403()
```

## Integration Tests

### `{{config:paths.tests}}/integration/{domain}/test_{name}_integration.py`

Full-stack tests with real database.

```python
test_full_lifecycle():
    """Create -> read -> update -> delete -> verify gone."""

test_{specific_flow}():
    """Description of the business flow being tested."""
```

## Real API Verification

**This section is MANDATORY.** Every endpoint must be tested against the running server.

### Verification Script

For each endpoint, specify the exact call and expected response:

```bash
# 1. List {resource} (expect 200, items array)
curl -s "http://localhost:8000/v1/organizations/$ORG_ID/{path}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | python3 -m json.tool
# Expected: {"items": [...], "total": N, "skip": 0, "limit": 50, "has_more": false}

# 2. Create {resource} (expect 201)
curl -s -X POST "http://localhost:8000/v1/organizations/$ORG_ID/{path}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test", "description": "Test item"}' | python3 -m json.tool
# Expected: {"id": "{prefix}_...", "name": "Test", ...}
# Save the ID: RESOURCE_ID="{the returned id}"

# 3. Get {resource} (expect 200)
curl -s "http://localhost:8000/v1/organizations/$ORG_ID/{path}/$RESOURCE_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | python3 -m json.tool
# Expected: Same object as create response

# 4. Update {resource} (expect 200)
curl -s -X PATCH "http://localhost:8000/v1/organizations/$ORG_ID/{path}/$RESOURCE_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated Name"}' | python3 -m json.tool
# Expected: Updated object

# 5. Delete {resource} (expect 204, empty body)
curl -s -X DELETE "http://localhost:8000/v1/organizations/$ORG_ID/{path}/$RESOURCE_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" -w "\nHTTP_STATUS: %{http_code}\n"
# Expected: HTTP_STATUS: 204

# 6. Error: missing auth (expect 401)
curl -s "http://localhost:8000/v1/organizations/$ORG_ID/{path}" | python3 -m json.tool
# Expected: {"success": false, "error": {"code": "AUTHENTICATION_REQUIRED", ...}}

# 7. Error: wrong org (expect 403)
curl -s "http://localhost:8000/v1/organizations/org_fake/{path}" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | python3 -m json.tool
# Expected: {"success": false, "error": {"code": "ORGANIZATION_ACCESS_DENIED", ...}}
```

### SDK Verification (when available)

If the project has an SDK, test against it:

```python
# Full CRUD lifecycle
item = client.{domain}.{resource}.create(organization_id=ORG_ID, name="Test")
assert item.id.startswith("{prefix}_")

fetched = client.{domain}.{resource}.retrieve(organization_id=ORG_ID, id=item.id)
assert fetched.name == "Test"

updated = client.{domain}.{resource}.update(organization_id=ORG_ID, id=item.id, name="Updated")
assert updated.name == "Updated"

client.{domain}.{resource}.delete(organization_id=ORG_ID, id=item.id)
```

### Expected Response Shapes

Document the exact JSON shape for each endpoint response:

```json
// GET /v1/organizations/{org_id}/{resource}
{
    "items": [
        {
            "id": "{prefix}_abc123",
            "name": "Example",
            "description": "...",
            "organization_id": "org_xyz",
            "created_by": "usr_abc",
            "created_at": "2025-01-15T10:30:00Z",
            "updated_at": "2025-01-15T10:30:00Z"
        }
    ],
    "total": 1,
    "skip": 0,
    "limit": 50,
    "has_more": false
}
```

## Compliance Checks

```bash
# Linting
{{config:commands.lint.check}}

# Formatting
{{config:commands.lint.format_check}}

# Full compliance suite
{{config:commands.compliance}}
```

## Run Commands

```bash
# Unit tests (specific)
{{config:commands.test.all}} {{config:paths.tests}}/unit/services/{domain}/ -v

# Integration tests
{{config:commands.test.all}} {{config:paths.tests}}/integration/{domain}/ -v

# All tests for this phase
{{config:commands.test.all}} {{config:paths.tests}}/ -k "{keyword}" -v

# Full test suite (regression)
{{config:commands.test.all}} {{config:paths.tests}}/ -q -m "not slow and not e2e"
```

## Public API Documentation

Create public API docs per project conventions (see `project.config.yaml` for documentation paths, templates, and sidebar configuration).

## Acceptance Criteria

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Real API verification confirms all endpoints work (both happy and error paths)
- [ ] Response shapes match documented shapes exactly
- [ ] Naming conventions followed throughout
- [ ] Compliance checks pass
- [ ] Public API docs created for all endpoints (if applicable)
- [ ] ROADMAP.md updated
```

## Rules

### NEVER
- Write application code (models, routes, services, tests)
- Modify files outside `{{config:paths.specs}}/` and project configuration directories
- Skip the "Existing Codebase State" analysis
- Assume what exists — always explore
- Leave ambiguity unresolved — ask the user
- Skip the rollback plan
- Skip the test specification
- Write a spec without real API verification examples

### ALWAYS
- Read the codebase before planning (use Explore agent)
- Read `project.config.yaml` for project-specific conventions before writing specs
- Ask questions aggressively — more is better
- Create notes files for discovered context
- Update `overview.md` and `ROADMAP.md` at project root
- Log decisions in `notes/decisions.md` and concerns in `notes/concerns.md`
- Include exact file paths in specs
- Include schema definitions
- Include repository method signatures
- Include error codes and error handling
- Include rollback plans (phase-level and subphase-level)
- Include risk assessments
- Include stop conditions (when should execution halt?)
- Include comprehensive test specifications with exact test function names
- Include real API verification with exact curl commands and expected responses
- Include public API documentation requirements
- Ask the user when you encounter ambiguity
- Reference existing patterns in the codebase

</workflow>

## Project Directory Structure

Every project under `{{config:paths.specs}}/{project}/` follows this layout:

```
{{config:paths.specs}}/{project}/
├── overview.md                    — Project summary (what and why)
├── ROADMAP.md                     — Live progress tracker (updated continuously)
├── notes/                         — Reference material
│   ├── decisions.md               — Architectural decision log
│   ├── concerns.md                — Risk register (open/resolved)
│   └── {topic}.md                 — API research, frontend contracts, etc.
└── phases/                        — Phase specs (YOUR output)
    ├── phase-1-{name}/
    │   ├── README.md              — Phase overview, strategy, rollback, sizing
    │   ├── 1.1-{name}.md          — Subphase spec
    │   └── ...
    ├── phase-2-{name}/
    │   ├── README.md
    │   └── ...
    └── phase-N-{name}-done.md     — Completed phases get renamed with -done suffix
```

**Rules:**
- NO `technical-execution/` folder — phases go directly under `phases/`
- `overview.md` and `ROADMAP.md` live at the project root (not buried in subfolders)
- Decisions and concerns go in `notes/` (reference material, not primary docs)
- Completed phase folders get a `-done` suffix on the README or folder name
