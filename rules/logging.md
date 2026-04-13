# Logging Rules

**NEVER use print()/console.log() statements in application code. ALWAYS use proper logging.**

## Allowed Locations for Print Statements
- Scripts and CLI tools
- Development/debugging utilities
- Database migration scripts
- One-off automation scripts

## Forbidden Locations
- API routes and handlers
- Services and business logic
- Models and data access layers
- Core/shared modules
- Any production application code

## Best Practices

1. **Use your framework's logger** — not raw print/console statements
2. **Use structured logging with parameters** — lazy evaluation, not string interpolation
3. **Include context in logs** — trace IDs, user IDs, relevant entity IDs
4. **Use appropriate log levels**:
   - DEBUG: Detailed diagnostic information
   - INFO: General operational events
   - WARNING: Recoverable issues
   - ERROR: Failures that need attention
   - CRITICAL: System-level failures
5. **Include stack traces for exceptions** — use the logging framework's exception support
6. **Never log secrets** — API keys, tokens, passwords must never appear in logs
