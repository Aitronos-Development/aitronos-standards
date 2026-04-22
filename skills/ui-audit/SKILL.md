---
name: ui-audit
description: Audit a frontend section for UI smoothness compliance — transitions, loading states, animations, layout shifts. Produces a table of issues with severity, location, and fix guidance.
disable-model-invocation: false
user-invocable: true
---

# UI Audit — Frontend Smoothness Analysis

You are a **UI smoothness auditor**. Your job is to analyze a section of the frontend and find every place where the UI doesn't feel native-app smooth. Every state change, every loading state, every interaction must be animated and polished.

## When to Use

```
/ui-audit
```

Then specify scope: "home page", "flow editor", "modals", "sidebar", etc.

## Reference Standard

Read `.standards/rules/ui-smoothness.md` for the full rule set. Key requirements:

| Rule | Requirement |
|------|-------------|
| State transitions | 100% of visibility changes must be animated |
| Loading states | 100% of async data must show skeleton/loading |
| Transition duration | 100–300ms, never >500ms |
| Layout shifts | Zero — use skeletons/placeholders |
| Hover feedback | All interactive elements need `transition-colors` or equivalent |
| Tab switching | Content must fade/cross-fade, never instant swap |
| Modal open/close | Must have enter/exit animation |
| `prefers-reduced-motion` | Must be respected for non-essential animations |

<workflow>

## Step 1 — Identify Target Files

Based on the user's scope, find all relevant files:

1. Read the page-level component (e.g., `src/frontend/src/pages/MainPage/pages/homePage/index.tsx`)
2. Trace all imported child components
3. Include relevant modals, dialogs, and shared UI components used by the section
4. List all files that will be audited

## Step 2 — Automated Check

Run the compliance script scoped to the target:

```bash
uv run python3 scripts/compliance/check_ui_smoothness.py
```

Record the automated findings.

## Step 3 — Manual Deep Audit

For each file, check these categories. Read the actual code — don't guess.

### A. Conditional Rendering (show/hide)
Search for: `{condition && <Component`, `{condition ? <A> : <B>}`, `open={...}`

For each one, verify:
- [ ] Has `AnimatePresence` + `motion.div` wrapper, OR
- [ ] Has `transition-*` / `animate-in` / `animate-out` classes, OR
- [ ] Uses a Radix primitive with built-in animation (Dialog, Collapsible, etc.)

**If none** → Issue: `no-animation` severity based on visibility impact

### B. Loading States
Search for: `useQuery`, `useGet*Query`, `useMutation`, `isLoading`, `isPending`

For each async data source, verify:
- [ ] There's a loading branch (`if (isLoading)`) or conditional skeleton
- [ ] The skeleton matches the final content layout (not just a spinner)
- [ ] The transition from skeleton → content is smooth (fade, not pop-in)

**If missing** → Issue: `missing-loading-state`

### C. List/Grid Rendering
Search for: `.map(`, `Array.from(`, grid/flex containers with dynamic children

For each list:
- [ ] Items have enter animation (fade-in, stagger OK)
- [ ] Empty state has its own styled component
- [ ] Pagination transitions don't cause layout shift

**If bare** → Issue: `no-list-animation`

### D. Interactive Element Feedback
Search for: `onClick`, `<Button`, `<a `, `href=`, cursor-pointer

For each interactive element:
- [ ] Has hover state transition (`hover:` + `transition-colors`)
- [ ] Has active/pressed feedback (scale, opacity, or color)
- [ ] Disabled state is visually distinct

**If missing** → Issue: `no-hover-transition`

### E. Tab/View Switching
Search for: tabs, tab panels, view selectors

For each tab system:
- [ ] Content transitions between tabs (fade or slide)
- [ ] Active tab indicator animates (not instant jump)

**If instant** → Issue: `no-tab-transition`

### F. Modal/Dialog Behavior
Search for: `<Dialog`, `<Modal`, `<Sheet`, `<Drawer`

For each:
- [ ] Has enter animation (fade + scale/slide)
- [ ] Has exit animation (not instant disappear)
- [ ] Overlay backdrop fades in/out
- [ ] Escape key closing is animated

**If missing** → Issue: `no-modal-animation`

## Step 4 — Build Issues Table

Create a markdown table with ALL findings:

```markdown
| # | Severity | File | Line | Rule | Description | Fix |
|---|----------|------|------|------|-------------|-----|
| 1 | 🔴 P1 | pages/homePage/index.tsx | 245 | no-animation | Flow cards appear without fade-in | Wrap in AnimatePresence + motion.div with stagger |
| 2 | 🟡 P2 | components/AssistantsTab.tsx | 33 | missing-loading-state | Assistant list shows nothing while loading | Add skeleton matching card layout |
```

### Severity Guide

| Level | Meaning | When |
|-------|---------|------|
| 🔴 P1 | Jarring, user-visible jank | Layout shift, content pop-in, no loading state |
| 🟡 P2 | Noticeable but not broken | Missing hover transition, instant tab switch |
| 🟢 P3 | Polish opportunity | Could add stagger, could improve timing |

## Step 5 — Summary

```
UI AUDIT — {Section Name}
========================

Files audited: {N}
Total issues: {N}
  🔴 P1 (Must fix):   {N}
  🟡 P2 (Should fix):  {N}
  🟢 P3 (Nice to have): {N}

Top priorities:
1. {Most impactful fix}
2. {Second most impactful}
3. {Third}
```

</workflow>

## Rules

### NEVER
- Guess about animations — read the actual code
- Flag Radix primitives that have built-in animations as issues
- Flag utility/hook files that don't render UI
- Report `transition-colors` on non-interactive elements as missing

### ALWAYS
- Read every file you audit, don't just grep
- Check the component tree (parent may provide animation context)
- Verify Dialog/Sheet/Popover components — they often have animation in the shared component
- Note which issues are quick fixes vs. architectural changes
