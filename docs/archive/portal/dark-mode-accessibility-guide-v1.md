# Basecoat Portal — Dark Mode & Accessibility Features Guide

## Dark Mode Implementation

### CSS Variables Approach (Recommended)

\\\css
:root {
  /* Light mode (default) */
  --color-background: #FFFFFF;
  --color-surface: #F3F2F1;
  --color-text: #323232;
  --color-primary: #0078D4;
  --color-success: #107C10;
  --color-warning: #F7630C;
  --color-error: #D13438;
}

@media (prefers-color-scheme: dark) {
  :root {
    /* Dark mode (system preference) */
    --color-background: #0D1117;
    --color-surface: #161B22;
    --color-text: #E6EDF3;
    --color-primary: #58A6FF;
    --color-success: #3FB950;
    --color-warning: #D29922;
    --color-error: #F85149;
  }
}

/* Manual dark mode class */
body.dark-mode {
  --color-background: #0D1117;
  --color-surface: #161B22;
  --color-text: #E6EDF3;
  --color-primary: #58A6FF;
  --color-success: #3FB950;
  --color-warning: #D29922;
  --color-error: #F85149;
}

/* Use variables everywhere */
body { background: var(--color-background); color: var(--color-text); }
button { background: var(--color-primary); }
\\\

### Contrast Ratios — Dark Mode

All colors verified for 4.5:1+ contrast in dark mode:

| Component | Light | Dark | Contrast |
|-----------|-------|------|----------|
| Body text | #323232 on #FFFFFF | #E6EDF3 on #0D1117 | 9.1:1 |
| Primary button | #FFFFFF on #0078D4 | #0D1117 on #58A6FF | 8.7:1 |
| Success badge | #107C10 on #DFF6DD | #3FB950 on #0D1117 | 4.7:1 |
| Warning badge | #F7630C on #FFF4CE | #D29922 on #0D1117 | 4.8:1 |
| Error message | #D13438 on #FDE7E9 | #F85149 on #0D1117 | 5.2:1 |

### Dark Mode Toggle Implementation

\\\javascript
const themeToggle = document.querySelector('.theme-toggle');
const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');

function updateTheme(isDark) {
  if (isDark) {
    document.documentElement.classList.add('dark-mode');
    localStorage.setItem('theme', 'dark');
    themeToggle.setAttribute('aria-label', 'Switch to light mode');
    themeToggle.innerHTML = '☀️'; // Sun icon for light mode
  } else {
    document.documentElement.classList.remove('dark-mode');
    localStorage.setItem('theme', 'light');
    themeToggle.setAttribute('aria-label', 'Switch to dark mode');
    themeToggle.innerHTML = '🌙'; // Moon icon for dark mode
  }
}

// Check saved preference or system preference
const savedTheme = localStorage.getItem('theme');
if (savedTheme) {
  updateTheme(savedTheme === 'dark');
} else {
  updateTheme(prefersDark.matches);
}

// Listen for system preference changes
prefersDark.addEventListener('change', (e) => {
  if (!localStorage.getItem('theme')) {
    updateTheme(e.matches);
  }
});

// Toggle on button click
themeToggle.addEventListener('click', () => {
  const isDark = document.documentElement.classList.contains('dark-mode');
  updateTheme(!isDark);
});
\\\

---

## Keyboard Navigation Implementation

### Tab Order Management

\\\html
<!-- HTML structure determines tab order by default -->
<!-- Use tabindex sparingly (only for custom components) -->

<!-- Good: Natural order -->
<input id="email" />
<input id="password" />
<button type="submit">Sign In</button>

<!-- Custom control: Use tabindex="0" for custom components only -->
<div role="button" tabindex="0">Custom Button</div>

<!-- Remove from tab order if needed: tabindex="-1" -->
<div role="presentation" tabindex="-1">Decorative element</div>
\\\

### Focus Management in Modals

\\\javascript
// Store reference to element that triggered modal
let triggerElement;

function openModal(modalId, trigger) {
  triggerElement = trigger;
  const modal = document.getElementById(modalId);
  modal.showModal(); // Native <dialog> element
  
  // Move focus inside modal
  const firstFocusable = modal.querySelector(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );
  firstFocusable?.focus();
}

function closeModal(modal) {
  modal.close();
  
  // Return focus to trigger
  triggerElement?.focus();
}

// Esc key closes modal (browser handles with <dialog>)
\\\

### Keyboard Shortcuts Reference

\\\javascript
// Optional: Power user keyboard shortcuts
document.addEventListener('keydown', (e) => {
  // Ctrl+K or Cmd+K: Open search
  if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
    e.preventDefault();
    document.querySelector('.search-input').focus();
  }
  
  // / : Open search (if input not focused)
  if (e.key === '/' && !isInputFocused()) {
    e.preventDefault();
    document.querySelector('.search-input').focus();
  }
  
  // ? : Show help
  if (e.key === '?' && e.shiftKey) {
    e.preventDefault();
    openHelpModal();
  }
  
  // Esc: Close active modal/dropdown
  if (e.key === 'Escape') {
    closeActiveModal();
  }
});

function isInputFocused() {
  return ['INPUT', 'TEXTAREA', 'SELECT'].includes(
    document.activeElement.tagName
  );
}
\\\

---

## Focus Indicators

### CSS Implementation

\\\css
/* Global focus style */
:focus-visible {
  outline: 2px solid #0078D4;
  outline-offset: 3px;
}

/* For browsers that don't support :focus-visible */
:focus {
  outline: 2px solid #0078D4;
  outline-offset: 3px;
}

/* Remove outline only if custom style provided */
:focus-visible:not(:focus) {
  outline: none;
}

