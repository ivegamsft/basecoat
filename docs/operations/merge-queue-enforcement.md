# Native merge queue enforcement

## Purpose

The native GitHub merge queue serializes merges to `main` and runs required
checks against generated merge-group commits. It supplements, but does not
replace, existing repository, organization, or enterprise governance.

## Required check contexts

The repository ruleset requires the six current solo-dev main checks plus the
cloud-agent guard. These names are sourced from
`.github/governance/policy-packs.json` and verified against the live branch
protection state during preflight.

| Check context | Source |
|---|---|
| `lint-and-validate` | `ci.yml` |
| `test` | `ci.yml` |
| `validate-commit-messages` | `validate-basecoat.yml` |
| `validate-unix` | `validate-basecoat.yml` |
| `validate-windows` | `validate-basecoat.yml` |
| `release-label-gate` | `pr-validation.yml` |
| `Agent merge guardrails` | `agent-merge.yml` |

The cloud-agent context is the job name reported by a successful GitHub Actions
check run on readiness PR #3506; its integration is bound to GitHub Actions app
ID `15368`. The ruleset uses `ALLGREEN`, squash, one entry to build and merge,
and zero bypass actors. The release-label gate resolves the generated head from
the live queue, refetches the current PR labels and source head, and verifies its
merge tree with the event base against the synthetic squash tree. It fails closed
on stale content, missing/ambiguous membership, or unsupported multi-commit groups.
Original PR commits need not be ancestors of a squash group.

It contains no pull-request rule, so it does not set or
change approval counts.

## Validate, preflight, apply, and rollback

Local validation has no network or write side effects:

```powershell
pwsh scripts/deploy-merge-queue.ps1 -DryRun
```

After the queue configuration PR has merged, run a read-only live preflight:

```powershell
pwsh scripts/deploy-merge-queue.ps1 -Preflight
```

Only the authorized operator should apply, after the readiness and
configuration changes are merged and the parent explicitly authorizes
activation:

```powershell
pwsh scripts/deploy-merge-queue.ps1 -Apply
```

Apply verifies that #3506 is merged, required merge-group workflows and the
declarative ruleset are present on live `main`, the observed cloud-agent check
passed on the readiness head, branch protection remains strict and contains
every existing required context, squash merging is allowed, and the target
ruleset is repository-owned. It writes only through the repository rulesets
API. Organization- or enterprise-owned rulesets and branch protection are
never modified.

Verification fingerprints all supported writable enforcement fields: name,
target, enforcement, conditions, rules, and bypass actors. The local descriptive
annotation is not a GitHub ruleset API field and is neither sent nor compared;
server-generated metadata is also excluded. Required checks and bypass changes
still fail exact verification.

Apply prints a unique rollback snapshot path outside the repository. Preserve
that file and pass it explicitly if rollback is needed:

```powershell
pwsh scripts/deploy-merge-queue.ps1 -Rollback -BackupPath <snapshot-path>
```

Rollback restores the previous repository-owned ruleset or deletes the ruleset
created by this apply. It refuses to overwrite the target if its identity or
post-apply fingerprint changed. A failed verification is an explicit blocker;
do not use a direct merge or bypass as a recovery shortcut.

The Bash entry point accepts matching modes:

```text
scripts/deploy-merge-queue.sh --dry-run
scripts/deploy-merge-queue.sh --preflight
scripts/deploy-merge-queue.sh --apply
scripts/deploy-merge-queue.sh --rollback <snapshot-path>
```

## Preserved governance

- `.github/governance/policy-packs.json` remains unchanged; solo-dev queue
  posture remains `deferred`.
- The existing zero-approval-through-XL posture and qualified-human XXL
  approval boundary remain unchanged.
- Existing strict required checks, signed-commit rules, organization/enterprise
  rulesets, the `prd-spec-gate.yml` high-change intake contract, issue/spec
  authorization, and production environment approvals remain in force.
- The declarative ruleset targets only `refs/heads/main`; it has no bypass
  actors and adds no pull-request approval rule.
- Neither this configuration nor queue activation authorizes direct merging.

## Rollout and verification

1. Land readiness PR #3506 through its governed merge path.
2. Land the declarative queue configuration PR through the parent-owned
   serialized merge path.
3. Obtain explicit parent authorization, run the live preflight, then apply.
4. Verify the active repository-owned ruleset and its required check contexts.
5. Put an already authorized PR into the queue and verify every required check
   on its generated merge-group commit before treating queue delivery as ready.

Do not report the queue as enabled or verified until the live ruleset and
generated merge-group checks have both been observed.

## References

- [Queue activation PRD](../prd/synthesized/issue-3499-queue-activation.prd.md)
- [Queue activation specification](../spec/synthesized/issue-3499-queue-activation.spec.md)
- [Readiness PR #3506](https://github.com/IBuySpy-Shared/basecoat/pull/3506)
- [Issue #3499](https://github.com/IBuySpy-Shared/basecoat/issues/3499)
- [Governance contract](../reference/governance-contract.md)
