# PRD: Retire destructive skill frontmatter cleanup

Status: implemented for #3656 as a non-mutating guard in
`scripts/fix-skill-frontmatter.ps1`, covered by
`tests/fix-skill-frontmatter-retirement-tests.ps1`. This does not authorize
source migration or portable export.

## Problem

`scripts/fix-skill-frontmatter.ps1 -Fix` can delete `compatibility`, `metadata`
and `allowed-tools` blocks from canonical skill files. These fields have valid
source or portable meanings; deleting them is not a schema conversion and can
strip BaseCoat-required metadata. Its regex/indentation loop cannot distinguish
host profiles or prove semantic preservation.

## Decision and Scope

Prefer retirement of the legacy mutation path over repairing an ad hoc YAML
rewriter. Keep the familiar entry point temporarily as an explicit deprecation
guard: read-only invocation reports why the operation is unsupported; `-Fix`
returns nonzero before any source read/write or traversal. It must not report
zero repairs as successful schema validation.

This runtime change is now current behavior. Callers must
not run the legacy helper as a migration tool. Future validation and export
belong to #3655 and #3654 respectively; retirement must not implement either
contract partially or imply that those tools already exist.

## Requirements and Acceptance

| ID | Requirement | Verification |
| --- | --- | --- |
| R1 | No mode can delete supported/source-required fields | Byte-for-byte tree snapshot before/after all invocation fixtures |
| R2 | Mutation request fails explicitly before traversal | Nonzero `-Fix`, stable deprecation reason, no writes or success-shaped output |
| R3 | Read-only invocation explains scope, not schema validity | Warning/output identifies source versus portable profiles and owner issues |
| R4 | No silent substitute tool or conversion | No dynamic dependency installation, fallback validator, approval or host claims |
| R5 | Guard does not conceal a blocked migration | Wrapped caller propagates refusal; notice identifies #3654/#3655 as future work, not runnable substitutes |

Named export/validation operation, profile, exact migration diff and provenance
remain future acceptance under #3654/#3655. They are not required proof for this
non-mutating guard and are not supplied by its deprecation notice.

## Non-Goals

Do not rewrite `SKILL.md`, strip unsupported-looking extensions, stringify
policy maps, normalize formatting, change bootstrap/sync behavior, install a
parser, broaden permissions or modify agents/skills/evals.
Do not preserve the destructive behavior behind an opt-in "legacy" switch.

## Consumer Experience

Explain that a field's source validity and its portable projected type are
different questions. Point to the published host contract and actual existing
source validation, accurately describing known validation gaps. Future export
is separately planned, not an alternative command consumers can run today.

Existing callers of `-Fix` intentionally stop instead of silently damaging
files. Treat that compatibility break as the safety correction and document it.
No new profile selector or mandatory catalog migration is required for retirement.

## Rollout, Risks and Success

Implementation needs source-scoped authorization after this contract is reviewed.
Land guard and fixtures together; inventory automation references before release,
communicate the nonzero mutation behavior, and confirm consumers see the guard.
Success is measured preservation plus explicit refusal, not a clean portable
catalog or proof of host restriction enforcement.

The guard may break scripts relying on cleanup. They must stop and migrate
deliberately; do not catch the failure and continue as if validation passed.
Rollback must not silently restore destructive cleanup: stop affected callers
while investigating a guard defect and preserve original source bytes.

## References

- Source: #3656; companion design: [spec](../spec/legacy-skill-cleanup-retirement.spec.md).
- [Published boundaries](../reference/frontmatter-host-contract.md).
- [Existing host authoring contract](../spec/host-frontmatter-contract.spec.md).
