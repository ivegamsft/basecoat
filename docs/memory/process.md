# Memory Contribution Process

This document describes how knowledge produced during agent sessions flows into the
shared `{org}/basecoat-memory` repository and becomes available to all future sessions.

## Memory Tier Overview

```text
L0/L1 — Always-on rules (instruction files, frontmatter)      ← baked in, no lookup
L2    — Team hot index (memory-index.instructions.md)         ← loaded at session start
L2s   — Shared hot index (basecoat-memory/hot-index.md)      ← pulled via sync script
L3    — Episodic (session_store_sql — personal, 7-day TTL)   ← queried on demand
L3s   — Shared deep (basecoat-memory/memories/{domain}/)     ← pulled via sync script
L4    — Semantic (store_memory — permanent tag in session)    ← recalled on demand
```

The gap this process closes: `store_memory` (L4) and episodic sessions (L3) only exist
in the Copilot CLI session store. This pipeline bridges those facts into L3s so every
team member benefits.

## End-to-End Flow

```text
Session produces memory
  └─ store_memory() → session_store_sql (personal cloud store)

Sprint end — agent or steward exports
  ├─ Single memory:  pwsh scripts/sync-shared-memory.ps1 -Export -Subject "domain:key"
  │                  (edit template, then)
  │                  pwsh scripts/sync-shared-memory.ps1 -ExportFile /tmp/edit.md -Subject "domain:key"
  │
  └─ Batch export:   pwsh scripts/contribute-memories.ps1 -InputFile memories.json -Sprint sprint-N
                     (or trigger .github/workflows/memory-contribute.yml via workflow_dispatch)

Both paths create a PR in {org}/basecoat-memory for review
  └─ memories/{domain}/{subject}.md  (candidate)

Memory steward reviews PR
  └─ Validates scope, confidence, wording
  └─ Merges or requests changes

After merge — all agents pull on next session
  └─ pwsh scripts/sync-shared-memory.ps1          (auto: 24h TTL)
  └─ pwsh scripts/sync-shared-memory.ps1 -Force   (manual: immediate)
  └─ Cached in .memory/shared/ (git-ignored)
```

## Consumer Repo Contributions

Any repo can feed learnings back into basecoat memory via two paths:

### Passive (Label-Based Sweep)

`.github/workflows/memory-sweep.yml` runs every Monday and sweeps all repos
with the `basecoat-enabled` GitHub topic. It extracts:

- Merged PRs labelled `learning`, `retrospective`, or `decision`
- Closed issues with the same labels
- CHANGELOG entries within the configured window

Raw candidates (with a structured promotion block per entry) are written to
`basecoat-memory/sweep-candidates/YYYY-MM-DD.md` as a PR for steward review.

**Enlist a repo:**

```sh
gh api repos/{org}/{repo}/topics --method PUT --field names[]=basecoat-enabled
```

**Configure sweep behavior** via `.basecoat.yml` at the repo root
(copy `.basecoat.yml.example` from this repo as a starting point).

### Active Push (submit-learning.ps1)

Consumer repos can submit a structured learning immediately without waiting for
the weekly sweep:

```powershell
pwsh scripts/submit-learning.ps1 `
    -Subject  "ci:agent-pr-approval" `
    -Fact     "Copilot agent PRs have action_required CI until a maintainer pushes an empty commit." `
    -Evidence "https://github.com/myorg/myrepo/pull/42" `
    -Domain   "ci" `
    -Source   "myorg/myrepo" `
    -OpenPR
```

The script validates scope, writes a structured candidate to
`basecoat-memory/sweep-candidates/`, and optionally opens a review PR.

See `docs/memory/contributing.md` for the full consumer guide.

## Memory File Format

Every promoted memory lives at `memories/{domain}/{subject}.md` with this structure:

```markdown
---
subject: "domain:key"
category: "convention"        # convention | anti-pattern | decision | pattern
confidence: 0.90              # 0.0–1.0
created: "YYYY-MM-DD"
applies_to: "all teams"
---

# Short Title

## Pattern

The reusable pattern or rule — ≤ 300 chars, generic, no project-specific references.

## Evidence

- Source: link to originating issue, session, or document

## Does NOT apply to

- Exceptions or overrides
```

## Memory Domains

