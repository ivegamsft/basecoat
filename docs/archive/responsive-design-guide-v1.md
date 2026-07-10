# Basecoat Portal — Responsive Design Implementation Guide

## Overview

This guide details the responsive design strategy for the Basecoat Portal across all breakpoints (mobile, tablet, desktop, large).

---

## Breakpoints & Grid System

| Device | Width | Columns | Use Case |
|--------|-------|---------|----------|
| Mobile | 375px | 4 | Phones (iPhone SE) |
| Tablet | 768px | 8 | iPads, surface devices |
| Desktop | 1440px | 12 | Standard monitors |
| Large | 1920px+ | 12 | 4K displays, TV |

---

## Mobile (375px) — Touch-First Design

### Layout Strategy
- Single column layout
- Full-width content area
- Collapsed navigation (hamburger or bottom tab bar)
- Touch targets: 48×48px minimum
- Font: 16px base (prevents auto-zoom on iOS)

### Navigation Patterns
- Option 1: Hamburger menu → Slide drawer
- Option 2: Bottom tab bar (5 main sections)
- Recommended: Bottom tab bar for primary nav, hamburger for secondary

### Form Adaptations
- Full-width inputs
- Labels above inputs
- Single column for form fields
- Checkbox/radio groups stack vertically
- 16px font prevents iOS zoom

### Table Rendering
- Option 1: Card-based layout (rows as cards)
- Option 2: Horizontal scroll with sticky first column
- Recommended: Card layout for readability

### CSS Breakpoint
\\\css
@media (max-width: 640px) {
  /* Single column */
  .container { grid-template-columns: 1fr; }
  
  /* Sidebar hidden */
  nav { display: none; }
  
  /* Touch targets */
  button, input, .touch-target { min-height: 48px; }
  
  /* Forms full-width */
  input, select, textarea { width: 100%; }
  
  /* Tables as cards */
  table { display: block; }
  tbody tr { display: block; margin-bottom: var(--spacing-lg); border: 1px solid; }
}
\\\

---

## Tablet (768px) — Two-Column Layout

### Layout Strategy
- Sidebar shown by default (collapsible)
- Content area flexible width
- Two-column grids for metrics
- Touch targets still 48×48px

### Navigation
- Sidebar: 200px fixed
- Toggle button to collapse
- Navigation remains sticky during scroll

### Forms
- Two-column layouts where appropriate
- Multi-column checkbox/radio groups
- Optimized spacing

### CSS Breakpoint
\\\css
@media (min-width: 768px) and (max-width: 1024px) {
  /* Two-column grid */
  .grid { grid-template-columns: repeat(2, 1fr); }
  
  /* Sidebar visible */
  nav { width: 200px; display: block; }
  
  /* Two-column forms */
  .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: var(--spacing-md); }
}
\\\

---

## Desktop (1440px) — Three-Column Layout

### Layout Strategy
- Sidebar: 280px fixed width
- Content area: Flexible
- Optional right panel: 300px
- Optimal line length: 50-70 characters
- Touch targets still accessible (not reduced)

### Navigation
- Persistent sidebar with icons + labels
- Active item highlighted
- Hover states on navigation items

### Grids
- 3-column layouts for metric cards
- Full-width tables with horizontal scroll capability

### CSS Breakpoint
\\\css
@media (min-width: 1440px) {
  /* Three-column grid */
  .grid { grid-template-columns: repeat(3, 1fr); }
  
  /* Sidebar fixed */
  nav { width: 280px; position: sticky; top: 64px; }
  
  /* Main content max-width */
  main { max-width: 1000px; }
}
\\\

---

## Large (1920px+) — Optimized Spacing

### Layout Strategy
- Increased whitespace and padding
- Sidebar 280px fixed
- Content area max-width 1200px
- Right sidebar for dashboard context

### CSS Breakpoint
\\\css
@media (min-width: 1920px) {
  main { max-width: 1200px; margin: 0 auto; padding: var(--spacing-xl); }
  .grid { gap: var(--spacing-xl); }
  .card { padding: var(--spacing-xl); }
}
\\\

---

## Mobile-First CSS Architecture

Write CSS mobile-first, then enhance at larger breakpoints:

\\\css
/* Base mobile styles */
.card-grid { grid-template-columns: 1fr; }
.sidebar { display: none; }

/* Tablet and up */
@media (min-width: 768px) {
  .card-grid { grid-template-columns: repeat(2, 1fr); }
  .sidebar { display: block; }
}

/* Desktop and up */
@media (min-width: 1440px) {
  .card-grid { grid-template-columns: repeat(3, 1fr); }
}

/* Large screens */
@media (min-width: 1920px) {
  .card-grid { gap: var(--spacing-xl); }
}
\\\

---

## Responsive Components

