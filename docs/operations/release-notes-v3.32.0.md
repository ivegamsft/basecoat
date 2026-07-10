# Release Notes v3.32.0

Release date: 2026-06-14

## Highlights

- Added environment routing and infra validation capabilities.
- Hardened publish/release workflow reliability.
- Refreshed docs/governance guidance and inventory consistency.

## Change summary

### Added

- Added operation-context-resolver environment routing skill coverage and environment-audit-drift infrastructure validation. (#1624, #1636)
- Added governance/metadata hardening updates for agent catalog consistency. (#1625)

### Changed

- Updated Auto model-baseline documentation with explicit upshift triggers and integrated token-optimization guidance. (#1637, #1631)
- Updated dependency maintenance for `mcp/basecoat-extension` (`esbuild` dev dependency bump). (#1638)

### Fixed

- Fixed publish-to-production workflow dispatch tag resolution and reduced false workflow-agent failure issue noise. (#1632, #1629)
- Fixed stale docs inventory counts and release-impact-advisor unsupported model handling. (#1620, #1618)

## Breaking changes

- None identified.
