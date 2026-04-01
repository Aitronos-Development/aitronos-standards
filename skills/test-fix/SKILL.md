---
name: test-fix
description: Run all tests and automatically fix failing ones. Use when tests are failing and you want automated fixes applied.
disable-model-invocation: false
user-invocable: true
---

# Test Fix Skill

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling. The test and lint commands referenced below come from that file.

Automatically run all tests, identify failures, and apply fixes.

## When to Use

- Tests are failing and you need quick fixes
- After refactoring code
- Before committing changes
- When you see test failures in CI/CD

## What This Does

1. **Runs all tests** using the project's test runner
2. **Identifies failures** and categorizes them by type:
   - Assertion mismatches
   - Missing attributes
   - Database constraints
   - Unique violations
   - Foreign key issues
   - Type mismatches
   - Import errors
3. **Applies automatic fixes**:
   - Code formatting with linter
   - Import sorting
   - Common linting issues
4. **Suggests manual fixes** for complex issues
5. **Re-runs tests** to verify fixes worked

## Usage

User invocation:
```
/test-fix
```

Or with options:
```
/test-fix --failed-only    # Only run previously failed tests
/test-fix --verbose        # Show detailed suggestions
```

## Workflow

<workflow>

### Step 1: Run Initial Test Suite

Use the Bash tool to run all tests:

```bash
nice -n 10 {{config:commands.test.all}} --tb=short -v -q
```

Capture the output and analyze failure patterns.

### Step 2: Analyze Failures

Parse the test output to identify:
- Which tests failed
- Error types (AssertionError, IntegrityError, etc.)
- File locations
- Error messages

Common patterns to detect:
- **Unique constraint violations**: "unique constraint" -- Use uuid4() or equivalent for test data
- **Foreign key violations**: "foreign key" -- Create parent records first
- **Assertion failures**: "AssertionError" -- Check expected vs actual values
- **Import errors**: "ImportError" -- Fix imports or missing modules
- **Type errors**: "TypeError" -- Check function signatures

### Step 3: Apply Automatic Fixes

Apply fixes in this order:

1. **Format code**:
   ```bash
   nice -n 10 {{config:commands.lint.format}}
   ```

2. **Fix imports**:
   ```bash
   nice -n 10 {{config:commands.lint.sort_imports}}
   ```

3. **Fix linting issues**:
   ```bash
   nice -n 10 {{config:commands.lint.fix}}
   ```

### Step 4: Suggest Manual Fixes

For issues that can't be auto-fixed, provide specific suggestions:

**Database Constraints**:
- Use unique identifiers (e.g., `uuid4().hex`) for unique values in test data
- Create parent records before child records
- Ensure proper test isolation

**Assertion Failures**:
- Check if expected values need updating
- Verify test data setup
- Review business logic changes

**Type Errors**:
- Check function signatures
- Verify argument types
- Update type hints

### Step 5: Re-run Tests

After applying fixes:

```bash
nice -n 10 {{config:commands.test.all}} --lf --tb=short -v
```

Report results to user with:
- Number of tests fixed
- Remaining failures (if any)
- Manual fix suggestions

### Step 6: Generate Summary

Provide a clear summary:

**Fixed automatically**: X tests
**Requires manual fix**: Y tests
**Suggestions**: [list specific fixes needed]

</workflow>

## Examples

### Example 1: Unique Constraint Violation

**Failure**:
```
IntegrityError: duplicate key value violates unique constraint "users_email_key"
```

**Auto-fix**: Format and lint code

**Manual suggestion**:
```python
# Change from:
user = User(email="test@example.com")

# To:
from uuid import uuid4
unique_id = uuid4().hex[:8]
user = User(email=f"test_{unique_id}@example.com")
```

### Example 2: Import Error

**Failure**:
```
ImportError: cannot import name 'get_user' from 'app.services.auth'
```

**Auto-fix**: Sort and fix imports with linter

**Manual suggestion**: Check if function was renamed or moved

### Example 3: Assertion Mismatch

**Failure**:
```
AssertionError: assert response.status_code == 200
actual: 401
```

**Auto-fix**: None (requires business logic review)

**Manual suggestion**: Check authentication requirements or update expected status code

## Integration

This skill works best with:
- Project test suite (as defined in `project.config.yaml`)
- Project linter and formatter
- Project package manager
- Git for committing fixes

## Notes

- Use `--verbose` flag for detailed diagnostics
- Commit fixes incrementally for easier review
- Check `project.config.yaml` for project-specific test commands and conventions
