# Install Payload Policy

This document defines what files are included in and excluded from
Base Coat consumer install payloads, and how those exclusions are enforced.

## Allowed Files

Consumer install payloads (`base-coat-<version>.zip`, `base-coat-<version>.tar.gz`,
and `basecoat-ghcp.zip`) include:

- `agents/` — agent definition files (`*.agent.md`)
- `skills/` — skill directories (each containing `SKILL.md` and supporting files)
- `instructions/` — instruction files (`*.instructions.md`)
- `prompts/` — prompt template files (`*.prompt.md`)
- `docs/` — consumer-facing documentation
- `scripts/` — sync and utility scripts (`sync.sh`, `sync.ps1`, and others)
- `examples/` — example configurations
- `.github/` — workflow templates for consumers
- `.githooks/` — git hook scripts
- `README.md`, `CHANGELOG.md`, `INVENTORY.md`
- `version.json`, `asset-manifest.json`
- `basecoat-metadata.json`, `CATALOG.md` (GHCP zip only)

## Excluded Files

The following are **explicitly excluded** from all consumer install payloads:

| Pattern | Reason |
|---|---|
| `eval.yaml` | Behavioral eval metadata — internal testing only |
| `*.agent.eval.yaml` | Agent-specific eval definitions — internal testing only |
| `mkdocs.yml` | Docs-site build config — not consumer guidance |

## Enforcement

Exclusions are enforced at two layers:

### 1. Package Scripts

Both packaging scripts remove eval files immediately after staging content:

- **`scripts/package-basecoat.sh`** — uses `find ... -delete` to remove
  `eval.yaml` and `*.agent.eval.yaml` from `dist/stage/skills` and `dist/stage/agents`
- **`scripts/package-basecoat.ps1`** — uses `Get-ChildItem` + `Remove-Item` to
  remove the same patterns, then verifies zero leaks remain (throws on failure)
- **`.github/workflows/package-basecoat.yml`** (GHCP zip step) — runs `find ... -delete`
  on `dist/ghcp-stage/skills` and `dist/ghcp-stage/agents` before zipping

### 2. CI Verification Step

The `package-basecoat.yml` workflow includes a **"Verify no eval metadata in
install artifacts"** step that runs after all staging and before upload. It scans
both `dist/stage` and `dist/ghcp-stage` for any remaining eval files and fails
the workflow with a `::error::` annotation if any are found.

This ensures that a packaging script regression cannot silently ship eval metadata
to consumers.

## Adding New Exclusions

To exclude a new file pattern from install payloads:

1. Add a `find ... -delete` (or `Remove-Item`) call in `scripts/package-basecoat.sh`
   and `scripts/package-basecoat.ps1` after the staging copy step.
2. Add the same pattern to the GHCP zip prune block in `.github/workflows/package-basecoat.yml`.
3. Add the corresponding `grep -q` check to the "Verify no eval metadata" CI step
   in the same workflow.
4. Update the exclusion table in this document.
