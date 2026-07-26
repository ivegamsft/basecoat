# Business Model Canvas — BaseCoat Multi-Agent Guidance System

## Purpose

Applies the [Business Model Canvas](https://en.wikipedia.org/wiki/Business_model_canvas)
(Osterwalder & Pigneur, 2010) to the BaseCoat multi-agent system. Revenue is measured
in guidance adoption and knowledge quality, not money.

---

## Canvas Overview

```text
┌─────────────────┬──────────────┬─────────────────┬──────────────────┬──────────────────┐
│  Key Partners   │ Key          │  Value          │  Customer        │  Customer        │
│                 │ Activities   │  Propositions   │  Relationships   │  Segments        │
│                 ├──────────────┤                 │                  │                  │
│                 │ Key          │                 │                  │                  │
│                 │ Resources    │                 │                  │                  │
├─────────────────┴──────────────┴─────────────────┴──────────────────┤  (Channels       │
│  Cost Structure                │  Revenue Streams                   │   between        │
│  (what we spend)               │  (what we gain)                    │   Value Prop     │
│                                │                                    │   and Segments)  │
└────────────────────────────────┴────────────────────────────────────┴──────────────────┘
```

---

## 1. Customer Segments

The agents and humans who consume BaseCoat guidance:

| Segment | Description | Size Estimate |
|---|---|---|
| **Internal Teams** | IBuySpy-Shared org members using agents/skills/instructions | Primary (10–50 teams) |
| **Enterprise Contributors** | Repos that both consume and contribute learnings back | Growing (basecoat-enabled) |
| **External Organizations** | Teams outside IBuySpy-Shared adopting BaseCoat | Secondary |
| **Copilot Agents** | AI agents whose behavior is shaped by instructions/skills | End consumer |
| **Memory Stewards** | Humans who review and promote candidate memories | Governance role |

---

## 2. Value Propositions

What BaseCoat provides that no consumer builds alone:

| Proposition | For Whom | Differentiator |
|---|---|---|
| **Curated shared memory** | All agents | Cross-team learnings in one place; no repeated mistakes |
| **Validated guidance** | Teams authoring new agents | Lint, structure, and scope checks built in |
| **Friction-graded contribution** | Any team, any toolset | 5 paths from zero-setup issue form to PowerShell script |
| **Org-level secret propagation** | Internal enterprise teams | One admin action → zero per-repo config |
| **Automated sweep** | Memory stewards | Weekly candidate surfacing from `basecoat-enabled` repos |
| **Multi-agent templates** | Platform engineers | Tested patterns (creator-verifier, pub-sub, delegation) |

---

## 3. Channels

How guidance reaches consumers:

| Channel | Mechanism | Pull or Push |
|---|---|---|
| `.memory/shared/` sync | `sync-shared-memory.ps1` runs in CI | Pull (per-repo) |
| GitHub Copilot CLI session | Memories injected by session store | Pull (per session) |
| Starter workflow UI | `.github/workflow-templates/` appears in Actions | Pull (org-level) |
| Memory sweep candidates | YAML promotion blocks emailed/PR'd to stewards | Push |
| `repository_dispatch` events | Broadcast to all subscriber repos | Push |
| `basecoat-enabled` topic | Makes repos discoverable to sweep | Discovery |

---

## 4. Customer Relationships

How BaseCoat interacts with each segment:

| Relationship Type | Mechanism | Segment |
|---|---|---|
| **Self-service** | `onboard-basecoat.sh`, issue templates, starter workflows | All |
| **Automated service** | Sweep, validation CI, broadcast events | All |
| **Community co-creation** | Consumer repos contribute learnings back | Enterprise contributors |
| **Steward review** | Human memory stewards approve promotions | All (quality gate) |
| **Governance audit** | Quarterly compliance/governance agent run | Internal teams |

---

## 5. Revenue Streams

Measured in knowledge quality and adoption, not money:

| Stream | Metric | Target |
|---|---|---|
| **Memory adoption rate** | % of promoted memories reused in sessions | > 60% after 3 sprints |
| **Contribution velocity** | Candidate memories submitted per sprint | ≥ 5 per sprint |
| **Guidance coverage** | % of tasks covered by at least one instruction file | > 80% of common patterns |
| **Consumer repo count** | Repos with `basecoat-enabled` topic | +5 per quarter |
| **Validation pass rate** | % of PRs passing guidance validation on first push | > 85% |
| **Pattern reuse** | Instances where consumer cites a basecoat agent/skill | Tracked via CHANGELOG sweep |

---

## 6. Key Resources

What the system requires to function:

| Resource | Type | Owner |
|---|---|---|
| `IBuySpy-Shared/basecoat` repo | Digital | IBuySpy-Shared org |
| `IBuySpy-Shared/basecoat-memory` repo | Digital | IBuySpy-Shared org |
| `MEMORY_REPO_TOKEN` org secret | Credential | Org admin |
| Memory steward time (review) | Human | Designated per sprint |
| GitHub Actions minutes | Compute | GitHub org plan |
| Copilot CLI session store | Digital (ephemeral) | Per-agent session |

---

## 7. Key Activities

What the multi-agent system must do continuously:

| Activity | Agent/Script | Cadence |
|---|---|---|
| **Sweep consumer repos** | `sweep-enterprise-memory.ps1` | Weekly (cron) |
| **Validate guidance PRs** | `validate.yml` (basecoat-memory) | Per PR |
| **Author new guidance** | `guidance-author.agent.md` | On demand |
| **Review guidance quality** | `guidance-reviewer.agent.md` | On demand (creator-verifier loop) |
| **Intake contributions** | `memory-contribution-issue.yml` | On issue label |
| **Promote memories** | Memory steward + `contribute-memories.ps1` | Weekly |
| **Broadcast promotions** | `repository_dispatch` pub-sub | On merge to basecoat-memory |
| **Onboard new repos** | `onboard-basecoat.sh` / `auto-enlist.yml` | On demand |
| **Governance audit** | `policy-as-code-compliance` + `memory-curator` chain | Quarterly |

---

## 8. Key Partners

External actors the system depends on:

| Partner | Contribution | Risk if Lost |
|---|---|---|
| **GitHub Actions** | CI/CD execution, workflow triggers | High — most automation depends on it |
| **GitHub Copilot CLI** | Session memory injection, agent execution | High — primary consumer |
| **Consumer repo maintainers** | Signal labelling, contribution submission | Medium — sweep still works passively |
| **Memory stewards** | Quality gate for promotion | Medium — candidates queue without review |
| **Org admin** | Sets `MEMORY_REPO_TOKEN` secret | Low (one-time setup) |

---

## 9. Cost Structure

What the system costs to operate:

| Cost | Type | Magnitude |
|---|---|---|
| GitHub Actions minutes | Variable (per PR + weekly sweep) | Low (< 100 min/week) |
| Memory steward review time | Human time | Medium (1–2 hr/sprint) |
| Guidance authoring time | Human + agent time | Variable (sprint-dependent) |
| Secret rotation | Operational overhead | Low (annual or on leak) |
| Onboarding new repos | One-time setup | Negligible (< 5 min/repo) |

---

## Strategic Observations

### Jobs to Be Done (JTBD)

The primary job BaseCoat performs: *"When I start a new coding session, I want the
best knowledge from past sessions pre-loaded, so I don't repeat solved problems."*

Secondary jobs:

- *"When I write a new agent, I want immediate feedback that it follows conventions."*
- *"When my team learns something, I want to contribute it without friction."*

### Moats

1. **Network effect**: More `basecoat-enabled` repos → more candidate memories → better sweep quality
2. **Switching cost**: Teams that embed `.memory/shared/` sync develop institutional memory in the system
3. **Governance trust**: Steward review creates a quality signal that raw LLM outputs cannot match

### Growth Levers

1. Increase `basecoat-enabled` adoption (auto-enlist workflow + org starter workflow)
2. Reduce steward bottleneck (better scope-check automation → fewer false positives)
3. Add contribution attribution (which consumer repo surfaces the most valuable memories)

---

## Related Documents

- `docs/research/multi-agent-strategy-matrix.md` — Eisenhower×Cynefin task mapping
- `docs/architecture/multi-agent-orchestration-patterns.md` — implementation patterns
- Issue [#613](https://github.com/ivegamsft/basecoat/issues/613) — parent investigation
