# PRD: Asset Distribution Classification

> **Status:** Draft (awaiting approval)
> **Issue:** #3374
> **Author:** Copilot
> **Target Version:** Next release
> **Last Updated:** 2026-09-13

## Problem Statement

BaseCoat authors skills, agents, prompts, and instructions and distributes them
to consumer repositories via `sync.ps1`. There is no explicit classification of
which assets are meant to **ship to consumers**, which are **internal to
developing BaseCoat itself**, and which are **both**. Prior investigation
(#3348 and #3373) established that the existing signals do not encode this:

- Skill `visibility` is `public|private` and only gates workflow-dependency
  validation (`private` = skip); it is not a distribution flag.
- Agent `visibility` is a routing tier (`basic|specialized|advanced|internal`),
  a surfacing concept, not distribution.
- `sync.ps1` copies whole asset trees to consumers unconditionally; nothing can
  mark an asset as internal-only.

Two concrete needs are blocked by this gap: (1) the #3348 dogfood self-install
needs to know which assets to project into BaseCoat's own session without
inflating context with consumer-only deliverables; (2) BaseCoat cannot withhold
a genuinely internal asset from consumer distribution. Adjacent, related needs
are equally unmet: marking an asset **deprecated** or **not-yet-ready**, and
**versioning** it, have no authoritative, validated home either.

A key framing constraint: none of these are runtime/harness features. The
Copilot CLI harness honors only `name` + `description` (the always-on picker)
and loads skill bodies on demand, so "load on demand" is already the default and
"hide from picker" is achieved by controlling which assets are physically
projected into a target — not by a runtime flag. This classification is a
BaseCoat build-/sync-time concern.

## Goals

- Introduce an explicit, authoritative distribution classification for BaseCoat
  assets, authored in frontmatter (the single source of truth).
- Generate a queryable rollup into the asset manifest and validate it in CI, so
  the classification cannot silently drift (consistent with the repo's existing
  generate-from-source + drift-check pattern for `asset-manifest.json`).
- Enable the two consumers of the classification: consumer distribution
  (`sync.ps1`) and the #3348 dogfood self-install.

## Non-Goals

- Changing the content or behavior of any asset.
- Re-designing the existing `visibility` semantics (skill `public|private`,
  agent routing tier) — the new classification is a separate, additive axis.
- Implementing the #3348 self-install itself (this feature only supplies the
  `dogfood` signal it consumes).
- Deciding the final ship/internal disposition of every current asset in this
  document (the seed classification is proposed; edge cases are an approval
  input).

## User Personas and Use Cases

- **BaseCoat maintainer authoring an asset:** declares, in one place in the
  asset's frontmatter, whether it ships to consumers and whether it is dogfooded
  locally, and gets a CI error if the declaration is missing or invalid.
- **Consumer repository:** receives only assets marked as shipped; internal-only
  BaseCoat tooling is withheld.
- **#3348 dogfood self-install:** projects exactly the assets marked `dogfood`
  into BaseCoat's own `.github/` layout.

## User Experience Summary

Every distributable asset carries an explicit, validated classification. A
generated manifest section lets anyone see, at a glance, which assets are
shipped, internal, or both. CI fails a PR that adds an asset without a valid
classification or that diverges from what distribution and dogfood actually do.

## Model

Distribution is modeled as **two orthogonal booleans** (not a single tri-state),
plus two additive axes for lifecycle and versioning:

| Field | Meaning | Drives |
|---|---|---|
| `ships` | Distributed to consumer repositories | `sync.ps1` / `package` / `asset-manifest` |
| `dogfood` | Projected into BaseCoat's own local session | #3348 self-install |
| `status` | Lifecycle/readiness: `experimental\|active\|deprecated` | `sync.ps1` readiness gate; reporting |
| `version` | Optional SemVer (existing field, formalized) | manifest `effectiveVersion` |

A human-readable label is derived from the distribution booleans: `both` (ships
and dogfood), `shipped` (ships only), `internal` (dogfood only). The fourth
combination (`neither`) is invalid unless the asset is explicitly
`status: experimental` or `status: deprecated`.

