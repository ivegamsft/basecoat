# Learning Model

Base Coat learns from usage in two complementary ways: **personal session
learning** (what this agent learned in this repo) and **shared organizational
learning** (what the whole team has discovered about a domain).

## How Learning Happens

### 1. In-session discovery

During a session the agent:

1. Observes what works (commands, patterns, file paths)
2. Calls `store_memory` to persist the fact with citations
3. Updates `memory-index.instructions.md` if the pattern is hot enough

### 2. Cross-session reinforcement

`session_store_sql` accumulates every turn across all sessions. Patterns that
recur across multiple sessions are candidates for L2 promotion.

Query to find recurring patterns:

```sql
SELECT user_message, COUNT(*) AS frequency
FROM turns
WHERE timestamp > now() - INTERVAL '30 days'
GROUP BY user_message
ORDER BY frequency DESC
LIMIT 20
```

### 3. Organizational knowledge (shared memory)

`scripts/sync-shared-memory.ps1` pulls from `IBuySpy-Shared/basecoat-memory`:

- `hot-index.md` — shared hot-cache entries for the org
- `memories/<domain>.md` — domain-specific knowledge (azure, security, dotnet…)

This knowledge is contributed by any team member running the sync script with
the `-Export` flag after a session that produced durable insights.

---

## Knowledge Taxonomy

Knowledge is classified by **domain** and **confidence tier**:

| Domain | Example facts |
|--------|---------------|
| `azure` | Service connector patterns, App Config key hierarchy |
| `dotnet` | Modernization decision tree, migration playbooks |
| `security` | RBAC patterns, secret scanning policy |
| `agents` | Skill composition rules, agentic workflow structure |
| `ci-cd` | Workflow expression whitelist, deploy patterns |
| `repo` | Build commands, test commands, lint config |

Confidence tiers:

| Tier | Meaning |
|------|---------|
| **established** | Verified across ≥ 3 sessions, no contradictions |
| **provisional** | Observed once or twice, not yet confirmed |
| **deprecated** | Superseded by a newer fact — kept for audit trail |

---

## TRM / HRM Concepts (Exploratory)

Two research directions are being evaluated for future learning improvements:

**Tiny Recursive Model (TRM)** — A small sub-model that operates within the
context of a larger model to handle recursive self-improvement tasks. In the
Base Coat context: a lightweight prompt that takes the current `memory-index`
as input and proposes additions, removals, or re-rankings based on recent
session activity. Evaluated in issue [#574](https://github.com/IBuySpy-Shared/basecoat/issues/574).

**Hierarchical Reasoning Model (HRM)** — A structured reasoning approach that
decomposes complex tasks into a tree of sub-goals, each solved at the
appropriate layer of the memory hierarchy. In Base Coat: routing agent
requests through L0→L1→L2 with each layer either resolving the request or
escalating to the next. Aligns closely with the existing five-layer design.

See `docs/architecture/execution-hierarchy.md` for the current implementation
of HRM-adjacent routing.

---

## Adopter Learning Path

When a team forks Base Coat, the learning model starts cold. Warm-up sequence:

1. **Week 1** — Run `scripts/bootstrap.ps1`. Captures repo structure and
   initial conventions into L4.
2. **Week 2–4** — Normal usage. L3 accumulates session history. Identify
   recurring patterns manually.
3. **Month 2** — First L2 promotion: add the top 3–5 patterns to
   `memory-index.instructions.md`.
4. **Month 3+** — Connect to shared memory repo for org-wide knowledge.
   Run `sync-shared-memory.ps1 -Export` after high-value sessions.

---

## Contributing to Organizational Memory

After a session that produces reusable insights:

```powershell
# Export a specific memory entry to the shared repo
.\scripts\sync-shared-memory.ps1 -Export -Subject "azure:app-config-hierarchy"

# Review what would be exported (dry run)
.\scripts\sync-shared-memory.ps1 -Export -Subject "azure:app-config-hierarchy" -WhatIf
```

> **Note:** In `-Export` mode, `-Subject` is required (format: `domain:key`).
> `-Domain` only filters results in pull/sync mode — it has no effect on exports.

Exported memories are reviewed via PR in `IBuySpy-Shared/basecoat-memory`
before merging. This prevents low-quality or sensitive facts from entering
the shared knowledge base.

---

## Anti-patterns

| Anti-pattern | Why it hurts | Correct approach |
|--------------|-------------|-----------------|
| Storing secrets in memory | Security violation | Never store credentials, keys, or PII |
| Storing user-specific preferences as repo facts | Pollutes shared memory | Use personal store_memory only |
| Promoting too aggressively to L0 | Inflates every agent's context | Require 50 % session threshold |
| Never cleaning up deprecated facts | Stale guidance misleads agents | Run quarterly memory audits |
| Skipping citations | Cannot verify source | Always include file:line or issue reference |
