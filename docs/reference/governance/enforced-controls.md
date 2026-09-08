# Enforced Control Inventory

This inventory separates deterministic controls from advisory guidance. Enforced
controls must have a validation surface that can fail closed. Advisory guidance
can still be required by reviewers, but it is not presented as machine-enforced
unless a validator or workflow gate exists.

| Control | Source | Enforceability | Validation surface | Failure mode | Owner |
|---|---|---|---|---|---|
| LOG-FIRST issue evidence | `instructions/basecoat-20-lang-governance.instructions.md`; `instructions/basecoat-10-core-intent-routing.instructions.md` | Enforced for PRs through evidence in PR body, linked issues, and approval flow; advisory for local-only exploration | `BaseCoat - Merge eligibility` and issue approval workflows | PR is not eligible for automated merge until issue evidence or approval state is present | Governance/workflow maintainer |
| Routine PR size limit | `instructions/basecoat-20-lang-governance.instructions.md`; `.github/instructions/deployment-infrastructure.instructions.md` | Enforced for PRs by deterministic changed-file and churn thresholds with documented override labels/justification | PRD/spec gate, deterministic PR size labeling, and merge eligibility workflows | Oversized routine PR is blocked or routed for explicit review/override before merge | Governance/workflow maintainer |
| Config secret examples | `instructions/basecoat-20-lang-governance.instructions.md`; `.env.example` files | Enforced for committed environment templates and configuration examples | `scripts/validate-basecoat.ps1` via `Test-ConfigSecretExamples` | Validation fails with the file, variable name, and placeholder remediation | Security/configuration maintainer |

## Advisory controls

Some hard rules still require judgment and are intentionally advisory until a
stable enforcement surface exists. Examples include deciding whether a design
change needs a new issue, determining if a scope expansion is material, or
reviewing nuanced security tradeoffs. These must stay in instructions and review
checklists, but should not be described as deterministic gates until implemented
by a validator or workflow.

## Override path

When an enforced control supports an override, the PR must name the control,
state the reason, include validation evidence, and carry the repository's
documented override label or approval signal. Overrides are review evidence, not
silent bypasses.
