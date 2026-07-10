# Shared Memory Architecture

Defines how organizations using BaseCoat can share institutional knowledge across teams through a private memory repository.

> Related: `docs/sqlite-memory.md`, `instructions/basecoat-10-core-memory-index.instructions.md`, `agents/basecoat-10-core-memory-curator.agent.md`

---

## The Two-Tier Memory Model

```text
┌─────────────────────────────────────────────────────────────┐
│  Tier 1 — Personal / Team Memory  (private, local)          │
│  • SQLite store (.db file, git-ignored)                     │
│  • Session state (.copilot/session-state/, git-ignored)     │
│  • store_memory calls from current session                  │
│  • Hot index (memory-index.instructions.md) — team-tuned   │
│                                                             │
│  Owned by: the team. Never leaves the team's environment.   │
└────────────────────┬────────────────────────────────────────┘
                     │  promote via PR (threshold: 5+ sessions,
                     │  cross-team relevance, memory-curator review)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  Tier 2 — Org Shared Memory  (private repo, pull-cached)    │
│  • {org}/basecoat-memory  — private GitHub repo             │
│  • Curated, PR-gated, memory-curator reviewed               │
│  • Organized by domain:subject namespace                    │
│  • Hot index synced daily (≤500 tokens at session start)    │
│  • Deep memories loaded on demand by subject                │
│                                                             │
│  Owned by: the organization. All teams read; PR to write.   │
└─────────────────────────────────────────────────────────────┘
```text

---

## Setting Up the Shared Memory Repo

### 1. Create the repo

```bash
gh repo create {org}/basecoat-memory --private --description "Shared AI agent memory for BaseCoat"
```text

### 2. Initialize structure

```text
basecoat-memory/
├── README.md                    # What this repo is, how to contribute
├── CONTRIBUTING.md              # Contribution rules and PR template
├── hot-index.md                 # L2 shared hot cache (≤500 tokens, curated)
├── memories/
│   ├── ci/                      # CI, GitHub Actions, workflow patterns
│   ├── security/                # Security decisions and constraints
│   ├── architecture/            # Cross-team architectural decisions
│   ├── testing/                 # Test patterns and conventions
│   ├── tooling/                 # Tool-specific patterns (gh, az, docker)
│   └── {domain}/                # Add domains as your org grows
└── .github/
    ├── workflows/
    │   └── validate-memory.yml  # Memory curator validation on PR
    └── PULL_REQUEST_TEMPLATE.md # Contribution PR template
```text

### 3. Configure BaseCoat to pull from it

Add to your fork's `.env` or repo secrets:

```bash
BASECOAT_SHARED_MEMORY_REPO="{org}/basecoat-memory"
BASECOAT_SHARED_MEMORY_TOKEN="ghp_..."  # read-only PAT scoped to the memory repo
```text

Then run the sync script at session start:

```bash
pwsh scripts/sync-shared-memory.ps1
```text

---

## The `hot-index.md` File

The shared hot index mirrors the structure of `instructions/basecoat-10-core-memory-index.instructions.md` but contains only org-wide patterns. It is injected at session start (≤500 tokens). Deep memories are loaded on demand by subject.

```markdown
# Shared Memory Hot Index

Last synced: {date}
Memories: {count} entries across {N} domains

## Trigger Map

### {domain}
| Trigger | Pattern | Subject | Confidence |
|---|---|---|---|
| ... | ... | domain:subject | 0.90 |
```text

---

## Contribution Flow

### From personal → shared

```text
1. Pattern appears in your session's store_memory 5+ times
2. You identify it as cross-team useful (not project-specific)
3. Export the memory:
     pwsh scripts/sync-shared-memory.ps1 -Export -Subject "domain:subject"
4. Opens a PR to {org}/basecoat-memory with the memory formatted as a markdown file
5. Memory curator agent reviews the PR:
     - Is it generic enough for other teams?
     - Does it duplicate an existing memory?
     - Is the subject namespace correct?
     - Is it free of org/project-specific references?
6. Approved → merged → available to all teams on next sync
```text

### PR template for memory contributions

```markdown
## Memory Contribution

**Subject:** `{domain}:{subject}`
**Category:** fact | preference | decision | convention
**Confidence:** 0.XX (from N sessions of validation)

### The Memory

{content — max 200 chars, generic, no project-specific references}

### Evidence

- Validated in N sessions over {time period}
- Applies to: {teams or contexts this is relevant for}
- Does NOT apply to: {exceptions}

### Source

{link to session, issue, or document that originated this}
```text

---

## Subject Namespace

Use `{domain}:{subject}` to prevent collisions across teams with different stacks.

| Prefix | Use for |
|---|---|
| `ci:` | GitHub Actions, CI/CD patterns |
| `security:` | Auth, secrets, access control decisions |
| `arch:` | Cross-cutting architectural decisions |
| `testing:` | Test patterns, coverage conventions |
| `tooling:` | CLI tools, scripts, build tools |
| `api:` | API design decisions |
| `dotnet:` | .NET-specific patterns |
| `python:` | Python-specific patterns |
| `portal:` | Internal portal / dashboard patterns |
| `agent:` | Agent authoring conventions |

**Never use bare subjects like `testing` or `auth`** — always namespace.

---

## Retrieval Model at Session Start

```text
1. Load team hot-index (instructions/basecoat-10-core-memory-index.instructions.md)   — always, ~400 tokens
2. Load shared hot-index (basecoat-memory/hot-index.md)              — if synced, ~400 tokens
3. On domain match: load deep memories from memories/{domain}/        — on demand, per subject
4. Deep memories not found locally: gh api to fetch from shared repo  — fallback
```text

Total session-start cost: ~800 tokens for both hot indexes combined. Deep loads only when the task domain matches.

---

## Sync Script Behavior

`pwsh scripts/sync-shared-memory.ps1`:

- **Default (pull):** fetch latest `hot-index.md` + any subjects matching current task domain; cache to `.memory/shared/` (git-ignored); TTL = 24 hours
- **`-Force`:** bypass TTL, re-sync everything
- **`-Export -Subject "domain:subject"`:** package a local memory for PR contribution
- **`-Status`:** show last sync time, memory count, cache age

---

## Governance

- **Read access:** all teams with access to the memory repo
- **Write access:** PR only — no direct commits; reviewed by memory-curator agent
- **Merge authority:** designated memory stewards (typically platform/architecture team)
- **Pruning cadence:** quarterly — memory-curator agent reviews confidence and recency, proposes deprecations
- **No project-specific content:** memories must be generic; references to specific repos, issue numbers, or internal systems are rejected in PR review
- **No secrets:** same rule as BaseCoat main — ever

---

## Why Not a Shared Database?

| | Git repo | Shared database |
|---|---|---|
| Audit trail | ✅ Full history, blame, diff | ⚠️ Requires separate logging |
| Human review | ✅ PR workflow | ❌ Direct writes |
| Conflict resolution | ✅ Git merge | ⚠️ Requires locking |
| Infra dependency | ✅ None — just GitHub | ❌ Requires service uptime |
| Offline use | ✅ Local clone | ❌ Requires connectivity |
| Slow-changing knowledge | ✅ Right fit | ⚠️ Overkill |
| Real-time updates | ❌ Daily sync lag | ✅ Immediate |

For institutional knowledge (slow-changing, high-value, needs human review), git wins. For ephemeral session data, local SQLite wins. A shared live database adds infra complexity for a benefit you don't need.
