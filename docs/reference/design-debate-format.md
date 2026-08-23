# Design Debate Format

Use this format when a request includes `design: debate:` or otherwise asks to
compare options before implementation.

## Inputs

- Product-definition source (typically repository `PRODUCT.md`)
- Current UI/UX or information architecture evidence
- Accessibility and design-system constraints

## Required structure

### Question

State the specific design decision or gap.

### Option 1

- Evidence
- User impact
- Implementation scope
- Accessibility impact
- Risks

### Option 2

- Evidence
- User impact
- Implementation scope
- Accessibility impact
- Risks

Add more options only when the additional option is materially different.

### Recommendation

- Preferred option
- Why it is preferred based on evidence and constraints
- Follow-up validation plan

### Approval boundary

State that discovery and debate are complete, then wait for explicit approval
before applying file changes, opening issues, or creating pull requests.