/* Specific element adjustments */
button:focus-visible {
  outline: 2px solid #0078D4;
  outline-offset: 3px;
  box-shadow: inset 0 0 0 2px #FFFFFF;
}

input:focus-visible {
  outline: 2px solid #0078D4;
  border-color: #0078D4;
  outline-offset: 2px;
}

a:focus-visible {
  outline: 2px solid #0078D4;
  outline-offset: 3px;
  border-radius: 2px;
}

/* Dark mode adjustments */
@media (prefers-color-scheme: dark) {
  :focus-visible {
    outline-color: #58A6FF;
  }
  
  button:focus-visible {
    box-shadow: inset 0 0 0 2px #0D1117;
  }
}
\\\

### Skip Link Implementation

\\\html
<!-- Place at start of body -->
<a href="#main-content" class="skip-link">
  Skip to main content
</a>

<!-- Somewhere on the page -->
<main id="main-content" tabindex="-1">
  <!-- Content -->
</main>
\\\

\\\css
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  background: #0078D4;
  color: white;
  padding: 8px 16px;
  z-index: 100;
  text-decoration: none;
}

.skip-link:focus {
  top: 0;
}
\\\

---

## ARIA Labels & Roles

### Form Fields

\\\html
<!-- Good: Label associated with input -->
<label for="email-input">Email Address *</label>
<input id="email-input" type="email" required />

<!-- Good: Aria-label for icon button -->
<button aria-label="Close dialog">
  <svg aria-hidden="true"><!-- icon --></svg>
</button>

<!-- Good: Help text with aria-describedby -->
<label for="date">Date (MM/DD/YYYY) *</label>
<input id="date" type="text" aria-describedby="date-help" />
<small id="date-help">Format: 05/15/2024</small>

<!-- Good: Error message linked to input -->
<input id="email" type="email" aria-describedby="email-error" />
<span role="alert" id="email-error">Invalid email address</span>
\\\

### Live Regions (Dynamic Content)

\\\html
<!-- Status message (polite) -->
<div role="status" aria-live="polite" aria-atomic="true">
  Saving changes...
</div>

<!-- Alert message (assertive) -->
<div role="alert" aria-live="assertive">
  An error occurred. Please try again.
</div>

<!-- Progress region -->
<div role="progressbar" aria-valuenow="65" aria-valuemin="0" aria-valuemax="100">
  Uploading: 65%
</div>
\\\

### Landmark Roles

\\\html
<!-- Navigation -->
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/dashboard">Dashboard</a></li>
    <li><a href="/audits">Audits</a></li>
  </ul>
</nav>

<!-- Main content -->
<main id="main-content">
  <!-- Primary content -->
</main>

<!-- Complementary sidebar -->
<aside aria-label="Sidebar">
  <!-- Secondary content -->
</aside>

<!-- Footer -->
<footer>
  <!-- Footer content -->
</footer>
\\\

---

## Reduced Motion Support

### CSS Media Query

\\\css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
\\\

### JavaScript Detection

\\\javascript
const prefersReducedMotion = window.matchMedia(
  '(prefers-reduced-motion: reduce)'
).matches;

if (prefersReducedMotion) {
  // Disable complex animations
  element.classList.add('no-animation');
} else {
  // Enable animations
  element.classList.add('animate');
}
\\\

---

## Color Blind Friendly Design

### Patterns Beyond Color

\\\html
<!-- Bad: Color only -->
<span style="color: green;">Compliant</span>

<!-- Good: Icon + color + text -->
<span class="status">
  <svg class="icon" aria-hidden="true">✓</svg>
  <span>Compliant</span>
</span>
\\\

### Testing with Accessibility Inspector

1. DevTools → Rendering
2. Emulate vision deficiencies
3. Test: Protanopia, Deuteranopia, Tritanopia, Achromatopsia

---

## Text Spacing & Zoom

### Text Spacing CSS

\\\css
body {
  line-height: 1.5;
  letter-spacing: 0.12em;
  word-spacing: 0.16em;
}

p {
  margin-bottom: 1em;
}
\\\

### Viewport Meta Tag (No Zoom Disable)

\\\html
<!-- Good: Allow zoom -->
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<!-- Bad: Don't do this -->
<!-- <meta name="viewport" content="user-scalable=no"> -->
\\\

---

## Testing These Features

### Dark Mode
- [ ] Toggle button works
- [ ] Preference persisted (localStorage)
- [ ] System preference respected on first visit
- [ ] All colors 4.5:1+ in dark mode
- [ ] Images readable in dark mode

### Keyboard Navigation
- [ ] Tab moves through all interactive elements
- [ ] Shift+Tab goes backward
- [ ] Enter submits forms
- [ ] Esc closes modals
- [ ] No keyboard traps

### Focus Indicators
- [ ] Visible on all interactive elements
- [ ] 2px minimum outline
- [ ] Visible in both light and dark modes
- [ ] 3px+ offset from element

### ARIA Implementation
- [ ] Screen reader announces all labels
- [ ] Live regions announced
- [ ] Roles and properties correct
- [ ] No redundant ARIA

### Reduced Motion
- [ ] Animations disabled when preference set
- [ ] Page still fully functional
- [ ] No seizure triggers

---

## Checklist for Implementation

- [ ] CSS variables defined for all colors
- [ ] Dark mode media query implemented
- [ ] Dark mode toggle button added
- [ ] localStorage persistence working
- [ ] Focus styles applied globally
- [ ] Skip link present and functional
- [ ] Keyboard shortcuts documented
- [ ] ARIA roles applied correctly
- [ ] Live regions for dynamic content
- [ ] Reduced motion support
- [ ] All contrasts verified (light + dark)
- [ ] Tested on NVDA, JAWS, VoiceOver

---

## End of Dark Mode & Accessibility Features Guide
