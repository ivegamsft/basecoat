---
description: "Use when changing UI, client-side state, styling, forms, or interactions. Covers frontend best practices for accessibility, responsive behavior, and UX clarity."
applyTo: "**/src/**/*.{ts,tsx,js,jsx,css,scss,html},**/app/**/*.{ts,tsx,js,jsx,css,scss,html},**/components/**/*.{ts,tsx,js,jsx,css,scss,html},**/pages/**/*.{ts,tsx,js,jsx,css,scss,html}"
---

# Frontend Standards

Use this instruction for UI and frontend work.

## Rules

- Preserve the existing visual language and component patterns unless redesign is requested.
- Make keyboard access, visible focus, semantics, and error messaging part of the default implementation.
- Design for loading, empty, error, and success states before polishing edge interactions.
- Keep state flow and side effects easy to trace during async updates and retries.

## Expectations

- Preserve the product's existing visual language unless redesign is requested.
- Maintain accessibility for keyboard, focus, contrast, semantics, and screen readers.
- Keep responsive behavior intentional, not incidental.
- Prefer straightforward state flow over clever abstractions.
- Validate loading, empty, error, and success states.
- Keep forms and async actions recoverable: preserve user input when requests fail.
- Avoid layout shift and confusing motion during initial load and async refreshes.

## Examples

### Example accessible async action

```tsx
<button type="submit" disabled={isSaving} aria-busy={isSaving}>
  {isSaving ? 'Saving…' : 'Save changes'}
</button>
{saveError && <p role="alert">Save failed. Your edits are still on the page.</p>}
```

### Example responsive empty state

```tsx
<section aria-labelledby="orders-heading">
  <h2 id="orders-heading">Recent orders</h2>
  {orders.length === 0 ? <p>No orders yet. Create your first order to get started.</p> : <OrdersTable orders={orders} />}
</section>
```

## Review Lens

- Is the UI understandable at common breakpoints?
- Are interactions accessible without a mouse?
- Are network and async states communicated clearly?
- Does the implementation fit existing patterns in the codebase?
- Are copy, affordances, and error states specific enough to help the user recover?
