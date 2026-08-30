# Frontend Development Agent — Detail Reference

Full standards for `agents/basecoat-10-core-frontend-dev.agent.md`.

## Component Design

- Apply single responsibility: one component, one job. Extract sub-components when a component exceeds 40 lines of render logic.
- Design composable APIs: accept children, slots, or render props rather than encoding layout decisions inside the component.
- Document every prop or input with its type, whether it is required, and its default value.
- Never leak internal implementation details through public prop names.
- Prefer controlled components (state owned by the caller) for form inputs and complex interaction widgets.

## Accessibility — WCAG 2.1 AA Minimum

Every component must satisfy these requirements before it ships:

### Perceivable

- All images have meaningful `alt` text, or `alt=""` if decorative.
- Color is never the sole means of conveying information.
- Text color contrast ratio is at least 4.5:1 for body text, 3:1 for large text.
- All content is accessible when text size is increased to 200%.

### Operable

- All interactive elements are reachable and usable via keyboard alone.
- Focus indicators are always visible — never remove the default outline without replacing it.
- No content flashes more than three times per second.
- Provide skip navigation links on page-level components.

### Understandable

- Form inputs have associated `<label>` elements or `aria-label` attributes.
- Error messages are descriptive and appear adjacent to the relevant field.
- Language is set on `<html lang="...">`.

### Robust

- Use semantic HTML elements (`<button>`, `<nav>`, `<main>`, `<article>`) over generic `<div>` and `<span>`.
- ARIA roles are only used to supplement — not replace — native semantics.
- All ARIA attributes have valid values and are applied to the correct element types.

## Responsive Design

- Design mobile-first: write base styles for the smallest viewport, layer up with min-width breakpoints.
- Define breakpoints as named tokens (e.g., `sm: 640px`, `md: 768px`, `lg: 1024px`). Do not use magic pixel values inline.
- Test at 320px, 768px, 1024px, and 1440px widths at minimum.
- Avoid fixed widths on containers. Use relative units (`%`, `rem`, `clamp()`, `fr`).

## State Management

- Use local component state for state that only affects the component itself.
- Use shared state (context, store, or equivalent) only for state that multiple components need.
- Avoid prop drilling beyond two levels — introduce a context or lift state to a common ancestor.
- Async state must model all four phases: idle, loading, success, and error.
- Never store derived data in state — compute it from source of truth at render time.

## Performance

- Target Core Web Vitals: LCP < 2.5s, CLS < 0.1, FID/INP < 100ms.
- Lazy-load components and routes that are not on the initial critical path.
- Avoid rendering large lists without virtualization.
- Do not import entire libraries for single utilities — import only what is used.
- Avoid inline style objects defined inside render functions — they cause unnecessary re-renders.
- Measure before optimizing: use browser DevTools Performance tab and Lighthouse.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Tech Debt]`
- **Base labels:** `tech-debt,frontend,accessibility`
- **Category options:** `<missing ARIA | hardcoded color | non-semantic markup | missing loading state | inline styles>`
- **File:** `<path/to/component.ext>`

| Finding | Labels |
|---|---|
| Interactive element missing ARIA role, label, or description | `tech-debt,frontend,accessibility` |
| Color hardcoded as hex or RGB literal (not a design token) | `tech-debt,frontend` |
| `<div>` or `<span>` used where a semantic element exists | `tech-debt,frontend,accessibility` |
| Component has no loading state for async data | `tech-debt,frontend` |
| Inline style object defined inside render function | `tech-debt,frontend,performance` |
