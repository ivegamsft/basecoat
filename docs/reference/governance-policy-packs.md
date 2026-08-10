# Governance Policy Packs

Issue: #1830

This reference defines three governance packs that route changes by risk tier.

## Policy pack matrix

| Pack | Intended use | Low risk | Medium risk | High risk | Critical risk |
|---|---|---|---|---|---|
| `solo-dev` | Single maintainer repos with an available independent reviewer | 1 approval | 1 approval | 1 approval | 1 approval |
| `team-dev` | Team repos with routine collaboration and shared ownership | 0 approvals | 1 approval | 1 approval | 1 approval |
| `regulated-team` | Security-sensitive or regulated delivery streams | 1 approval | 1 approval | 2 approvals | 2 approvals |

Required checks per pack are defined in `.github/governance/policy-packs.json`.
The portable `solo-dev` ruleset requires one review globally because a
repo-local GitHub Actions status cannot provide an executor-specific identity.
The author may still complete the merge after another qualified collaborator
approves the latest push; self-merge never means self-approval.

## Risk-tier routing

Routing is path-based and evaluated from changed files:

- `low`: docs/templates metadata paths
- `medium`: agents, skills, instructions, prompts, scripts, tests
- `high`: workflows and governance control references
- `critical`: IaC and production deployment workflow surfaces

The effective tier is the highest tier matched by any changed file.

`production_release_paths` separately identifies production workflows that
always retain the human production-approval boundary, even when their path risk
tier is `high` rather than `critical`.

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
