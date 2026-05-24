---
name: public-safe-sanitization
description: "Use when turning internal roadmap notes, issue details, or feedback into public-safe guidance; strip internal-specific content before external publication."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Security & Compliance"
  tags: ["sanitization", "redaction", "guardrails", "publication", "public-safe"]
  maturity: "production"
  audience: ["tech-writers", "platform-teams", "developers"]
allowed-tools: ["bash", "git", "grep", "find"]
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
5. Validate the draft with `agents/guardrail.agent.md` before publication.
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

- `instructions/public-guidance.instructions.md`
- `docs/guides/public-guidance-workflow.md`
- `agents/guardrail.agent.md`
