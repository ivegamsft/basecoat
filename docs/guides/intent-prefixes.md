# Intent Prefixes

BaseCoat sessions use a structured prefix convention to communicate intent.
Every message prefix tells the AI three things at once: **what kind of work**,
**how urgent**, and **which agents to involve**.

Prefix prompts should use native SDLC nouns (workflow run, job, PR, issue,
release, version drift) to reduce routing ambiguity.

---

## The prefix vocabulary

| Prefix | Means | Timing | Routes to |
|---|---|---|---|
| `bug:` | Defect, regression, broken behavior | **Now** | `@code-review`, `@self-healing-ci` |
| `feature:` | New capability or enhancement | **Backlog** | `@sprint-planner`, `@solution-architect` |
| `audit:` | Review, assess, validate — no changes | **Now, read-only** | `@security-analyst`, `@config-auditor` |
| `plan:` | Sprint or project planning | **Now, no implementation** | `@sprint-planner`, `@product-manager` |
| `optimize:` | Normalize composite prompts into an execution packet with scope, stop rules, validation clauses, and routing hints before execution | **Now, advisory-first** | `@task-scope-validator`, `@orchestrator`, `@prompt-coach` |
| `spike:` | Time-boxed investigation, no deliverable | **Now, research only** | `@solution-architect` |
| `chore:` | Maintenance, cleanup, non-functional | **Soon** | `@devops-engineer`, `@release-manager` |
| `pr:` | Pull request lifecycle handling: remaining WIP logging, merge readiness, build-gated lane closeout, and branch/worktree hygiene. Use `pr-lifecycle=full` when you want the whole chain kept together. | **Now** | `lane-closeout` skill, `@orphaned-pr-cleanup`, `@merge-coordinator`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `fleet:` | Close previous sprint, plan and execute the next sprint, triage oldest issues, audit PRs/builds, clean branches | **Now** | `@parallel-session-coordinator`, `@sprint-closeout-auditor`, `@sprint-planner`, `@issue-triage`, `@broken-build-troubleshooter`, `@branch-hygiene-sweeper` |
| `workflow:` | GitHub Actions workflow failure triage and repair | **Now** | `@broken-build-troubleshooter`, `@self-healing-ci`, `@devops-engineer` |
| `actions:` | GitHub Actions configuration, runs, and policy checks | **Now** | `@self-healing-ci`, `@ci-failure-escalation`, `@devops-engineer` |
| `issue:` | GitHub issue triage, labeling, and backlog hygiene | **Now** | `@issue-triage`, `@sprint-planner` |
| `portfolio:` | Project audit across issues and PRs: dedupe, categorization, dependency wiring, feature grouping, and project linking | **Now** | `@issue-triage`, `@orphaned-pr-cleanup`, `@sprint-project-mapper`, `@sprint-planner`, `@governance-auditor` |
| `release:` | Release planning, version bumping, and publication | **Now** | `@release-manager`, `@release-readiness-chair`, `@release-impact-advisor` |
| `version:` | BaseCoat version inspection and drift check | **Now** | `@release-manager`, `@devops-engineer` |
| `security:` | Security concern or vulnerability | **Now, high priority** | `@security-analyst`, `@guardrail` |
| `perf:` | Performance degradation | **Now, measure first** | `@performance-analyst` |
| `outage:` | Service outage, broken or dead system, site down | **Now, high priority** | `@rca`, `@incident-responder` |
| `rca:` | Root-cause analysis of a known failure — execution suspended | **Now, read-only** | `@rca`, `@config-auditor` |
| `deploy:` | Staged infrastructure deployment — azure-prepare, azure-validate, azure-deploy in sequence | **Now, staged** | `@devops-engineer` |
| `azure:` | Azure-scoped operation (auth, infra, SDK, provisioning) | **Now** — preflight first, then staged sequence | `@devops-engineer`, `@solution-architect` |
| `infra:` | Infrastructure change (IaC, networking, firewall, RBAC) | **Now** — preflight first, then staged sequence | `@devops-engineer`, `@solution-architect` |
| `architect:` | Architecture design or system-design decision | **Later** — plan before any implementation | `@solution-architect` |
| `docs:` | Documentation only | **Soon** | `@tech-writer` |
| `chronicle:` | Export session/worktree learnings into durable story updates and issue-ready follow-up packets | **Soon** | `@memory-promoter`, `@tech-writer` |
| `test:` | Test coverage gap or test failure | **Now** | `@manual-test-strategy` |
| `refactor:` | Structural improvement, no behavior change | **Later, batch** | `@code-review` |
| `ui:` | User interface: components, layout, visual and interaction implementation | **Soon** | `@frontend-dev`, `@ux-designer`; conditional sheen delegate for governance/audit |
| `ux:` | User experience: flows, usability, journeys, interaction design | **Soon** | `@ux-designer`, `@frontend-dev`; conditional sheen delegate for governance/audit |
| `ia:` | Information architecture: content structure, navigation, taxonomy, sitemap | **Soon** | `@ux-designer`, `@tech-writer`; conditional sheen delegate for governance/audit |
| `design:` | Product-definition and UX/UI governance, design system, component audit, or finish-coat work; `debate:` compares options before implementation | **Soon** | Read downstream `PRODUCT.md`, use `.github/base-coat/docs/reference/design-debate-format.md` (or custom overlay location), then use the `basecoat-sheen` catalog when applicable |
| `sprint:` | Sprint planning, execution, or closeout | **Now** | `@sprint-planner`, `@sprint-closeout-auditor` |
| `wave:` | Dependency-ordered batch within a sprint (issues and PRs) | **Now** | `@sprint-planner`, `@parallel-session-coordinator` |
| `autopilot:` | Continuous oldest-to-newest backlog burndown in dependency-ordered waves, unattended until stopped or blocked | **Now** | `@backlog-autopilot`, `@parallel-session-coordinator`, `@ship-it-control-loop`, `@delivery-autopilot` |

