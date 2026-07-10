---
description: "Use when converting internal roadmap or feedback into a separate public-safe guidance artifact."
applyTo: "**/*"
---

# Public Guidance Transformation

Use this instruction when turning internal roadmap notes, production feedback, or issue details
into guidance that can be published externally as a separate artifact.

## Workflow

1. **Capture the source** — identify the internal notes, roadmap items, and feedback signals that led to the guidance.
   Use the internal roadmap intake as source material, not as the publishable draft.
2. **Classify each detail** — mark every item as `keep`, `generalize`, or `redact` before writing the public draft.
3. **Remove sensitive specificity** — strip repo names, ticket numbers, customer names, private URLs, internal hosts, incident IDs, and unshipped commitments.
4. **Generalize the pattern** — rewrite the guidance in reusable terms that preserve the lesson without exposing internal context.
5. **Record a redaction ledger** — list what was removed or generalized and why.
6. **Validate before publish** — run guardrail validation and block publication if the draft still depends on internal-only details.
7. **Publish only the sanitized artifact** — keep internal source notes separate from public docs and publish the generic version only.

## Redaction Guardrails

- Redact secrets, credentials, API keys, tokens, and connection strings.
- Redact customer names, tenant IDs, account numbers, and private URLs.
- Redact operational details that expose timing, scale, incidents, or rollout plans.
- Replace precise numbers, dates, and internal milestones with ranges or relative language when they reveal private cadence.
- If redaction would remove the core lesson, omit the example instead of exposing the detail.

## Output

Return:

- Public-safe guidance draft
- Redaction ledger
- Publication note
