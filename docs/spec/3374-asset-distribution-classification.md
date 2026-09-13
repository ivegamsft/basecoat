# Technical Specification: Asset Distribution Classification

## Context

BaseCoat distributes skills, agents, prompts, and instructions to consumer
repositories via `sync.ps1`, and (per #3348/#3373) needs to project a subset of
its own assets into its local session for dogfooding. Neither operation has an
authoritative signal for *which assets ship to consumers* versus *which are
internal to developing BaseCoat*. The existing `visibility` fields encode
surfacing/validation semantics, not distribution, and `sync.ps1` ships whole
trees unconditionally.

Critically, none of these are runtime/harness concerns. The Copilot CLI harness
honors only `name` and `description` — which populate the always-on skill picker
catalog — and skill *bodies* already load on demand via the skill tool. There is
no harness field for hiding a skill from the picker, marking it deprecated,
versioning it, or withholding it from a consumer. Every distribution and
lifecycle signal in this spec is therefore a BaseCoat **build- and sync-time
selection** over the repository tree, not a harness feature: "load on demand"
is already the default, and "hide from picker" / "withhold from consumer" are
achieved by controlling which assets are physically projected into a given
target, not by a runtime flag.

## Scope

- Add distribution (`ships`, `dogfood`) and lifecycle (`status`) classification
  to asset frontmatter as the source of truth, and formalize the existing
  optional `version` (SemVer) as the fourth axis.
- Extend the asset-manifest generator to emit the classification and add CI
  validation + drift detection.
- Wire `sync.ps1` to enforce `ships` and `status` (withhold non-ready and
  `ships:false` assets) and expose a `dogfood` set for the #3348 self-install.
- Apply a reviewed seed classification to the current catalog.

## Out of Scope

- Changing existing `visibility` semantics or any asset content/behavior.
- Implementing the #3348 self-install (only the `dogfood` signal is provided).
- The #3375 skill-visibility conformance fix (separate, already handled).
- A full deprecation lifecycle (auto-removal timelines, tombstones); `status`
  only records the state and gates distribution.
- Any harness/runtime change (e.g., an installed-but-hidden picker state); this
  spec is limited to build-/sync-time selection of repository assets.

## Considered Options

1. **Single `distribution: shipped|internal|both` enum.** Rejected as the
   primary model: collapses two independent decisions (consumer distribution vs
   local dogfood), cannot represent `neither`, and couples the two consumers so
   a change for one silently affects the other. It is retained only as a
   *derived, human-readable label*.
2. **Overload existing `visibility`.** Rejected: skill `visibility` (`public|
   private`) and agent `visibility` (routing tier) already have defined,
   consumed semantics; overloading them conflates surfacing with distribution.
3. **Two orthogonal boolean fields (`ships`, `dogfood`) as source of truth,
   generated into the manifest and validated (recommended).** Expresses all four
   combinations, keeps the two consumers independent, reuses the existing
   generate-from-source + drift-check pattern, and yields a derived label.

This spec implements option 3 for the distribution axis, and adds two
independent, additive axes — lifecycle (`status`) and versioning (`version`) —
that are orthogonal to distribution rather than alternatives to it. See the
Requirement-to-axis mapping for how the four axes cover all stated needs without
a field-per-need.

## Architecture

### Source of truth: frontmatter

Each applicable asset declares its classification in frontmatter across four
orthogonal axes:

```yaml
ships: true            # distributed to consumer repositories
dogfood: true          # projected into BaseCoat's own local session (#3348)
status: active         # experimental | active | deprecated (lifecycle/readiness)
version: 1.2.0         # optional SemVer; already validated when present
```

`ships` and `dogfood` are the two distribution consumers; `status` gates
readiness (an `experimental` or `deprecated` asset can be withheld from
consumers independently of `ships`); `version` is the existing optional SemVer
field, formalized here as the versioning axis. Frontmatter is authoritative
because it travels with the asset and is reviewed in the same PR that changes it.

### Runtime vs. build-time layering (why these are not harness flags)

The harness honors only `name` + `description` (always-on picker) and loads skill
bodies on demand; it ignores every field above. Consequently:

- **On-demand loading** (need: do not pollute context) is already the default —
  only the `description` line is ever always-on. No flag creates it; the lever
  is whether the asset is *present* at all.
- **Hide from picker** has no runtime flag. Picker presence is *derived*: an
  asset appears in a target's picker only if it is physically projected there.
  For consumers that is `ships`; for BaseCoat's own session that is `dogfood`.
- **Withhold from consumers / not-ready / internal** is `ships:false` and/or
  `status` (`experimental`/`deprecated`), enforced by `sync.ps1`.
- **Deprecated** is `status: deprecated`; **versioning** is `version`.

An installed-but-hidden picker state would require a harness feature BaseCoat
does not control and is explicitly out of scope.

### Generated manifest

Extend `scripts/generate-asset-manifest.ps1` to record `ships`, `dogfood`, and
the derived `distribution` label per asset in `asset-manifest.json`. To avoid
churning adoption SHAs and inflating diffs, the generator emits these fields
**only when an asset deviates from the defaults** (`ships:true`,
`dogfood:false`, `status:active`); a default-classified asset carries no
distribution fields, and every manifest reader treats their absence as the
defaults. The manifest is regenerated from frontmatter and is never hand-edited,
mirroring the current manifest contract.

### Consumers

- **Consumer distribution:** `sync.ps1` (and `scripts/package-basecoat.ps1`)
  filter out assets with `ships:false` — and, by default, `status:experimental`
  or `status:deprecated` — before projecting into a consumer's `.github/`.
- **Dogfood self-install (#3348):** consumes the `dogfood:true` set as the
  projection source, replacing the interim category+name allowlist.

### Derived label

`distribution` = `both` (ships and dogfood), `shipped` (ships only), `internal`
(dogfood only). `neither` (both false) is invalid unless the asset is explicitly
`status: deprecated` or `status: experimental` (a staged/retired asset may
legitimately ship nowhere).

## Data Model

| Field | Type | Default (un-migrated) | Consumer |
|---|---|---|---|
| `ships` | boolean | `true` | `sync.ps1` / `package` distribution filter |
| `dogfood` | boolean | `false` | #3348 self-install projection |
| `status` | enum `experimental\|active\|deprecated` | `active` | `sync.ps1` readiness gate; reporting |
| `version` | SemVer string | absent (inherits library version) | manifest `effectiveVersion`; already validated |
| `distribution` (derived) | enum `shipped\|internal\|both\|neither` | derived | manifest/reporting only |

Applicability: skills, agents, prompts. `instructions/` classification is an
open question (they auto-load and #3348 does not project them); the spec's
default is to include them with `dogfood:false` unless decided otherwise.

### Requirement-to-axis mapping

The classification is deliberately minimal: the six stated needs collapse onto
these axes (plus the harness default), with no field per need.

| Need | Axis | Notes |
|---|---|---|
| Load on demand, not always in context | harness default | already true; only `description` is always-on |
| Hide from picker | derived from `ships`/`dogfood` | picker presence = physical projection; no runtime flag |
| Withhold from consumers when not ready/internal | `ships` + `status` | `ships:false` and/or `experimental`/`deprecated` |
| Mark deprecated | `status: deprecated` | gates distribution; label reflects it |
| Version | `version` (SemVer) | existing optional field, formalized |
| Dogfood some internal but not all | `dogfood` | independent of `ships`, so `ships:false,dogfood:true` is expressible |

## API / Interface Contracts

- Generator (`generate-asset-manifest.ps1`): reads `ships`/`dogfood`/`status`
  (and existing `version`) from each asset's frontmatter (applying defaults) and
  emits them plus the derived label.
- Validation (`validate-basecoat.ps1` or a dedicated sub-validator, mirroring
  `validate-skill-visibility.ps1`): asserts each applicable asset has boolean
  `ships`/`dogfood`, a `status` in `experimental|active|deprecated`, a SemVer
  `version` when present, rejects `neither` (unless `status` is `experimental`/
  `deprecated`), and asserts the manifest matches frontmatter (drift check).
- `sync.ps1`: excludes assets that are `ships:false` or (by default)
  `status:experimental`/`status:deprecated` from the consumer overlay.
- Dogfood query: a function/flag exposing the `dogfood:true` set for #3348.

## Security and Privacy

- The classification governs only repository-owned assets; no external input or
  new trust boundary is introduced.
- Enforcing `ships` **reduces** exposure: internal-only tooling can be withheld
  from consumers instead of shipping unconditionally as today.
- The generator/validator read only the repository tree.

## Reliability and Failure Modes

- **Mis-seeded disposition (`ships:false` on a real deliverable):** de-ships it
  from consumers. Mitigation: reviewed seed at approval; conservative
  `ships:true` default for ambiguous assets; a distribution snapshot test that
  fails if the shipped set changes unexpectedly.
- **Manifest drift:** frontmatter changes without regeneration. Mitigation: CI
  drift check (regenerate in a temp path and diff against the committed
  manifest), consistent with the existing manifest contract.
- **Missing/invalid classification:** caught by CI validation; permissive
  default + warn during migration, error after.

## Performance

Generation and validation are bounded directory scans over the catalog
(hundreds of files), run in CI; negligible cost.

## Implementation Plan

1. Define the `ships`/`dogfood`/`status` frontmatter fields and defaults
   (`version` already exists); document them in the skill/agent frontmatter
   reference.
2. Extend `generate-asset-manifest.ps1` to emit the classification + derived
   label; regenerate the manifest.
3. Add CI validation (booleans present, `status` enum, SemVer `version`, no
   `neither` unless staged/deprecated) and a manifest drift check, ideally as a
   dedicated sub-validator mirroring `validate-skill-visibility.ps1`.
4. Apply the reviewed seed classification to the catalog (seeded by the #3373
   audit), conservatively defaulting ambiguous assets to `ships:true`,
   `status:active`.
5. Wire `sync.ps1`/`package` to enforce `ships` and the `status` readiness gate;
   expose the `dogfood` set.
6. Add distribution snapshot tests; flip validation from warn to error once
   migration completes.

## Testing Strategy

- **Unit:** generator emits correct `ships`/`dogfood`/`status`/`version`/label
  from fixture frontmatter; defaults applied for un-migrated assets.
- **Validation:** an asset missing the classification, with an invalid `status`,
  a non-SemVer `version`, or set to `neither` without a staged/deprecated
  `status`, fails CI; a valid asset passes.
- **Distribution:** `sync.ps1` excludes a `ships:false` fixture and a
  `status:deprecated`/`status:experimental` fixture, and includes a
  `ships:true, status:active` fixture; a snapshot test guards the shipped set.
- **Dogfood:** the `dogfood` query returns exactly the `dogfood:true` set,
  including a `ships:false, dogfood:true` internal-only fixture (proving the two
  axes are independent); #3348's self-install (when implemented) consumes it.
- **Layering invariant:** a test asserts picker/consumer presence is derived
  purely from projection (a `ships:false` asset is absent from a synced consumer
  overlay), documenting that no runtime "hidden" flag exists.
- **Drift:** regenerating the manifest yields no diff against the committed file.
- Run `pwsh scripts/validate-basecoat.ps1` and `pwsh tests/run-tests.ps1`.

## Rollout, Migration, and Rollback

- **Rollout:** land schema + generator + validation with a permissive default
  and warn-only CI; apply the reviewed seed; wire consumers; flip to error.
- **Migration:** mechanical, uniform frontmatter additions across the catalog,
  batched and documented per PR-size policy.
- **Rollback:** revert the `sync.ps1` enforcement first (restores current
  ship-everything behavior), then the generator/validation and frontmatter
  fields. No consumer data or external state is affected.

## Observability

- The generator/validator emit counts per bucket (shipped/internal/both) and a
  clear failure listing any unclassified or `neither` assets, so drift and
  migration progress are visible in CI logs.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| De-shipping a real deliverable | Reviewed seed + `ships:true` default + shipped-set snapshot test |
| Manifest churn/adoption-SHA impact | Choose embed vs sibling manifest during implementation to avoid SHA churn |
| Migration breaks CI mid-flight | Permissive default + warn-before-error rollout |
| Two consumers diverge from manifest | Single generated source + drift check |

## Open Questions

- Embed the classification in `asset-manifest.json` or a sibling manifest, to
  avoid churning adoption-detection blob SHAs?
- Are `instructions/` in scope, and if so what is their default `dogfood`?
- Migration default and warn-vs-error timing.
- Should the derived `distribution` label also be written to frontmatter, or
  remain manifest-only to keep a single source of truth?
- Should `sync.ps1` withhold `status:experimental` by default, or ship it behind
  an opt-in consumer flag? (Deprecated is assumed withheld.)
- Does `status:deprecated` still ship for a grace period (with a warning), or is
  it withheld immediately?

## References

- PRD: `docs/prd/3374-asset-distribution-classification.md`
- Issue #3374
- Issue #3348, PR #3373 (dogfood self-install; consumes `dogfood`)
- Issue #3375 (skill visibility conformance bug; distinct)
- `sync.ps1`, `scripts/generate-asset-manifest.ps1`,
  `scripts/validate-skill-workflow-dependencies.ps1`
