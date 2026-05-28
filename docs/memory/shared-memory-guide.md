# Shared Memory Guide

The shared memory repo (`IBuySpy-Shared/basecoat-memory`) extends the personal
session memory layer into an organization-wide knowledge base. Any team member
can contribute discoveries; all consumers benefit immediately.

## Repository Structure

```text
basecoat-memory/
├── README.md
├── CONTRIBUTING.md
├── hot-index.md          ← L2s: shared hot-cache (loaded by sync script)
├── memories/
│   ├── azure.md          ← Domain memories
│   ├── dotnet.md
│   ├── security.md
│   ├── agents.md
│   └── <domain>.md
└── .github/
    └── workflows/
        └── validate-memory.yml
```

---

## Setup

### 1. Create the shared memory repo

If your organization does not yet have a shared memory repo:

```powershell
# Bootstrap creates the repo from the template automatically
.\scripts\bootstrap.ps1 -SharedMemoryRepo
```

Or manually:

```bash
gh repo create <org>/basecoat-memory --private --template IBuySpy-Shared/basecoat-memory
```

### 2. Configure the remote in your repo

Add to `.github/copilot-instructions.md` (or your team's memory-index):

```markdown
Shared memory repo: https://github.com/<org>/basecoat-memory
Run `scripts/sync-shared-memory.ps1` at session start to pull latest.
```

### 3. Pull shared knowledge

```powershell
# Pull all domains (cached for 24h)
.\scripts\sync-shared-memory.ps1

# Force refresh
.\scripts\sync-shared-memory.ps1 -Force

# Check sync status
.\scripts\sync-shared-memory.ps1 -Status

# Pull a specific domain only
.\scripts\sync-shared-memory.ps1 -Domain azure
```

---

## Contributing Knowledge

### Export after a valuable session

```powershell
# Export insights from the current session to the shared repo
.\scripts\sync-shared-memory.ps1 -Export -Domain azure

# What gets exported:
# - Facts stored with store_memory during this session (domain-tagged)
# - Hot-cache entries promoted during this session
```

### Manual contribution

Edit `memories/<domain>.md` directly in a PR:

```markdown
## <fact-title>

**Confidence:** established | provisional
**Source:** <file:line or issue URL>
**Sessions:** <count where this was useful>

<fact body — concise, actionable, with example if helpful>
```

### Review process

All contributions go through a PR review in `basecoat-memory`. The validate
workflow checks:

- Frontmatter presence on all memory files
- No secrets or PII patterns
- Minimum citation quality (source field required)

---

## hot-index.md Format

The `hot-index.md` file is a structured catalog loaded as L2s context:

```markdown
## <domain>: <pattern-name>

**Heat:** hot | warm | cold
**Last accessed:** YYYY-MM-DD
**Sessions:** <count>

<one-sentence summary of the pattern>

→ Full detail: memories/<domain>.md#<anchor>
```

The agent uses heat level and recency to decide whether to load the full
domain memory or rely on the summary.

---

## Namespace Conventions

Domain names are lowercase, hyphen-separated:

| Domain | Contents |
|--------|----------|
| `azure` | Azure service patterns, resource configs, Bicep/Terraform tips |
| `dotnet` | .NET modernization, upgrade paths, EF migration patterns |
| `security` | Auth patterns, secret scanning, RBAC, OIDC federation |
| `agents` | Agent authoring conventions, skill composition, agentic workflows |
| `ci-cd` | GitHub Actions patterns, workflow expression rules, deploy strategies |
| `repo` | Per-repo conventions — build commands, test patterns, lint setup |
| `data` | Data pipelines, schema patterns, medallion architecture |
| `llm` | Prompt engineering, token optimization, model selection |

Create a new domain file when content doesn't fit an existing domain.

---

## Privacy and Security Rules

1. **Never store credentials, API keys, tokens, or connection strings**
2. **Never store personal data** (names, emails, org-internal handles)
3. **Repo-specific secrets stay in the source repo** — don't export them
4. **Public-safe content only** — treat the memory repo as potentially
   readable by any org member

The `validate-memory.yml` workflow scans for common secret patterns and
blocks the PR if any are found.

---

## Sync Architecture

```text
Session start
    │
    ▼
sync-shared-memory.ps1
    │  checks TTL cache (~/.copilot/shared-memory-cache/)
    │
    ├─── cache fresh ──▶ load from cache (no network)
    │
    └─── cache stale ──▶ gh api fetch from basecoat-memory
                         │
                         ├── hot-index.md  → L2s context injected
                         └── memories/*.md → available for L3s queries
```

Cache TTL: 24 hours by default. Override with `-Force`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `sync-shared-memory.ps1` 404 | Shared repo not created | Run `bootstrap.ps1 -SharedMemoryRepo` |
| Stale knowledge loaded | TTL not expired | Run with `-Force` |
| Export creates empty PR | No domain facts in current session | Add domain tag to `store_memory` calls |
| validate-memory fails on secret scan | Accidentally included a token | Remove the value, replace with `<REDACTED>` |
