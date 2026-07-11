# Human Approval Boundaries

This file defines where BaseCoat delivery automation must pause for explicit human approval.

## Source of truth

- Machine-readable policy: `.github/governance/human-approval-boundaries.json`
- Merge eligibility policy: `.github/governance/policy-packs.json`

## Boundary model

Automation continues by default after issue approval unless a boundary says a human is required.

Always-human boundaries:

1. `production_environment_approval`
2. `policy_exception_override`
3. `security_incident_override`

Profile-specific PR review boundaries are declared under `pr_approval_required_by_risk`:

- `low`
- `medium`
- `high`
- `critical`

## Operational intent

1. Issue approval (`/approve`) remains the canonical execution handoff signal.
2. PR auto-merge automation must enforce configured risk-tier human boundaries.
3. Production release gates must always require explicit environment approval.
