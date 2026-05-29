# Guidance Vocabulary and Syntax Guide

This guide defines the canonical language for BaseCoat intent routing, agent and
skill selection, chaining, and prompt construction.

## Taxonomy

### Asset taxonomy

| Asset | Primary role | Scope |
|---|---|---|
| Agent (`agents/*.agent.md`) | Executor | End-to-end workflow orchestration |
| Skill (`skills/*/SKILL.md`) | Capability | Focused reusable method |
| Instruction (`instructions/*.instructions.md`) | Constraint | Cross-cutting behavior basecoat-30-ai-guardrail |
| Prompt (`prompts/*.prompt.md`) | Entry point | Intent shaping and kickoff |

### Work taxonomy

| Layer | Meaning | Examples |
|---|---|---|
| Intent | What outcome is needed | fix regression, design feature, run audit |
| Task phase | Where work sits in SDLC | plan, build, test, deploy, operate |
| Interaction mode | How work executes | autonomous, collaborative, reactive |
| Evidence mode | What proof is required | findings report, test output, diff summary |

## Ontology

### Core entities

- **Intent**: user objective.
- **Executor**: agent selected to own the outcome.
- **Capability**: skill used by the executor.
- **Constraint**: instructions that bound behavior.
- **Evidence**: validation artifacts that justify output.
- **Handoff**: transition between executors.
- **Chain**: ordered set of handoffs for one intent.

### Relationship model

1. Prompt frames intent.
2. Intent selects executor.
3. Executor applies one or more capabilities.
4. Constraints govern every step.
5. Executor emits evidence.
6. If needed, handoff starts the next executor in a chain.

### Cardinality model

| Source | Relationship | Target |
|---|---|---|
| Intent | routes-to | 1 primary executor (optionally 1 fallback) |
| Executor | invokes | 0..N capabilities |
| Capability | governed-by | 1..N constraints |
| Chain | contains | 1..N executors |
| Executor | emits | 1 evidence bundle |

## Canonical vocabulary

Use canonical terms in agents, skills, instructions, and prompts.

| Concept | Canonical term | Avoid |
|---|---|---|
| Evaluate and sort incoming work | triage | handle, look at |
| Determine severity and owner | classify | review quickly |
| Enforce a rule or policy | validate | check stuff |
| Escalate to a higher responder | escalate | pass along |
| Transfer context between basecoat-10-core-agents | handoff | transfer, toss over |
| Sprint end reporting | closeout | shutdown, wrap-up |
| Scope reduction for safety | constrain | trim vaguely |
| Plan without implementation | plan-only | think about, discuss only |

## Intent families and execution model

| Intent family | Typical prefixes | Primary outcome | Primary agent classes |
|---|---|---|---|
| Delivery | `feature:`, `refactor:` | Shipped change set | architect, dev, reviewer |
| basecoat-10-core-reliability | `bug:`, `outage:`, `perf:` | Restored stability | diagnostics, responder, SRE |
| basecoat-20-lang-governance | `audit:`, `security:`, `chore:` | Risk reduction and compliance | security, policy, release |
| Planning | `plan:`, `spike:` | Decision artifact or backlog map | planner, product, architect |
| basecoat-90-quality-quality | `test:`, `docs:` | basecoat-10-core-verification and clarity | test strategy, reviewer, writer |

## Chain patterns

### Standard chains

| Pattern | Sequence | Use when |
|---|---|---|
| Design to delivery | `basecoat-10-core-solution-architect -> backend-dev/basecoat-10-core-frontend-dev -> basecoat-90-quality-code-review` | New feature implementation |
| Incident response | `basecoat-10-core-rca -> basecoat-60-workflow-incident-responder -> basecoat-10-core-sre-engineer` | Service degradation or outage |
| basecoat-50-security-security hardening | `basecoat-50-security-security-analyst -> basecoat-50-security-policy-as-code-compliance -> basecoat-30-ai-guardrail` | basecoat-50-security-security findings require remediation |
| Test evolution | `basecoat-90-quality-manual-test-strategy -> basecoat-10-core-strategy-to-automation -> basecoat-90-quality-e2e-test-strategy` | Manual pathways need automation |
| Sprint cycle | `basecoat-10-core-product-manager -> basecoat-10-core-sprint-planner -> basecoat-60-workflow-retro-facilitator` | Sprint planning and closeout |

### Chain contract

Every chain step should pass:

1. Intent statement.
2. Scope and constraints.
3. Output contract.
4. Evidence collected so far.
5. Explicit next-step question.

## Prompting with the vocabulary

### Prompt shape

Use this structure for deterministic routing:

```text
<prefix>: <objective>
scope: <in/out boundaries>
constraints: <instructions, policy, risk limits>
deliverable: <artifact expected>
evidence: <what proof is required>
next-hop: <agent or none>
```

### Examples

```text
bug: CI pipeline fails on Windows path handling
scope: scripts/sync.ps1 and tests only
constraints: no workflow changes, no secret handling changes
deliverable: targeted fix plus regression test
evidence: failing test before and passing test after
next-hop: basecoat-90-quality-code-review
```

```text
plan: next sprint for extension hardening
scope: open issues tagged extension and basecoat-50-security-security
constraints: planning only, no implementation
deliverable: prioritized issue list with dependency waves
evidence: rationale per issue
next-hop: basecoat-10-core-sprint-planner
```

## Design debate and decisions

### Debate 1: intent-first vs asset-first routing

- **Option A (asset-first):** ask users to pick an agent first.
- **Option B (intent-first):** infer asset from intent language.
- **Decision:** intent-first.
- **Reason:** reduces user cognitive load and makes routing consistent across assets.

### Debate 2: broad verbs vs canonical verbs

- **Option A:** allow loose synonym use.
- **Option B:** enforce canonical vocabulary in guidance.
- **Decision:** canonical vocabulary with synonym normalization at routing time.
- **Reason:** consistent authoring and predictable prompt outcomes.

### Debate 3: free-form chains vs standard chain archetypes

- **Option A:** fully ad hoc handoffs.
- **Option B:** defined chain archetypes with optional extension.
- **Decision:** standard chains plus optional branch-specific steps.
- **Reason:** better reviewability, fewer dead-end handoffs, easier eval coverage.

## Authoring and syntax rules

### Agent files

- Required frontmatter: `name`, `description`, `compatibility`, `metadata`,
  `allowed-tools`.
- Strongly recommended: `model`, `allowed_skills`, `task_phase`,
  `interaction_type`, `invocation_rules`, `visibility`, `handoffs`.
- Required body sections: `## Inputs`, `## Workflow` or `## basecoat-10-core-process`, `## Output`
  or `## Results`.

### Skill files

- Required frontmatter: `name`, `description`, `compatibility`, `metadata`,
  `allowed-tools`.
- Recommended: `invocation_rules`, `visibility`.
- Required companion: `eval.yaml` with positive and negative routing scenarios.

### Description style

- Start with `Use when...`.
- Include `USE FOR` and `DO NOT USE FOR` trigger language.
- Use procedural phrasing and explicit escalation criteria.

## Consistency rollout plan

1. Normalize intent vocabulary in agent and skill descriptions.
2. Align intent prefixes, chain patterns, and handoff prompts.
3. Add missing routing evals where ontology terms are absent.
4. Track drift in CI with structure and eval checks.