| Domain | Covers |
|---|---|
| `ci` | GitHub Actions, workflow patterns, CI/CD conventions |
| `git` | Branch hygiene, commit format, squash merge behavior |
| `authoring` | Agent, skill, instruction file conventions |
| `process` | Sprint workflow, branching, PR process |
| `security` | Secret scanning, CodeQL, Dependabot patterns |
| `portal` | Frontend component patterns, React hooks |
| `testing` | Test commands, coverage thresholds |
| `governance` | Approval gates, policy, access control |
| `memory` | Memory system patterns, routing, scoring |
| `infra` | Terraform, cloud configuration |

## Memory Scope Policy

Before calling `store_memory` or contributing to `basecoat-memory`, validate:

1. **Repo-scoped** — Does this apply to _this_ repository's conventions, not a specific
   customer or sub-project?
2. **Generic** — Would another team using BaseCoat find this useful, or is it
   specific to one company's setup?
3. **Durable** — Will this pattern still be true in 3+ sprints?
4. **Actionable** — Does knowing this change what an agent does next?

If any answer is "no", do not promote to `basecoat-memory`. Keep it in L4 session memory
or document it in `docs/` instead.

### Stale Memory Eviction

Memories are reviewed during the quarterly memory audit:

1. Check `confidence` — if confidence was set high but no evidence has accumulated, lower it
2. Check `created` — memories older than 1 year without a `last_validated` update are candidates for removal
3. Check scope — if a pattern was repo-specific and slipped through, remove it

## Memory Steward Responsibilities

The memory steward (a human maintainer or designated agent run) is responsible for:

- Reviewing PRs to `basecoat-memory` weekly
- Promoting candidates from `sweep-candidates/` to `memories/{domain}/`
- Updating `hot-index.md` when high-confidence patterns are promoted
- Running the quarterly memory audit

## Scripts Reference

| Script | Purpose |
|---|---|
| `scripts/sync-shared-memory.ps1` | Pull shared memories to local cache |
| `scripts/sync-shared-memory.ps1 -Export -Subject domain:key` | Generate contribution template |
| `scripts/sync-shared-memory.ps1 -ExportFile f.md -Subject domain:key` | Push single memory as PR |
| `scripts/contribute-memories.ps1 -InputFile m.json -Sprint sprint-N` | Batch contribute memories |
| `scripts/sweep-enterprise-memory.ps1` | Scan enlisted repos for candidates (with structured promotion blocks) |
| `scripts/submit-learning.ps1 -Subject … -Fact … -Evidence …` | Active push from a consumer repo |

## Workflow Reference

| Workflow | Trigger | Purpose |
|---|---|---|
| `memory-sweep.yml` | Weekly Monday 06:00 UTC | Sweep enlisted repos for candidates |
| `memory-contribute.yml` | `workflow_dispatch` | Agent-triggered batch memory push |
| `memory-audit.yml` | Quarterly + `workflow_dispatch` | Validate all memories, evict stale ones |

## Memory Lifecycle

```text
store_memory()                    ← produce (session)
    ↓
contribute-memories.ps1           ← export (sprint end)
    ↓
basecoat-memory PR review         ← validate (steward)
    ↓
memories/{domain}/{subject}.md    ← promote (merge)
    ↓
hot-index.md (if conf ≥ 0.90)    ← loopback (steward)
    ↓
sync-shared-memory.ps1 -Force     ← distribute (all sessions)
    ↓
audit-memories.ps1 -Audit         ← evict (quarterly)
    ↓
deprecated/{domain}/{subject}.md  ← archive (steward PR)
```

## Validation Gate (add to basecoat-memory)

Add a `validate.yml` workflow to your `basecoat-memory` repo that runs on every PR:

```yaml
name: Validate Memories
on:
  pull_request:
    paths: ["memories/**"]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: your-org/basecoat
          path: basecoat
      - uses: actions/checkout@v4
        with:
          path: basecoat-memory
      - name: Validate
        shell: pwsh
        env:
          BASECOAT_SHARED_MEMORY_REPO: ${{ github.repository }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: pwsh basecoat/scripts/audit-memories.ps1 -Validate
```

## Audit Script Reference

```powershell
# Validate all memory files (CI safe, no writes)
pwsh scripts/audit-memories.ps1 -Validate

# Report stale memories
pwsh scripts/audit-memories.ps1 -Audit

# Report and open deprecation PR for stale memories
pwsh scripts/audit-memories.ps1 -Audit -OpenPR

# Update a memory with new evidence
pwsh scripts/audit-memories.ps1 -Update -Subject "ci:copilot-agent-pr" -Evidence "Confirmed in PR #620"

# Deprecate a memory (move to deprecated/)
pwsh scripts/audit-memories.ps1 -Purge -Subject "portal:scan-backend" -Reason "Portal removed in v4.0"
```
