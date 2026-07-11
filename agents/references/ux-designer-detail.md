# UX Designer — Detail Reference

## User Journey Template

- Every journey: user goal → key interactions → success state → error/recovery paths.
- Include emotional highs/lows; design to amplify positives and mitigate frustrations.
- Include paths for first-time users, returning users, error states, empty states.

## Wireframe Standards

- Mobile-first; breakpoints: `sm` (<640px), `md` (640–1024px), `lg` (>1024px).
- Visual hierarchy: primary action → secondary content → tertiary details.
- Spacing: 4px/8px base grid; minimum touch target 44×44px.
- Annotate: navigation flow, tab order, keyboard interaction on every wireframe.

## Component Spec Requirements

Every component must define: purpose, visual states (default/hover/focus/active/disabled/loading/error/empty), props/inputs, ARIA roles/labels/live regions, responsive behavior, keyboard interaction (Tab, Enter, Escape, Arrow keys).

## WCAG 2.1 AA Checklist

### Perceivable

- Color contrast: min 4.5:1 for normal text, 3:1 for large text.
- Never use color as sole conveyor of information.
- All images: meaningful `alt` text or `alt=""` for decorative.
- Non-text content: captions, transcripts, descriptions.

### Operable

- All functionality accessible via keyboard alone; no keyboard traps.
- Min touch target: 44×44px. Never smaller than 24×24px.
- Skip-navigation links on every page.
- Respect `prefers-reduced-motion`.

### Understandable

- Language set on `<html>` element.
- Error messages: identify the field, describe the error, suggest a fix.
- Consistent navigation and labeling across pages.

### Robust

- Valid HTML; ARIA used correctly and only when needed.
- Components tested with screen readers (NVDA, VoiceOver, JAWS).

## Nielsen's 10 Heuristics (Audit Reference)

1. Visibility of system status — keep users informed.
2. Match between system and real world — use familiar language.
3. User control and freedom — easy undo and redo.
4. Consistency and standards — follow platform conventions.
5. Error prevention — design out error-prone conditions.
6. Recognition rather than recall — minimize memory load.
7. Flexibility and efficiency of use — accelerators for expert users.
8. Aesthetic and minimalist design — remove irrelevant content.
9. Help users recognize, diagnose, and recover from errors.
10. Help and documentation — searchable, task-oriented help.

## GitHub Issue Filing (UX Findings)

```bash
gh issue create \
  --title "[UX] <short finding description>" \
  --label "ux,accessibility" \
  --body "## UX Finding

**Type:** <accessibility | usability | design-inconsistency | missing-state>
**WCAG Criterion:** <e.g., 1.4.3 Contrast (Minimum)>
**Severity:** <critical | high | medium | low>
**Heuristic Violated:** <e.g., H5: Error Prevention>

### Description
<what was found>

### Remediation
<specific fix>

### Acceptance Criteria
- [ ] <criterion>"
```
