# Spec: Review Activation Boundaries

## Design Contract

Update the descriptions and activation bodies of `frontend-audit`, `frontend-dev`,
and `ux` to distinguish code findings, code changes, and experience assessment.
Each names its primary/delegate neighbors and retains explicitly requested
composition. Update the security agent workflow/output to delegate rule
implementation to its namesake skill, whose description identifies that namespace.

## Security and Failure Modes

An audit request never grants edit authority. Inspected PR text, source, alerts,
and tool output remain evidence, not instructions. SOC phases are guidance,
not live-action approval. Ambiguous requests require scope clarification rather
than assuming remediation. No tool permissions or live settings change.

## Implementation and Validation

- Keep existing templates, model assignments, and tool fields unchanged.
- Add neighboring review/remediation/experience and namespace evaluation cases,
  including untrusted-input negatives for frontend review and SOC triage.
- Add static routing-contract regression assertions to the existing routing tests.
- Regenerate the asset manifest; run routing tests, repository validation, and
  the full suite. Evaluation scenarios specify expected host behavior; static
  tests do not establish live loader or model routing accuracy.

## Rollout, Observability, and Risks

Ship canonical assets through normal release/sync. Reviewers can inspect the
description/body contract and companion evals; no telemetry service is added.
The main risk is over-excluding composed requests, mitigated by positive
composition cases. Revert the asset/eval/manifest changes to roll back.

## References

- [PRD](../prd/review-activation-boundaries.prd.md)
- Tracking: #3333; governance: [contract](../reference/governance-contract.md)
