# Multi-Agent Strategy Matrix for BaseCoat

## Purpose

Maps the eight core BaseCoat operational tasks to their best-fit multi-agent
pattern, using two complementary frameworks:

- **Eisenhower Matrix** (urgency × importance) to prioritize automation investment
- **Cynefin Framework** (certainty × cause-effect clarity) to select the right
  agent coordination pattern

---

## Framework Reference

### Eisenhower Quadrants

| Quadrant | Urgency | Importance | Action |
|---|---|---|---|
| Q1 | High | High | Do now — automate with reactive agents |
| Q2 | Low | High | Schedule — use deliberate multi-step pipelines |
| Q3 | High | Low | Delegate — lightweight single agents or webhooks |
| Q4 | Low | Low | Eliminate or fully automate without review |

### Cynefin Domains

| Domain | Characteristics | Best Agent Pattern |
|---|---|---|
| **Simple** | Known cause-effect, best practices clear | Rule-based single agent, no LLM needed |
| **Complicated** | Multiple right answers, requires expertise | Sequential specialist chain |
| **Complex** | Emergent outcomes, probe-sense-respond | Creator-Verifier or deliberative loop |
| **Chaotic** | No discernible cause-effect | Broadcast + triage, then stabilize |

---

## Task Matrix

### 1. Memory Promotion

Moving candidate memories from `contributions/` to `memories/{domain}/`.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q2 — important (durable knowledge), not urgent (weekly cadence) |
| Cynefin | Complicated — needs domain judgment but has clear criteria |
| **Pattern** | **Creator-Verifier**: sweep agent surfaces candidates; curator agent validates scope policy and promotes |
| Decision Book Model | PDCA cycle — plan (scope check), do (PR), check (vote), act (merge) |
| Automation Level | Semi-automated: agent drafts PR, human steward approves |

### 2. Guidance Authoring

Drafting new instruction files, skill SKILL.md, or agent frontmatter.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q2 — important (guidance quality), not urgent (sprint-paced) |
| Cynefin | Complex — no single right answer; emergent through iteration |
| **Pattern** | **Creator-Verifier loop**: author agent drafts, reviewer agent validates lint/structure/conventions, repeat until criteria met |
| Decision Book Model | Ladder of Inference — author climbs from raw need to polished guidance through structured reflection |
| Automation Level | Fully automated with human review gate on PR merge |

### 3. Memory Sweep

Weekly scan of `basecoat-enabled` repos for labelled PRs, issues, CHANGELOGs.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q4 — routine, low urgency, low per-cycle importance |
| Cynefin | Simple — deterministic pattern matching, known labels |
| **Pattern** | **Single scheduled agent**: `sweep-enterprise-memory.ps1` runs via cron, emits YAML candidates |
| Decision Book Model | Pareto principle — focus sweep on high-signal labels (learning:, decision:, convention:) |
| Automation Level | Fully automated; output queued for human promotion review |

### 4. Guidance Validation

Checking that instruction/skill/agent files meet structural and quality criteria.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q1 — urgent (blocks PRs) and important (correctness) |
| Cynefin | Simple — deterministic rules: frontmatter schema, MD lint, required sections |
| **Pattern** | **Rule-based validator agent**: runs on every PR as a check; fails fast with actionable errors |
| Decision Book Model | Checklist Manifesto — fixed validation checklist executed consistently |
| Automation Level | Fully automated (no LLM); GitHub Actions check |

### 5. Contribution Intake

Processing incoming learning submissions from consumer repos.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q3 — high urgency (contributor waiting), lower importance |
| Cynefin | Complicated — scope checks require judgment; format varies by path |
| **Pattern** | **Delegation chain**: intake bot validates format → scope validator agent checks 4-point policy → promotion candidate emitted |
| Decision Book Model | Triage funnel — quick reject on invalid format before expensive scope check |
| Automation Level | Bot-automated intake; human final promotion decision |

### 6. Broadcast / Notification

Notifying subscribers when memories are promoted or guidance is updated.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q3 — high urgency (immediate), low per-event importance |
| Cynefin | Simple — event-driven, deterministic routing |
| **Pattern** | **Pub-Sub broadcast**: promotion event → GitHub Actions dispatch → subscriber workflows (sync, validate, index update) |
| Decision Book Model | Information radiator — push to all interested parties simultaneously |
| Automation Level | Fully automated via `repository_dispatch` events |

### 7. Consumer Onboarding

Enlisting new repos in the `basecoat-enabled` ecosystem.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q4 — neither urgent nor high daily importance |
| Cynefin | Simple — known steps: add topic, create labels, add secret, add workflow |
| **Pattern** | **Single setup agent**: `onboard-basecoat.sh` handles idempotently; `auto-enlist.yml` bulk automates |
| Decision Book Model | Ikea effect — consumer installs it themselves (ownership → adoption) |
| Automation Level | Fully automated; human runs once per repo |

### 8. Compliance / Governance

Ensuring guidance files stay within scope policy and meet quality standards.

| Dimension | Assessment |
|---|---|
| Eisenhower | Q2 — important (governance), not urgent (quarterly audit cadence) |
| Cynefin | Complicated — requires policy knowledge plus file inspection |
| **Pattern** | **Sequential specialist chain**: policy-as-code-compliance agent + memory-curator agent in series; produces audit report |
| Decision Book Model | SWOT analysis per domain — strengths (coverage), weaknesses (gaps), opportunities (new patterns), threats (drift) |
| Automation Level | Semi-automated quarterly workflow; human reviews report |

---

## Pattern Selection Guide

When adding a new BaseCoat operation, use this decision tree:

```text
Is the output deterministic (same input → same output)?
├── Yes → Rule-based single agent (Cynefin: Simple)
└── No → Does it require iteration to reach quality?
    ├── Yes → Creator-Verifier loop (Cynefin: Complex)
    └── No → Does it require specialized knowledge sequence?
        ├── Yes → Sequential specialist chain (Cynefin: Complicated)
        └── No → Is it event-triggered with many recipients?
            ├── Yes → Pub-Sub broadcast (Cynefin: Simple/Chaotic)
            └── No → Delegation chain with triage (Cynefin: Complicated)
```

---

## Summary Table

| Task | Eisenhower | Cynefin | Pattern | Automation |
|---|---|---|---|---|
| Memory Promotion | Q2 | Complicated | Creator-Verifier | Semi (human approve) |
| Guidance Authoring | Q2 | Complex | Creator-Verifier loop | Semi (human review) |
| Memory Sweep | Q4 | Simple | Scheduled single agent | Full |
| Guidance Validation | Q1 | Simple | Rule-based validator | Full (CI check) |
| Contribution Intake | Q3 | Complicated | Delegation + triage | Semi (human promote) |
| Broadcast | Q3 | Simple | Pub-Sub | Full |
| Consumer Onboarding | Q4 | Simple | Setup agent | Full (one-shot) |
| Compliance/Governance | Q2 | Complicated | Sequential specialists | Semi (quarterly) |

---

## Related Documents

- `docs/architecture/multi-agent-orchestration-patterns.md` — implementation patterns
- `docs/multi-agent-bmc.md` — Business Model Canvas for the system
- `docs/memory/PROCESS.md` — memory lifecycle
- Issue [#613](https://github.com/ivegamsft/basecoat/issues/613) — parent investigation
