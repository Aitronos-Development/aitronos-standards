# UI Kit Mandatory Usage Rules

**ALL UI elements MUST use UI Kit components when an equivalent exists. Hand-rolled HTML elements are compliance errors.**

## Available UI Kit Components

| HTML Element | UI Kit Replacement | Import Path | Severity |
|-------------|-------------------|-------------|----------|
| `<table>`, `<thead>`, `<tbody>`, `<tr>`, `<th>`, `<td>` | `Table` | `@aitronos/vue/Table.vue` | ERROR |
| `<button>` | `Button` | `@aitronos/vue/Button.vue` | ERROR |
| `<input type="text/search/email/password/number">`, `<textarea>` | `InputField` | `@aitronos/vue/InputField.vue` | ERROR |
| `<select>` | `Dropdown` | `@aitronos/vue/Dropdown.vue` | ERROR |
| Custom pagination (prev/next + page numbers) | `Pagination` | `@aitronos/vue/Pagination.vue` | ERROR |
| `<span class="badge/chip/tag/pill">` | `Badge` | `@aitronos/vue/Badge.vue` | WARNING |
| `<input type="checkbox">` with custom CSS | `Checkbox` | `@aitronos/vue/Checkbox.vue` | WARNING |
| Custom tooltip divs with show/hide | `Tooltip` | `@aitronos/vue/Tooltip.vue` | WARNING |
| Image + initials fallback (avatar pattern) | `Avatar` | `@aitronos/vue/Avatar.vue` | WARNING |
| Inline `<svg>` elements (not charts) | `Icon` | `@aitronos/vue/Icon.vue` | WARNING |
| Teleport-based modals | Shared Modal pattern | TBD (no UI Kit Modal yet) | WARNING |
| Custom `@keyframes rotate/spin` | `ContentTransition` / `SkeletonLoader` | `@/components/common/` | WARNING |

## Allowed Native HTML Elements

These are acceptable and will NOT trigger violations:

- `<input type="hidden">` — form mechanics
- `<input type="file">` — no UI Kit equivalent
- `<input type="date">` — no UI Kit equivalent
- `<input type="checkbox">` — acceptable without custom CSS (native browser checkbox)
- `<input type="radio">` — no UI Kit equivalent yet
- `<svg>` inside chart/graph components — SVG IS the purpose
- `<button>` inside `<template #slot>` of UI Kit components — slot content
- `<button type="submit">` in native form submissions

## Domain Boundary Rules

Feature domains must respect component boundaries:

| Domain | Forbidden Imports |
|--------|-------------------|
| Chat UI (`src/components/FreddyChat*`, `src/views/chat/`, `src/views/conversation/`) | `@/components/Knowledge/*`, `@/stores/knowledge-*` |

Cross-domain data should flow through shared stores, event buses, or props, not direct imports.

## How to Add Allowlist Exceptions

If a file legitimately needs a native element, add it to the allowlist at the top of `scripts/compliance/check-ui-kit-usage.sh`:

```bash
# In the relevant allowlist array:
TABLE_ALLOWLIST=(
  "src/components/my-special/SpecialTable.vue"   # Explain why
)
```

### Allowlist guidelines:
- **Always add a comment** explaining why the exception exists
- **Prefer fixing** over allowlisting — can the UI Kit component be enhanced instead?
- **Directory prefixes** are supported: `"src/components/auth/"` allows all files under auth/
- **Global allowlist** bypasses ALL checks for a file

## Enforcement

This is enforced by the compliance check:

```bash
# Run standalone
bash scripts/compliance/check-ui-kit-usage.sh

# Run as part of full compliance
./start-compliance.sh --quick
```

- **ERROR-level** violations block CI and must be fixed
- **WARNING-level** violations are tracked but do not block
- Exit code 1 = errors found, exit code 0 = clean or warnings only