### Metric Cards
- Mobile: Single column, full-width
- Tablet: 2-column grid
- Desktop: 3-4 column grid
- Large: 4-5 column grid with larger cards

### Tables
- Mobile: Card layout (each row = card)
- Tablet: Horizontal scroll with sticky header
- Desktop: Full table with pagination
- Large: Full table with optimized spacing

### Forms
- Mobile: Single column, full-width inputs
- Tablet: Two columns where appropriate
- Desktop: Multi-column, aligned labels
- Large: Centered layout with max-width

### Navigation
- Mobile: Hamburger or bottom tab bar
- Tablet: Collapsible sidebar
- Desktop: Persistent sidebar
- Large: Same as desktop with padding

---

## Accessibility in Responsive Design

### Touch Targets
- Minimum 44×44 CSS pixels (48×48 recommended)
- Maintain on all breakpoints
- Adequate spacing between targets

### Focus Indicators
- Visible on all devices
- 2px outline minimum
- 3px outline offset

### Zoom & Magnification
- Content must reflow without horizontal scroll at 200% zoom
- Text readable at large zoom levels
- All functionality available at any zoom level

### Keyboard Navigation
- Tab order follows logical reading sequence
- Focus visible on all interactive elements
- No keyboard traps

---

## Testing Responsive Design

### DevTools Testing
1. Open Chrome DevTools (F12)
2. Click Device Toolbar (Ctrl+Shift+M)
3. Select device or custom size
4. Test at: 375px, 768px, 1024px, 1440px, 1920px

### Manual Testing
- [ ] Mobile (iPhone SE 375px)
- [ ] Tablet (iPad 768px)
- [ ] Desktop (1440px)
- [ ] Large (1920px)
- [ ] Zoom 200% (no horizontal scroll)
- [ ] Landscape orientation
- [ ] Touch-only navigation (mobile)

### Screen Reader Testing (All Breakpoints)
- [ ] NVDA (Windows)
- [ ] JAWS (Windows)
- [ ] VoiceOver (Mac/iOS)

---

## Common Patterns

### Hero Section Responsive
\\\css
.hero {
  padding: var(--spacing-lg) var(--spacing-md); /* Mobile */
  text-align: center;
}

@media (min-width: 768px) {
  .hero { display: flex; gap: var(--spacing-lg); }
  .hero-content { flex: 1; text-align: left; }
  .hero-image { flex: 1; }
}

@media (min-width: 1440px) {
  .hero { gap: var(--spacing-xl); padding: var(--spacing-xl); }
}
\\\

### Sidebar Toggle Mobile
\\\javascript
const sidebarToggle = document.querySelector('.sidebar-toggle');
const sidebar = document.querySelector('nav');

sidebarToggle.addEventListener('click', () => {
  sidebar.classList.toggle('open');
  sidebarToggle.setAttribute('aria-expanded',
    sidebar.classList.contains('open'));
});
\\\

### Responsive Tables
\\\css
/* Mobile: Card layout */
@media (max-width: 768px) {
  table, thead, tbody, tr, td {
    display: block;
  }
  
  tr {
    margin-bottom: var(--spacing-lg);
    border: 1px solid var(--color-border);
  }
  
  td {
    text-align: right;
    padding-left: 50%;
    position: relative;
  }
  
  td::before {
    content: attr(data-label);
    position: absolute;
    left: 0;
    font-weight: 600;
  }
}

/* Desktop: Normal table */
@media (min-width: 768px) {
  table, thead, tbody, tr, td { display: table-*; }
}
\\\

---

## Performance Considerations

### Image Responsive
\\\html
<picture>
  <source media="(min-width: 1440px)" srcset="image-large.webp">
  <source media="(min-width: 768px)" srcset="image-medium.webp">
  <img src="image-small.webp" alt="Description">
</picture>
\\\

### CSS Media Queries
- Avoid too many breakpoints (3-4 maximum)
- Use logical breakpoints (device widths, not arbitrary)
- Consider mobile-first for performance

### JavaScript Responsive
\\\javascript
const mediaQuery = window.matchMedia('(min-width: 768px)');

function handleTabletChange(e) {
  if (e.matches) {
    // Tablet/Desktop logic
  } else {
    // Mobile logic
  }
}

mediaQuery.addEventListener('change', handleTabletChange);
\\\

---

## Verification Checklist

- [ ] Content reflows to single column at 375px
- [ ] Touch targets 48×48px minimum (mobile)
- [ ] Navigation clear on all breakpoints
- [ ] Tables readable on mobile (card layout or scroll)
- [ ] Forms accessible on all breakpoints
- [ ] Focus indicators visible on all breakpoints
- [ ] No horizontal scroll at 200% zoom
- [ ] Tested on real devices (not just DevTools)
- [ ] Keyboard navigation works on all breakpoints
- [ ] Screen readers work on all breakpoints

---

## End of Responsive Design Guide
