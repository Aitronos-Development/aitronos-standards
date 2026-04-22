# Button Loading State — Mandatory Rule

**NEVER use text-swap ternaries for button loading states. ALWAYS use the Button component's `:loading` prop.**

## Core Principle

Every button must show loading state the same way — a built-in spinner via the UI Kit Button's `loading` prop. Text-swap patterns (`isLoading ? 'Creating...' : 'Create'`) are inconsistent, harder to maintain, and look different across the app.

## Forbidden Pattern

```vue
<!-- FORBIDDEN: text-swap loading -->
<Button @click="handleCreate" :disabled="isCreating">
  {{ isCreating ? 'Creating...' : 'Create' }}
</Button>
```

## Correct Pattern

```vue
<!-- CORRECT: use :loading prop -->
<Button @click="handleCreate" :loading="isCreating">
  Create
</Button>
```

The Button `loading` prop automatically:
- Shows a spinner icon
- Applies `cursor: wait` and `pointer-events: none`
- Keeps the button text visible (via `loadingText` prop, default true)
- Maintains consistent styling across the app

## Compliance

```bash
bash scripts/compliance/check-button-loading.sh
```