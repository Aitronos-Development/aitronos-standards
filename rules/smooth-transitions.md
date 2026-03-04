# Smooth Transitions — Mandatory Animation Rule

**NOTHING appears or disappears instantly. Every visual state change MUST be animated.**

## Core Principle

Users should never see UI elements pop in, flash, or vanish. Every appearance, disappearance, position change, and state change must use a smooth transition. Abrupt visual changes feel broken — smooth motion signals quality.

## What Must Be Animated

| Visual Change | Required Animation |
|---|---|
| Element appearing (mount, v-if, v-show) | Fade in, slide in, or scale in |
| Element disappearing (unmount, v-if, v-show) | Fade out, slide out, or scale out |
| Loading → content switch | `<ContentTransition>` wrapper |
| Modal / dialog open/close | `<Transition name="ait-modal">` |
| Panel / drawer open/close | `<Transition name="ait-panel-slide">` |
| List item add/remove/reorder | `<TransitionGroup name="ait-list">` |
| Route / tab change content | `<ContentTransition>` or `<Transition name="ait-page-fade">` |
| Expanding / collapsing sections | CSS transition on height/max-height or `<Transition>` |
| Numeric value changes | `useAnimatedNumber` composable |
| Hover / focus / active states | CSS `transition` on the affected properties |
| Skeleton → real content | `<ContentTransition :loading="isLoading">` |
| Toast / notification | `<Transition name="ait-modal">` or equivalent |
| Tooltip show/hide | CSS `transition: opacity` |
| Dropdown open/close | CSS `transition: opacity, transform` |
| Error/success banner appear | `<Transition name="ait-content">` |
| Badge count changes | CSS `transition: transform` (scale bump) |

## Available Transition Presets

All presets are defined in `src/assets/transitions.css` and use tokens from `animations.css`:

| Preset Name | Use Case | Enter | Exit |
|---|---|---|---|
| `ait-page-fade` | Route-level crossfade | 0.3s ease-in | 0.15s ease-out |
| `ait-content` | Skeleton → content fade | 0.3s ease-in | 0.15s ease-out |
| `ait-panel-slide` | Side panels / drawers | 0.3s spring + fade | 0.2s ease-out |
| `ait-list` | List item add/remove | 0.2s ease-in + translateY | 0.15s ease-out |
| `ait-modal` | Modals / dialogs | 0.2s fade + 0.3s spring scale | 0.15s fade + 0.2s scale |

## Animation Tokens

**ALWAYS use animation tokens. NEVER hardcode durations or easing.**

```css
/* ─── Transition Durations ─── */
--ait-animation-duration-fast: 0.15s;    /* Exits, micro-interactions, hover/focus */
--ait-animation-duration-normal: 0.2s;   /* Standard transitions, state changes */
--ait-animation-duration-slow: 0.3s;     /* Entrances, large movements, panels */

/* ─── Continuous Animation Durations ─── */
--ait-animation-duration-spin: 0.8s;     /* Loading spinners (linear, infinite) */
--ait-animation-duration-shimmer: 1.5s;  /* Skeleton shimmer/pulse (ease, infinite) */
--ait-animation-duration-pulse: 2s;      /* Live indicators, glows (ease-in-out, infinite) */

/* ─── Easing Curves ─── */
--ait-easing-default: cubic-bezier(0.4, 0, 0.2, 1);  /* Hover, focus, color changes */
--ait-easing-enter: cubic-bezier(0.0, 0, 0.2, 1);    /* Content appearing */
--ait-easing-exit: cubic-bezier(0.4, 0, 1, 1);       /* Content leaving */
--ait-easing-spring: cubic-bezier(0.16, 1, 0.3, 1);  /* Panels, modals, popovers */
```

**Compliance:** `bash scripts/compliance/check-transitions.sh`

## How to Animate Common Patterns

### Conditional content (`v-if` / `v-show`)
```vue
<Transition name="ait-content">
  <div v-if="showBanner" class="banner">...</div>
</Transition>
```

### Loading states
```vue
<ContentTransition :loading="isLoading">
  <template #loading><SkeletonLoader /></template>
  <ActualContent />
</ContentTransition>
```

### List mutations
```vue
<TransitionGroup name="ait-list" tag="ul">
  <li v-for="item in items" :key="item.id">{{ item.name }}</li>
</TransitionGroup>
```

### Modals / dialogs
```vue
<Transition name="ait-modal">
  <dialog v-if="open" class="my-dialog">...</dialog>
</Transition>
```

### Interactive states (CSS-only)
```css
.my-card {
  transition: border-color var(--ait-animation-duration-fast) var(--ait-easing-default),
              box-shadow var(--ait-animation-duration-fast) var(--ait-easing-default);
}
.my-card:hover {
  border-color: var(--color-1-color-modes-colors-border-border-primary);
}
```

### Expanding/collapsing
```css
.collapsible {
  overflow: hidden;
  max-height: 0;
  transition: max-height var(--ait-animation-duration-slow) var(--ait-easing-default);
}
.collapsible--open {
  max-height: 500px; /* use a generous upper bound */
}
```

## Forbidden Patterns

```vue
<!-- FORBIDDEN: raw v-if without transition -->
<div v-if="showError" class="error-banner">Error occurred</div>

<!-- CORRECT: wrapped in Transition -->
<Transition name="ait-content">
  <div v-if="showError" class="error-banner">Error occurred</div>
</Transition>
```

```css
/* FORBIDDEN: no transition on interactive state */
.card:hover { background: var(--bg-hover); }

/* CORRECT: with transition */
.card {
  transition: background var(--ait-animation-duration-fast) var(--ait-easing-default);
}
.card:hover { background: var(--bg-hover); }
```

```css
/* FORBIDDEN: hardcoded duration */
.fade { transition: opacity 0.2s ease; }

/* CORRECT: token-based duration */
.fade { transition: opacity var(--ait-animation-duration-normal) var(--ait-easing-default); }
```

## Exceptions

- **Initial page skeleton render** — the first skeleton frame appears instantly (no fade-in for loading states on mount). `ContentTransition` handles this automatically.
- **`prefers-reduced-motion`** — all transitions collapse to near-instant (0.01ms) automatically via the media query in `transitions.css`.
- **Drag operations** — elements being dragged follow the cursor without easing.
- **Immediate feedback** — focus rings and cursor changes are instant (CSS `:focus-visible`, `cursor`).
