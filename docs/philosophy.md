# Philosophy: Why Four Primitives?

BaseCoat uses four complementary primitives — **agents**, **skills**, **instructions**,
and **prompts** — because each solves a different problem:

| Primitive | What it is | When it activates | Analogy |
|---|---|---|---|
| **Agent** | A persona with a workflow | When explicitly invoked | A specialist on your team |
| **Skill** | A knowledge pack with templates | When attached to a conversation | A reference manual |
| **Instruction** | A set of rules and standards | Always active (ambient) | Company policy |
| **Prompt** | A structured invocation template | When the user calls it by name | A meeting agenda |

---

## How They Compose

- An **agent** (e.g., `@backend-dev`) defines *who* does the work and *how* they approach it.
- A **skill** (e.g., `backend-dev/`) provides *templates and knowledge* the agent draws from.
- An **instruction** (e.g., `backend.instructions.md`) enforces *standards* that apply regardless of who's working.

**Example:** When you invoke `@backend-dev`, it uses its paired `backend-dev` skill for
templates and follows `backend.instructions.md` + `development.instructions.md` +
`governance.instructions.md` for standards.

```text
┌─────────────────────────────────────────────┐
│  User: @backend-dev build a REST API        │
├─────────────────────────────────────────────┤
│                                             │
│  Agent ─── backend-dev.agent.md             │
│    ├── Skill ─── skills/backend-dev/        │
│    │     ├── api-spec-template.md           │
│    │     ├── service-template.md            │
│    │     └── error-catalog-template.md      │
│    └── Instructions (ambient)               │
│          ├── development.instructions.md    │
│          ├── backend.instructions.md        │
│          └── governance.instructions.md     │
│                                             │
└─────────────────────────────────────────────┘
```

---

## Why Not Just Agents?

Agents alone can't enforce cross-cutting standards. Instructions are **ambient** — they
apply to ALL agents and even raw Copilot chat. Without instructions, every agent would
need to duplicate security rules, naming conventions, and quality gates.

Consider: you have 50 agents. A new security policy drops. With instructions, you update
one file and every agent inherits it. With agents-only, you'd edit 28 files and hope
you didn't miss one.

---

## Why Not Just Instructions?

Instructions are rules, not workflows. They can tell an agent "always validate input"
but they can't guide a multi-step code review, plan a sprint, or design an API schema.

Agents bring **structured workflows** that go beyond "follow these rules":

- Step-by-step processes with decision points
- Output format specifications
- Handoff protocols between agents
- Model selection for cost/quality trade-offs

---

## Why Skills?

Skills bridge the gap between agents (workflow) and instructions (rules) by providing
**reusable knowledge artifacts** — templates, checklists, decision trees.

Key properties of skills:

1. **Shareable** — Multiple agents can reference the same skill. The `manual-test-strategy`
   skill is used by three different agents.
2. **Composable** — An agent can draw from multiple skills in a single session.
3. **Declarative** — Skills are documents, not code. They're easy to audit and version.

Without skills, templates would live inside agent definitions (bloating them) or in
instructions (mixing policy with reference material).

---

## The Router: Tying It Together

The `/basecoat` router skill sits on top, providing a **single entry point**. Users
don't need to know about the three primitives — they just say:

```text
/basecoat backend build a REST API
```

and the router loads the right agent, skill, and instructions automatically.

Two modes:

| Mode        | Example                              | What happens                        |
|-------------|--------------------------------------|-------------------------------------|
| **Discover**| `/basecoat`                          | Shows categorized agent catalog     |
| **Delegate**| `/basecoat backend build a REST API` | Routes to `@backend-dev` with prompt |

The router reads `basecoat-metadata.json` to resolve discipline keywords to agents,
attach paired skills, and validate that instructions exist — all before the agent
sees its first token.

---

## What About Prompts?

Prompts are lightweight — they don't carry a workflow or enforce ambient rules. They're
**structured invocation templates**: named shortcuts users call by name to kick off a
repeatable task with the right context already loaded.

```text
/sprint-plan          ← prompt template, no agent persona
/basecoat             ← router skill, delegates to an agent
@backend-dev          ← agent, runs a full workflow
```

Prompts are the entry point when the task is simple enough that it doesn't need an
agent's full workflow, but structured enough that you don't want users to rephrase it
from scratch every time.

---

## Summary

| Question | Answer |
|---|---|
| Who does the work? | **Agent** |
| What knowledge do they use? | **Skill** |
| What rules must everyone follow? | **Instruction** |
| How does the user kick it off? | **Prompt** |
| How does the user access it all? | **`/basecoat` router** |

Four primitives. One router. Zero ambiguity about where to put things.

---

## Shearing Layers: The Pace of Change

Not all parts of BaseCoat change at the same speed. Borrowing from Stewart Brand's
*How Buildings Learn*, we model the system as nested layers — each with its own pace
of change. Fast layers sit inside slow layers, and coupling must flow inward, never
outward.

