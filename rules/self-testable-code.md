# Self-Testable Code Rules

## Core Principle
**ALL code changes MUST be verified before declaring work complete. No feature or fix is done until it has been tested end-to-end.**

## Mandatory Self-Testing

Before declaring work complete:

1. **Run the relevant tests** — verify existing tests still pass
2. **Test the actual behavior** — make a real call/interaction to confirm it works
3. **Confirm the result** matches the expected behavior

## How to Self-Test

### Step 1 — Run the test suite
```
Run: {{config:commands.test.unit}}
```

### Step 2 — Test the actual behavior
- For APIs: make a real HTTP call to the running server
- For UI: verify the component renders correctly
- For libraries: write a quick usage script
- For CLI tools: run the command and check output

### Step 3 — Verify the response
- Behavior matches the spec/requirements
- Error cases are handled correctly
- No regressions in existing functionality

## What Counts as Self-Testing

| Action | Counts? |
|--------|---------|
| Running the test suite and seeing green | Yes |
| Making a real API/HTTP call to the running server | Yes |
| Making a real UI interaction and verifying output | Yes |
| Running a script that exercises the code | Yes |
| Reading the code and reasoning it should work | No |
| Assuming existing tests cover the new code | No |
| Skipping tests because "it's a minor change" | No |

## Rules

- **Never mark a task done** without verified test results
- **Permanent tests are preferred** — if worth testing once, worth testing permanently
- **Test both happy path and error cases**
- **Log what was tested** — briefly note what was verified

**REMEMBER: If you built it, you must test it before you ship it.**