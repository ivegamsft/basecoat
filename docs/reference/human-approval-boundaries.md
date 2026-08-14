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

Solo-maintainer acknowledgement boundaries are declared under
`maintainer_acknowledgement_required_by_risk`. The shipped `solo-dev` profile
requires acknowledgement only for `critical` changes. Team profiles do not use
acknowledgement as a substitute for independent PR review.
For `solo-dev`, the same acknowledgement mechanism also satisfies
`policy_exception_override` and `security_incident_override`; team profiles
continue to require an independent qualified PR approval for those boundaries.

The production boundary is described by `production_environment_contract`.
Its `pr_approval_is_equivalent: false` setting is normative: a PR review never
satisfies deployment approval. For production-path changes, the PR gate verifies
both the committed contract and the live environment's required-reviewer and
deployment-branch protections. The deployment job then waits on the protected
GitHub `production` environment.

## Operational intent

1. Issue approval (`/approve`) remains the canonical execution handoff signal.
2. PR auto-merge automation must enforce configured risk-tier human boundaries.
3. A critical `solo-dev` PR requires either:
   - an exact PR comment `/acknowledge-critical <full-head-sha>` from a
     write, maintain, or admin user after the executor observes the latest
     push, or
   - a closing link to an open issue labeled `approved` with an exact
     `/approve` comment from a write, maintain, or admin user.
4. Bot users, arbitrary commenters, stale SHA comments, and PR approvals do not
   satisfy the solo-maintainer acknowledgement. Editing or deleting the
   acknowledgement revokes it.
5. Linked-issue `/approve` comment and `approved` label changes publish pending
   eligibility on each linked open PR and dispatch reevaluation. PR title/body
   edits also reevaluate closing-link evidence.
6. Production release gates always require explicit GitHub environment
   approval; they never add an independent PR-approval requirement. A changed
   production workflow must retain the trusted job-level environment binding
   and full-workflow SHA-256 digest declared in
   `production_environment.workflow_bindings`.
7. Governance contracts and every canonical, distributed, or downstream
   executor filename are critical paths, so `solo-dev` changes to the
   acknowledgement trust root require explicit maintainer acknowledgement.
