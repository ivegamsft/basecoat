# Public Guidance Workflow

Use this workflow to turn internal roadmap intake or feedback material into a separate
public-safe guidance draft.

## End-to-End Flow

1. Ingest the completed internal roadmap intake, feedback notes, or issue summaries.
2. Identify details that cannot leave the organization as-is.
3. Rewrite the content so the pattern stays useful without the internal specifics.
4. Capture a redaction ledger for anything removed or generalized.
5. Run guardrail validation before any publish step.
6. Publish only the sanitized guidance artifact.

The internal roadmap remains an internal artifact; the published output is the separate
sanitized guidance draft.

## Redaction Checklist

| Keep | Generalize | Redact |
|---|---|---|
| Reusable pattern or recommendation | Internal milestone or rollout timing | Secrets, tokens, credentials |
| Public-safe example | Specific repo or branch name | Customer names and IDs |
| General process step | Ticket or incident number | Private URLs and hostnames |
| Outcome or lesson | Exact counts that expose internal scale | Unshipped roadmap commitments |

## Publication Split

- Public guidance lives in `docs/guides/`.
- Internal source notes live outside the published docs tree.
- The internal roadmap intake template lives in `docs/internal/` and is not published.
- Guardrails should block publication if the redaction ledger is missing.

## Related Assets

- `skills/public-safe-sanitization/SKILL.md` for the interactive sanitization workflow
- `instructions/public-guidance.instructions.md` for the publication transformation checklist
- `agents/guardrail.agent.md` for validation before release
