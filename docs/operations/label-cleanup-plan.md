# Label Cleanup Plan

Use this runbook when cleaning label drift in BaseCoat or a consumer repo.
The goal is to normalize shared governance labels without destroying repo-specific
delivery work.
Preserve delivery labels unless the repo owner explicitly approves a rename or removal.

## Operating Model

| Bucket | Examples | Action |
|---|---|---|
| Governance labels | `bug`, `enhancement`, `security`, `priority:*`, `needs-triage`, `agent`, `skill`, `instruction` | Normalize to the shared contract |
| Delivery labels | `sprint:*`, `wave:*`, repo-local milestones, component tags | Preserve unless the repo owner approves a rename or removal |
| Migration labels | `P0-critical`, `priority/high`, `size/m`, `risk-high`, `sprint-24`, `area/ci` | Accept only as temporary aliases during transition |
| Unknown labels | Anything uncategorized | Keep, document, and escalate for repo-owner review |

The canonical set and every deprecated-to-canonical mapping live in
`.github/governance/label-taxonomy.json`; `docs/reference/label-taxonomy.md#migration-procedure`
defines the reversible, logged migration steps.

## Safe Cleanup Sequence

1. Export the current label set and label counts.
2. Partition labels into governance, delivery, migration, or unknown.
3. Update docs and templates to the shared governance contract.
4. Apply label changes only to the governance bucket.
5. Leave delivery labels intact unless the repo owner has signed off.
6. Record every exception in a follow-up issue.
7. Run an audit-only pass before any enforcement pass.

## Do Not Do

- Do not delete labels just because they are missing from BaseCoat.
- Do not rename `sprint-*` or `area/*` labels automatically in consumer repos.
- Do not normalize unknown labels without repo-owner approval.
- Do not change colors or descriptions for delivery labels unless the target repo requests it.

## Approval Matrix

| Change type | Needs owner approval | Safe to automate |
|---|---|---|
| Governance label normalization | No, if it stays within the shared contract | Yes |
| Delivery label rename or removal | Yes | No |
| Unknown label classification | Yes | No |
| Migration alias cleanup | Yes, after the transition window | Limited |

## Related References

- `docs/reference/governance-contract.md`
- `docs/reference/label-taxonomy.md`
- `.github/governance/label-taxonomy.json`
- `.github/workflows/governance-audit.yml`
- `.github/workflows/governance-enforce.yml`
