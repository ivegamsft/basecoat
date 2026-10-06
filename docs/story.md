# The Story of BaseCoat

How a simple idea — *what if teams could share Copilot customizations the way they share
linting configs?* — became an enterprise framework with 200+ assets, automated quality
gates, a fleet execution model, and a live metrics dashboard. And why it's called what
it's called.

---

## Origin (March 2026)

BaseCoat began as a modest scaffold: sync scripts for PowerShell and Bash, a handful of
instruction files, and a version file. The core insight was already present in v0.1.0 —
separate **instructions** (ambient rules) from **agents** (workflows) from **skills**
(knowledge packs). That separation is still the foundation today.

---

## The Name

A base coat of paint does something specific: it prepares a surface so that everything
applied on top adheres properly, covers evenly, and lasts. Skip it and the topcoat looks
fine at first — then starts to peel, leaves bare patches, and has to be stripped and
redone. The problem wasn't the topcoat. The foundation was missing.

That maps directly to what happens in a Copilot setup without shared standards.

### Adherence

Without a shared instruction layer, each team lays its own standards directly onto its
agents — inline, duplicated, drifting apart. Security rules in one agent, naming
conventions in another, nothing in a third. When a new policy lands, you update what you
can find and hope you didn't miss one. Standards that live in 30 places don't stick
the way standards that live in one place do.

BaseCoat's instruction files are ambient — they apply to every agent, every session,
every developer in every repo that has adopted the overlay. Change one file, the whole
surface re-adheres uniformly. That's what adherence means here: standards that hold
because they're part of the foundation, not painted on top.

### The tacky window

There's a moment in a new project — a new repo, a new team, a new onboarding — when
patterns haven't formed yet. The surface is still open. That's when a base coat sets.
Once habits are in place, conventions are established, and agents are already written,
changing the foundation means scraping and repainting.

BaseCoat is designed to be adopted in that window. The sync takes minutes. The overlay
lands before the first agent is written. The standards arrive at the right moment —
when the surface is still receptive — rather than as a retrofit six months later.

### What happens without it

No base coat means no consistent surface to build on:

- **Duplication** — Security rules, naming conventions, and quality standards get copied
  into every agent that needs them. When requirements change, you're editing 40 files.
- **Gaps** — Something always gets missed. An agent that should enforce OIDC doesn't.
  A workflow that should validate input doesn't. Bare patches in the surface.
- **Drift** — Each team's standards diverge from every other team's. What looks like
  "consistency" is just proximity — people on the same team happen to follow the same
  rules because they talked to each other, not because the rules are enforced.
- **Rework** — Eventually the gaps become visible: a security audit, a failed review,
  an incident. Then it's strip-and-repaint time, which costs more than getting the
  foundation right at the start.

The instructions in BaseCoat are the base coat. The agents and skills are the topcoats —
your team's specific workflows, custom to your stack and domain. The distinction matters:
standards belong in the foundation; customization belongs on top.

---

## How the Guidance Was Developed

### Sprints 1–3: Build by doing

Each asset started life as a real need. The `backend-dev` agent didn't exist because
someone designed it on a whiteboard — it was written because a dev needed a consistent
API scaffolding workflow. The `governance.instructions.md` was written because security
rules were being duplicated across 12 agent files.

The rule from the start: **no asset without a use case**. Every agent, skill, and
instruction in BaseCoat was written to solve a problem that had already surfaced.

### The agent + skill + instruction pattern

Sprint 2 established the pattern that every subsequent agent follows:

```
agent file       → defines who does the work and the workflow
paired skill     → provides templates and reference material
ambient instructions → enforce cross-cutting standards regardless of agent
```

This was tested empirically: agents without paired skills produced inconsistent output.
Agents without ambient instructions duplicated security rules and missed governance
standards. The three-part pattern eliminated both failure modes.

### Quality gates (v1.0.0+)

From v1.0.0, every PR runs `validate-basecoat.ps1`:

- Required frontmatter fields (`name`, `description`, `applyTo`)
- `## Inputs`, `## Workflow`, and an output section for every agent
- `## Process` and output section for every skill
- Average asset score ≥ 5.0/10; no asset scoring 0

