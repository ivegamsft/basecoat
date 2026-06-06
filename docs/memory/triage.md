# Memory Triage: Universal vs App-Specific

Not every learning belongs in shared memory. The most common mistake is
submitting something true — even genuinely useful — that only applies to
one codebase, one org's infrastructure, or one team's workflow. Shared
memory only carries value if every consumer of it can act on it.

This guide covers how the steward team triages candidates and how contributors
can self-screen before they submit.

---

## The Core Question

> **Would another team using BaseCoat on a completely different codebase find
> this useful and act on it?**

If yes: candidate for shared memory.
If no: keep it in your repo's local memory (L2 hot index or L4 personal store).
If maybe: it needs evidence from more than one source before promotion.

---

## The Decision Tree

```text
Is the learning free of product names, internal system names, and org-specific tooling?
│
├─ No  → App-specific. Keep in repo memory. Do not submit.
│
└─ Yes → Would another team using BaseCoat on a different stack encounter this?
          │
          ├─ No  → Stack-specific. Submit only if the domain tag scopes it
          │         (e.g., domain: dotnet). Still must pass all four criteria.
          │
          └─ Yes → Has it held across ≥ 3 sprints or ≥ 2 independent sources?
                    │
                    ├─ No  → Too early. Mark as candidate in your L2 index.
                    │         Re-evaluate after more evidence accumulates.
                    │
                    └─ Yes → Submit. The steward team will debate scope and wording.
```

---

## The Four-Point Scope Check

The steward team applies all four before promoting any candidate:

| Criterion | Question | Fail example |
|---|---|---|
| **Generic** | Free of product names, internal systems, org-specific tooling? | "Always use our internal OIDC provider" |
| **Broadly applicable** | Would another BaseCoat team find this useful? | "Set AKS node pool to 3 for our prod cluster" |
| **Durable** | Has it held true across ≥ 3 sprints or ≥ 2 similar incidents? | A pattern observed once, not yet verified |
| **Actionable** | Would a team actually change behavior based on this? | "Copilot is sometimes slow" |

All four must be **yes** for promotion.

---

## Examples: What Gets Promoted vs Declined

### ✅ Promoted to shared memory

> "Enterprise Copilot fleet limit: max 3 concurrent background agents is safe."

- Generic: yes — no org names, no internal systems
- Broadly applicable: yes — any team using fleet dispatch hits this
- Durable: yes — hit consistently across Sprint 24, confirmed in multiple orgs
- Actionable: yes — teams immediately changed wave sizes

> "Copilot agent PRs have `action_required` CI until a maintainer pushes an empty commit."

- Generic: yes — it's a GitHub platform behavior, not org-specific
- Broadly applicable: yes — any org using GitHub Copilot coding agent faces this
- Durable: yes — consistent across multiple repos over multiple months
- Actionable: yes — add empty-commit step to unblock PRs

> "Instructions provide uniform enforcement across all agents; per-agent rule duplication is the anti-pattern."

- Generic: yes — describes how the BaseCoat instruction layer works
- Broadly applicable: yes — foundational to any BaseCoat adoption
- Durable: yes — architectural constant since v0.1.0
- Actionable: yes — governs where new rules go

---

### ❌ Declined (app-specific)

> "Always use TypeScript strict mode for this project."

- Broadly applicable: ❌ — only relevant to one codebase's conventions
- **Decision:** Keep in repo's `.github/copilot-instructions.md`. Do not submit.

> "Deploy to the AKS cluster named prod-aks-we-01."

- Generic: ❌ — internal system name
- **Decision:** Repo-local memory only.

> "The sprint velocity for Team Infra is 28 points."

- Generic: ❌ — team-specific metric
- Broadly applicable: ❌ — meaningless to other teams
- **Decision:** Not a memory candidate at all. Close the issue.

> "Rate limit recovery: wait 90 seconds after a 429."

*Wait — is this universal or app-specific?*

The specific number (90s) is derived from BaseCoat's own experience.
The pattern (wait + reduce concurrency after 429) is universal.

- **What got promoted:** The pattern and the rate limit floor (3 concurrent = safe).
- **What stayed local:** The exact 90s recovery time (implementation detail that varies by enterprise tier).

This is the most common triage call: **promote the pattern, not the specific value.**

---

## The Debate: How Stewards Decide

When a candidate is ambiguous — passing some criteria, failing others — the
steward team debates via the PR thread before merging to `basecoat-memory`.

Typical debate questions:

1. **"Would the wording work for a team on a completely different stack?"**
   If you have to imagine them already knowing your context, it's not generic enough.

2. **"Is this prescriptive or descriptive?"**
   Shared memory should be prescriptive ("do X, not Y") not descriptive ("we did Y last sprint").

3. **"Is the evidence from one source or many?"**
   Single-source patterns get flagged as `confidence: 0.60` and set to probationary status.
   Cross-source patterns get `confidence: 0.80+` and full promotion.

4. **"Does this conflict with an existing memory?"**
   If a new learning contradicts a promoted one, the steward calls a synchronous review
   rather than silently overwriting.

---

## What To Do With App-Specific Learnings

App-specific learnings still have value — just not in shared memory.

| Store here | When |
|---|---|
| `.github/copilot-instructions.md` | Always-on rules for your repo's agents |
| `memory-index.instructions.md` | Hot facts that every session in your repo should know |
| `store_memory` (personal L4) | Facts relevant to your own sessions — not team-wide |
| Repo wiki / ADR | Architecture decisions that belong in your repo's docs |

The threshold for shared submission is high by design. It ensures that the
hot index (loaded at every session start) stays small and signal-dense.
A bloated shared memory is worse than a sparse one.

---

## Memory Confidence Levels

When submitting, set confidence honestly:

| Level | Value | Meaning |
|---|---|---|
| Established | 0.90–1.0 | Verified across ≥ 5 independent sessions or sources |
| Tested | 0.75–0.89 | Observed across ≥ 3 sessions; not yet cross-org confirmed |
| Probationary | 0.60–0.74 | Single strong source; awaiting corroboration |
| Hypothesis | < 0.60 | Promising but unverified — do not submit to shared memory yet |

The steward team will adjust confidence during review if evidence doesn't
match the submitted level. Overclaiming confidence is the fastest way to
get a submission declined.

---

## References

- [Contributing Learnings](contributing.md) — the five submission paths
- [Memory Process](process.md) — end-to-end lifecycle
- [Memory Design](memory-design.md) — the five-layer hierarchy
- [Shared Memory Guide](shared-memory-guide.md) — org-level setup
