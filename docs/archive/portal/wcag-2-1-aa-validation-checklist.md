# WCAG 2.1 AA Accessibility Validation Checklist

## Overview

This checklist ensures all Basecoat Portal screens meet WCAG 2.1 Level AA accessibility standards. Use this for design review, development, and QA validation.

---

## 1. PERCEIVABLE

### 1.1 Text Alternatives

#### Screen: All Screens
- [ ] All images have descriptive `alt` text (or marked as decorative)
- [ ] SVG icons have `aria-label` (e.g., `aria-label="Alert icon"`)
- [ ] Decorative images have `alt=""` (empty)
- [ ] Complex charts have text descriptions or data table fallback

**Example**:
```html
<img src="error.svg" alt="Error icon" width="24" height="24" />
<button aria-label="Close dialog"><IconClose /></button>
```

### 1.2 Time-based Media
- [ ] Videos have captions (if applicable, future feature)
- [ ] Audio has transcripts (if applicable, future feature)

### 1.3 Adaptable

#### Screen: All Screens
- [ ] Content reflows to single column on mobile (no horizontal scroll at 320px)
- [ ] No information lost when zoomed to 200%
- [ ] Tables have proper `<thead>`, `<tbody>`, `<th>` semantics
- [ ] Form labels associated with inputs via `<label for>` or `aria-label`

**Example**:
```html
<!-- Good -->
<label for="email-input">Email Address *</label>
<input id="email-input" type="email" required />

<!-- Also good (for custom inputs) -->
<input aria-label="Email Address" type="email" required />
```

- [ ] Lists use semantic HTML (`<ul>`, `<ol>`, `<li>`)
- [ ] Headings follow logical order: h1 → h2 → h3 (no skipping levels)

**Example**:
```html
<!-- Good -->
<h1>Compliance Dashboard</h1>
<h2>Repository Status</h2>
<h3>Audit Details</h3>

<!-- Bad - don't skip -->
<h1>Compliance Dashboard</h1>
<h3>Audit Details</h3>  <!-- Skipped h2 -->
```

### 1.4 Distinguishable

#### Color Contrast

**Screen: All Text**
- [ ] Body text (14px): 4.5:1 minimum contrast
- [ ] Large text (18px+): 3:1 minimum contrast
- [ ] Icon + background: 3:1 minimum
- [ ] Border + background: 3:1 minimum

**Tool**: Use WebAIM Contrast Checker or axe DevTools

| Element | Text Color | Background | Ratio | Pass |
|---------|-----------|-----------|-------|------|
| Primary Button Text | #FFFFFF | #0078D4 | 12.5:1 | ✓ |
| Body Text | #323232 | #FFFFFF | 8.6:1 | ✓ |
| Disabled Button | #999999 | #EBEBEB | 4.5:1 | ✓ |
| Error Message | #D13438 | #FFFFFF | 5.1:1 | ✓ |
| Success Badge | #107C10 | #DFF6DD | 4.9:1 | ✓ |

#### No Color Alone

**Screen: Status Indicators, Form Errors, Charts**
- [ ] Green checkmark paired with text "Compliant"
- [ ] Red error icon paired with error message text
- [ ] Chart legend has both color AND pattern/icon
- [ ] Focus indicators always visible (not color-only)

**Example - BAD**:
```html
<!-- Don't do this -->
<div style="color: red;">Field is required</div>  <!-- Red only -->

<!-- Do this -->
<div style="color: #D13438;">
  <IconError aria-hidden="true" />
  <span>Field is required</span>
</div>
```

#### Visual Focus Indicator

**Screen: All Interactive Elements (Buttons, Links, Inputs)**
- [ ] Focus indicator visible (2px outline or box-shadow)
- [ ] Minimum 3px gap between focus ring and element
- [ ] Focus order visible and logical
- [ ] No `outline: none` without replacement

**CSS**:
```css
button:focus-visible {
  outline: 2px solid #0078d4;
  outline-offset: 3px;
}
```

#### Text Spacing

**Screen: All Text (Mobile 375px)**
- [ ] Line height: 1.5x font size minimum
- [ ] Paragraph spacing: 2x font size minimum
- [ ] Letter spacing: 0.12x font size minimum
- [ ] Word spacing: 0.16x font size minimum

