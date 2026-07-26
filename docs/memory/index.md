# Memory System

The BaseCoat memory system gives AI agents persistent knowledge that survives
session boundaries. Without it, every session starts from scratch — rediscovering
facts, repeating fixes, and rebuilding context that prior sessions already earned.

Memory is organized into five layers, from the fastest (ambient instructions) to
the richest (shared cross-org knowledge). Each layer trades retrieval speed for
storage capacity.

---

## The Five Layers at a Glance

```text
L0  Agent frontmatter          Always loaded, ~200 tokens per agent
L1  Scoped instructions        Always loaded for matching file types, ~500–1,500 tokens
L2  Hot-index (session store)  Fast KV lookup, loaded on demand, ~1,500 tokens
L3  Session DuckDB             Full search, queried when L2 misses, cost: ~5K tokens
L4  Personal store_memory      Persisted across sessions, surfaced as memories{}
    └── Shared promotion path  Cross-team knowledge via basecoat-memory repo
```

The design goal: **answer 80% of questions from L0–L2 without touching L3–L4.**
L3 and L4 are powerful but expensive — reserve them for Novel tasks and
cross-session knowledge transfer.

See [Memory Design](memory-design.md) for the full architectural specification.

---

## What Goes Where

| Memory type | Layer | Example |
|---|---|---|
| Role definition, agent purpose | L0 — agent frontmatter | "You are a security reviewer. Always run SAST first." |
| Universal coding rules | L1 — instructions | `instructions/basecoat-20-lang-governance.instructions.md` |
| Hot facts for this repo | L2 — hot-index | "This repo uses OIDC for Azure auth, not client secrets" |
| Sprint history, session patterns | L3 — DuckDB | Prior session summaries, turn history |
| Reusable patterns across sessions | L4 — store_memory | "check-coherence.ps1 exits 0 unless -Strict is passed" |
| Cross-team, promotable knowledge | Shared promotion | Facts useful to any BaseCoat consumer |

---

## Contributing a Learning

When a session produces a reusable insight, you can contribute it back.
Five paths are available — choose based on your setup and urgency:

| Path | Setup needed | Best for |
|---|---|---|
| Label a PR or issue `learning` | Enlist your repo once | Ongoing passive collection |
| Open a memory-contribution issue | GitHub account only | Zero-setup, one-off |
| Call `submit-learning-callable.yml` | One workflow file | CI-native, any OS |
| Run `submit-learning.ps1` | Org secret or PAT | Windows/PowerShell |
| Run `submit-learning.sh` | Org secret or PAT | Linux/macOS/WSL |

See [Contributing Learnings](contributing.md) for the full guide with examples
for each path.

---

## What Gets Promoted vs Kept Local

Not every learning belongs in shared memory. The memory system has a high bar
for promotion to ensure the shared hot-index stays small and signal-dense.

**Universal (promote):** Patterns that work across any repo, any team, any stack.

- "Enterprise Copilot fleet limit: 3 concurrent agents safe, 4 risky, 5+ = 429"
- "Copilot agent PRs have `action_required` CI until a maintainer pushes an empty commit"
- "Instructions provide uniform enforcement across all agents — per-agent rule duplication is the anti-pattern"

**App-specific (keep local):** Facts true for your repo but not others.

- "Deploy to the AKS cluster named prod-aks-we-01"
- "Team velocity is 28 story points per sprint"
- "Use TypeScript strict mode for this project"

See [Memory Triage](triage.md) for the decision tree, the four-point scope check,
and examples of promotions that were accepted vs declined.

---

## The Promotion Path

```text
Session insight
  │
  ▼
L4 store_memory (your session)
  │  ← passes 4-point scope check?
  ▼
submit-learning.ps1 / submit-learning.sh
  │
  ▼
basecoat-memory/sweep-candidates/   ← PR opened for steward review
  │  ← steward debate: generic? broadly applicable? durable? actionable?
  ▼
memories/{domain}/{subject}.md      ← promoted to shared memory
  │
  ▼
Weekly sync → hot-index.md          ← distributed to all consumers
```

See [Memory Process](process.md) for the end-to-end lifecycle with timing,
review criteria, and rollback guidance.

---

## Setting Up Memory in Your Repo

- **YOUR-ORG org members:** See [Internal Setup](setup-internal.md) —
  one admin secret, then a single onboarding command per repo.
- **External orgs:** See [External Setup](setup-external.md) —
  fine-grained PAT, then one onboarding command.
- **Enlisting a repo for passive sweep:** See [Enlistment](enlistment.md).

---

## References

| Doc | What it covers |
|---|---|
| [Memory Design](memory-design.md) | Five-layer architecture, schema, cache TTL |
| [Learning Model](learning-model.md) | How memories flow from session to shared |
| [Contributing](contributing.md) | Five submission paths with examples |
| [Process](process.md) | Lifecycle, review criteria, timing |
| [Triage Guide](triage.md) | Universal vs app-specific decision guide |
| [Shared Memory Guide](shared-memory-guide.md) | Org-level setup and management |
