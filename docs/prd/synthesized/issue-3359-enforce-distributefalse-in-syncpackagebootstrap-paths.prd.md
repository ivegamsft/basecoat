---
issue: 3359
title: "Enforce distribute:false in sync/package/bootstrap paths"
status: in-review
author: ibuyspy
created: 2026-09-10
updated: 2026-09-18
labels: ["enhancement", "priority:low", "sprint:2026-W38"]
---

# PRD: Enforce `distribute: false` in Distribution Paths

## Problem Statement

BaseCoat authors can mark an instruction as repository-internal with
`distribute: false`, but only `scripts/show-context.ps1` currently interprets
that marker. Consumer sync, bootstrap, and release-package paths copy the
`instructions/` tree wholesale, so internal governance, memory, enterprise, or
cost-routing guidance can still be installed in downstream repositories.

The marker therefore communicates an intent that the product does not enforce.
This creates misleading author expectations, unnecessary downstream context,
and a risk that BaseCoat-only operational guidance is exposed to or executed by
consumer agents.

## Goals

- Make `distribute: false` an enforceable exclusion contract for every
  installable downstream distribution surface.
- Keep PowerShell and Bash distribution behavior equivalent.
- Remove previously managed internal instructions from consumer-discoverable
  paths during a safe upgrade without deleting consumer-owned content.
- Preserve the current default: instructions without the marker continue to
  ship.
- Provide deterministic tests that fail if an internal instruction enters a
  downstream overlay or release package.

## Non-Goals

- Generalizing the marker to agents, prompts, skills, workflows, or docs. Those
  assets use or may adopt separate distribution contracts such as
  `ships`/`dogfood`.
- Renaming or relocating the current internal instruction source files.
- Removing internal instructions from the BaseCoat source repository or from
  GitHub-generated source archives.
- Changing `applyTo`, instruction content, precedence, or runtime loading rules.
- Replacing the asset manifest format or the shared guidance-lock ownership
  model.
- Silently deleting a downstream file that has been locally modified or is
  owned by another distribution product.

## Users and Stakeholders

| Persona | Need | Priority |
|---|---|---|
| BaseCoat asset author | One frontmatter flag that reliably prevents downstream installation | High |
| Consumer repository maintainer | Consumer overlays that contain only intended guidance and preserve local content | High |
| Release maintainer | Installable ZIP and tar artifacts with the same exclusion semantics as sync | High |
| BaseCoat contributor | Cross-platform tests and actionable failures for malformed metadata | Medium |

## Distribution Surfaces

The contract applies wherever repository instructions become an installable or
consumer-visible payload:

| Surface | Required outcome |
|---|---|
| `sync.ps1` | Exclude internal instructions from `.github/base-coat/instructions/` and `.github/instructions/`; safely retire prior managed copies |
| `sync.sh` | Match the PowerShell sync outcome byte-for-byte for the filtered instruction set |
| `scripts/bootstrap-basecoat.ps1` | Exclude internal instructions from its reference overlay and Copilot-discoverable overlay |
| `scripts/package-basecoat.ps1` | Exclude internal instructions from `dist/stage/base-coat/instructions/` and resulting ZIP/tar payloads |
| `scripts/package-basecoat.sh` | Match the PowerShell package outcome |
| `.github/workflows/package-basecoat.yml` GHCP stage | Exclude internal instructions from `dist/ghcp-stage/instructions/` and `basecoat-ghcp.zip` |

## Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-1 | A leading-frontmatter field whose effective value is `distribute: false` must exclude that instruction from every distribution surface listed above. | Must |
| FR-2 | Missing `distribute` metadata must preserve existing behavior and ship the instruction. Explicit `distribute: true` must also ship it. | Must |
| FR-3 | PowerShell and Bash implementations must use the same parsing and exclusion rules. | Must |
| FR-4 | Sync upgrades must remove a previously BaseCoat-managed excluded instruction from both canonical and discoverable consumer locations, subject to existing ownership and content-hash protections. | Must |
| FR-5 | Consumer-facing `asset-manifest.json` data must not advertise an instruction omitted from that payload. The source repository manifest remains the complete source inventory. | Must |
| FR-6 | Invalid or ambiguous explicit `distribute` metadata must stop the distribution operation with the source-relative path and reason instead of leaking the instruction. | Must |
| FR-7 | Dry-run/bootstrap reporting and asset counts must reflect the filtered result. | Should |
| FR-8 | Packaging and sync validation must assert that no excluded instruction remains in a staged or installed destination. | Must |

## Frontmatter Contract

- Only the YAML frontmatter block at the beginning of an
  `instructions/*.instructions.md` file is authoritative.
- A UTF-8 BOM and CRLF or LF line endings are supported.
- The key is the exact lower-case scalar key `distribute`.
- Boolean `false`, including quoted and case-insensitive scalar spellings after
  trimming whitespace and an inline comment, means exclude.
- Boolean `true` means include.
- No frontmatter or no `distribute` key means include for backward
  compatibility.
- A duplicate key, empty value, unsupported value, or unterminated leading
  frontmatter block is an error when distribution is attempted.
- Text such as `distribute: false` in the Markdown body or a code sample has no
  effect.