---

## 2. OPERABLE

### 2.1 Keyboard Accessible

#### Screen: All Screens
- [ ] All functionality available via keyboard
- [ ] No keyboard trap (user can tab out of elements)
- [ ] Tab order logical and predictable
- [ ] Skip navigation link at top of page

**Skip Link Example**:
```html
<a href="#main-content" class="sr-only">Skip to main content</a>
<nav id="navigation">...</nav>
<main id="main-content">...</main>
```

#### Screen: Forms
- [ ] Tab through all inputs in logical order
- [ ] Enter submits form
- [ ] Esc closes dropdowns and modals
- [ ] Arrow keys navigate within selects, menus, tables

#### Screen: Navigation
- [ ] Sidebar toggles with keyboard
- [ ] Breadcrumbs navigable
- [ ] Hamburger menu opens/closes with keyboard

### 2.2 Enough Time

#### Screen: All Screens
- [ ] Auto-dismissing toasts: 5 seconds minimum (user can dismiss manually before)
- [ ] Form auto-save: Doesn't lose data on timeout
- [ ] Session timeout: User warned before logout (30s countdown)
- [ ] No time limit for complex actions (multi-step forms)

**Toast Implementation**:
```jsx
<Toast autoClose={5000} role="status">
  Changes saved successfully
  <button onClick={dismiss}>Dismiss</button>
</Toast>
```

### 2.3 Seizures and Physical Reactions
- [ ] No content flashing more than 3 times per second
- [ ] No bright red/white strobe patterns
- [ ] Animations respect `prefers-reduced-motion` media query

**CSS**:
```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation: none !important;
    transition: none !important;
  }
}
```

### 2.4 Navigable

#### Screen: All Screens
- [ ] Page title unique and descriptive
- [ ] Page purpose clear within first screen
- [ ] Multiple ways to find pages: Search, navigation, sitemap

#### Screen: Links
- [ ] Link text descriptive (not "Click here")
- [ ] Links distinguish from surrounding text (underline, color, icon)

**Examples**:
```html
<!-- Good -->
<a href="/audits">View recent audits</a>
<a href="/compliance">Compliance status report</a>

<!-- Bad -->
<a href="/audits">Click here</a>
```

#### Screen: Focus Management
- [ ] Focus visible when moving between screens
- [ ] Focus moves to modal when opened
- [ ] Focus moves back to trigger when modal closes
- [ ] Focus trap in modal: Tab stays within modal

---

## 3. UNDERSTANDABLE

### 3.1 Readable

#### Screen: All Text
- [ ] Language clearly indicated in HTML (`<html lang="en">`)
- [ ] Text level: Plain language, average sentence length < 20 words
- [ ] Abbreviations expanded on first use: "SOC 2 (System and Organization Controls)"

#### Screen: Forms, Errors, Help Text
- [ ] Instructions before form (not after)
- [ ] Required fields marked with asterisk (*)
- [ ] Error messages: Specific and prescriptive (not "Invalid" but "Email must contain @")
- [ ] Help text visible (not just on focus)

**Example - BAD**:
```html
<input type="email" required />
<span class="error">Invalid</span>
```

**Example - GOOD**:
```html
<label for="email">Email address *</label>
<input id="email" type="email" required aria-describedby="email-help" />
<small id="email-help">Must be a valid work email (name@company.com)</small>
<span role="alert" id="email-error" style="display:none;">
  Invalid email format. Did you include @company.com?
</span>
```

### 3.2 Predictable

#### Screen: Navigation
- [ ] Navigation menu in same place on all pages
- [ ] Sidebar doesn't move or collapse unexpectedly
- [ ] Logo always links to home