---

## Intent families

Each prefix belongs to an intent family. Families are useful for routing and
for selecting chain patterns.

| Family | Prefixes | Default output type |
|---|---|---|
| Delivery | `feature:`, `refactor:`, `deploy:`, `architect:` | implementation plan, code changes, or staged deployment |
| Reliability | `bug:`, `perf:`, `outage:`, `rca:` | fix, mitigation, incident analysis, or root-cause report |
| Governance | `audit:`, `security:`, `chore:` | findings, policy action, risk controls |
| GitHub Operations | `workflow:`, `actions:`, `pr:`, `issue:`, `portfolio:`, `release:`, `version:` | run triage, repo hygiene, release/version decisions |
| Planning | `plan:`, `spike:`, `sprint:`, `wave:` | prioritized backlog, design notes, decision doc |
| Continuous delivery | `autopilot:` | unattended multi-wave backlog burndown with merge-queue landing and deploy |
| Packetization | `optimize:` | normalized execution packet and optional execution chain |
| Quality | `test:`, `docs:`, `ui:`, `ux:`, `ia:`, `design:` | tests, documentation, or design artifacts |
| Knowledge capture | `chronicle:` | story/update packet, follow-up issue bundle, optional memory suggestions |
| Infrastructure | `azure:`, `infra:`, `deploy:` | preflight advisory, IaC changes, staged deployment |

---

## Syntax matters as much as the prefix

The same prefix means different things depending on how it appears in the message.

### Standalone → act now

```text
bug: the sync script exits with code 1 on Windows when BASECOAT_REPO is unset
```

A prefix at the start of a standalone message is an immediate work order.
The AI investigates and fixes it in this session.

### Bulleted list → triage and log, not implement

```text
- bug: metrics dashboard is broken on mobile
- feature: add a getting-started prompt
- chore: clean up stale branches
```

