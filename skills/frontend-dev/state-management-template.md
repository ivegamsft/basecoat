# State Management Template

Use this template to design the state structure for a feature or component before writing state logic. Define all state slices, transitions, and async lifecycles before implementation.

---

## Feature / Component State Overview

| Field | Value |
|---|---|
| **Feature / Component** | `<FeatureName>` |
| **State scope** | Local component / Shared context / Global store |
| **Async operations** | Yes / No |
| **Last Updated** | `YYYY-MM-DD` |

---

## 1. Local Component State

State that belongs to a single component and does not need to be shared.

| State key | Type | Initial value | Description |
|---|---|---|---|
| `isOpen` | `boolean` | `false` | Controls whether a modal or panel is visible |
| `inputValue` | `string` | `""` | Controlled input value before submission |
| `selectedId` | `string \| null` | `null` | Currently selected item ID |

**Guideline:** If state is referenced by more than one component, it is not local — promote it to shared state.

---

## 2. Shared State (Context / Store)

State shared by multiple components. Document the shape and the scope (which components have access).

```
State slice: <sliceName>

{
  "<entityName>": {
    data: <Entity>[] | null,  // null means not yet loaded
    status: "idle" | "loading" | "success" | "error",
    error: { code: string, message: string } | null,
    pagination: {
      pageSize: number,
      nextCursor: string | null,
      total: number | null
    }
  },
  "selectedId": string | null,
  "filters": {
    searchQuery: string,
    sortBy: "createdAt" | "name",
    sortOrder: "asc" | "desc"
  }
}
```

**Access scope:** List the components that read or write this slice.

| Component | Reads | Writes |
|---|---|---|
| `<ComponentA>` | `data`, `status` | `filters` |
| `<ComponentB>` | `selectedId` | `selectedId` |

---

## 3. Async State Lifecycle

Every async operation must model all four phases explicitly.

| Phase | `status` value | UI behavior |
|---|---|---|
| Not started | `"idle"` | Show default/empty UI. Enable triggering controls. |
| In progress | `"loading"` | Show skeleton or spinner. Disable triggering controls to prevent double-submit. |
| Succeeded | `"success"` | Render data. Clear error state. |
| Failed | `"error"` | Show error message. Offer retry. Log the error. |

**Transitions:**

```
idle → loading  (when action is dispatched / fetch begins)
loading → success  (when data is received)
loading → error  (when request fails)
error → loading  (when user retries)
success → loading  (when user triggers a refresh or next page)
```

---

## 4. Error State

Define the shape of error state and how it is displayed.

```
error: {
  code: string,       // machine-readable error code from the API error catalog
  message: string,    // human-readable message, safe to display
  field: string | null  // null for non-field errors; field name for form validation errors
} | null
```

**Error display rules:**
- Non-field errors: render in an inline error banner above the form or content area.
- Field errors: render adjacent to the input field. Associate via `aria-describedby`.
- All error messages must use `role="alert"` or be placed in an `aria-live="polite"` region.
- Never display raw error codes or stack traces to the user.

---

## 5. Derived State

Computed values derived from source state. Do not store derived data in state — compute at render time.

| Derived value | Formula | Used by |
|---|---|---|
| `hasResults` | `data !== null && data.length > 0` | `<ComponentA>` — controls empty state rendering |
| `isFirstPage` | `pagination.nextCursor === null && data?.length === pageSize` | `<ComponentA>` — disables previous button |
| `canSubmit` | `inputValue.trim().length > 0 && status !== "loading"` | `<FormComponent>` — controls submit button disabled state |

---

## 6. State Initialization

| When | Action |
|---|---|
| Component mounts | Set `status` to `"idle"`, clear `error`, clear `data` if stale |
| User navigates back to the view | Restore from cache if TTL has not expired; otherwise reset to `"idle"` and re-fetch |
| User logs out | Clear all user-scoped state slices |

---

## 7. Anti-Patterns to Avoid

- ❌ Storing derived values in state (they go stale and diverge from source of truth).
- ❌ Using `null` and `undefined` interchangeably — pick one semantic per key and stick to it.
- ❌ Nesting state mutations (treat state updates as immutable replacements).
- ❌ Setting `status = "success"` before all data for the view has loaded.
- ❌ Ignoring the `"idle"` phase — components that can be in idle must render an appropriate initial state.
- ❌ Prop drilling state through more than two component levels — use context or lift higher.