```text
Site         ∞        Org identity, repo layout, four-primitive model
Structure    Rare     Asset types, frontmatter schema, validation contract
Skin         Seldom   Governance vocabulary, audit rules, guidance syntax
Services     Periodic MCP server, Extension, CI/CD, deployment infra
Space plan   Occasional  Instruction scoping, agent-to-skill wiring
Stuff        Frequent Individual prompts, skill content, eval cases
```

**Design principle:** Put decisions at the fastest layer that can own them. An agent
prompt (Stuff) should never hard-code a deployment URL (Services). A validation
script (Structure) should never enumerate specific skill names (Stuff).

**Review principle:** Changes to slower layers demand broader consensus. A tweak to
an agent prompt is lightweight; a change to the frontmatter schema is an RFC.

For the full framework and anti-patterns, see
[`instructions/shearing-layers.instructions.md`](/instructions/shearing-layers.instructions.md).

---

## Paint Layers: Depth of Protection

The product name is no accident. In automotive finishing, a paint system is a stack
of protective layers — each with a distinct purpose, each shielding the layers beneath
it. Defects at different depths carry different severity.

```text
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   Defects:   Deep        Paint       Clear coat    Surface      │
│              scratch     scratch     scratch       stain        │
│                                                                 │
│   ▼ ▼ ▼      ▼ ▼         ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Clear coat (protection + gloss)             │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │              Base coat (color + identity)                │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │              Primer (adhesion + corrosion guard)         │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │              Metal / body panel (structural)             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Mapped to BaseCoat

| Paint Layer | Purpose | BaseCoat Analog |
|-------------|---------|-----------------|
| **Metal / body panel** | Structural integrity | Repository structure, asset type schemas, validation contract |
| **Primer** | Adhesion and corrosion resistance | Governance instructions, security rules, naming conventions |
| **Base coat** | Color and identity | Agent personas, skill knowledge packs, prompt templates |
| **Clear coat** | Protection, gloss, user-facing finish | Instructions that polish output (formatting, tone, style) |

### Defect Severity by Depth

| Depth | Defect type | Severity | Repair cost |
|-------|-------------|----------|-------------|
| **Surface stain** | Formatting issue, typo in output | Low | Quick fix — touch up the clear coat |
| **Clear coat scratch** | Missing style rule, inconsistent tone | Medium | Update an instruction file |
| **Paint scratch** | Wrong agent behavior, bad skill content | High | Rework the asset, re-evaluate |
| **Deep scratch (to metal)** | Broken schema, invalid structure, missing primitives | Critical | Structural repair — RFC required |

### Design Implications

1. **Protect from the outside in.** Clear coat instructions catch surface defects
   before they reach users. Governance (primer) prevents corrosion of standards
   across the entire system.

2. **Deeper layers are harder to change.** Repainting (swapping an agent) is
   routine. Replacing the body panel (restructuring asset types) is a rebuild.

3. **Each layer must fully cure before the next is applied.** Don't write skills
   (base coat) before governance rules (primer) are stable. Don't add polish
   instructions (clear coat) before the asset content (base coat) is correct.

4. **Oxidation happens at boundaries.** Where layers meet — where an agent
   references a skill, where an instruction scopes to a path — is where defects
   accumulate. Pay extra attention to integration points.

---

## Vocabulary

BaseCoat's name is grounded in a straightforward idea: every workspace needs a solid
foundation before custom work is layered on top — a base coat. The product itself avoids
paint-shop language; these are the terms we use:

The operating language is native SDLC and GitHub artifacts. Prefer concrete nouns
like workflow run, job log, PR, issue, release, and version drift over generic
phrasing like "pipeline output" or "ticket."

| Term | Meaning |
|---|---|
| **BaseCoat** | The product. The shared Copilot configuration distributed to consumer repos. |
| **Asset** | Any individual file: an agent, skill, instruction, or prompt. |
| **Overlay** | The `.github/base-coat/` directory and Copilot-discoverable paths that `sync` creates. |
| **Adopt** | Integrate BaseCoat into a repo for the first time (run `bootstrap-basecoat.ps1`). |
| **Sync** | Pull the latest BaseCoat assets into an already-adopted repo (run `sync.ps1`). |
| **Consumer** | A repository that has adopted the overlay. |
| **Contributor** | Someone who adds or improves assets in the BaseCoat source repo. |
| **Drift** | When a consumer's installed version lags behind the current BaseCoat release. |
| **Workflow run** | A single GitHub Actions execution instance for a workflow. |
| **Job log** | The logs for a specific job in a workflow run; primary CI failure evidence. |
| **PR** | A GitHub pull request; the merge unit for review and checks. |
| **Issue** | A GitHub issue; tracked work item for planning and triage. |
| **Release** | A GitHub release/tag publication event, separate from deployment execution. |
