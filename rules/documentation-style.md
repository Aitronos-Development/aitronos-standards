# Documentation Style Rules

**Keep docstrings and comments concise. 1-5 lines max for most functions.**

## Guidelines

### Simple Functions - One Line
```
"""Calculate sum of all items."""
```

### Complex Functions - Max 3-5 Lines
```
"""
Process payment for user.

Validates amount, checks balance, creates transaction.
Raises InsufficientFundsException if balance too low.
"""
```

## Don't Repeat
- Function name
- Type hints
- Parameter names
- Framework-generated documentation

## Focus on "Why" Not "What"
```
# Wrong: "Takes email string, checks regex pattern, returns True if valid."
# Correct: "Check if email format is valid."
```

## Summary
- Be concise: 1-5 lines
- Avoid redundancy
- Explain purpose, not mechanics
- Good code is self-documenting