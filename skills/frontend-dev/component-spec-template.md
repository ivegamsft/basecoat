# Component Specification Template

Use this template to define a component before implementation begins. Fill in all sections. A complete spec prevents ambiguous implementations and missing states.

---

## Component Overview

| Field | Value |
|---|---|
| **Component Name** | `<ComponentName>` |
| **Type** | Presentational / Container / Hybrid |
| **Owner** | `<team or developer>` |
| **Last Updated** | `YYYY-MM-DD` |

**Description:**
One sentence describing what this component does and where it is used.

---

## Props / Inputs

| Prop | Type | Required | Default | Description |
|---|---|---|---|---|
| `<propName>` | `string` | Yes | — | Description of this prop's purpose |
| `<propName>` | `number` | No | `0` | Description |
| `<propName>` | `boolean` | No | `false` | Description |
| `onAction` | `(payload: ActionPayload) => void` | No | — | Callback fired when the primary action occurs |
| `children` | `ReactNode / slot` | No | — | Slot for composable content |

---

## Events / Callbacks

| Event | Payload | When Emitted |
|---|---|---|
| `onChange` | `{ value: string }` | When the user changes the input value |
| `onSubmit` | `{ data: FormData }` | When the form is submitted successfully |
| `onError` | `{ code: string, message: string }` | When an error occurs during async operations |

---

## UI States

The component must implement all applicable states below. Mark each as Required or N/A.

| State | Required / N/A | Design Note |
|---|---|---|
| **Loading** | Required | Show a skeleton or spinner. Disable interactive elements. |
| **Error** | Required | Display an inline error message near the affected content. Include a retry affordance if applicable. |
| **Empty** | Required | Render a meaningful empty state — not a blank region. |
| **Populated** | Required | Normal content rendering. |
| **Disabled** | N/A | Visual and interactive disabled state. |
| **Read-only** | N/A | Content visible but not editable. |
| **Selected / Active** | N/A | Visual indicator for selected state. |

---

## Accessibility Requirements

Every requirement below must be satisfied before the component ships.

| Requirement | Verification Method |
|---|---|
| All interactive elements are keyboard-reachable via `Tab` | Manual keyboard walkthrough |
| Focus indicator is visible on all focusable elements | Visual inspection |
| Component has a descriptive `aria-label` or visible label | Inspect DOM |
| Error messages are announced by screen readers (`role="alert"` or `aria-live`) | Screen reader test |
| Color is not the sole means of conveying information | Visual inspection |
| Text contrast ratio meets 4.5:1 (body) or 3:1 (large text) | Automated scan (axe, Lighthouse) |
| All images have `alt` text or `alt=""` if decorative | Inspect DOM |
| Semantic HTML used for structure (`button`, `nav`, `main`, etc.) | Inspect DOM |

---

## Children / Slots / Composition

Describe how this component accepts and renders content from its parent.

| Slot | Required | Description |
|---|---|---|
| `default` / `children` | No | Primary composed content |
| `header` | No | Content rendered in the component header area |
| `footer` | No | Content rendered in the component footer area |
| `actions` | No | Action buttons or controls rendered in a dedicated area |

---

## Responsive Behavior

| Breakpoint | Behavior |
|---|---|
| `< 640px` (mobile) | Describe layout at smallest viewport |
| `640px – 1023px` (tablet) | Describe layout at medium viewport |
| `≥ 1024px` (desktop) | Describe layout at full width |

---

## Test Plan

| Scenario | Type | Assertion |
|---|---|---|
| Renders in populated state with valid props | Unit | Component output matches snapshot or expected DOM |
| Renders loading skeleton when `isLoading` is true | Unit | Skeleton is visible, content is not |
| Renders error message when `error` is set | Unit | Error message text is present and `role="alert"` is applied |
| Renders empty state when `data` is empty array | Unit | Empty state message is visible |
| Keyboard user can reach and activate the primary action | Accessibility | Tab to element, Enter/Space activates callback |
| Screen reader announces error messages | Accessibility | `aria-live` or `role="alert"` present on error region |

---

## Open Questions

List any design or behavior decisions that need clarification before implementation.

1. `<open question>`
2. `<open question>`
