---
description: "Tailwind CSS v4 patterns, CSS-first configuration, and migration guidance"
applyTo: "**/*.css,**/*.tsx,**/*.html"
---

# Tailwind CSS v4 Instruction

## Overview

Tailwind CSS v4 introduces a CSS-first configuration model, native cascade layers,
and significant performance improvements. This instruction guides Copilot to generate
modern Tailwind v4 code following current best practices.

## CSS-First Configuration

Tailwind v4 replaces `tailwind.config.js` with CSS-native configuration using the
`@theme` directive:

```css
@import "tailwindcss";

@theme {
  --color-primary: #3b82f6;
  --color-secondary: #10b981;
  --font-display: "Inter", sans-serif;
  --breakpoint-3xl: 1920px;
}
```

## Theme Customization

Define design tokens directly in CSS rather than JavaScript config files:

```css
@theme {
  --color-brand-50: oklch(0.97 0.01 250);
  --color-brand-100: oklch(0.93 0.02 250);
  --color-brand-500: oklch(0.55 0.18 250);
  --color-brand-900: oklch(0.25 0.08 250);

  --spacing-18: 4.5rem;
  --radius-pill: 9999px;

  --animate-slide-in: slide-in 0.3s ease-out;
}

@keyframes slide-in {
  from { transform: translateX(-100%); }
  to { transform: translateX(0); }
}
```

## Native Cascade Layers

Tailwind v4 uses CSS cascade layers for predictable specificity:

```css
@layer theme, base, components, utilities;
```

- `theme` — design tokens and CSS variables
- `base` — reset and element defaults
- `components` — reusable component classes
- `utilities` — single-purpose utility classes

## Container Queries

Use container queries for component-level responsive design:

```html
<div class="@container">
  <div class="@sm:grid-cols-2 @lg:grid-cols-3 grid gap-4">
    <div class="@sm:flex-row flex flex-col">
      <!-- Responds to container width, not viewport -->
    </div>
  </div>
</div>
```

## Color-Mix Utilities

Generate color variations without defining every shade:

```html
<div class="bg-primary/50">50% opacity primary</div>
<div class="bg-mix-primary-white-20">20% white mixed with primary</div>
```

## Variant API

Define custom variants using the `@variant` directive:

```css
@variant hocus (&:hover, &:focus);
@variant group-active (group:active &);

@variant theme-dark (@media (prefers-color-scheme: dark));
```

Usage in HTML:

```html
<button class="hocus:bg-primary-600 bg-primary-500">
  Hover or focus state
</button>
```

## Component Patterns

### Card Component

```html
<div class="shadow-md dark:bg-gray-800 rounded-xl bg-white p-6">
  <h3 class="text-gray-900 dark:text-white text-lg font-semibold">
    Card Title
  </h3>
  <p class="text-gray-600 dark:text-gray-300 mt-2">
    Card content goes here.
  </p>
</div>
```

### Responsive Navigation

```html
<nav class="@container">
  <ul class="@md:flex-row @md:gap-6 flex flex-col gap-2">
    <li><a class="hocus:text-primary-500 text-gray-700" href="#">Home</a></li>
    <li><a class="hocus:text-primary-500 text-gray-700" href="#">About</a></li>
  </ul>
</nav>
```

## Performance Improvements

Tailwind v4 delivers significant build performance gains:

- Oxide engine written in Rust for faster scanning
- Incremental builds — only processes changed files
- Smaller CSS output via cascade layers (less duplication)
- No PostCSS dependency required for core functionality

## Migration from v3 to v4

### Configuration Changes

Replace `tailwind.config.js`:

```text
v3: module.exports = { theme: { extend: { colors: { brand: '#3b82f6' } } } }
v4: @theme { --color-brand: #3b82f6; }
```

### Import Changes

```css
/* v3 */
@tailwind base;
@tailwind components;
@tailwind utilities;

/* v4 */
@import "tailwindcss";
```

### Deprecated Utilities

- `bg-opacity-*` → use `bg-color/opacity` syntax
- `text-opacity-*` → use `text-color/opacity` syntax
- `ring-opacity-*` → use `ring-color/opacity` syntax

### Plugin Migration

```css
/* v3 plugin (JavaScript) */
/* plugin({ addUtilities }) => addUtilities({ '.content-auto': { 'content-visibility': 'auto' } }) */

/* v4 equivalent (CSS) */
@utility content-auto {
  content-visibility: auto;
}
```

## Anti-Patterns

- Do not use `tailwind.config.js` — use `@theme` in CSS
- Do not use `@apply` excessively — extract components instead
- Do not mix v3 opacity utilities with v4 slash syntax
- Do not skip cascade layers when adding custom CSS
- Do not use `@screen` directive — use container queries for component responsiveness

## Best Practices

- Define all design tokens in `@theme` for single source of truth
- Use container queries (`@container`) over media queries for components
- Leverage cascade layers for third-party CSS integration
- Use `oklch()` color space for perceptually uniform color palettes
- Prefer `@variant` for reusable state combinations
- Keep utility classes in HTML — minimize `@apply` usage
