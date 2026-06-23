# Governance Guide

This guide defines the shared governance layer for BaseCoat and how to separate
common rules from repo-specific rules.

## What belongs where

| Layer | Use for | Examples |
|---|---|---|
| Common | Rules that should apply across repos | label taxonomy, PRD/spec gates, issue template structure, agent/skill authoring rules |
| Specific | Rules that depend on this repo's structure or release flow | sprint labels, area labels, workflow names, repo-only exceptions |

## Downstream intake contract (consumer repos)

| Tier | Ownership | Requirement |
|---|---|---|
| Packaged by BaseCoat | BaseCoat | `.github/base-coat/templates/intake/PULL_REQUEST_TEMPLATE.md` and `.github/base-coat/templates/intake/issue.md` are shipped as defaults. |
| Required local surface | Consumer repo | `.github/PULL_REQUEST_TEMPLATE.md` must exist and `.github/ISSUE_TEMPLATE/` must contain at least one template file (`.md`, `.yml`, or `.yaml`). |
| Optional repo-specific extension | Consumer repo | Additional issue forms, PR templates, or repository-specific intake sections may be added without changing the BaseCoat defaults. |

The sync/bootstrap flows seed required local surfaces only when missing and never overwrite existing local customizations.

## Downstream reviewer-routing audit opt-in

BaseCoat runs a fleet audit loop to detect reviewer-routing failures across consumer repositories:

- Workflow: `.github/workflows/downstream-reviewer-routing-audit.yml`
- Opt-in registry: `.github/downstream-reviewer-routing-targets.json`
- Remediation guide: `docs/guides/downstream-reviewer-routing-audit.md`

Repositories are considered opted in when listed in the target registry with `"enabled": true`.
The audit classifies each repo into exactly one routing state:

1. `no reviewer-routing automation installed`
2. `automation installed but not configured`
3. `automation configured but ineffective in live PRs`
4. `healthy`

## Label namespaces

| Namespace | Ownership | Cleanup rule |
|---|---|---|
| Governance | Shared BaseCoat contract labels | Safe to normalize across repos |
| Delivery | Repo-specific labels such as sprint, area, wave, or feature tracking | Preserve unless the repo owner explicitly approves a rename or removal |
| Migration | Legacy aliases kept for backward compatibility | Accept only during migration and bulk cleanup; do not add to new work |

Only governance labels should be auto-normalized by shared tooling. Delivery labels belong to the target repo and must be treated as preserved state.

## Labels

### Issue types

- `bug`
- `enhancement`
- `documentation`
- `chore`
- `security`
- `question`

### Priorities

- `priority:critical`
- `priority:high`
- `priority:medium`
- `priority:low`

### State and routing labels

- `needs-triage`
- `needs-info`
- `needs-verification`
- `duplicate`
- `blocked`
- `approved`
- `copilot-agent`

### Asset labels

- `agent`
- `skill`
- `instruction`
- `prompt`

## Versioning

Version labels are repo-specific and should follow the repo's release policy.
Use this section to document any version or sprint label conventions that are
specific to this repository rather than the shared BaseCoat contract.

## Legacy label migration

| Legacy label | Canonical label |
|---|---|
| `P0-critical` | `priority:critical` |
| `P1-high` | `priority:high` |
| `P2-medium` | `priority:medium` |
| `P3-low` | `priority:low` |
| `priority/critical` | `priority:critical` |
| `priority/high` | `priority:high` |
| `priority/medium` | `priority:medium` |
| `priority/low` | `priority:low` |

Legacy labels may still exist on older issues, but new triage, templates, and
workflows should use the canonical labels above.

## Cleanup safety

1. Snapshot labels before making changes.
2. Normalize governance labels first.
3. Preserve delivery labels unless the target repo declares them obsolete.
4. Treat unknown labels as repo-specific until the owner confirms otherwise.
5. Comment and file an issue before deleting any label that is not in the governance namespace.

## Authoring rules

1. Keep shared policy in one place.
2. Put repo-specific exceptions in the repo-specific section, not in the common contract.
3. Link issues and PRs back to this guide when they touch labels, templates, or workflows.
4. File a GitHub issue for every gap you find in docs, labels, workflows, or assets.

## Gap categories

| Category | Example |
|---|---|
| Documentation gap | Missing or outdated guidance doc |
| Label gap | Canonical label missing or legacy label still treated as primary |
| Workflow gap | Audit or enforcement check missing |
| Asset gap | Missing agent or skill for a recurring governance task |

## Related references

- `docs/reference/governance.md`
- `docs/reference/label-taxonomy.md`
- `docs/operations/label-cleanup-plan.md`
- `docs/reference/treatment-matrix.md`
- `.github/ISSUE_TEMPLATE/issue.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
