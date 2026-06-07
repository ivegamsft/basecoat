# {org} BaseCoat Shared Memory

Private repository for shared AI agent knowledge across all teams using BaseCoat.

## What this is

This repo is the organization's shared memory layer for BaseCoat agents. It contains curated, peer-reviewed patterns that have proven useful across multiple teams and sessions. It is the L2/L3 shared tier of the [BaseCoat memory hierarchy](https://github.com/{org}/basecoat/blob/main/docs/shared-memory.md).

**Not in here:**
- Project-specific knowledge (stays in your team's local SQLite)
- Session state or ephemeral context
- Secrets, credentials, or internal system references

## Structure

```
hot-index.md          # Shared L2 hot cache (≤500 tokens, loaded at session start)
memories/
  ci/                 # CI, GitHub Actions, workflow patterns
  security/           # Security decisions and constraints
  architecture/       # Cross-team architectural decisions
  testing/            # Test patterns and conventions
  tooling/            # CLI tools, scripts, build tools
  api/                # API design decisions
  {domain}/           # Add domains as your org grows
```

## Using shared memories

Configure in your BaseCoat fork:

```bash
export BASECOAT_SHARED_MEMORY_REPO="{org}/basecoat-memory"
```

Then sync at session start:

```bash
pwsh scripts/sync-shared-memory.ps1
```

## Contributing a new memory

See [CONTRIBUTING.md](CONTRIBUTING.md). Short version: open a PR with a new file in `memories/{domain}/`. The memory-curator agent will review it.

## Governance

- **Read:** all team members with repo access
- **Write:** PR only — no direct commits
- **Review:** memory-curator agent + designated memory steward
- **Pruning:** quarterly review by platform/architecture team
