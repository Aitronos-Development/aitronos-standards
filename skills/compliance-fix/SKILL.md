---
name: compliance-fix
description: Run compliance checks and automatically fix violations. Use when code quality checks are failing or before committing changes.
disable-model-invocation: false
user-invocable: true
---

# Compliance Fix Skill

> **Project Configuration**: Before using this skill, read `project.config.yaml` in the project root. It defines project-specific paths, commands, conventions, and tooling. The compliance commands, lint commands, and project-specific validators referenced below come from that file.

Automatically run all compliance checks and apply fixes for code quality violations.

## When to Use

- Before committing code
- When CI/CD compliance checks fail
- After major code changes
- During code reviews
- Regular code quality maintenance

## What This Does

1. **Runs compliance checks**:
   - Linting
   - Code formatting
   - Naming convention validation
   - File size checks
   - Complexity validation
   - Project-specific validators (as defined in `project.config.yaml`)

2. **Applies automatic fixes**:
   - Code formatting
   - Import sorting
   - Auto-fixable lint issues
   - Whitespace cleanup

3. **Suggests manual fixes**:
   - Naming convention violations
   - Function complexity reduction
   - File splitting
   - Project-specific convention fixes

## Usage

User invocation:
```
/compliance-fix
```

Or with options:
```
/compliance-fix --fast        # Skip slow checks
/compliance-fix --verbose     # Show detailed suggestions
```

## Workflow

<workflow>

### Step 1: Run Compliance Checks

Execute the compliance runner:

```bash
{{config:commands.compliance}}
```

For fast mode (skip slow checks):
```bash
{{config:commands.compliance}} --fast
```

Capture output and categorize violations.

### Step 2: Categorize Violations

Parse output for these violation types:

**Auto-fixable**:
- Lint issues
- Code formatting
- Import sorting
- Trailing whitespace

**Manual fixes required**:
- Naming convention violations (e.g., camelCase in a snake_case project)
- File size violations (> 600 lines)
- Complexity violations (> 60 lines/function)
- Project-specific convention violations (check `project.config.yaml` for details)

### Step 3: Apply Automatic Fixes

Run fixes in this order:

1. **Format code**:
   ```bash
   {{config:commands.lint.format}}
   ```

2. **Fix linting issues**:
   ```bash
   {{config:commands.lint.fix}}
   ```

3. **Sort imports** (if supported by the project's linter):
   ```bash
   {{config:commands.lint.sort_imports}}
   ```

### Step 4: Provide Manual Fix Guidance

For each violation type, provide specific instructions:

**Naming Convention Violations**:
```
# Change from language-inappropriate casing to the project's convention.
# Example (Python — snake_case):
myVariable = "value"    ->    my_variable = "value"
userEmail = "test"      ->    user_email = "test"

# Example (JavaScript — camelCase):
my_variable = "value"   ->    myVariable = "value"
```

**File Size Violations**:
- Split files over 600 lines into logical modules
- Extract shared utilities
- Separate concerns (models, services, routes)

**Complexity Violations**:
- Functions over 60 lines: Extract helper methods
- Parameters over 5: Use structured input objects (dataclasses, Pydantic models, interfaces, etc.)
- Nesting over 4 levels: Use early returns/guard clauses

**Project-Specific Convention Violations**:
Check `project.config.yaml` for the project's specific conventions (auth patterns, error handling patterns, etc.) and follow those guidelines when suggesting fixes.

### Step 5: Re-run Compliance Checks

After applying fixes:

```bash
{{config:commands.compliance}}
```

Verify which violations were fixed and which remain.

### Step 6: Generate Fix Report

Provide clear summary:

**Fixed automatically**: X violations
- Formatting: Y files
- Linting: Z issues
- Imports: N files

**Requires manual fix**: M violations
- Naming: [list files]
- Complexity: [list functions]
- File size: [list large files]
- Convention violations: [list files]

**Next steps**: [prioritized list of manual fixes]

</workflow>

## Compliance Thresholds

### File Size
- **Warning**: 600 lines
- **Error**: 1000 lines

### Function Complexity
- **Parameters**: Max 5 (warning), 7 (error)
- **Lines**: Max 60 (warning), 100 (error)
- **Nesting**: Max 4 (warning), 6 (error)

### Code Quality
- **Line length**: Max 120 characters
- **Test coverage**: Minimum 80%
- **Naming**: Follow project conventions (see `project.config.yaml`)

## Examples

### Example 1: Lint Violations

**Violations**:
- Unused imports
- Line too long
- Missing whitespace

**Auto-fix**: Run `{{config:commands.lint.fix}}`

### Example 2: Naming Convention Violations

**Violation**:
```python
userEmail = request.form.get("email")  # camelCase in a snake_case project
```

**Auto-fix**: None

**Manual fix**:
```python
user_email = request.form.get("email")  # snake_case
```

### Example 3: File Size Violation

**Violation**: `src/services/conversation.py` - 1200 lines

**Auto-fix**: None

**Manual fix**:
- Extract message processing to `src/services/conversation/message_processor.py`
- Extract response generation to `src/services/conversation/response_generator.py`
- Extract validation to `src/services/conversation/validator.py`

### Example 4: Complexity Violation

**Violation**: `process_conversation()` has 85 lines

**Auto-fix**: None

**Manual fix**:
```python
# Split into smaller functions:
def process_conversation(data):
    validated_data = _validate_input(data)
    context = _build_context(validated_data)
    response = _generate_response(context)
    result = _format_output(response)
    return result
```

## Integration

This skill integrates with:
- Project compliance runner (as defined in `project.config.yaml`)
- Project linter and formatter
- Project-specific validators
- Git hooks (optional)

## Fast vs Full Mode

### Fast Mode (`--fast`)
Skips slow checks:
- Spell checking
- Comprehensive doc validation
- Deep complexity analysis

Use for:
- Quick iterations
- Pre-commit checks
- Local development

### Full Mode (default)
Runs all checks including slow ones.

Use for:
- Final validation before PR
- CI/CD pipelines
- Weekly code quality audits

## Notes

- Commit auto-fixes separately from manual fixes
- Check `project.config.yaml` for project-specific compliance commands and thresholds
- Some projects may have additional validators beyond the standard set
