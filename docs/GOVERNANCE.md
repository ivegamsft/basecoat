# Governance Landing Page

Use this page as the canonical entry point for governance in BaseCoat.
It separates shared rules from repo-specific rules, defines the canonical label
set for new work, and maps legacy labels used during migration.

## Shared vs repo-specific rules

| Governance layer | Use for | Source of truth |
|---|---|---|
| Common (shared) | Rules that should be consistent across repos: issue types, priority labels, canonical migration mapping, governance process | [`docs/reference/governance-contract.md`](reference/governance-contract.md) |
| Repo-specific (delivery) | Rules tied to this repository's planning and operations: sprint labels, area labels, workflow-specific conventions | [`docs/reference/governance.md`](reference/governance.md) |

## Canonical label set (for new work)

Apply labels from these groups for new issues:

### Issue type labels

- `bug`
- `enhancement`
- `documentation`
- `question`
- `chore`
- `security`

### Priority labels

- `priority:critical`
- `priority:high`
- `priority:medium`
- `priority:low`

### Status and routing labels

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

For full criteria, ownership, and usage examples, see
[`docs/reference/label-taxonomy.md`](reference/label-taxonomy.md).

## Legacy-to-canonical migration notes

Use this mapping when normalizing old labels. Do not add legacy labels to new
work.

| Legacy label | Canonical label |
|---|---|
| `P0-critical` | `priority:critical` |
| `P1-high` | `priority:high` |
| `P2-medium` | `priority:medium` |
| `P3-low` | `priority:low` |
| `priority/high` | `priority:high` |

Migration safety rules:

1. Normalize shared governance labels first.
2. Preserve repo-specific delivery labels unless the repo owner explicitly approves changes.
3. Treat unknown labels as repo-specific until verified.

## Where to file governance gaps

Open a GitHub issue for any missing or inconsistent governance guidance:

- Missing documentation
- Missing canonical labels or incomplete migration mapping
- Audit/enforcement workflow gaps
- Template/governance link drift

Tag gaps with `governance` and `documentation` when applicable.

## Related references

- [`docs/reference/governance-contract.md`](reference/governance-contract.md)
- [`docs/reference/governance.md`](reference/governance.md)
- [`docs/reference/label-taxonomy.md`](reference/label-taxonomy.md)
- [`docs/operations/label-cleanup-plan.md`](operations/label-cleanup-plan.md)