The six stated needs collapse onto these axes with no field-per-need: on-demand
loading is the harness default; "hide from picker" is derived from
`ships`/`dogfood` (physical projection); withholding not-ready/internal assets is
`ships` + `status`; deprecation is `status`; versioning is `version`; and
dogfooding a subset of internal assets is `dogfood` independent of `ships`
(so `ships:false, dogfood:true` is expressible).

## Functional Requirements

| ID | Requirement |
|---|---|
| FR1 | Each distributable asset (skill, agent, prompt; instructions decided in the spec) declares `ships` and `dogfood` in frontmatter. |
| FR2 | Frontmatter is the single source of truth; the classification is generated into the asset manifest (or a sibling manifest), never hand-maintained. |
| FR3 | CI validation asserts every applicable asset has a valid classification (both flags present and boolean; a `status` in `experimental\|active\|deprecated`; a SemVer `version` when present; no `neither` unless `status` is `experimental`/`deprecated`). |
| FR4 | `sync.ps1` withholds `ships:false` assets, and by default `status:experimental`/`status:deprecated` assets, from consumer distribution. |
| FR5 | The classification exposes a `dogfood` set consumable by the #3348 self-install (replacing its interim category+name allowlist), independent of `ships`. |
| FR6 | A drift check asserts the generated manifest matches the frontmatter and that distribution/dogfood behavior matches the manifest. |
| FR7 | A defensible seed classification is applied to the current asset catalog (seeded by the #3373 audit: 90 dev-governance vs 53 shipped skills), reviewable as part of approval. |
| FR8 | The skill/agent frontmatter reference documents `ships`/`dogfood`/`status` and the existing `version`, and clarifies that these are build-/sync-time selectors, not harness flags. |

## Non-Functional Requirements

- **No drift class:** classification lives in one authoritative place and is
  generated/validated, not duplicated.
- **Backward compatible:** existing `visibility` semantics are unchanged; the
  new fields are additive with a defined default for un-migrated assets.
- **Cross-platform:** generator and validation run on Windows and Unix and in
  CI.

## Success Metrics

- 100% of applicable assets carry a valid classification; CI blocks regressions.
- `sync.ps1` provably withholds every `ships:false` asset (test-asserted).
- The #3348 self-install consumes the `dogfood` set with no separate allowlist.

## Constraints and Assumptions

- The repo already generates and drift-checks `asset-manifest.json`; this
  feature extends that mechanism rather than adding a parallel one.
- Some current `visibility: internal` skills are consumer deliverables and some
  are internal tooling; the seed classification must be reviewed, not inferred
  purely from `visibility`.

## Risks and Open Questions

- **Mis-seeding disposition:** wrongly marking a deliverable `ships:false` would
  de-ship it from consumers. Mitigation: explicit seed review at approval; a
  conservative default of `ships:true` for ambiguous assets.
- **Migration size:** classifying the full catalog touches many files.
  Mitigation: mechanical, uniform frontmatter additions; batch and document.
- **Default for un-migrated assets:** should the default be `ships:true,
  dogfood:false, status:active` during migration, and should CI warn vs error
  until migration completes?
- **Instructions scope:** are `instructions/` in or out of the classification,
  given they auto-load and #3348 deliberately does not project them?
- **Deprecated distribution:** does `status:deprecated` ship for a grace period
  with a warning, or is it withheld from consumers immediately?

## Dependencies

- `scripts/generate-asset-manifest.ps1` and `asset-manifest.json`.
- `sync.ps1` / `scripts/package-basecoat.ps1` (distribution consumers).
- #3348 dogfood self-install (dogfood consumer).
- #3373 audit (seed data).

## Rollout and Adoption Plan

1. Land the schema + generator + CI validation with a permissive default.
2. Apply and review the seed classification for the current catalog.
3. Wire `sync.ps1` to enforce `ships`, and #3348 to consume `dogfood`.
4. Flip CI from warn to error once migration completes.

## References

- Spec: `docs/spec/3374-asset-distribution-classification.md`
- Issue #3374
- Issue #3348, PR #3373 (dogfood self-install; consumes `dogfood`)
- Issue #3375 (skill visibility conformance bug; distinct from this feature)
- `sync.ps1`, `scripts/generate-asset-manifest.ps1`