Prefixes inside a bulleted list are **triage items**. The AI logs them
(as GitHub issues, plan notes, or backlog entries) and confirms receipt.
It does **not** start implementing.

> This is the most important distinction. A bulleted `feature:` means
> *"add this to the backlog."* It does not mean *"build this now."*

### Mixed message → preamble is immediate, list is triage

```text
run an audit against the CI workflows and log issues

- feature: add retry logic to sync.sh
- bug: secret-scan.yml always exits 0
```

The preamble instruction ("run an audit") executes now.
The bulleted items are logged. The AI returns audit findings plus a summary
of what was filed. It waits for direction before starting any of the list items.

---

## Timing modifiers

These words in a message override the default timing of any prefix:

| Word | Effect |
|---|---|
| `now`, `immediately`, `urgent` | Promote to immediate, even `feature:` |
| `later`, `backlog`, `next sprint` | Defer, even `bug:` |
| `no changes`, `read-only` | Analysis only, suppress all implementation |
| `log it`, `file an issue` | Log and stop; do not implement |
| `just document` | Documentation output only; no code changes |

---

## Optimize routing

Use `optimize:` when the request bundles multiple intents (for example, plan +
execute + triage + RCA) and needs a bounded execution packet before action.

### Packet contract

`optimize:` should produce:

1. **Objectives** — explicit, ordered objectives.
2. **Scope boundaries** — what is included and excluded.
3. **Stop conditions** — done, blocked, and manual-stop conditions.
4. **Validation clauses** — what must pass before closure.
5. **Routing hints** — direct agent/skill/workflow path per objective.

### Advisory-only mode

If the prompt contains `advisory-only`, emit the packet and stop without side
effects.

### Compatibility with `ship-it` and `rca`

When `optimize:` wraps `ship-it` or `rca`, keep existing governance and safety
rules intact; packetization must not bypass required checks or RCA evidence
capture.

---

## Plan-first enforcement

For `feature:`, `refactor:`, and `architect:` prefixes, a planning step is
required before implementation begins whenever the work spans multiple files
or involves design decisions.

The expected flow:

1. Emit a plan (scope, approach, risks, verification criteria).
2. Present it and wait for confirmation.
3. Implement only after the plan is confirmed.

The user can waive planning explicitly ("no plan needed", "skip planning",
"implement directly"). Record the waiver so downstream agents respect it.

### Sprint-style request nudge

When the user asks to "plan and execute the next sprint" or similar:

1. Route to `@sprint-planner` first.
2. Present the sprint plan and wait for confirmation.
3. Only then begin execution with the oldest actionable item.

---

## Azure preflight

Before any `azure:`, `infra:`, or `deploy:` operation, emit this advisory:

```text
Azure preflight: ci-firewall and rbac-authentication checks apply.
See instructions/basecoat-60-workflow-ci-firewall.instructions.md and instructions/basecoat-50-security-rbac-authentication.instructions.md.
```

Then verify:

- **CI Firewall** — workflow accesses firewalled Azure resources? Confirm the
  single-job runner IP pattern (`instructions/basecoat-60-workflow-ci-firewall.instructions.md`)
  is in place before deploying.
- **RBAC Authentication** — change provisions or configures Azure resources?
  Confirm RBAC-only auth (`instructions/basecoat-50-security-rbac-authentication.instructions.md`)
  before proceeding.

The advisory is non-blocking unless a firewall or RBAC gap is found, in which
case surface the finding and wait for explicit user confirmation.

---

## Audit mode is always read-only

`audit:` never makes changes unless the user adds "and fix" or "resolve."

```text
audit: run a say-vs-do check on the CI workflows
```

→ Returns findings. Logs issues if asked. Waits.

```text
audit: run impeccable against GH Pages, log issues, and resolve
```

→ Runs audit, logs issues, then implements fixes.

---

## Why this convention exists

Working in a long session with many items in flight, prefixes let you:

- **Drop items into the backlog mid-conversation** without losing flow
- **Signal urgency without context-switching** — the AI knows `security:` means
  stop and address it, `chore:` means batch it
