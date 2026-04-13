# UI Kit Component Reuse Rules

**ALWAYS use existing UI Kit components instead of building custom alternatives from scratch.**

## Core Principle

When a UI Kit component exists that covers your use case — even partially — **use it**. If it needs enhancement, add features to the existing component rather than creating a new custom one.

## Available UI Kit Components

| Use Case | Component | Import Path |
|----------|-----------|-------------|
| Data tables | `Table` | `@aitronos/vue/Table.vue` |
| Buttons | `Button` | `@aitronos/vue/Button.vue` |
| Badges/tags | `Badge` | `@aitronos/vue/Badge.vue` |
| Text inputs | `InputField` | `@aitronos/vue/InputField.vue` |
| Checkboxes | `Checkbox` | `@aitronos/vue/Checkbox.vue` |
| Icons | `Icon` | `@aitronos/vue/Icon.vue` |
| Pagination | `Pagination` | `@aitronos/vue/Pagination.vue` |
| Dropdowns | `Dropdown` | `@aitronos/vue/Dropdown.vue` |
| Avatars | `Avatar` | `@aitronos/vue/Avatar.vue` |
| Tooltips | `Tooltip` | `@aitronos/vue/Tooltip.vue` |

## Shared App Components

| Use Case | Component | Import Path |
|----------|-----------|-------------|
| Card grid/stack layouts | `CollectionView` | `@/components/common/CollectionView.vue` |
| Skeleton→content transitions | `ContentTransition` | `@/components/common/ContentTransition.vue` |

## Rules

### Forbidden
- Hand-rolling `<table>` HTML when UI Kit `Table` covers the use case
- Creating custom button components when `Button` exists
- Building custom checkbox/radio components when `Checkbox` exists
- Writing custom skeleton loaders when the component has `loading` prop support

### Required
- Use `Table` for all data tables (it supports loading, empty state, selection, expansion, sorting, clickable rows, sticky headers)
- Use `CollectionView` for card grids and accordion stacks
- Use `ContentTransition` for skeleton-to-content loading transitions
- If a UI Kit component needs a new feature, **enhance the component** — don't build a workaround

## When to Enhance vs Build Custom

1. **UI Kit component exists and covers 80%+** of the need → **Enhance it** (add a prop, slot, or variant)
2. **UI Kit component exists but covers <50%** → **Ask the user** whether to enhance or build custom
3. **No UI Kit component exists** → Build in `src/components/common/` if reusable, otherwise in the feature folder
