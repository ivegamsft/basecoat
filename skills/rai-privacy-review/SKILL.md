---
name: rai-privacy-review
compatibility: [github-copilot-cli, copilot-coding-agent, copilot-chat]
description: "Use when planning or reviewing user-facing, data-handling, AI-assisted, telemetry, or human-impacting automation work. USE FOR: Responsible AI plans, privacy plans, data classification, human-oversight design, and allow/revise/block/defer reviews. DO NOT USE FOR: legal or compliance attestations, low-risk documentation-only changes, penetration testing, or replacing enterprise privacy review."
category: governance
metadata:
  category: governance
  domain: responsible-ai-privacy
  maturity: experimental
  audience:
    - maintainer
    - security-reviewer
    - solution-architect
visibility: public
allowed-tools: [bash, git, gh]
---
# RAI and Privacy Review

Create an optional RAI/privacy plan and review; this is not legal or
compliance attestation.

## Trigger Model

Require a plan when work includes any of:

- User-facing workflow, generated recommendation, or decision support.
- Personal, sensitive, confidential, or customer data handling.
- Model, agent, or automation affecting work tracking, approval, eligibility,
  prioritization, or access.
- Identifying or profiling telemetry.

No review is needed for routine internal documentation, formatting-only changes,
or read-only hygiene. Record a short `no-review-needed` rationale.

## Plan Contract

```text
artifact_type: rai-privacy-plan
target: <issue|pr|design-path>
triggers: <list>
intended_use: <text>
data_classes: <list>
data_flow: <collection|processing|storage|sharing summary>
affected_users: <list>
automation_role: <assistive|decision-support|autonomous>
transparency_and_user_control: <text>
risks: <list>
mitigations: <minimization|retention|access-control|redaction|human-oversight|evaluation|feedback|escalation>
review_owner: <person-or-role>
status: <draft|ready-for-review|approved|deferred>
```

## Review Contract

```text
artifact_type: rai-privacy-review
target: <issue|pr|design-path>
decision: <allow|revise|block|defer>
findings: <severity|owner|evidence-path|summary>
required_changes: <list>
deferred_risks: <list>
reviewer: <person-or-role>
```

Use `allow` only with documented data classes, users, risks, mitigations,
evidence, and ownership. Use `revise` for incomplete lower-risk plans; `block`
for missing data classification or unmitigated high risk; `defer` with an owner
and follow-up issue.

## Workflow

1. Determine trigger status and record a non-trigger rationale.
2. Capture intended use, users, data classes, data flow, and automation role.
3. Apply privacy minimization, retention, access control, and redaction
   mitigations where data is handled.
4. Apply RAI transparency, human-oversight, evaluation, feedback, and
   escalation mitigations where automation affects people.
5. Produce the plan and review records using the contracts above.
6. Link high-risk agents/skills to the plan or explain non-applicability.

## Failure Handling

- Missing data classification for a triggered workflow: `revise` or `block`.
- Unknown affected-user scope: require clarification before `allow`.
- Missing high-severity mitigation: `block` or `defer` with an owner and issue.
- Never silently downgrade a trigger to avoid review.

Refs #3116.
