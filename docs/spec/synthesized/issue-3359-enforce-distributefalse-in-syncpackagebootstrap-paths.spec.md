---
issue: 3359
title: "Enforce distribute:false in sync/package/bootstrap paths"
status: in-review
author: ibuyspy
created: 2026-09-10
updated: 2026-09-18
labels: ["enhancement", "priority:low", "sprint:2026-W38"]
---

# Technical Specification: Enforce `distribute: false`

## Context

`scripts/show-context.ps1` recognizes `distribute: false` as an internal
instruction marker, while distribution code copies the complete
`instructions/` directory. The affected paths are `sync.ps1`, `sync.sh`,
`scripts/bootstrap-basecoat.ps1`, both package scripts, and the GHCP package
stage in `.github/workflows/package-basecoat.yml`.

Current sync also projects the canonical
`.github/base-coat/instructions/` payload into `.github/instructions/` and
records shared destinations in `guidance-lock.json`. Any fix must therefore
filter both copies and use the existing stale-file ownership protocol rather
than directly deleting shared-overlay files.

## Scope

- Define one deterministic parser contract for `distribute` on
  `instructions/*.instructions.md`.
- Filter internal instructions from canonical consumer payloads,
  Copilot-discoverable overlays, bootstrap output, package stages, GHCP output,
  ZIP files, and tar files.
- Filter consumer-facing manifest entries for omitted instructions.
- Safely retire previously managed copies during sync.
- Add PowerShell, Bash, bootstrap, package, archive-content, malformed-metadata,
  and upgrade tests.
- Align `scripts/show-context.ps1` with the same scalar interpretation if its
  current parser differs from the new shared contract.

## Out of Scope

- Applying `distribute` to assets outside `instructions/`.
- Changing the `ships`, `dogfood`, or `status` distribution model.
- Removing internal assets from the BaseCoat source tree or GitHub-generated
  repository source archives.
- Changing instruction bodies, names, `applyTo` globs, or precedence.
- Weakening guidance-lock collision, local-modification, or path-safety checks.

## Architecture Overview

Distribution uses a filter-before-copy design:

1. Enumerate regular `*.instructions.md` files directly under the source
   `instructions/` directory.
2. Parse and validate each leading frontmatter block.
3. Build an immutable included-file set and excluded-file report before
   mutating a destination.
4. Copy non-instruction payload items as today.
5. Materialize the canonical consumer `instructions/` directory from only the
   included set.
6. Build discoverable overlay plans from that filtered canonical directory.
7. Produce a consumer manifest with excluded instruction entries removed.
8. Let existing guidance-lock stale-entry handling remove prior managed
   discoverable copies after all preflight checks pass.

Filtering before destination mutation prevents a late metadata error from
leaving a partially updated instruction tree. Implementations may stage files in
an existing script-owned temporary/staging directory, but must not filter by
copying everything and deleting from shared consumer paths afterward.

## Frontmatter Parsing Contract

The PowerShell and Bash implementations must satisfy the same behavior:

| Input | Effective result |
|---|---|
| No leading frontmatter | Include |
| Leading frontmatter without `distribute` | Include |
| `distribute: true` | Include |
| `distribute: false` | Exclude |
| Quoted or mixed-case boolean scalar | Normalize, then include/exclude |
| Scalar followed by an inline YAML comment | Ignore the comment |
| `distribute` only in body or code fence | Include |
| Duplicate `distribute` key | Error |
| Empty or non-boolean value | Error |
| Opening frontmatter fence without closing fence | Error |

Detailed rules:

- Accept an optional UTF-8 BOM before the first `---` fence.
- Accept LF and CRLF.
- Match the exact lower-case key `distribute`; differently cased keys are not
  aliases and should be rejected as likely metadata mistakes if they normalize
  to the same name.
- Trim surrounding whitespace and matching single or double quotes from the
  scalar, remove a trailing inline comment, and compare `true`/`false`
  case-insensitively.
- Parse only the first leading fenced block. Never scan the Markdown body.
- Emit a non-zero, path-specific error for ambiguous explicit metadata.
- Do not add a runtime YAML-library dependency solely for this scalar.

The parsing logic should be implemented as small reusable helpers in each shell
ecosystem rather than repeated regular expressions at every copy call.

## Distribution Surface Contracts

### PowerShell Sync

`sync.ps1` must replace wholesale copying of the canonical instruction
directory with staged filtered materialization. The downstream
`.github/base-coat/instructions/` tree contains only included instructions.
`Add-GuidancePlanTree` then naturally projects only that set to
`.github/instructions/`.

