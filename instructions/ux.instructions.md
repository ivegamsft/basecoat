---
description: "Use when working on user experience, interface design, accessibility, component specifications, or user journey mapping. Covers design system reference, WCAG compliance, naming conventions, handoff format, and journey standards."
applyTo: "**/*.{tsx,jsx,html,css,scss,vue,svelte,astro},docs/ux/**,docs/design-system.md"
---

# UX Standards

Use this instruction for any work that defines, evaluates, or modifies user-facing experiences, component specifications, or interaction patterns.

## Design System Reference

- Every project must designate a design system as the single source of truth for visual and interaction patterns. Document the chosen system in the project README or in `docs/design-system.md`.
- Do not invent custom components when the design system provides an equivalent. Deviations require a documented rationale reviewed by the ux agent.
- Reference design tokens (colors, spacing, typography scales) by their token names — never by raw values. This ensures theme consistency and makes updates propagate automatically.
- When the design system lacks a needed pattern, propose the addition through the design system's contribution process. Until accepted, document the interim pattern in `docs/design-system.md` with a clear label: `[Interim — pending design system inclusion]`.

## Accessibility Minimum Bar

All user-facing work must meet **WCAG 2.1 Level AA** as the non-negotiable baseline.

### Required Checks

- **Color contrast:** Text and interactive elements must meet minimum contrast ratios (4.5:1 for normal text, 3:1 for large text and UI components).
- **Keyboard navigation:** Every interactive element must be operable with keyboard alone. Focus order must follow a logical reading sequence.
- **Screen reader support:** All images have meaningful `alt` text or are marked decorative. All form inputs have associated labels. Dynamic content changes are announced via ARIA live regions.
- **Motion and animation:** Respect `prefers-reduced-motion`. No content relies solely on animation to convey meaning.
- **Zoom and reflow:** Content must be usable at 200% zoom without horizontal scrolling on standard viewport widths.
- **Touch targets:** Interactive elements must have a minimum target size of 44×44 CSS pixels.

### Accessibility Review

- Run automated accessibility checks (axe-core or equivalent) before any PR that modifies UI.
- Automated checks catch roughly 30–40% of issues. Manual testing with keyboard navigation and a screen reader is required for new workflows or significant UI changes.
- File accessibility issues with the labels `accessibility` and the relevant tier label (`frontend`). Accessibility issues are treated as bugs, not enhancements.

## Component Naming Conventions

- Use **PascalCase** for component names: `UserProfileCard`, `NavigationSidebar`, `OrderSummaryTable`.
- Prefix shared or design-system components with the system abbreviation if the project uses multiple component sources (e.g., `DsButton`, `DsModal`).
- Name components by what they represent, not how they are implemented: `UserAvatar` not `CircleImage`, `SearchResults` not `FilteredList`.
- Variant names use a consistent suffix pattern: `ButtonPrimary`, `ButtonSecondary`, `ButtonDanger`.
- State-specific variants use a clear state suffix: `CardLoading`, `CardError`, `CardEmpty`.

### File Naming

- One component per file. The file name matches the component name.
- Co-locate component styles, tests, and stories in the same directory:

```
components/
  UserProfileCard/
    UserProfileCard.tsx
    UserProfileCard.test.tsx
    UserProfileCard.module.css
    UserProfileCard.stories.tsx
```

## Handoff Format to Frontend-Dev Agent

When the ux agent hands off a design to the **frontend-dev agent**, the handoff must include:

### Required Handoff Artifacts

| Artifact | Format | Description |
|----------|--------|-------------|
| Component specification | Markdown in `docs/ux/specs/` | Layout, spacing, typography, responsive breakpoints, and interaction states |
| Visual reference | Screenshot or Figma link | Annotated mockup showing the target appearance |
| Interaction states | Table or state diagram | Every state the component can be in: default, hover, focus, active, disabled, loading, error, empty |
| Accessibility notes | Section in the spec | Required ARIA roles, keyboard behavior, screen reader announcements |
| Design tokens used | List of token names | All tokens referenced so the frontend-dev agent uses the correct values |
| Content examples | Real or realistic sample data | Representative content showing minimum, typical, and maximum-length cases |

### Handoff Rules

- The ux agent must not hand off a component without documenting all interaction states. Missing states cause implementation gaps and rework.
- The frontend-dev agent may push back on a handoff that lacks required artifacts. Incomplete handoffs return to the ux agent for completion.
- If a design deviates from the design system, the handoff must include the rationale and a reference to the interim pattern documentation.
- Responsive behavior must be specified for at least three breakpoints: mobile (≤ 640px), tablet (641–1024px), and desktop (> 1024px).

## User Journey Mapping Standards

### When to Create a Journey Map

- Any new feature that introduces a multi-step workflow.
- Any change that modifies the sequence of steps a user follows to complete a task.
- Any feature with more than one entry point or branching path.

### Journey Map Format

Store journey maps in `docs/ux/journeys/` as Markdown files with embedded Mermaid diagrams.

Each journey map must include:

| Section | Content |
|---------|---------|
| **Goal** | What the user is trying to accomplish |
| **Actor** | Who the user is (persona or role) |
| **Entry points** | How the user arrives at this journey |
| **Steps** | Numbered sequence of user actions and system responses |
| **Decision points** | Where the journey branches based on user choice or system state |
| **Error paths** | What happens when something goes wrong at each step |
| **Success criteria** | How we know the user achieved their goal |
| **Diagram** | Mermaid flowchart showing the journey with decision points and error paths |

### Journey Map Example Structure

```markdown
# Journey: <Name>

## Goal
<What the user wants to accomplish>

## Actor
<User persona or role>

## Entry Points
- <Entry point 1>
- <Entry point 2>

## Steps
1. User does X → System responds with Y
2. User does A → System responds with B
   - **Decision:** If condition, go to step 3a. Otherwise, step 3b.
3a. ...
3b. ...

## Error Paths
- Step 1 failure: <what happens and how the user recovers>
- Step 2 failure: <what happens and how the user recovers>

## Success Criteria
- <Observable outcome that confirms the goal was met>

## Diagram
(Mermaid flowchart here)
```

### Journey Map Review

- Journey maps for new features must be reviewed by both the ux agent and the architect agent before implementation begins.
- The architect agent confirms that the journey is feasible within the current system boundaries. The ux agent confirms that the experience meets usability standards.
- Update journey maps when the implementation diverges from the original design. Outdated journey maps are worse than no journey maps.
