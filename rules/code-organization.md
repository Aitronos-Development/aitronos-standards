# Code Organization Rules

## Core Principle
**NEVER duplicate helper functions across files. ALWAYS extract shared utilities to dedicated modules.**

## When to Extract a Helper

1. **Is the function used in multiple files?** -> Extract to shared utils
2. **Is the function likely to be reused?** -> Extract to shared utils
3. **Is the function more than 10 lines?** -> Consider extracting
4. **Is the function validation/transformation logic?** -> Extract to shared utils

If a helper appears in 2+ files, it MUST be extracted to a shared module.

## Guidelines

- **Shared utilities**: Place in a dedicated utils/helpers directory
- **File-specific helpers**: Can stay in the file if truly unique, tightly coupled, and under 10 lines
- **Naming**: Use descriptive verb phrases (e.g., `verify_access`, `parse_date_range`)
- **Single responsibility**: Each utility function should do one thing well
- **Type safety**: Always include type hints/annotations
- **Testing**: Write unit tests for utility functions

## Anti-Pattern

Duplicating the same helper function across multiple files — even with minor variations. Consolidate into one implementation and import everywhere.

## Summary
- **Shared helpers** -> Dedicated utils module
- **File-specific helpers** -> Can stay in file (if truly unique)
- **Duplicate helpers** -> ALWAYS consolidate
- **DRY** (Don't Repeat Yourself) is non-negotiable
