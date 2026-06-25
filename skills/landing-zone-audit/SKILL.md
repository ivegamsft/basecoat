---
name: landing-zone-audit
compatibility: [github-copilot-cli]
description: "Use when reviewing Azure landing zone designs, management group hierarchies, hub/spoke patterns, policy baselines, or vending completeness. USE FOR: audit landing zone designs, verify hierarchy and platform subscriptions, check policy baseline coverage, review vending readiness. DO NOT USE FOR: single-resource deployment, AWS org design, application code generation."
---
# Landing Zone Audit Skill

Review Azure landing zone designs for hierarchy hygiene, hub-and-spoke consistency, policy coverage, and vending readiness.

## USE FOR

- Auditing management group and subscription layout
- Checking hub/spoke or Virtual WAN decisions for consistency
- Verifying policy baselines, exemptions, and diagnostics
- Reviewing landing-zone vending completeness before rollout

## DO NOT USE FOR

- Single-resource app deployment
- AWS organization design
- Application code generation
- Non-landing-zone Azure troubleshooting

## Workflow

1. Check the management group hierarchy and subscription placement.
2. Verify platform subscriptions and shared services are separated cleanly.
3. Review the network model, policy baseline, and exemption strategy.
4. Confirm vending outputs, RBAC, diagnostics, and ADRs are complete.
5. Summarize architectural gaps with severity and evidence.

## Output

Return:

- Verdict: pass, pass with notes, or request changes
- Findings with severity and evidence
- Missing platform or policy pieces
- Suggested remediation or follow-up

## Related Agent

Use with `azure-landing-zone` agent.


