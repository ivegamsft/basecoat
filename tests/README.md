# Base Coat Tests

This directory contains smoke tests for the scaffolding repository.

## Scope

- Validate core repository structure and frontmatter checks
- Verify packaging scripts create release artifacts
- Verify git hook installation script configures `.githooks`
- Verify commit message scanner detects and rejects sensitive commit messages
- Verify token cost observability thresholds and auto-compact signals
- **NEW:** Adoption scanner parameter parsing and output formats (table, json, markdown)
- **NEW:** Workflow guardrails validation (timeout-minutes, concurrency, SHA pinning)

## Run Tests

PowerShell:

```powershell
./tests/run-tests.ps1
```

Bash:

```bash
bash tests/run-tests.sh
```

Both test runners are designed to fail fast with clear messages.

## Test Files

### `adoption-scanner-tests.ps1`

Tests for `scripts/adoption/detect-basecoat.ps1` covering:

- Parameter validation (Org, BasecoatRepo, OutputFormat)
- Output format structures (table, json, markdown)
- Asset type detection (agent, instruction, prompt)
- Sync path calculation
- Coverage percentage calculations
- Stale asset flagging
- Copilot seat data structures

**Key tests:**

- OutputFormat must be one of: table, json, markdown
- JSON output must include scan_date, org, source, repos, copilot_seats
- Markdown output must include table format with repo summary
- Asset types correctly categorized by file extension
- Coverage calculated as (synced / total_source_assets) * 100

### `workflow-guardrails-tests.ps1`

Tests for workflow compliance in `.github/workflows/*.yml` covering:

- **timeout-minutes**: All jobs have explicit timeout settings
- **concurrency**: Workflows define concurrency groups with cancel-in-progress
- **SHA pinning**: All action `uses:` statements pin to commit SHAs (not @main/@v)
- **permissions**: Workflows define restrictive permissions
- **shell safety**: Detection of potential shell injection risks
- **artifact retention**: Upload steps include retention-days
- **checkout pinning**: Checkout actions pinned to specific versions
- **matrix bounds**: Matrix strategies have reasonable parallelism
- **job naming**: Jobs have descriptive names

### `token-status-tests.ps1`

Tests for `scripts/token-status.ps1` covering:

- JSON contract fields for session token/event status
- Auto-compact trigger thresholds (400 events or 50M input tokens)
- Warning marker thresholds (ratio >= 300x, events >= 500, input tokens >= 50M)
- Input file parsing for reusable session metric snapshots
