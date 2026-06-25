---
name: public-safe-sanitization
compatibility: [github-copilot-cli]
description: "Converts internal material to public-safe artifacts. USE FOR: sanitizing roadmap/issue notes for sharing, redacting private URLs/customer names/IDs, producing public-safe summaries with redaction ledger, rewriting internal details into generic guidance. DO NOT USE FOR: publishing raw internal notes, preserving sensitive identifiers, generating legal/compliance determinations, creating unrelated product plans."

visibility: "internal"
---
# Public Safe Sanitization Skill

Use this skill to convert internal material into a reusable public artifact without leaking internal-only details.

## Inputs

- Internal roadmap notes, issue summaries, feedback, or draft guidance
- Existing public-facing destination such as docs, an announcement, or a public repo
- Optional publication constraints or redaction requirements

## Workflow

1. Classify each detail as `keep`, `generalize`, or `redact`.
2. Remove repo names, ticket numbers, customer names, private URLs, hostnames, incident IDs, secrets, and unshipped commitments.
3. Rewrite the remaining content in generic terms that preserve the lesson.
4. Produce a redaction ledger listing what changed and why.
5. Validate the draft with `agents/basecoat-30-ai-guardrail.agent.md` before publication.
6. Publish only the sanitized artifact; keep source notes internal.

## Output

- Public-safe draft
- Redaction ledger
- Publication note

## Guardrails

- If redaction removes the core lesson, omit the example.
- Do not carry over precise timing, scale, or internal topology unless it is already public and essential.
- Prefer general patterns over named entities or unresolved commitments.

## Related Assets

- `instructions/basecoat-10-core-public-guidance.instructions.md`
- `docs/guides/public-guidance-workflow.md`
- `agents/basecoat-30-ai-guardrail.agent.md`