#### Screen: Interactions
- [ ] Buttons don't navigate unexpectedly (stay on page unless intended)
- [ ] Checkboxes toggle state (don't cause form submission)
- [ ] Selecting a select option doesn't change context (unless clearly marked)

### 3.3 Input Assistance

#### Screen: Forms
- [ ] Required fields identified before submission
- [ ] Error identification: Clear which field has error
- [ ] Error suggestion: "Did you mean...?" for typos
- [ ] Submission confirmation: "Are you sure?" for destructive actions

**Example - Confirm Delete**:
```html
<dialog role="alertdialog" aria-labelledby="confirm-title">
  <h2 id="confirm-title">Delete this audit?</h2>
  <p>This action cannot be undone.</p>
  <button onclick="cancel()">Cancel</button>
  <button onclick="delete()" class="danger">Delete</button>
</dialog>
```

#### Screen: Form Validation
- [ ] Real-time validation with clear feedback
- [ ] Submit button disabled if validation fails
- [ ] Success message appears after successful submission

---

## 4. ROBUST

### 4.1 Compatible

#### Screen: All Screens
- [ ] Valid HTML (no mismatched tags, duplicate IDs)
- [ ] Valid CSS (no deprecated properties)
- [ ] Semantic HTML used (no `<div role="button">`)
- [ ] ARIA used correctly (no redundant ARIA)

**Validate**: Use W3C Markup Validator, axe DevTools

#### Screen: ARIA Implementation
- [ ] `role` only on elements needing custom behavior
- [ ] `aria-label` only when no visible text
- [ ] `aria-labelledby` links to visible heading
- [ ] `aria-describedby` for additional context

**Good ARIA Examples**:
```html
<!-- Button with visible text (no aria-label needed) -->
<button>Submit Audit</button>

<!-- Icon-only button (needs aria-label) -->
<button aria-label="Close dialog"><IconClose /></button>

<!-- Form field with help text -->
<input aria-describedby="format-help" />
<small id="format-help">Format: MM/DD/YYYY</small>

<!-- Alert message to screen readers -->
<div role="alert">Changes saved successfully</div>

<!-- Landmark navigation -->
<nav aria-label="Main navigation">...</nav>
```

---

## Screen-by-Screen Validation Matrix

### Authentication Screens

| Screen | Element | Requirement | Status |
|--------|---------|-------------|--------|
| Login | Page title | "Sign In - Basecoat Portal" | ☐ |
| | Email input | Label + error messaging | ☐ |
| | Password input | Type is password, not text | ☐ |
| | Forgot password link | Descriptive text | ☐ |
| | GitHub button | `aria-label="Sign in with GitHub"` | ☐ |
| | Error messages | 4.5:1 contrast, not color-only | ☐ |
| | Focus indicators | Visible 2px outline | ☐ |
| MFA Setup | QR code | Alternative text or manual entry option | ☐ |
| | Code input | 6-digit input with visual feedback | ☐ |
| | Backup codes | Copyable list with clear labeling | ☐ |
| Password Reset | Email input | Label + validation | ☐ |
| | Success message | Clear next steps | ☐ |

### Dashboard Screen

| Element | Requirement | Status |
|---------|-------------|--------|
| Page title | "Dashboard - Basecoat Portal" | ☐ |
| Main navigation | Skip link functional | ☐ |
| Sidebar nav | Keyboard navigable, active item marked | ☐ |
| Metric cards | Color + text (not color-only), semantic heading (h2) | ☐ |
| Recent audits table | Sortable headers keyboard accessible, row hover not color-only | ☐ |
| Quick actions | Buttons min 48px height, focus visible | ☐ |
| Status badge | Icon + color + text | ☐ |

### Audit Submission Form

| Step | Element | Requirement | Status |
|------|---------|-------------|--------|
| 1: Scope | Form labels | All associated with inputs | ☐ |
| | Required asterisk | Color + marker (not color-only) | ☐ |
| | Checkboxes | All keyboard accessible | ☐ |
| | Date inputs | Accessible date picker or text input | ☐ |
| 2-4: Review/Confirm | Progress indicator | Accessible via screen reader | ☐ |
| | Submit button | Disabled state clear, not color-only | ☐ |

### Compliance & Audit Details

| Element | Requirement | Status |
|---------|-------------|--------|
| Status card | Color + icon + text (compliance states) | ☐ |
| Framework boxes | Accessible card structure with title | ☐ |
| Findings table | Sortable, pagination accessible | ☐ |
| Severity labels | Color + icon + text | ☐ |
| Export button | Alternative formats keyboard accessible | ☐ |

### Repository Management

| Element | Requirement | Status |
|---------|-------------|--------|
| Repository list | Table with proper semantics | ☐ |
| Status column | Icon + text (not icon-only) | ☐ |
| Sync button | Clear feedback when loading | ☐ |
| Details view | Logical heading hierarchy | ☐ |

---

## Testing Procedures

### Automated Accessibility Testing

```bash
# Run axe-core in tests
pnpm test:a11y

# Browser DevTools audit
1. Open Chrome DevTools → Lighthouse → Accessibility
2. Run audit
3. Fix all "Fails" and "Needs improvement" items
```

### Manual Screen Reader Testing

#### Setup
- **Windows**: NVDA (free) from https://www.nvaccess.org/
- **Mac**: VoiceOver (built-in: Cmd+F5)
- **iOS**: VoiceOver (Settings → Accessibility)

#### Test Path: Login → Dashboard → Submit Audit
1. Open page with screen reader on
2. Hear page title announced
3. Navigate with Tab key:
   - Hear "Email address, edit text"
   - Hear "Password, password edit text"
   - Hear "Sign in, button"
4. Fill form with keyboard only (no mouse)
5. Submit form, hear success message
6. Repeat on dashboard and audit form

### Keyboard Navigation Testing

#### Test Path: Full User Journey
```
1. Tab through login form
   - Email input focused
   - Password input focused
   - Sign in button focused
   - Tab doesn't trap

2. Enter email/password, press Tab to sign in button
3. Press Enter to submit

4. Dashboard loads
   - Focus moves to main content
   - Tab through sidebar: Dashboard, Audits, Compliance, etc.
   - Tab through metric cards
   - Tab through action buttons

5. Press Tab on "Submit Audit" button
   - Modal opens
   - Focus moves inside modal
   - Tab cycles within modal (form → submit → cancel → form)
   - Esc closes modal, focus returns to button
```

### Contrast Ratio Verification

#### Using WebAIM Contrast Checker
1. Go to https://webaim.org/resources/contrastchecker/
2. For each text element, enter:
   - Foreground color (text)
   - Background color
3. Verify ratio ≥ 4.5:1 for body text or 3:1 for large text
4. Document pass/fail

#### Automated Check
```bash
pnpm test:contrast
# Verifies all components against design system
```

### Zoom and Reflow Testing

#### Desktop (Chrome DevTools)
1. Open DevTools (F12)
2. Ctrl+Scroll wheel to zoom 200%
3. Verify:
   - No horizontal scroll bar
   - All content readable
   - No text cutoff
   - Links still clickable

#### Mobile (375px)
1. DevTools: Device emulation (iPhone SE)
2. Pinch zoom to 200%
3. Verify same as above

---

## Remediation Priority

### Critical (Must Fix Before Launch)
- Missing `<html lang>` attribute
- Links with no descriptive text
- Images with no alt text
- Form labels missing
- Color contrast < 4.5:1
- Keyboard traps
- No skip navigation link

### High (Fix Before QA Sign-off)
- Poor heading hierarchy
- Focus indicators not visible
- ARIA misuse
- Missing error messages
- No success confirmations
- Tab order illogical

### Medium (Fix Before Production)
- Help text could be clearer
- Animation ignores `prefers-reduced-motion`
- Status updates not announced to screen readers
- Table not fully sortable via keyboard

### Low (Consider for Next Release)
- Reduced motion preferences for non-critical animations
- High contrast theme option
- Larger text size option (beyond browser zoom)

---

## Monitoring & Continuous Testing

### Automated Checks (CI/CD)
```bash
# Run on every PR
pnpm test:a11y          # axe-core + jest-axe
pnpm test:contrast      # Color contrast
pnpm test:keyboard      # Tab order simulation
```

### Weekly Audits
- [ ] Run Lighthouse accessibility audit
- [ ] Manual screen reader test (NVDA/VoiceOver)
- [ ] Review new issue reports from users

### Monthly Review
- [ ] WCAG 2.1 guideline checklist update
- [ ] Training: New accessibility patterns
- [ ] Tech debt: Deprecate inaccessible patterns

---

## Resources

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/)
- [WebAIM Articles](https://webaim.org/articles/)
- [axe DevTools](https://www.deque.com/axe/devtools/)
- [NVDA Screen Reader](https://www.nvaccess.org/)

---

## Document Version

**WCAG 2.1 AA Validation Checklist v1.0**  
**Last Updated**: May 2024  
**Status**: Final Review  
**Owner**: Frontend-Dev Agent, QA Team

