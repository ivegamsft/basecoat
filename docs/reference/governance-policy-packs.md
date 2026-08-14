# Governance Policy Packs

Issue: #1830

This reference defines three governance packs that route changes by risk tier.

## Policy pack matrix

| Pack | Intended use | Low risk | Medium risk | High risk | Critical risk |
|---|---|---|---|---|---|
| `solo-dev` | True single-maintainer repos with reliable automated checks | 0 approvals | 0 approvals | 0 approvals | 0 approvals + maintainer acknowledgement |
| `team-dev` | Team repos with routine collaboration and shared ownership | 0 approvals | 1 approval | 1 approval | 1 approval |
| `regulated-team` | Security-sensitive or regulated delivery streams | 1 approval | 1 approval | 2 approvals | 2 approvals |

Required checks per pack are defined in `.github/governance/policy-packs.json`.
The portable `solo-dev` ruleset requires zero approving reviews. The trusted
executor preserves human intent for critical changes through a durable
maintainer acknowledgement, while `team-dev` and `regulated-team` continue to
require independent write, maintain, or admin reviewers.

The `solo-dev` pack also requires an automated review from
`copilot-pull-request-reviewer[bot]` for the current PR head. A review of an
earlier commit does not satisfy the executor.

For critical `solo-dev` PRs, post
`/acknowledge-critical <full-head-sha>` after the executor observes the latest
push. The PR author may
acknowledge because this is an accountable-maintainer decision, not a fabricated
GitHub review. A linked issue labeled `approved` with an exact qualified
maintainer `/approve` comment is also accepted. Bots, stale SHA comments, users
without write, maintain, or admin permission never count, and deleting or
editing the acknowledgement revokes it. Changes to a linked issue's exact
`/approve` comment or `approved` label set linked PR eligibility to pending and
dispatch reevaluation.

## Risk-tier routing

Routing is path-based and evaluated from changed files:

- `low`: docs/templates metadata paths
- `medium`: agents, skills, instructions, prompts, scripts, tests
- `high`: workflows and governance control references
- `critical`: IaC and production deployment workflow surfaces

The effective tier is the highest tier matched by any changed file.

`production_release_paths` separately identifies production workflows that
always retain the protected GitHub environment boundary, even when their path
risk tier is `high` rather than `critical`. The PR executor validates the
`production_environment` and `production_environment_contract` settings plus
the live environment's reviewer and branch protections. It does not convert
environment approval into an independent PR approval. The actual deployment
remains paused on the `production` environment.

## Cloud-agent guardrails by pack

| Pack | Auto-approve pending workflow runs for `app/copilot-swe-agent` | Cloud-agent required checks |
|---|---|---|
| `solo-dev` | Enabled | `Agent merge guardrails` |
| `team-dev` | Enabled | `Agent merge guardrails` |
| `regulated-team` | Disabled | `Agent merge guardrails`, `prd-spec-gate` |

## Selection and override path

Set the active pack with repository variable `BASECOAT_POLICY_PACK`.

- Default when unset: the policy file's `default_profile` (`solo-dev` in the
  shipped v4.2 policy pack)
- Supported values: `solo-dev`, `team-dev`, `regulated-team`

Set the variable explicitly in consumer repositories. Bootstrap defaults to
`team-dev` when no onboarding profile or contract is supplied, while governance
workflows fall back to the policy file. An explicit contract and repository
variable keep those surfaces aligned.

Override policy is time-boxed:

1. Open a governance issue with risk, owner, expiry, and rollback plan.
2. Link the issue in the PR.
3. Restore default pack controls before exception expiry.

See profile-specific `override_path` text in `.github/governance/policy-packs.json`.
For implementation guidance, see
`docs/guides/solo-dev-profile.md`.
