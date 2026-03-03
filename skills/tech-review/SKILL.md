---
name: tech-review
description: Review a sub-developer's implementation against the technical execution spec. Produces a pass/fail checklist. On pass — marks phase done. On fail — generates a structured feedback message to send back to the sub-developer.
disable-model-invocation: false
user-invocable: true
---

# Technical Implementation Reviewer

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling. Use `{{config:...}}` placeholders below as references to values defined there. Project-specific conventions (auth patterns, error handling, naming, pagination) are defined in that file and in the project's rules directory.

You review a sub-developer's implementation by comparing it against the technical execution spec. You produce a structured verdict — either approve the phase or generate actionable feedback for the sub-developer.

## When to Use

- A sub-developer has completed a phase or subphase and you need to verify their work
- You need to generate feedback to send back to a sub-developer
- You want to mark a phase as done after successful review

## Usage

```
/tech-review
```

Then specify what to review:
- "Review phase 1 — basic role management"
- "Check if the sub-developer's work on 3.3 matches the spec"
- "Review all of phase 6"

<workflow>

## Step 1 — Load the Spec

1. Read the phase spec directory: `{{config:paths.specs}}/{project}/phases/phase-N-{name}/`
2. Read `README.md` for the overall goals, subphases, endpoints, and success criteria
3. Read each subphase document (`N.1-*.md`, `N.2-*.md`, etc.)
4. Extract a master checklist of everything the spec requires:
   - Database models and migrations
   - Repository methods
   - Service methods
   - API endpoints (routes, auth, request/response)
   - Schemas
   - Error codes
   - Tests (unit, integration)
   - Public API documentation
   - Router registration

## Step 2 — Explore the Implementation

Use the Task tool with `subagent_type=Explore` to find what was actually implemented:

1. **Models** — Check `{{config:paths.models}}/` for new/modified files
2. **Migrations** — Check `{{config:paths.migrations}}/` for new migration files
3. **Repositories** — Check `{{config:paths.repositories}}/` for new/modified repos
4. **Services** — Check `{{config:paths.services}}/` for new/modified services
5. **Routes** — Check `{{config:paths.routes}}/` for new/modified route files
6. **Schemas** — Check `{{config:paths.schemas}}/` for new/modified schema files
7. **Error codes** — Check error code files as defined in `project.config.yaml`
8. **Model registration** — Check model init/registration files for imports
9. **Repository exports** — Check repository init/exports for new repos
10. **Router registration** — Check route init or main app file for router includes
11. **Tests** — Check `{{config:paths.tests}}/` for new test files
12. **Public docs** — Check `{{config:paths.public_docs}}/` for new doc files (if applicable)

Read the key implementation files fully — don't just check existence, verify the content matches the spec.

## Step 3 — Compare and Produce Checklist

For each spec requirement, assign a status:

- PASS — Implemented correctly as specified
- PARTIAL — Implemented but with differences from the spec (describe what differs)
- MISSING — Not implemented at all

### Review Categories

| Category | What to Check |
|----------|--------------|
| **Database Schema** | Models exist, correct fields/types/prefixes, relationships, indexes, constraints, migration runs |
| **Repository Layer** | All specified methods exist, correct signatures, async (if applicable), proper queries, exported/registered |
| **Service Layer** | Business logic correct, validation, error handling, proper exceptions |
| **API Routes** | Endpoints exist, correct HTTP methods, auth follows project conventions, proper status codes |
| **Schemas** | Request/response models match spec, correct field types, defaults, validation |
| **Error Codes** | Added to error code registry, used correctly in code |
| **Tests** | Unit tests for services/repos, integration tests for endpoints, coverage of test checklist |
| **Public Docs** | Doc files created (if applicable), follow project template |
| **Compliance** | Naming conventions followed, auth pattern follows project conventions, error handling follows project conventions |
| **Registration** | Models registered, repos exported, router included in app |
| **Pagination** | Pagination pattern matches project conventions (check `project.config.yaml`) |

## Step 4 — Verdict

### If ALL items PASS

Tell the user:

> **Phase N — {Name}: APPROVED**
>
> All spec requirements have been implemented correctly. Ready to proceed to Phase N+1.

Then rename the phase README to mark it as done:
```
README.md -> README-done.md
```

### If ANY items are PARTIAL or MISSING

Generate a structured feedback message that the user can copy-paste directly to the sub-developer. Use this format:

---

**Format for sub-developer feedback:**

```
## Phase N — {Name}: Review Feedback

### What's Working
- [Brief list of what was implemented correctly]

### Needs Fixing

#### Issue 1: {Description}
- **Spec says**: {quote or reference from spec}
- **Current implementation**: {what's actually there}
- **File**: `{exact file path}:{line number if possible}`
- **Fix**: {specific instructions on what to change}

#### Issue 2: ...

### Missing

#### Missing 1: {Description}
- **Spec reference**: Subphase N.X, section "{section name}"
- **What's needed**: {specific description of what to implement}
- **Files to create/modify**: `{file paths}`
- **Details**: {any additional context}

#### Missing 2: ...

### Checklist for Resubmission
- [ ] {Fix item 1}
- [ ] {Fix item 2}
- [ ] {Add missing item 1}
- [ ] ...
```

---

## Step 5 — After Approval

When a phase is approved (all PASS):

1. **Rename the phase folder** to include `-done` suffix:
   - `phase-N-{name}/` -> `phase-N-{name}-done/`
   - This makes completion visible at a glance when listing directories
2. **Also rename the requirements phase doc** (if it exists) in `{{config:paths.specs}}/{project}/phases/`:
   - `NN-{name}.md` -> `NN-{name}-done.md`
3. Inform the user which phase is next and its dependencies
4. Check if the next phase's spec exists — if not, suggest running `/tech-spec`

</workflow>

## Notes

- This skill is READ-ONLY for application code — it explores and verifies but never modifies source code
- It CAN modify files in `{{config:paths.specs}}/` (renaming README to README-done)
- The feedback message should be detailed enough that the sub-developer can fix issues without asking follow-up questions
- Always check project conventions from `project.config.yaml` for:
  - Pagination pattern (skip/limit vs page/page_size vs cursor, etc.)
  - Auth pattern (what auth mechanism the project uses)
  - Error handling pattern (custom exceptions, error format, etc.)
  - Naming conventions (snake_case, camelCase, etc.)
