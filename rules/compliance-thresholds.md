# Compliance Thresholds & Key Guidelines

## File Size Limits
- **Warning**: 600 lines
- **Error**: 1000 lines
- **Scope**: All source code files

## Function Complexity
- **Parameters**: Max 5 (warning), 7 (error)
- **Lines**: Max 60 (warning), 100 (error)
- **Cyclomatic Complexity**: Max 10 (warning), 15 (error)
- **Nesting Depth**: Max 4 (warning), 6 (error)
- **Return Statements**: Max 4 (warning), 6 (error)

## Class Complexity
- **Lines**: Max 300 (warning), 500 (error)
- **Methods**: Max 15 (warning), 25 (error)

## Code Quality
- **Line Length**: Max 120 characters
- **Test Coverage**: Minimum 80%
- **Naming**: Follow language conventions (snake_case for Python, camelCase for JS/TS)

## Key Principles
- Keep functions small and focused (under 60 lines)
- Limit function parameters (under 5)
- Avoid deep nesting (under 4 levels)
- Split large files (under 600 lines)
- Follow your language's naming conventions consistently