- **Audit without side effects** — `audit:` is a safe way to ask "what's wrong
  here?" without triggering changes
- **Control sprint scope** — a bulleted list of `feature:` items at the end of
  a message becomes the next sprint's backlog, not this session's work

---

## Outage routing

When a user says a service is broken, dead, down, or not responding, normalize
that request to `outage:` and route it to the RCA agent.

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

Use `@rca` for the deep-dive investigation after the active incident is stable.

---

## RCA routing

`rca:` suspends all execution. Use it when you want to diagnose before retrying.
The prefix activates the public `rca` skill; use `@rca` when you want to invoke
the deeper RCA agent explicitly.

| Alias | Normalized intent |
|---|---|
| `stop and rca` | `rca:` |
| `why is it failing` | `rca:` |
| `same error` (after a prior failure) | `rca:` |
| `still broken` (after a retry) | `rca:` |
| deployment retried 3 or more times | `rca:` (hard block) |

To resume execution after RCA, re-issue a `deploy:` or `outage:` intent explicitly
once the root cause is confirmed.

For broken build RCA intake, use
[`docs/templates/rca-broken-build-intake.md`](../templates/rca-broken-build-intake.md)
to capture required evidence fields consistently.

---

## Term disambiguation and aliases

Normalize these bare terms and phrases to an intent before plain-text
interpretation.

### Design terms: UI vs UX vs IA

`ui`, `ux`, and `ia` are distinct disciplines and must not collapse to one route.
Governance and audit requests may use the downstream `basecoat-sheen` delegate;
direct implementation remains with the local routes.

| Term | Discipline | Normalized intent | Routes to |
|---|---|---|---|
| `ui` | User interface — components, layout, visual and interaction implementation | `ui:` | `@frontend-dev`, `@ux-designer`; conditional downstream governance/audit delegate |
| `ux` | User experience — flows, usability, journeys, interaction design | `ux:` | `@ux-designer`, `@frontend-dev`; conditional downstream governance/audit delegate |
| `ia` | Information architecture — content structure, navigation, taxonomy, sitemap | `ia:` | `@ux-designer`, `@tech-writer`; conditional downstream governance/audit delegate |
| `design` | Product-definition and UX/UI governance, design system, component audit, or finish-coat work; `debate:` compares options before implementation | `design:` | Read downstream `PRODUCT.md`, use `.github/base-coat/docs/reference/design-debate-format.md` (or custom overlay location), then use the `basecoat-sheen` catalog when applicable |

### Error and failure: route on the subject noun

`error`, `fail`, and `failing` are overloaded. Route on what is failing, not on
the word. `broken`, `broke`, `down`, `dead`, `site down`, and `not responding`
normalize to `outage:` only when the subject is a running service, site, or app
(see Outage routing); application code or test defects route to `bug:` and
GitHub Actions workflow/CI failures route to `workflow:`.

| Subject of the error/failure | Normalized intent | Routes to |
|---|---|---|
| A running service, site, or app is down | `outage:` | `@rca`, `@incident-responder` |
| A GitHub Actions workflow run, job, or CI step | `workflow:` | `@broken-build-troubleshooter`, `@self-healing-ci` |
| Application code or a test defect | `bug:` | `@code-review`, `@self-healing-ci` |
| Repeated or unknown failure needing diagnosis first | `rca:` | `@rca`, `@config-auditor` |

When the subject noun is absent or ambiguous, ask one disambiguation question
before acting.

### Work-in-progress and cleanup

| Term or phrase | Normalized intent | Routes to |
|---|---|---|
| `wip` | `pr:` (remaining WIP logging) | `@orphaned-pr-cleanup` |
| `backlog wip` | `issue:` (backlog WIP triage) | `@issue-triage` |
| `clean up branches` / `stale branches` | `chore:` | `@branch-hygiene-sweeper` |
| `clean up worktrees` / `clean up work trees` / `prune worktrees` | `chore:` | `@branch-hygiene-sweeper` + `git-worktrees` skill |

