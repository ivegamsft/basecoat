# Basecoat Portal — Accessibility Testing Guide

## Quick Start

This guide walks through testing the portal for WCAG 2.1 AA compliance using automated tools and manual testing.

---

## Part 1: Automated Testing

### 1.1 Lighthouse Accessibility Audit

1. Open Basecoat Portal in Chrome
2. Open DevTools (F12)
3. Go to Lighthouse tab
4. Select "Accessibility"
5. Click "Analyze page load"

**Target**: Score ≥ 90/100

**Expected Results**:
- All images have alt text
- Background and foreground colors have sufficient contrast ratio
- Form elements have associated labels
- Page has heading structure
- Links have descriptive names

### 1.2 axe DevTools Browser Extension

1. Install axe DevTools (free)
2. Open portal page
3. Click axe extension icon
4. Click "Scan ALL of my page"

**Target**: 0 Violations, 0 Warnings

**Categories to Check**:
- Color contrast
- Form labels
- Alt text
- ARIA roles
- Keyboard accessibility

### 1.3 Command Line Testing

\\\ash
# Install dependencies
npm install --save-dev jest @axe-core/react jest-axe

# Run automated tests
npm run test:a11y

# Check color contrast
npm run test:contrast

# Keyboard navigation test
npm run test:keyboard
\\\

---

## Part 2: Manual Testing — Keyboard Navigation

### 2.1 Full Keyboard Test Path

**Setup**: Disconnect mouse, use only keyboard

**Test Path: Login → Dashboard → Submit Audit**

1. **Tab through login form**
   - First Tab: "Skip to main content" link highlighted
   - Second Tab: Email input focused (visible outline)
   - Type: "user@company.com"
   - Tab: Password input focused
   - Type: "password123"
   - Tab: "Sign In" button focused
   - Press Enter: Form submits

2. **Dashboard loads**
   - Focus should move to main content or first interactive element
   - Tab through navigation items
   - Verify focus order: Sidebar → Cards → Table → Buttons

3. **Table Navigation**
   - Tab focuses first table cell
   - Arrow Right/Down: Move between cells
   - Arrow Up/Left: Move backwards
   - All sortable headers keyboard accessible

4. **Modal Interaction**
   - Tab to "Submit Audit" button
   - Press Enter: Modal opens
   - Tab: Focus moves inside modal
   - Tab: Cycles through form fields
   - Tab: Reaches "Submit" and "Cancel" buttons
   - Press Esc: Modal closes, focus returns to button

**Success Criteria**:
- [x] Tab moves focus to all interactive elements
- [x] Shift+Tab moves backwards
- [x] Enter submits forms
- [x] Esc closes modals
- [x] Arrow keys navigate menus/tables
- [x] No keyboard traps

### 2.2 Focus Indicator Verification

**For each interactive element:**
- [x] Tab to element → Focus outline visible (2px min)
- [x] Outline is #0078D4 or equivalent high-contrast color
- [x] Outline has 3px offset from element edge
- [x] Outline doesn't disappear during interaction

### 2.3 Skip Link Test

1. Open any page
2. Press Tab immediately
3. "Skip to main content" link should appear at top-left
4. Press Enter
5. Focus moves to \#main-content\ element
6. Tab again skips past navigation directly to content

---

## Part 3: Manual Testing — Screen Readers

### 3.1 NVDA Testing (Windows, Free)

**Installation**:
1. Download from https://www.nvaccess.org/
2. Run installer
3. Restart computer (required)

**Basic Commands**:
- Insert+N: Start/stop NVDA
- Insert+Right Arrow: Read next item
- Insert+Left Arrow: Read previous item
- Insert+H: Announce heading information
- Insert+T: Read table information
- T: Jump to next table
- H: Jump to next heading
- F: Jump to next form field

**Test Path: Login Page**

1. Start NVDA (Insert+N)
2. Hear: "Mozilla Firefox, window"
3. Tab: "Skip to main content, link"
4. Tab: "Basecoat Portal, link"
5. Tab: "Search, search, edit text"
6. Tab: "Sign in with email, button" or similar
7. Tab: "Email, required, edit text"
   - Verify: Screen reader announces "required" and "edit text"
8. Type email: NVDA reads characters as typed
9. Tab: "Password, password, required, edit text"
   - Verify: Type doesn't show characters (password field)
10. Tab: "Sign in, button"
11. Enter: Form submits (NVDA announces success or error)

**Expected NVDA Announcements**:
- Page title
- Headings with level (h1, h2, etc.)
- Form labels with input type
- Button names
- Alert messages
- Table structure

### 3.2 VoiceOver Testing (Mac/iOS)

**Mac Setup**:
1. System Preferences → Accessibility → VoiceOver
2. Toggle ON (or Cmd+F5)

**iOS Setup**:
1. Settings → Accessibility → VoiceOver
2. Toggle ON

**Basic Gestures (Mac)**:
- VO+Right Arrow: Move to next item
- VO+Left Arrow: Move to previous item
- VO+Up/Down: Jump to headings
- VO+Space: Activate item

**Test Path (Same as NVDA)**

**Expected Announcements**:
- Page structure and landmarks
- Form labels and required status
- Button purposes
- Dynamic content updates

### 3.3 Screen Reader Checklist

For each page tested:
- [ ] Page title announced clearly
- [ ] Navigation structure clear
- [ ] Headings in logical order (h1, h2, h3)
- [ ] Form labels associated with inputs
- [ ] Buttons announce their purpose
- [ ] All images have alt text
- [ ] Error messages announced clearly
- [ ] Success messages announced
- [ ] Tables have proper th/td structure
- [ ] Links have descriptive text

---

## Part 4: Color Contrast Verification

### 4.1 WebAIM Contrast Checker

