# Latest Release Notes

## 4.6.0 - 2026-10-06

### Added

- Add explicit `ship-it: <goal>` and `spec-2-prod: <goal>` aliases for existing gated delivery intents with qualified source approval, non-placeholder scope, and separate delivery authorization (#3493).
- Add auditable pre-approval evidence and an isolated evidence foundation for unattended ship-it preparation without fabricating issue approval or bypassing delivery gates (#3487, #3489).
- Add curated local dogfood installation for BaseCoat development (#3473).
- Add isolated merge-group readiness checks and a repository-scoped native merge-queue activation guard; readiness evidence does not itself authorize queue bypass (#3506, #3509).

### Changed

- Treat `feature:` as issue/spec/draft intake rather than automatic delivery; source provenance, approved scope, required checks, actor permissions, and explicit delivery evidence remain required (#3493).
- Enforce batch decomposition for independently deliverable units above 15 files or 300 changed lines while preserving cohesive single-unit release metadata; mechanical exceptions require reproducible evidence and qualified current-head approval (#3485, #3491).
- Preserve independent approval, required checks, branch and merge protections, serialized merges, XXL qualified review, production environment approval, rollback evidence, and post-release verification (#3485, #3491, #3493).
- Refresh only previously selected factory-owned consumer workflows after pinned sync, validate installed payloads and active workflows, and fail closed on partial installation or invalid ownership (#3486).
- Normalize model-policy selectors while preserving supported default routing (#3498).
- Recover exact native merge-queue verification and release-label handling for merge groups (#3514).
- Distinguish installed consumer paths from source-repository paths in downstream onboarding guidance (#3508).

### Fixed

- Correct downstream workflow-name replacement without duplicate YAML keys (#3468).
- Close public-mirror identifier gaps without loosening publication controls (#3471).
- Format release validation reports consistently (#3497).
- Clarify review-only and namespace activation routing so review requests do not trigger write-capable delivery flows (#3502).
- Enforce `distribute:false` instruction exclusions in consumer payloads (#3516).
- Honor live mode for ship-it comment directives and scope ship-it build-guard tokens to the target repository (#3525, #3524).
- Honor explicit delivery holds at merge boundaries, including automation refresh PRs (#3526).
- Give the retro facilitator authenticated Actions access required for its workflow operations (#3527).
- Emit complete intake-contract metadata on automation and model-capability refresh PRs (#3529, #3533).

### Documentation

- Record reviewed intake, pre-approval, decomposition, consumer-refresh, release verification, and workflow-name contracts (#3478, #3479, #3480, #3467, #3434, #3496).
- Version host-aware frontmatter semantics and examples (#3503).
- Link PR intent to capture-plan proof in intake documentation (#3511).
- Publish v4.5.2 release notes and refresh dependency-graph and token-context reports (#3449, #3451, #3452, #3510, #3515).

### Consumer Upgrade

This section describes the proposed release payload, not proof that `v4.6.0`
is published. Pin `v4.6.0` only after the release owner verifies the final merged
candidate, approved publication, source and production-mirror artifacts,
checksums, matching tag/archive/installed version, provenance, and consumer
acceptance.

Use the supported rollout-basecoat flow in an isolated consumer worktree:
capture owned active workflow selection before sync, resolve the configured
sync entrypoint, run a full pinned compatible-payload refresh, onboard only
captured workflow targets, and run the installed consumer validator. Verify
installed intent routing, ship-it runtime/evaluator, distribution exclusions,
active workflow contracts, merge-boundary holds, and release/decomposition
behavior, not only files on BaseCoat `main` or a version string. Repeat refresh
must be idempotent and preserve repository-owned content. Review the persistent
`.basecoat.yml` pin and imported changes through normal consumer PR gates.

The release owner must re-inventory the final candidate and update these notes,
date, and manifest before publication if additional PRs land.
