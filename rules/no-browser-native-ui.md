# No Browser-Native UI — Mandatory Rule

**NEVER use browser-native UI elements. ALL user interactions MUST use the project's own components.**

## Core Principle

Browser-native dialogs (`alert()`, `confirm()`, `prompt()`) and native form elements (`<select>`) cannot be styled, break visual consistency, and look different across browsers. Every user-facing interaction must use the project's component library for a consistent, branded experience.

## Forbidden Patterns

### Browser-Native Dialogs

```javascript
// FORBIDDEN: browser-native dialogs
alert('Something went wrong');
if (confirm('Are you sure?')) { ... }
const name = prompt('Enter your name');

// CORRECT: use custom dialog composable
import { useConfirmDialog } from '@/composables/useConfirmDialog';
const { confirm } = useConfirmDialog();
const confirmed = await confirm({
  title: 'Delete Item',
  description: 'This action cannot be undone.',
  confirmLabel: 'Delete',
  variant: 'destructive'
});
```

### Native `<select>` Elements

```vue
<!-- FORBIDDEN: native select -->
<select v-model="selectedOption">
  <option value="a">Option A</option>
</select>

<!-- CORRECT: use UI Kit Select or custom dropdown -->
<Select v-model="selectedOption" :options="options" />
```

## What to Use Instead

| Browser Native | Project Replacement |
|---------------|-------------------|
| `alert()` | Toast notification or error banner with `<Transition>` |
| `confirm()` | `useConfirmDialog()` composable (async, returns Promise) |
| `prompt()` | Custom modal with input field |
| `<select>` | UI Kit `Select` or custom dropdown component |
| `window.open()` (popup) | In-app modal or panel (exception: OAuth flows, external links) |

## Exceptions

- **OAuth popup flows** — `window.open()` is required for third-party auth popups
- **External links** — `window.open(url, '_blank')` for opening links in new tabs is acceptable
- **File downloads** — `window.open()` as download fallback is acceptable
- **Hidden file inputs** — `<input type="file">` is acceptable when visually hidden and triggered programmatically

## Compliance

```bash
bash scripts/compliance/check-native-browser-ui.sh
```