Before writing, the complete guidance plan must continue to pass canonical
path, symlink, owner, collision, and content-hash preflight checks. An excluded
instruction present in the previous BaseCoat lock becomes stale. It is removed
only after its current hash matches the lock; a modified copy raises
`GUIDANCE_CONTENT_MODIFIED`.

### Bash Sync

`sync.sh` must use the same filter-before-copy and stale-plan semantics as
PowerShell. Its fixture must compare resulting relative paths against the
PowerShell fixture. The implementation must remain compatible with the
repository's supported Bash baseline and must not depend on non-portable YAML
tools.

### Bootstrap

`scripts/bootstrap-basecoat.ps1` must materialize filtered instruction trees in
both `.github/base-coat/instructions/` and `.github/instructions/`. Dry-run
output and final asset counts must represent the included set. Existing
behavior for prompts, skills, agents, and templates remains unchanged.

### Package Scripts

`scripts/package-basecoat.ps1` and `scripts/package-basecoat.sh` must filter
`dist/stage/base-coat/instructions/` before archive creation. Both
`base-coat-<version>.zip` and `base-coat-<version>.tar.gz` must contain the same
included instruction paths and no excluded paths.

The GHCP stage in `.github/workflows/package-basecoat.yml` must use the same
filtered source set rather than copying the repository directory wholesale.
`basecoat-ghcp.zip` is subject to the same exclusion assertion.

### Consumer Manifest

The committed source `asset-manifest.json` remains a complete inventory.
Every consumer payload that includes a manifest must emit a filtered copy:

- remove entries whose `path` matches an excluded instruction;
- preserve all unrelated entries and metadata;
- fail packaging or sync validation if a manifest instruction path does not
  exist in the payload or if an excluded path remains.

This keeps cleanup and adoption tooling from treating a deliberately absent
instruction as current managed content.

## Security and Path-Containment Considerations

`distribute: false` is treated as a release-boundary control. Explicit malformed
metadata fails closed because silently shipping a likely internal file is the
higher-risk outcome. Absence of the field remains fail-open only for backward
compatibility with the existing corpus.

Implementations must:

- enumerate regular files without following instruction-directory symlinks;
- canonicalize source, stage, and destination roots;
- reject a source or destination resolving outside its expected root;
- complete metadata parsing and plan construction before shared-path writes;
- preserve guidance-lock ownership and content-hash checks;
- avoid logging file contents;
- never delete an unmanaged, foreign-owned, symlinked, or locally modified
  destination.

## Reliability and Failure Modes

| Failure | Required behavior |
|---|---|
| Invalid or duplicate metadata | Abort before instruction destination mutation; report relative path and reason |
| Missing source instruction directory | Preserve each command's existing required-input behavior; do not create a misleading partial success |
| Canonical path escape or symlink | Abort with a path-safety diagnostic |
| Foreign/unmanaged destination collision | Preserve `GUIDANCE_PATH_COLLISION` behavior |
| Modified stale managed file | Preserve `GUIDANCE_CONTENT_MODIFIED`; leave file and lock intact |
| Manifest rewrite/serialization failure | Abort before archive publication or sync completion |
| PowerShell/Bash output mismatch | Fail parity tests and block release |
| Archive contains excluded path | Fail package validation before upload |

Sync remains transactional at the current guidance-plan boundary: all shared
overlay checks occur before writes. Canonical payload staging should be built
before replacing its destination so parser failures do not leave a partially
filtered directory.

## Performance and Capacity

The added work is one read of each top-level instruction file plus an included
set lookup during copy/manifest filtering. Complexity is O(number of
instructions plus manifest entries), memory is O(number of instruction paths),
and no additional network calls are introduced.

## Implementation Plan

1. Add equivalent PowerShell and Bash helpers that return included/excluded
   instruction paths or raise a metadata error.
2. Update `sync.ps1` and `sync.sh` to stage the filtered canonical instruction
   tree before building the discoverable guidance plan.
3. Rewrite the copied consumer manifest against the excluded path set and add
   referential-integrity validation.
4. Update `scripts/bootstrap-basecoat.ps1` to use the PowerShell filter for its
   canonical and discoverable instruction copies.
5. Update both package scripts to filter the main package stage and validate
   ZIP/tar contents.
6. Update the GHCP workflow stage to consume a filtered instruction tree and
   assert archive contents.
7. Align `scripts/show-context.ps1` parsing with the contract to avoid the same
   file being classified differently at authoring and distribution time.
8. Add targeted regression fixtures, then run repository-standard validation.