`wip/`, `preserved/`, and `backup/` branches are retained (never auto-pruned) and
logged with an owner and next action. Never remove a worktree with uncommitted
changes or one an active agent is using.

### Backlog and sprint execution

| Phrase | Normalized intent | Routes to |
|---|---|---|
| `burn down the backlog` / `backlog burndown` / `burndown` | backlog-burndown skill | `@issue-triage`, `@orphaned-pr-cleanup`, `@sprint-planner` |
| `plan sprint` / `execute sprint` / `sprint` | `sprint:` | `@sprint-planner` |
| `close sprint` / `sprint closeout` / `sprint retro` | `sprint:` | `@sprint-closeout-auditor` |
| `wave` | `wave:` | `@sprint-planner`, `@parallel-session-coordinator` |
| `burn the backlog` / `work the backlog` / `backlog autopilot` / `continuous delivery loop` | `autopilot:` | `@backlog-autopilot`, `@ship-it-control-loop`, `@delivery-autopilot` |

Burn-down and wave execution include open PRs, not just issues. Decomposition
hierarchy: **sprint -> wave -> issue -> task**.

---

## Chronicle routing

Use `chronicle:` to convert execution history into durable repo artifacts.

Expected outputs:

1. Markdown story/update packet from session/worktree references.
2. Append or update mode for target story docs.
3. Issue-ready learnings list for follow-up tracking.
4. Optional memory-promotion suggestions with dedupe checks.

---

## Deployment routing

`deploy:` enforces the staged deployment sequence and prevents skipping validation.

**Required chain:**

1. `azure-prepare` — scaffold IaC and validate configuration
2. `azure-validate` — pre-deployment checks, no resource changes
3. `azure-deploy` — provision and deploy

If the same deployment step fails twice, the session automatically enters RCA mode.

Example prompt:

```text
deploy: follow azure-prepare -> azure-validate -> azure-deploy exactly; do not deploy until validated
```

See [`docs/reference/guardrails/deployment-rca.md`](../reference/guardrails/deployment-rca.md)
for retry caps, path lock, and bootstrap immutability rules.

---

## PR routing

`pr:` is the direct intent for PR lifecycle execution.

`pr-lifecycle` is an optional modifier for `pr:` requests. Supported values are
`none`, `standard` (default), and `full`. Keep `pr:` as the prefix and append
the modifier only when the default behavior needs to change:

- `pr-lifecycle=none` — skip lifecycle steps; operate on a single PR without
  triage, branch hygiene, or cleanup passes.
- `pr-lifecycle=standard` — default; merge-ready validation, required-CI check,
  and branch cleanup for the affected PR only.
- `pr-lifecycle=full` — end-to-end across triage, merge, broken-build recovery,
  and cleanup for all open PRs in scope.

Use one authoritative prefix per request. Inputs that combine prefixes (for
example `feature: pr:`) are invalid and should be rejected with guidance to
choose either `feature:` or `pr:`.

### Default sequence

1. Log remaining WIP and triage stale or blocked pull requests with `@orphaned-pr-cleanup`.
2. Validate merge readiness and ordering with `@merge-coordinator`.
3. Verify required CI status before closure; if builds are red, route to `@broken-build-troubleshooter`.
4. Run `lane-closeout` for each exact branch/worktree and record
   `MERGED`, `HANDED_OFF`, `ABANDONED`, or `PARKED`.
5. Prune eligible terminal lanes only through `@branch-hygiene-sweeper` and the
   `git-worktrees` skill after re-verifying the exact worktree mapping.

### Guardrails

- Do not close or mark complete while required builds are still pending.
- If required builds fail, keep the PR open and attach failure evidence.
- Only run branch cleanup for branches tied to merged/closed PRs with required builds passing.
- Do not mark a full lifecycle request complete while WIP tasks or uncommitted changes remain.
- Do not auto-prune `preserved/`, `backup/`, or `wip/` branches; log them as retained WIP with an owner and next action.
- Treat a blocked open PR as `HANDED_OFF` and a conflict, interruption, or failed
  publish as `PARKED`; both are valid recorded stopping states.
