# UI Smoothness Rules

**Every UI interaction must feel native-app smooth. No jarring transitions, no layout shifts, no flash of unstyled content.**

## Core Principles

1. **Every state change must be animated** — loading → loaded, hidden → visible, collapsed → expanded
2. **No layout shifts** — use fixed dimensions or skeletons to reserve space before content loads
3. **No flash of empty content** — show skeletons or loading states immediately, never a blank area that pops in

## Required Patterns

### Transitions (Mandatory)

| Interaction | Required Animation | Duration |
|-------------|-------------------|----------|
| Modal open/close | Fade + scale | 150-200ms |
| Dropdown/popover | Fade + slide-y | 100-150ms |
| Tab switch content | Fade or cross-fade | 150-200ms |
| List item appear | Fade-in (stagger OK) | 100-200ms |
| Page/route transition | Fade | 150-300ms |
| Toast/notification | Slide-in + fade | 200-300ms |
| Hover state change | Color/opacity transition | 150ms |
| Button press feedback | Scale or opacity | 100ms |
| Sidebar collapse/expand | Width + fade content | 200-300ms |
| Card hover | Shadow + subtle lift | 150ms |

### Loading States (Mandatory)

| Content Type | Required Loading State |
|-------------|----------------------|
| Data list/grid | Skeleton cards matching final layout |
| Text content | Skeleton lines |
| Image/avatar | Placeholder with `animate-pulse` |
| Full page | Progressive loading with status message |
| Button action | Spinner + disabled state |
| Inline update | Optimistic update or spinner |

### Forbidden Patterns

- **Hard show/hide** — `display: none` toggling without transition
- **Content pop-in** — Data appearing without fade/slide
- **Layout jumps** — Content shifting other content when it loads
- **Unstyled flash** — Raw HTML visible before styles apply
- **Spinner-only loading** — Full-page spinners without context (what's loading?)
- **Instant tab switches** — Tab content swapping without any transition
- **Abrupt modal dismiss** — Modal disappearing without fade-out

## Implementation

### Tailwind Classes (Preferred)

```
transition-all duration-200     — General state changes
transition-opacity duration-150 — Fade in/out
transition-colors duration-150  — Hover color changes
transition-transform duration-200 — Scale/translate
animate-pulse                   — Skeleton placeholders
animate-in / animate-out        — Radix UI enter/exit
```

### Framer Motion (Complex Animations)

Use for: staggered lists, layout animations, shared element transitions, gesture-driven animations.

```tsx
<motion.div
  initial={{ opacity: 0, y: 10 }}
  animate={{ opacity: 1, y: 0 }}
  exit={{ opacity: 0, y: -10 }}
  transition={{ duration: 0.15 }}
/>
```

### Skeleton Pattern

```tsx
// Always match the skeleton to the final content layout
{isLoading ? (
  <div className="space-y-3">
    <Skeleton className="h-8 w-48" />    {/* Title */}
    <Skeleton className="h-4 w-full" />   {/* Description line 1 */}
    <Skeleton className="h-4 w-3/4" />    {/* Description line 2 */}
  </div>
) : (
  <ActualContent />
)}
```

## Accessibility

- Respect `prefers-reduced-motion: reduce` — disable non-essential animations
- Keep essential state-change animations but reduce duration to near-instant
- Never use animation as the only indicator of state change

## Summary

| Rule | Threshold |
|------|-----------|
| State transitions animated | 100% of visibility changes |
| Loading skeletons | 100% of async data renders |
| Transition duration | 100-300ms (never >500ms) |
| Layout shifts | Zero (use skeleton/placeholder) |
| `prefers-reduced-motion` | Must be respected |