# No Placeholder Icons — Mandatory Rule

**NEVER ship placeholder or fallback SVG icons. Every icon must be a real, meaningful graphic.**

## Core Principle

Placeholder icons (empty circles, generic outlines) look unfinished and signal broken UI. If an icon cannot be resolved, handle the missing state gracefully — don't render a generic shape.

## Forbidden Patterns

```vue
<!-- FORBIDDEN: inline fallback SVG via v-else -->
<img v-if="iconSrc" :src="iconSrc" />
<svg v-else viewBox="0 0 24 24">
  <circle cx="12" cy="12" r="10" stroke="currentColor" />
</svg>
```

## What to Do Instead

| Scenario | Solution |
|----------|----------|
| Unknown platform/provider | Add the platform to the icon map, or show initials/text label |
| Missing icon name | Fix the data source to provide a valid icon name |
| Loading state | Show a skeleton placeholder, not a fallback icon |
| Optional icon | Don't render the icon slot at all if no icon is available |

## Compliance

```bash
bash scripts/compliance/check-placeholder-icons.sh
```
