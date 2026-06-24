# AIDL Portfolio Project Bootstrap Manifest and Validator

Issue #1741 introduces a reusable bootstrap workflow for repo-scoped GitHub Projects.
It defines canonical fields, views, and rule defaults in a manifest, validates drift,
and applies only safe additive changes.

## Artifacts

1. Manifest schema: `docs/specs/aidl-portfolio/project-bootstrap-manifest.schema.json`
2. Baseline manifest: `docs/specs/aidl-portfolio/project-bootstrap-manifest.json`
3. Bootstrap script: `scripts/aidl-portfolio-project-bootstrap.ps1`

## Modes

1. `validate`: Validate manifest and emit drift report; exits non-zero when additive creates or mismatches are detected.
2. `dry-run`: Plan additive creates and report drift without changing project state.
3. `apply`: Apply additive creates only; never delete or rewrite mismatched config.

All modes require at least one current-state source:

1. Live fields: `-Owner` + `-ProjectNumber`
2. Snapshot state: `-CurrentStatePath`

## Dry-run against a state snapshot

```powershell
pwsh -File scripts/aidl-portfolio-project-bootstrap.ps1 `
  -ManifestPath docs/specs/aidl-portfolio/project-bootstrap-manifest.json `
  -Mode dry-run `
  -CurrentStatePath .\tmp\project-state.json `
  -JsonReportPath artifacts\aidl-portfolio-project-bootstrap\bootstrap-report.json `
  -MarkdownReportPath artifacts\aidl-portfolio-project-bootstrap\bootstrap-report.md
```

## Apply missing fields to a live project

```powershell
pwsh -File scripts/aidl-portfolio-project-bootstrap.ps1 `
  -ManifestPath docs/specs/aidl-portfolio/project-bootstrap-manifest.json `
  -Mode apply `
  -Owner IBuySpy-Shared `
  -ProjectNumber 1
```

## Reports

Each run produces:

1. **Machine-readable report** (`bootstrap-report.json`) with summary counts, planned/applied actions, and drift findings.
2. **Human-readable report** (`bootstrap-report.md`) with action tables and drift details.

## Idempotency contract

The script is additive-only:

1. Live apply (`-Owner` + `-ProjectNumber`) creates missing supported fields only (`single_select`, `text`, `number`, `date`).
2. Snapshot apply (`-CurrentStatePath`) can append missing fields, views, and rules in the local state file.
3. Existing mismatches are always reported as drift and never rewritten automatically.
4. Re-running after a successful apply produces no new create actions unless new drift is introduced.