These gates caught real regressions. During the v0.7.0–v1.0.0 development period,
multiple assets failed the quality gate before they shipped — and were improved before merge.

---

## How Guidance Was Tested

### CI as the test harness

The primary test vehicle is `tests/run-tests.ps1`, which runs on every PR:

| Test | What it checks |
|---|---|
| Frontmatter validation | Required fields, correct format |
| Agent structure | Inputs, Workflow, Output sections |
| Skill structure | Process section, SKILL.md presence |
| Coherence check | Scope overlap, orphaned files |
| Markdown lint | MD036, MD031, MD040, MD047 |

### Sprint retros as the feedback loop

Every sprint included a retro pass — issues opened for any guidance that produced
unexpected output, any instruction that conflicted with another, or any agent that
stalled on a real task.

The `detect-repeat-fixes.ps1` script checks session-state files against a predefined
list of known fix patterns and flags any that appear more than twice. When that happens,
it's evidence that a rule is missing or unclear — and a new instruction or agent update
follows. The set of patterns matched is hardcoded in the script; the script does not
discover or learn new patterns automatically.

### Real session data

Instructions like `token-economics`, `session-hygiene`, and `agent-routing` were
written specifically because patterns appeared in real Copilot sessions — sessions
where context was exhausted prematurely, or where 6 agents were dispatched when 2
would have done the job. The guidance was drafted, tested in a session, and revised
based on what actually changed behavior.

---

## How Guidance Was Hardened

### The impeccable audit cycle

Periodically the docs site undergoes a design quality audit using the `teach-impeccable`
skill. This surfaces UX issues in the public-facing documentation — broken links, missing
navigation, visual inconsistencies. Issues from these audits are filed and resolved in
dedicated PRs.

### The coherence check

`scripts/check-coherence.ps1` detects when two instructions have identical `applyTo`
scope, when skills are listed in `allowed_skills` but don't exist, and when agents
reference instructions that don't exist. This has caught ~30 latent consistency issues
across major version bumps.

### Rate limit hardening

Sprint 24 hit enterprise Copilot rate limits from over-aggressive fleet dispatch.
The failure produced `docs/guides/rate-limit-guidance.md` — a documented standard
for concurrency limits (3 safe, 4 risky, 5+ = 429), wave patterns, and recovery
procedures. The agent-routing configuration was updated to enforce these limits by
default.

### ADR-driven decisions

Contested decisions are captured as Architecture Decision Records. The first,
[ADR-001](architecture/decisions/adr-001-naming-convention.md), documented why
`basecoat` (repo name), `BaseCoat` (product name), and `base-coat` (artifact name)
coexist — a question that came up in every consumer onboarding conversation.

---

## Version History at a Glance

| Version range | Theme | Key additions |
|---|---|---|
| v0.1–v0.4 | Scaffold | Sync scripts, initial assets, CI, packaging |
| v0.5–v0.9 | Agent explosion | 28 agents across all disciplines |
| v1.0–v1.9 | Quality gates | Validation CI, coherence checks, scoring |
| v2.0–v2.9 | Router + metadata | `/basecoat` router, `basecoat-metadata.json` |
| v3.0–v3.25 | Enterprise scale | Fleet dispatch, memory system, 200+ assets, GH Pages |

The full changelog is at [Changelog](changelog.md).
The detailed narrative through v2.1.0 is preserved in the
[project archive](https://github.com/ivegamsft/basecoat/blob/main/docs/archive/repo_history/2026-05-01-story-of-basecoat.md).

---

## Principles That Emerged

These weren't designed up front. They appeared through iteration:

1. **No asset without a use case** — Every file in BaseCoat solves a problem that surfaced in a real session.
2. **Gate before ship** — Validation CI catches regressions before they reach consumers.
3. **Retro before retire** — Repeated failures become documentation, not just closed issues.
4. **One router, many specialists** — Users shouldn't need to memorize asset names; the router handles discovery.
5. **Foundation, not framework** — BaseCoat sets the floor, not the ceiling. Consumer customization is expected.
