# Repository Template Standard

This standard defines how new repositories adopt and enforce Base Coat controls from the first commit.

## Goal

- Start every new repository from a pinned, auditable baseline.
- Prevent silent drift from approved standards.
- Keep upgrade paths explicit and reviewable.

## Required Template Assets

Every template repository must include:

- `.github/base-coat.lock.json`
- `.github/workflows/bootstrap-basecoat-template.yml`
- `.github/workflows/enforce-basecoat-template.yml`

The lock file is the source of truth for the approved Base Coat version.

## Optional First-Class Hook Onboarding Assets

Templates that want standardized hook onboarding should include:

- `.github/basecoat-hook-profiles.json`
- `.github/hooks/*.json`
- `scripts/hooks/*`

These assets are optional at the template level, but when present they must be validated as a coherent pack:

1. Profiles must enable or disable whole hook packs, not ad hoc individual handlers.
2. Native JSON files must use runtime event names such as `Stop`, `preToolUse`, `postToolUse`, and `errorOccurred`.
3. Budget threshold handling must be routed through `postToolUse`; do not emit a non-native `OnBudgetExceeded` event in `.github/hooks/*.json`.
4. Every declared bash or PowerShell hook command must resolve to a checked-in script.

## Lock File Contract

`.github/base-coat.lock.json` must include:

- `baseCoatRepo`: upstream repository reference.
- `version`: pinned semantic tag (example: `vX.Y.Z`).
- `installPath`: expected install location (default: `.github/base-coat`).
- `checksumRequired`: boolean for release checksum policy.

Example:

```json
{
  "baseCoatRepo": "YOUR-ORG/basecoat",
  "version": "vX.Y.Z",
  "installPath": ".github/base-coat",
  "checksumRequired": true
}
```

## Bootstrap Requirements

Bootstrap workflow must:

1. Read lock file values.
2. Download the pinned release assets.
3. Install into `installPath`.
4. Verify required baseline directories exist.
5. Fail if lock file and installed version diverge.

## Enforcement Requirements

Enforcement workflow must run on pull requests and pushes to main.

The workflow must fail when:

- lock file is missing or malformed,
- baseline folders are missing,
- installed `.github/base-coat/version.json` does not match locked version,
- pull requests modify Base Coat content directly without an explicit upgrade change path.

Minimum required baseline folders in installed path:

- `instructions/`
- `skills/`
- `prompts/`
- `agents/`

## Upgrade Policy

- Upgrades are pull-request driven only.
- Upgrade pull requests must update lock file and installed Base Coat contents together.
- Upgrade pull requests should include release notes and risk summary.

## Branch Protection Recommendations

Set these as required status checks for template consumers:

- `validate-commit-messages`
- `validate-unix`
- `validate-windows`
- `enforce-basecoat-template`

## Operating Model

- Template owner: platform or COE team.
- Approval required from template owner for lock version changes.
- Release cadence should be explicit (for example monthly or quarterly).

## Adoption Pattern

1. Create repository from template.
2. Run bootstrap workflow.
3. Commit resulting `.github/base-coat` content.
4. Enable enforcement workflow as required status check.
5. Enforce upgrades through standard pull request flow.
