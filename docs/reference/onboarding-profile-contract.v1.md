# Onboarding Profile Contract v1

Tracking: #1836

This document defines the versioned onboarding profile contract for BaseCoat consumers. The goal is to select one profile once and apply the right repo surfaces without hand-editing per repository.

## Contract shape

```yaml
contract_version: "1.0.0"
profile: "team-dev"
branch_policy: "shared"
workflow_pack: "team"
template_pack: "team"
telemetry_mode: "shared"
secrets_mode: "workflow-secrets"
hook_pack: "standard"
preserve_local_customizations: true
migration_from: "solo-dev"
allow_profile_downgrade: false
```

## Required and optional keys

| Key | Required | Default | Repo surface |
|---|---|---|---|
| `contract_version` | Yes | `1.0.0` | Contract and schema versioning |
| `profile` | Yes | None | Profile selector for `solo-dev`, `team-dev`, or `regulated-team` |
| `branch_policy` | No | Derived from `profile` | Branch protection / ruleset posture |
| `workflow_pack` | No | Derived from `profile` | `.github/workflows/` and workflow pack selection |
| `template_pack` | No | Derived from `profile` | `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/`, `docs/templates/` |
| `telemetry_mode` | No | Derived from `profile` | Telemetry and reporting wiring used during onboarding |
| `secrets_mode` | No | Derived from `profile` | Workflow secrets and `.env.example` guidance |
| `hook_pack` | No | Derived from `profile` | `.githooks/`, `scripts/install-git-hooks.*`, `.github/basecoat-hook-profiles.json` |
| `preserve_local_customizations` | No | `true` | Sync behavior for existing repo-specific files |
| `migration_from` | No | Unset | Profile switch source used during reruns |
| `allow_profile_downgrade` | No | `false` | Safety gate for weakening a profile on rerun |

## Default profile posture

| Profile | Branch policy | Workflow pack | Template pack | Telemetry mode | Secrets mode | Hook pack |
|---|---|---|---|---|---|---|
| `solo-dev` | minimal | solo | solo | local | local | none |
| `team-dev` | shared | team | team | shared | workflow-secrets | standard |
| `regulated-team` | locked-down | regulated | regulated | org-managed | org-managed | guardrails |

## Profile-to-surface mapping

| Contract key | Concrete surface |
|---|---|
| `branch_policy` | Branch protection and ruleset configuration in the consumer repo |
| `workflow_pack` | BaseCoat workflow files copied into `.github/workflows/` |
| `template_pack` | Issue and PR templates plus supporting template docs |
| `telemetry_mode` | Workflow environment, observability wiring, and drift-reporting hooks |
| `secrets_mode` | Secret references, environment variables, and bootstrap guidance in `.env.example` |
| `hook_pack` | Git hook files and hook installer scripts |
| `preserve_local_customizations` | Sync logic that skips or preserves existing repo-owned files |
| `migration_from` | Rerun transition logic for profile changes |
| `allow_profile_downgrade` | Guardrail for profile weakening during reruns |

## Rerun semantics

Reruns are idempotent by default:

1. Reapplying the same profile refreshes generated surfaces without removing repo-owned customizations.
2. Added surfaces are merged in when missing.
3. Existing consumer edits are preserved unless the contract explicitly says otherwise.
4. A rerun must not weaken branch policy, secrets wiring, or hook coverage unless `allow_profile_downgrade` is explicitly enabled.

## Migration rules

### `solo-dev` -> `team-dev`

- upgrade branch policy from minimal to shared
- add the team workflow pack and team template pack
- switch telemetry from local-only to shared reporting
- enable standard hook pack behavior
- keep existing repo files unless they conflict with the new shared surface

### `team-dev` -> `regulated-team`

- tighten branch policy to locked-down
- switch to regulated workflow and template packs
- move secrets wiring to org-managed references
- enable guardrail hooks
- preserve local repo customizations while layering the stricter contract on top

### Downgrades

Downgrades are blocked by default. A weaker profile can only be applied when `allow_profile_downgrade: true` is present and the change is explicitly approved.

## Versioning

`1.0.0` is the first published contract version. Any future incompatible profile or key changes must bump the contract version and keep the prior contract file available for migration guidance.

## Related files

- `docs/reference/onboarding-profile-contract.v1.schema.json`
- `docs/reference/telemetry-scorecard-schema.v1.md`
- `docs/reference/telemetry-scorecard-schema.v1.schema.json`
- `docs/operations/onboarding-telemetry-readiness.md`
- `docs/guides/enterprise-setup.md`
- `docs/getting-started.md`
