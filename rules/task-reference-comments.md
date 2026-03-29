# Task Reference Comment Rules

**Task references (`# Task 16.4:`) are NOT allowed in code. TODO comments are OK.**

## Forbidden
```
# Task 16.4: Invalidate cache
# Task 9.1: Log tool name
```

## Allowed
```
# TODO: Add admin role check
# FIXME: Validation incomplete
# HACK: Temporary workaround
```

## What to Do
- **Task done** -> Remove the comment
- **Work remains** -> Convert to `# TODO: description`
- **Needs explanation** -> Write a proper comment explaining why, not referencing a task number

| Pattern | Status |
|---------|--------|
| `# Task X.Y:` | Error |
| `# TODO:` | Warning (tracked) |
| `# FIXME:` | Warning (tracked) |
