---
description: "Intent prefix routing — interprets user-defined prefixes to determine urgency, timing, and which agents/skills to invoke. Applies to all conversations."
applyTo: "**/*"
---

<!-- applyTo: "**/*" is intentional. Prefix routing must fire on every conversation so urgency
and timing signals (hot:, async:, batch:, etc.) are never silently dropped regardless of
which file or repo context is active. Do not narrow this scope. -->

# Intent Prefix Routing

The user communicates intent through structured prefixes in their messages.
Always read the prefix before deciding what to do. Prefix + syntax determines
both the type of work and **when** to do it.

---

## Prefix Vocabulary

| Prefix | Intent | Default timing | Primary agents |
|---|---|---|---|
| `bug:` | Defect, regression, broken behavior | **Now** — fix immediately | `@code-review`, `@self-healing-ci`, `@config-auditor` |
| `feature:` | New capability or enhancement | **Later** — log for backlog | `@sprint-planner`, `@solution-architect` |
| `audit:` | Review, assess, validate — no changes | **Now** — analysis only, no edits | `@security-analyst`, `@config-auditor`, `@github-security-posture` |
| `plan:` | Sprint or project planning | **Now** — planning mode, no implementation | `@sprint-planner`, `@product-manager` |
| `spike:` | Time-boxed investigation, no deliverable | **Now** — research only, produce findings | `@solution-architect` |
| `chore:` | Maintenance, cleanup, non-functional work | **Soon** — defer if sprint is full | `@devops-engineer`, `@release-manager` |
| `security:` | Security concern or vulnerability | **Now, high priority** — escalate | `@security-analyst`, `@guardrail` |
| `perf:` | Performance degradation or concern | **Now** — measure before changing | `@performance-analyst` |
| `outage:` | Service outage, broken or dead system, site down | **Now, high priority** — route to RCA | `@rca` |
| `docs:` | Documentation only | **Soon** — low urgency unless broken | `@tech-writer` |
| `test:` | Test coverage gap or test failure | **Now** — coverage gaps block releases | `@manual-test-strategy`, `@strategy-to-automation` |
| `refactor:` | Structural improvement, no behavior change | **Later** — batch with related work | `@code-review`, `@performance-analyst` |
| `ux:` | User experience or design concern | **Soon** | `@ux-designer`, `@frontend-dev` |

---

## Syntax Determines Timing

The same prefix has different timing implications depending on its syntactic context.

### Standalone message — act now

When a prefix appears as the first word of a standalone message, treat it as
immediate work:

```text
bug: the sync script exits with code 1 on Windows when BASECOAT_REPO is unset
```

→ Investigate and fix now.

```text
audit: run a say-vs-do check against the CI workflows
```

→ Run the audit now. Return findings. Do not make changes.

---

### Bulleted list — triage and log, not implement

When prefixes appear as items in a bulleted list within a message, they are
**triage items**, not immediate work orders. Log them (as issues, todos, or
plan notes) and confirm receipt. Do not implement.

```text
- bug: metrics dashboard is broken on mobile
- feature: add a prompt for getting started
- audit: run impeccable against the GH Pages output
- chore: clean up stale branches
```

→ Log each item appropriately (GitHub issue, plan note, backlog entry).
   Report what was logged. Ask which item to start with, if any.
   Do not begin implementation until explicitly directed.

**The most common mistake:** treating a bulleted `feature:` item as an immediate
implementation request. A bulleted `feature:` means *"add this to the backlog."*

---

### Mixed message — respect both

A message can contain both a preamble action and a bulleted list. The preamble
may be immediate; the list items are still triage:

```text
run an audit against the CI workflows — log issues

- feature: add retry logic to sync.sh
- bug: secret-scan.yml always exits 0
- chore: remove dead workflow stubs
```

→ Run the audit now. Log the bulleted items as issues. Return the audit findings
   and the list of what was logged.

---

## Timing Modifiers

These words in the user's message override the default timing of a prefix:

| Modifier | Effect |
|---|---|
| `now`, `immediately`, `urgent` | Promote any prefix to immediate action |
| `later`, `backlog`, `next sprint` | Defer any prefix, even `bug:` |
| `no changes`, `read-only`, `analysis only` | Suppress implementation even for `bug:` |
| `log it`, `file an issue` | Log only; do not implement |
| `just document` | Documentation output only; no code changes |

---

## Audit Mode (`audit:`)

`audit:` is always read-only unless the user explicitly says "and fix" or "resolve."

When `audit:` fires:

1. Run the analysis
2. Return findings with severity (`🔴 Critical / 🟠 High / 🟡 Medium / ⚪ Low`)
3. Log as GitHub issues if the user says "log issues"
4. Wait for explicit instruction before making any changes

---

## Feature Routing

`feature:` in a bullet list means: **plan it, don't build it.**

When a bulleted `feature:` item is logged, the appropriate output is:

- A GitHub issue with the feature description, or
- An entry in the plan/backlog, or
- A note in the session plan

The appropriate agent is `@sprint-planner` for prioritization or
`@solution-architect` for design — not an implementation agent.

---

## Outage Routing

When a user describes a system being broken, dead, down, or not responding,
normalize the request to `outage:` and route it to the RCA agent.

| Alias | Normalized intent |
|---|---|
| `broken` | `outage:` |
| `broke` | `outage:` |
| `dead` | `outage:` |
| `site down` | `outage:` |
| `down` | `outage:` |
| `not responding` | `outage:` |
| `incident` | `outage:` |
| `it's broken` | `outage:` |
| `nothing works` | `outage:` |

Use `@rca` for deep-dive analysis once the active incident is stabilized.

---

## Prefix-to-Skill Routing

| Prefix | Skills to consult |
|---|---|
| `bug:` | `code-review`, `error-kb` |
| `feature:` | `architecture`, `agent-design` (for new agents/skills) |
| `audit:` | `security`, `code-review`, `github-security-posture` |
| `plan:` | `architecture`, `documentation` |
| `security:` | `security`, `github-security-posture` |
| `perf:` | `performance-profiling` |
| `docs:` | `documentation` |
| `test:` | `manual-test-strategy` |

---

## Unknown or Missing Prefix

If a message has no prefix and is not clearly one intent type, ask before
acting. Ambiguous work done in the wrong mode wastes turns.

If the prefix is not in the vocabulary above, treat it as a custom label and
ask what it means before routing.