- Session/worktree-end automation runs lane-closeout in `safe` mode: capture,
  push, and report only, never rebase, merge, close, delete, or remove a worktree.
- Prefer serial merges for overlapping branches to reduce conflict churn.

---

## Fleet routing

`fleet:` is the shortcut intent for a sprint-execution batch that combines closeout, planning, oldest-first issue triage, PR/build auditing, and branch cleanup. It must start with the parallel-session coordinator and a latest-main sync preflight before fan-out.

### Normalized examples

| User phrasing | Normalized intent |
|---|---|
| `Fleet deployed: use basecoat...` | `fleet:` |
| `fleet: plan and execute the sprint` | `fleet:` |
| `use basecoat for fleet mode` | `fleet:` |

### Fleet chain

- `@parallel-session-coordinator`
- `@sprint-closeout-auditor`
- `@issue-triage`
- `@broken-build-troubleshooter`
- `@sprint-planner`
- `@branch-hygiene-sweeper`

### Persistent next-wave loop mode

When prompts repeat "plan and execute the next wave" (or equivalent continuation
language), keep fleet execution in a bounded control loop instead of re-running
full planning on every turn.

Contract:

1. Keep authoritative routing as `fleet:` with latest-main preflight first.
2. Execute continuation cycles using `ship-it-control-loop` semantics.
3. Emit a checkpoint each cycle from `/tasks`, in-scope PRs, and required checks.
4. Apply bounded retries for transient failures and escalate when retries are exhausted.
5. Stop on completion, blocking gate, max-cycle cap, or manual stop.

Normalized examples:

| User phrasing | Normalized execution path |
|---|---|
| `plan and execute the next wave` | `fleet:` + persistent `ship-it-control-loop` cycle |
| `execute the next wave` | `fleet:` + persistent `ship-it-control-loop` cycle |
| `continue ship-it loop` | `fleet:` + persistent `ship-it-control-loop` cycle |
| `burn the backlog until stopped` / `work the backlog in waves` | `autopilot:` + `@backlog-autopilot` multi-wave loop |

---

## GitHub-native deterministic routing

`workflow:`, `actions:`, `pr:`, `issue:`, `release:`, and `version:` are
deterministic routes. If the prefix is present, do not ask a follow-up
disambiguation question before first evidence collection.

### Contract

1. `workflow:` / `actions:`: fetch failing run and job evidence first, then fix,
   then rerun affected scope.
2. `pr:`: inspect PR state first (mergeability, checks, review blockers), then act.
3. `issue:`: inspect issue state first (labels, stale status, ownership), then act.
4. `release:`: start from release/version source-of-truth, then perform release steps.
5. `version:`: read installed downstream version first; compare to latest published
   release only when install origin is published BaseCoat.

---

## The instruction file

