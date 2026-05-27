---
description: "Intent prefix routing — interprets user-defined prefixes to determine urgency, timing, and which agents/skills to invoke. Applies to all conversations."
applyTo: "**/*"
---

# Intent Prefix Routing

The user communicates intent through structured prefixes in their messages.
Always read the prefix before deciding what to do. Prefix + syntax determines
both the type of work and **when** to do it.

---

## Enforcement Contract

Prefix parsing is a hard contract, not a soft hint. When a recognized prefix
appears at the start of a message, it must be interpreted as an authoritative
routing signal before any plain-text interpretation occurs.

Rules:

1. Parse the prefix **first**. Do not attempt plain-text interpretation before
   identifying the prefix.
2. A recognized prefix overrides any other reading of the request.
3. `bug:` routes immediately to the defect workflow — no further disambiguation.
4. `feature:` routes immediately to the implementation/design workflow — no
   further disambiguation.
5. Any agent or pipeline that ignores a recognized prefix and treats the message
   as plain text is in violation of this contract.

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
| `fleet:` | Close previous sprint, plan and execute the next sprint, triage oldest issues, audit PRs/builds, clean branches | **Now** — orchestrate the sprint batch | `@sprint-closeout-auditor`, `@sprint-planner`, `@issue-triage`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `security:` | Security concern or vulnerability | **Now, high priority** — escalate | `@security-analyst`, `@guardrail` |
| `perf:` | Performance degradation or concern | **Now** — measure before changing | `@performance-analyst` |
| `outage:` | Service outage, broken or dead system, site down | **Now, high priority** — route to RCA | `@rca` |
| `rca:` | Root-cause analysis of a known failure — execution suspended | **Now, read-only** — diagnose before next attempt | `@rca`, `@config-auditor` |
| `deploy:` | Staged infrastructure deployment — azure-prepare, azure-validate, azure-deploy in sequence | **Now** — staged sequence, do not skip validation | `@devops-engineer` |
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

## Fleet Routing

`fleet:` is the shortcut intent for a sprint-execution batch that combines:

1. closing the previous sprint,
2. planning the next sprint,
3. starting from the oldest actionable issues,
4. including PR and broken-build context in planning,
5. triaging new issues so they do not supersede the backlog order,
6. cleaning up old branches and stale worktrees.

Treat `fleet:` as an orchestration intent, not a single-task execution.

### Normalized examples

| User phrasing | Normalized intent |
|---|---|
| `Fleet deployed: use basecoat...` | `fleet:` |
| `fleet: plan and execute the sprint` | `fleet:` |
| `use basecoat for fleet mode` | `fleet:` |

### Fleet chain

When `fleet:` fires, prefer the following chain:

- `@sprint-closeout-auditor` — verify previous sprint completion and carry-forward items
- `@issue-triage` — rank oldest actionable issues and note superseded items
- `@broken-build-troubleshooter` — include current PR/build failures in planning
- `@sprint-planner` — form the next sprint plan from the oldest ready items
- `@branch-hygiene-sweeper` — clean merged/stale branches and worktree registrations

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

## RCA Routing

`rca:` suspends all execution. The session goal shifts to diagnosis only.

When `rca:` fires (or any of the aliases below), route to `@rca` and `@config-auditor`
before allowing any deployment, re-run, or remediation command.

| Alias | Normalized intent |
|---|---|
| `stop and rca` | `rca:` |
| `why is it failing` | `rca:` |
| `same error` (after a prior failure) | `rca:` |
| `still broken` (after a retry) | `rca:` |
| same stage fails in consecutive attempts | `rca:` |
| deployment retried 3 or more times | `rca:` (hard block on further retries) |

To exit RCA mode and resume execution, the user must:

1. Confirm the root cause is identified.
2. Confirm the remediation step is distinct from prior attempts.
3. Re-issue a `deploy:` or `outage:` intent explicitly.

---

## Deployment Routing

`deploy:` enforces the staged deployment sequence. Skipping any stage is not permitted.

**Required chain:**

1. `azure-prepare` — scaffold IaC and validate configuration
2. `azure-validate` — pre-deployment checks, no resource changes
3. `azure-deploy` — provision and deploy

If the user issues a `deploy:` without specifying the starting stage, begin at
`azure-prepare` unless a prior stage has already been completed and confirmed in
this session.

**Enforcement:**

- Do not call `azure-deploy` until `azure-validate` has completed successfully.
- If validation fails, surface the finding and wait for explicit instruction.
- If the same deployment step fails twice, suspend execution and enter RCA mode.

See the deployment RCA guardrail for retry caps and bootstrap immutability rules:
[`docs/reference/guardrails/deployment-rca.md`](/docs/reference/guardrails/deployment-rca.md).

---

## Prefix-to-Skill Routing

| Prefix | Skills to consult |
|---|---|
| `bug:` | `code-review`, `build-failure-triage` |
| `feature:` | `architecture`, `agent-design` (for new agents/skills) |
| `audit:` | `security`, `code-review`, `github-security-posture` |
| `plan:` | `sprint-planner`, `architecture`, `documentation` |
| `security:` | `security`, `github-security-posture` |
| `perf:` | `performance-profiling` |
| `docs:` | `documentation` |
| `test:` | `manual-test-strategy` |
| `deploy:` | `s4-deployment-checklist`, `architecture` |
| `rca:` | `build-failure-triage`, `failure-pattern-process` |

---

## Unknown or Missing Prefix

If a message has no prefix and is not clearly one intent type, ask before
acting. Ambiguous work done in the wrong mode wastes turns.

If the prefix is not in the vocabulary above, treat it as a custom label and
ask what it means before routing.