1. Go to https://webaim.org/resources/contrastchecker/
2. For each text element:
   - Get foreground color (text)
   - Get background color
   - Enter both in checker
   - Verify ratio ≥ 4.5:1

**Quick Checklist of Elements to Test**:
- [ ] Body text on white background
- [ ] Headings on white background
- [ ] Button text on button background
- [ ] Links on white background
- [ ] Error text on error background
- [ ] Success text on success background
- [ ] Form labels
- [ ] Placeholder text

### 4.2 Command Line Contrast Check

\\\ash
npm run test:contrast
# Output: ✓ All text meets 4.5:1 requirement
\\\

---

## Part 5: Zoom & Reflow Testing

### 5.1 Desktop Zoom Test (Chrome DevTools)

1. Open portal page
2. Press Ctrl+Scroll wheel to zoom
3. Zoom to 200% (or Ctrl++ multiple times)
4. Verify:
   - [ ] No horizontal scroll bar
   - [ ] All content visible and readable
   - [ ] Links still clickable
   - [ ] Buttons still operable
   - [ ] Form inputs visible

### 5.2 Mobile Zoom Test (iOS)

1. Open portal on iPhone
2. Pinch zoom to 200%
3. Verify same as above

### 5.3 Responsive Breakpoint Test

1. DevTools → Device Toolbar (Ctrl+Shift+M)
2. Test each breakpoint:
   - [ ] 375px (Mobile)
   - [ ] 768px (Tablet)
   - [ ] 1024px (Small Desktop)
   - [ ] 1440px (Desktop)
   - [ ] 1920px (Large)
3. Verify:
   - [ ] Layout reflows properly
   - [ ] Touch targets 48×48px (mobile)
   - [ ] Text readable
   - [ ] Navigation clear

---

## Part 6: Motion & Animation Testing

### 6.1 Prefers Reduced Motion Test

1. Open DevTools
2. Command Palette (Ctrl+Shift+P on Windows, Cmd+Shift+P on Mac)
3. Type "rendering"
4. Select "Show Rendering"
5. Check "Emulate CSS media feature prefers-reduced-motion"
6. Set to "reduce"
7. Verify:
   - [ ] All animations stop or are minimal
   - [ ] Transitions removed
   - [ ] Page still fully functional
   - [ ] No motion sickness triggers

---

## Part 7: Form Validation Testing

### 7.1 Required Fields

1. Leave required field empty
2. Try to submit form
3. Verify:
   - [ ] Error message appears
   - [ ] Error message links to field
   - [ ] Field outline highlights in error color
   - [ ] Error announced by screen reader

### 7.2 Invalid Input

1. Enter invalid email: "notanemail"
2. Tab out or submit
3. Verify:
   - [ ] Clear error message appears
   - [ ] Message suggests fix: "Must include @"
   - [ ] Field highlighted
   - [ ] Can correct and resubmit

### 7.3 Success Confirmation

1. Fill out form correctly
2. Submit
3. Verify:
   - [ ] Success message appears
   - [ ] Message readable by screen reader
   - [ ] Auto-dismisses after 5+ seconds
   - [ ] User can manually dismiss

---

## Testing Checklist — Full Portal

### Navigation & Structure
- [ ] Skip link works
- [ ] Page title unique and descriptive
- [ ] Headings in correct hierarchy
- [ ] Landmarks present (nav, main, aside, footer)

### Forms & Inputs
- [ ] All inputs have labels
- [ ] Required fields marked clearly
- [ ] Error messages specific and linked
- [ ] Focus visible on all inputs
- [ ] All operable via keyboard

### Tables
- [ ] Proper semantics (thead, tbody, th)
- [ ] Headers identified
- [ ] Sortable via keyboard
- [ ] Readable at 200% zoom

### Color & Contrast
- [ ] All text 4.5:1 contrast
- [ ] Status indicated by more than color
- [ ] Focus indicators visible
- [ ] Dark mode contrasts also 4.5:1

### Keyboard
- [ ] All functionality via keyboard
- [ ] Logical tab order
- [ ] No keyboard traps
- [ ] Esc closes modals
- [ ] Enter submits forms

### Responsive
- [ ] Mobile 375px: single column, readable
- [ ] Tablet 768px: two columns
- [ ] Desktop 1440px: three columns
- [ ] 200% zoom: no horizontal scroll
- [ ] Touch targets 48×48px

### Screen Readers
- [ ] NVDA: All content announced
- [ ] JAWS: All structure clear
- [ ] VoiceOver: Mac/iOS compatible

### Motion
- [ ] Animations respect prefers-reduced-motion
- [ ] No flashing > 3x/second
- [ ] No seizure triggers

---

## Weekly Testing Schedule

**Monday**: Automated testing (Lighthouse, axe)
**Tuesday**: Keyboard navigation test
**Wednesday**: Screen reader test (NVDA)
**Thursday**: Color contrast & responsive
**Friday**: Full user journey with all tools

---

## Issue Reporting Template

When you find an accessibility issue, file it with:

\\\markdown
## Title: [CRITICAL/HIGH/MEDIUM/LOW] Accessibility Issue: [Brief description]

### Category
- Perceivable / Operable / Understandable / Robust

### Severity
- Critical: Blocks all users
- High: Significantly limits access
- Medium: Minor inconvenience
- Low: Nice to have

### Steps to Reproduce
1. [Step 1]
2. [Step 2]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Screenshots
[Attach if applicable]

### Environment
- Browser: [Chrome/Firefox/Safari]
- Screen Reader: [NVDA/JAWS/VoiceOver]
- Breakpoint: [Mobile 375px / Tablet 768px / Desktop 1440px]

### WCAG Criterion
[e.g., 1.4.3 Contrast (Minimum)]
\\\

---

## End of Accessibility Testing Guide