## Testing Strategy

### Parser Matrix

Test LF/CRLF, optional BOM, absent metadata, true, false, quoted booleans,
mixed-case boolean values, whitespace, inline comments, body-only text,
duplicate keys, empty values, invalid values, and unterminated frontmatter.

### Distribution Tests

- Extend `tests/sync-tests.ps1` with source fixtures for included and excluded
  instructions and assertions for canonical and discoverable destinations.
- Extend `tests/sync-sh-parity-tests.ps1` with the same fixtures and compare
  relative output sets.
- Add bootstrap coverage that checks both overlay locations and dry-run/count
  behavior.
- Extend package tests to inspect the stage, ZIP, and tar path lists.
- Add a workflow contract assertion that the GHCP stage uses the filtered set.
- Assert filtered consumer-manifest referential integrity.

### Upgrade and Safety Tests

- Seed a prior guidance-lock entry and unchanged downstream file, then verify
  exclusion removes the file and entry.
- Modify the seeded file and verify sync fails without deletion.
- Seed foreign-owned, unmanaged, and symlink collision cases and verify no
  destructive action.
- Trigger invalid metadata and verify no instruction destination was partially
  replaced.

### Validation Commands

Use the smallest targeted commands during implementation, then the required
repository gates:

```powershell
pwsh tests/sync-tests.ps1
pwsh tests/sync-sh-parity-tests.ps1
pwsh tests/run-consumer-smoke.ps1 -ArtifactSource Current
pwsh scripts/validate-basecoat.ps1
pwsh tests/run-tests.ps1
python -m mkdocs build --strict
```

## Rollout, Migration, and Rollback Plan

Release through the normal package workflow. No feature flag or consumer
configuration is required. The first enforcing sync removes unchanged
BaseCoat-owned internal instructions and updates the lock/manifest. Modified or
conflicting files block the sync with remediation information rather than being
removed.

Before release, inspect all currently marked instruction files using the parser
fixture and package a candidate artifact. Rollback installs the prior release;
that release may restore the previously shipped files, subject to normal
ownership protections. No data migration is required.

## Observability and Operational Readiness

Each command emits:

- one concise exclusion line per internal instruction;
- included and excluded instruction totals;
- existing stale-removal messages during sync;
- path-specific metadata errors and non-zero exit status.

Package CI must publish no artifact after an exclusion or archive-content
validation failure. Existing GitHub Actions logs and test artifacts are
sufficient; no external telemetry is required.

## Risks and Mitigations

| Risk | Mitigation owner | Validation |
|---|---|---|
| Shell parsers disagree | Implementer | Shared parser matrix and sync parity test |
| One archive path bypasses filtering | Release maintainer | Inspect stage, ZIP, tar, and GHCP ZIP contents |
| Manifest references omitted files | Implementer | Consumer-manifest referential-integrity test |
| Upgrade removes local changes | Sync maintainer | Modified-file, ownership, collision, symlink, and containment fixtures |
| Stricter parsing rejects existing source | Asset author | Run corpus validation before packaging and name every failing path |
| Future copy path omits the filter | Repository maintainer | Central helpers plus tests enumerating all supported distribution surfaces |

## Requirements Traceability

| PRD requirement | Spec section | Test evidence |
|---|---|---|
| FR-1, FR-3 | Frontmatter Parsing; Distribution Surface Contracts | Parser matrix; PowerShell/Bash parity |
| FR-2 | Frontmatter Parsing Contract | Unmarked/true fixtures and content-hash comparison |
| FR-4 | PowerShell Sync; Bash Sync | Upgrade and safety tests |
| FR-5 | Consumer Manifest | Manifest referential-integrity tests |
| FR-6 | Security; Reliability | Invalid-metadata atomic-failure fixtures |
| FR-7 | Bootstrap; Observability | Bootstrap dry-run/count assertions |
| FR-8 | Package Scripts; Testing Strategy | Stage and archive-content assertions |

## Open Questions

None. Scope and compatibility decisions are fixed by this specification.

## References

- PRD:
  `docs/prd/synthesized/issue-3359-enforce-distributefalse-in-syncpackagebootstrap-paths.prd.md`
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3359>
- Follow-up source: PR #3353
- Existing marker consumer: `scripts/show-context.ps1`
- Distribution entry points: `sync.ps1`, `sync.sh`,
  `scripts/bootstrap-basecoat.ps1`, `scripts/package-basecoat.ps1`,
  `scripts/package-basecoat.sh`, `.github/workflows/package-basecoat.yml`