## Non-Functional Requirements

| ID | Requirement | Measure |
|---|---|---|
| NFR-1 | Security | Internal instructions never appear in supported installable payloads |
| NFR-2 | Path safety | Filtering and cleanup operate only on regular files under canonical source, stage, or repository-root destinations; symlinks and escapes fail closed |
| NFR-3 | Compatibility | Unmarked instructions and explicitly distributable instructions retain existing names, contents, and destinations |
| NFR-4 | Determinism | The same source tree produces the same included instruction set in PowerShell, Bash, bootstrap, and package paths |
| NFR-5 | Diagnostics | A metadata failure identifies the file and rejected condition without printing instruction contents |
| NFR-6 | Performance | Filtering is a single linear scan of instruction files and adds no network operations |

## User Stories

- As a BaseCoat maintainer, I want `distribute: false` to be enforced so that
  repository-only guidance cannot reach consumers accidentally.
- As a consumer maintainer, I want an upgrade to retire old internal guidance
  safely so that my overlay converges without losing local customizations.
- As a release maintainer, I want package and sync outputs to agree so that the
  installation method does not change which instructions a consumer receives.

## Acceptance Criteria

- [ ] Given an instruction with `distribute: false`, when any supported sync,
      bootstrap, or package path runs, then the file is absent from every
      downstream canonical, discoverable, staged, and archived instruction
      location produced by that path.
- [ ] Given an unmarked instruction or `distribute: true`, when distribution
      runs, then the file is present and unchanged.
- [ ] Given a previously installed, unchanged, BaseCoat-owned instruction that
      becomes `distribute: false`, when sync upgrades the consumer, then the
      canonical and discoverable copies and their BaseCoat guidance-lock entries
      are removed.
- [ ] Given the same previously installed file with downstream modifications,
      when sync runs, then it fails with the existing content-modified
      protection and does not delete or overwrite the file.
- [ ] Given a foreign-owned or unmanaged file at a colliding destination, when
      sync runs, then existing guidance-lock collision behavior is preserved.
- [ ] Given invalid, duplicate, empty, or unterminated explicit distribution
      metadata, when a distribution path runs, then it exits non-zero and names
      the affected source-relative path.
- [ ] Given a packaged or synced consumer manifest, then no manifest entry
      refers to an excluded instruction.
- [ ] PowerShell and Bash fixture tests produce the same included and excluded
      instruction sets.
- [ ] Repository Markdown, link, structure, and targeted distribution tests
      pass.

## Success Metrics

- Zero `distribute: false` instruction files in supported downstream fixtures
  and release-package stages.
- One hundred percent PowerShell/Bash parity across the frontmatter test matrix.
- No regression in the count or content hashes of unmarked distributable
  instructions.
- No consumer-owned file deletion in upgrade regression tests.

## Constraints and Assumptions

- `distribute` is an instruction-only legacy contract for this issue; it is not
  an alias for the newer `ships` field on other asset types.
- Distribution scripts must remain usable without adding a YAML parser
  dependency.
- The source repository retains internal files for BaseCoat development.
- Existing guidance-lock path containment, ownership, and content-hash checks
  remain the authority for shared-overlay mutation.

## Rollout and Backward Compatibility

The change ships as a normal BaseCoat release and requires no consumer
configuration migration. On first sync with the enforcing release, internal
instructions previously installed by BaseCoat are treated as stale managed
files and removed only when ownership and hashes permit. Consumers with modified
copies receive a blocking diagnostic and must explicitly preserve, rename, or
restore the file before retrying.

Rollback is performed by installing the prior BaseCoat release. Rollback may
restore previously shipped internal instructions; it must not bypass the same
ownership protections.

## Observability

Each distribution command reports the number and source-relative names of
instructions excluded by policy, plus a summary count. CI preserves the normal
command exit status and logs. No file contents or frontmatter beyond the
rejected field are emitted.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Parser drift between PowerShell and Bash | Medium | High | Shared fixture matrix and parity assertions |
| Filtered files remain listed in consumer manifest | Medium | Medium | Generate or rewrite the consumer manifest from the included set and test referential integrity |
| Upgrade cleanup deletes local content | Low | High | Retain guidance-lock ownership, hash, symlink, and path-boundary checks |
| Internal file leaks through a secondary package stage | Medium | High | Assert all stage directories and inspect both ZIP and tar contents |
| Existing malformed metadata breaks release | Low | Medium | Validate the repository corpus before rollout and provide path-specific errors |

## Dependencies

- Existing guidance-lock helpers in `scripts/guidance-lock.ps1` and
  `scripts/guidance-lock.sh`.
- Existing sync, package, bootstrap, and consumer-smoke test fixtures.
- Existing source `asset-manifest.json` generation and consumer cleanup logic.

## References

- Technical spec:
  `docs/spec/synthesized/issue-3359-enforce-distributefalse-in-syncpackagebootstrap-paths.spec.md`
- Issue: <https://github.com/IBuySpy-Shared/basecoat/issues/3359>
- Follow-up source: PR #3353
- Author guidance: `CONTRIBUTING.md` (`Asset Distribution`)
