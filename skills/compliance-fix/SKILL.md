---
name: compliance-fix
description: "DEPRECATED — Use /compliance-sweep instead. Full repository compliance cleanup that fixes ALL warnings and errors."
disable-model-invocation: false
user-invocable: true
---

# Compliance Fix — DEPRECATED

**This skill has been replaced by `/compliance-sweep`.**

`/compliance-sweep` does everything this skill did, plus:
- Fixes documentation accuracy issues (missing `system_message`, undocumented params, schema mismatches)
- Fixes documentation forbidden terms and quality issues
- Fixes project structure problems (stray root files)
- Removes `# noqa` and `# compliance: ignore` suppressions by fixing the underlying issues
- Adds missing type annotations
- Uses parallel agents for speed
- Runs a verify loop until everything is clean

## Redirect

When this skill is invoked, immediately run `/compliance-sweep` instead. Do not follow the old workflow below.
