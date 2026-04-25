# Issue Templates

This file contains standard issue templates for basecoat.  
Copy the relevant section when filing an issue, or use GitHub's issue template picker if configured.

---

## Bug Report

**Title format:** `[BUG] <short description>`

```markdown
## Bug Description
<!-- What is broken? Be specific. -->

## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior
<!-- What should happen? -->

## Actual Behavior
<!-- What actually happens? Include error messages, output, or screenshots. -->

## Environment
- basecoat version: 
- OS: 
- Shell / runtime: 
- Relevant tool versions: 

## Minimal Reproduction
<!-- Paste the smallest config, command, or script that reproduces the bug. 
     IMPORTANT: Do NOT include secrets, tokens, keys, or credentials. -->

## Impact
- [ ] Blocks development
- [ ] Breaks CI
- [ ] Incorrect output (non-blocking)
- [ ] Documentation error

## Additional Context
<!-- Anything else that might help. -->
```

---

## Feature Request

**Title format:** `[FEATURE] <short description>`

```markdown
## Summary
<!-- One paragraph: what you want, why it matters, who benefits. -->

## Problem Statement
<!-- What gap or pain point does this address? -->

## Proposed Solution
<!-- What should be built? Be as specific as you can. -->

## Acceptance Criteria
- [ ] Given X, when Y, then Z
- [ ] ...

## Alternatives Considered
<!-- What else did you consider? Why is this the right approach? -->

## Dependencies
<!-- Does this block or get blocked by other issues? -->
- Blocks: #
- Blocked by: #

## Spec Required?
<!-- Does this need a PRD before implementation starts? -->
- [ ] Yes — will file PRD at docs/templates/PRD_TEMPLATE.md
- [ ] No — small enough to go straight to implementation

## Additional Context
<!-- Links, prior art, related issues. -->
```

---

## Documentation Update

**Title format:** `[DOCS] <short description>`

```markdown
## What needs to change?
<!-- Describe the documentation that is missing, incorrect, or outdated. -->

## Why?
<!-- What is the impact of the current state? -->

## Proposed Changes
<!-- What should the updated doc say or cover? -->

## Files Affected
<!-- List the files that need to change. -->

## Additional Context
```

---

## Governance / Process Change

**Title format:** `[GOVERNANCE] <short description>`

```markdown
## What governance rule or process needs to change?

## Why is the current approach insufficient?

## Proposed Change
<!-- Be specific. If changing a rule, quote the current text and propose new text. -->

## Impact on Existing Workflows
<!-- How does this affect humans and AI agents currently following the old rule? -->

## Migration Path
<!-- How do existing contributors/agents adapt? -->

## Stakeholders
<!-- Who needs to be aware of or agree to this change? -->
```

---

## Security Issue

**⚠️ Do NOT file security vulnerabilities in public issues.**

For security disclosures, contact the repo owner directly or use GitHub's private security advisory workflow:
`Security → Advisories → Report a vulnerability`

For non-sensitive security improvements (e.g., adding a scan, tightening a rule):

**Title format:** `[SECURITY] <short description>`

```markdown
## Security Concern
<!-- Describe the security improvement or hardening needed. 
     Do NOT include proof-of-concept exploit details in a public issue. -->

## Risk Level
- [ ] Critical — active exploit possible
- [ ] High — exploit requires effort but is plausible
- [ ] Medium — defense-in-depth improvement
- [ ] Low — minor hardening

## Proposed Fix

## Testing / Validation Approach
```

---

## Checklist Before Filing Any Issue

- [ ] Searched existing issues to avoid duplicates
- [ ] Title follows the format for the issue type
- [ ] No secrets, tokens, credentials, or PII included
- [ ] Linked to related issues where applicable
- [ ] Applied the correct labels