This convention is codified in
[`instructions/basecoat-10-core-intent-routing.instructions.md`](https://github.com/IBuySpy-Shared/basecoat/blob/main/instructions/basecoat-10-core-intent-routing.instructions.md).

When BaseCoat is synced to your repo, this instruction is loaded by Copilot
automatically and applies to all conversations. You can adopt this prefix
convention in your own team immediately — no configuration required.

---

## Examples

### Good: bug in a standalone message

```text
bug: the lint workflow silently passes on instructions with trailing spaces
```

AI fixes it now.

### Good: features in a bulleted list

```text
- feature: add retry logic to sync.sh
- feature: add a prompt for onboarding new repos
- feature: support BASECOAT_EXCLUDE env var
```

AI logs three backlog items and reports what was filed.

### Common mistake: bulleted feature treated as immediate

```text
- feature: add a getting-started prompt
```

Wrong response: "Here is the getting-started prompt I just created..."
Correct response: "Logged as a backlog item. Should I add it to the current sprint?"

### Combine audit and fix explicitly

```text
audit: check all agent files for missing Workflow sections, log issues, fix them
```

AI audits → logs → fixes in one pass because "fix them" was explicit.

---

## Prompting with proper vocabulary

Use a compact, deterministic shape when writing prompts:

```text
<prefix>: <objective>
scope: <in/out boundaries>
constraints: <non-negotiables>
deliverable: <artifact to return>
evidence: <what to prove>
next-hop: <agent name or none>
```

### Delivery example

```text
feature: add plan-first lint checks for new agent files
scope: instructions/basecoat-10-core-agents.instructions.md and tests only
constraints: no workflow changes
deliverable: updated instruction rule plus test case
evidence: failing then passing test output
next-hop: code-review
```

### Governance example

```text
audit: evaluate all skills for missing USE FOR / DO NOT USE FOR sections
scope: skills/**/SKILL.md
constraints: read-only; log issues but do not edit files
deliverable: severity-ranked findings table
evidence: file paths and missing-section counts
next-hop: none
```

---

## Chain recipes by intent

Use these default chains unless there is a task-specific reason to override.

| Intent | Chain | Outcome |
|---|---|---|
| `feature:` | `plan: -> solution-architect -> backend-dev/frontend-dev -> code-review` | plan-first, then design to implementation with review |
| `refactor:` | `plan: -> code-review -> performance-analyst` | plan-first, then structural improvement |
| `architect:` | `plan: -> solution-architect` | plan-first, then design decision |
| `bug:` | `code-review -> self-healing-ci -> guardrail` | defect isolation and safe fix |
| `outage:` | `rca -> incident-responder -> sre-engineer` | triage, containment, and reliability follow-up |
| `rca:` | `rca -> config-auditor` | root-cause diagnosis, execution suspended |
| `azure:` | `azure-preflight -> azure-prepare -> azure-validate -> azure-deploy` | preflight advisory, then staged deployment |
| `infra:` | `azure-preflight -> azure-prepare -> azure-validate -> azure-deploy` | preflight advisory, then staged deployment |
| `deploy:` | `azure-prepare -> azure-validate -> azure-deploy` | staged deployment with pre-flight validation |
| `security:` | `security-analyst -> policy-as-code-compliance -> guardrail` | remediation and policy validation |
| `security:` credential exposure | `incident-responder -> secrets-manager -> guardrail` | containment, revocation/replacement, consumer recovery, and prevention validation |
| `plan:` | `product-manager -> sprint-planner` | scoped sprint-ready backlog |
| `test:` | `manual-test-strategy -> strategy-to-automation` | test strategy and automation candidates |
| `portfolio:` | `issue-triage -> orphaned-pr-cleanup -> sprint-project-mapper -> sprint-planner -> governance-auditor` | end-to-end project hygiene with dedupe, grouping, dependency traceability, and governance checks |

When chaining, each handoff prompt should include:

1. Intent statement.
2. What is done.
3. What remains.
4. Constraints that must carry forward.
5. Expected output contract.

### Credential exposure closure

Phrases such as `token exposed`, `secret leaked`, `credential in logs`, or
`key disclosed` stay under the existing `security:` intent. They activate the
credential-exposure chain rather than creating a new intent.

The chain is not complete until the disclosure path is fixed, the exposed
credential is revoked, a least-privilege replacement is installed, exposed
artifacts are removed after sanitized evidence capture, all consumers recover,
and learnings are logged. Owner-only credential actions remain explicit blockers;
log deletion or secret-store replacement alone is not closure.

---

## Design notes

These conventions intentionally prefer:

- **Intent-first routing** over asking users to pick an agent manually.
- **Canonical verbs** (`triage`, `classify`, `validate`, `escalate`, `handoff`)
  over ambiguous verbs.
- **Standard chains** over ad hoc sequencing.

This keeps prompting predictable and improves routing eval reliability.
