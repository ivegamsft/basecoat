# AI SDLC Work Units and Intent Vocabulary

Status: design proposal, 2026-10-07. Parent: #3625.
No new intent below is implemented or authorized by this document.
Existing [intent routing](../guides/intent-prefixes.md) remains authoritative.
The [spec-to-production trace](../guides/spec-to-production.md) is a dated
operational audit, not proof that every current handoff is automatic.

## Question

Should AI-assisted work be organized by calendar periods or verified outcomes?
How can BaseCoat distinguish the requested outcome from execution topology,
authorization and safety limits without confusing harness terminology?

AI can shorten implementation, but integration, review, external dependencies,
capacity and operational observation still take time. Faster code generation
does not establish production correctness or make time-based planning obsolete.

## Option 1: Time-based work units

A sprint or review period groups work within a fixed interval. The interval ends
even if some work remains unfinished; unfinished scope must be explicitly
replanned, not declared complete.

- Evidence: BaseCoat has `sprint:`, sprint labels, release grouping, weekly
  triage/hygiene/report jobs, and the current `fleet:` sprint-boundary bundle.
- User impact: predictable priority reviews and coordination with human teams.
- Implementation scope: preserve existing planning and reporting contracts.
- Accessibility: familiar to agile teams, but requires explaining planning versus delivery.
- Risks: artificial release waits, rollover hiding blocked work, and confusing
  period closure with verified feature completion.

Time boxes remain appropriate for discovery, experiments, operational
observation and spending limits. A deadline is a constraint, not acceptance
evidence. An elapsed time limit should produce a checkpoint or blocked/limited
outcome, never successful completion by itself.

## Option 2: Completion-based work units

A bounded scope progresses until explicit acceptance and delivery evidence
passes, or it stops on a blocker, exhausted budget or revoked authority.
Completion-based does not mean unbounded execution.

- Evidence: BaseCoat already has spec acceptance, dependency-ordered `wave:`,
  explicit `ship-it:`/`spec-2-prod:`, exact-head checks, native merge queue,
  immutable promotion evidence and bounded control-loop contracts.
- User impact: validated work can ship independently of a planning calendar.
- Implementation scope: clarify state/exit contracts and vocabulary; reuse
  existing governance instead of introducing a second delivery engine.
- Accessibility: outcome words are easier to discover than agent/harness metaphors.
- Risks: ambiguous "done", endless loops, batch scope creep, evidence reuse for
  the wrong revision, or mistaking parallelism for authorization.

## Recommendation

Use a hybrid: calendar-based priority/outcome reviews, completion-based
execution and delivery, and time/cost/retry limits as independent safety budgets.
No evidence currently justifies abolishing sprint planning everywhere.

| Dimension | Time-based planning | Completion-based execution/delivery |
| --- | --- | --- |
| Unit | Review period / sprint | Approved scope / change / bounded batch |
| Primary question | What should we prioritize this period? | What evidence makes this scope complete? |
| Boundary | Scheduled review date | Defined acceptance and target outcome |
| Incomplete work | Explicit replan with blocker | Resume from checkpoint or stop with reason |
| Release cadence | Can coordinate releases; should not force a wait | Release when gates and scope policy permit |
| Budget | Period capacity | Per-scope time, cost, retry and concurrency limits |
| Accountability | Priority owner and review participants | Scope owner, authority, execution owner and evidence |
| Measurement | Commitments versus outcomes per period | Lead time, blocked time, change failure, recovery, cost per outcome |
| Failure mode | Rollover or "sprint done" without delivery | Infinite continuation or "tests green" mistaken for production success |

## BaseCoat concepts: supported versus proposed

| Existing concept | Current supported role | Proposed conceptual separation |
| --- | --- | --- |
| `fleet:` | Sprint lifecycle bundle; coordinator preflight; bounded continuation contracts | Execution arrangement, not an outcome or delivery permission |
| `sprint:` | Plan/execute/close out a sprint | Optional planning/review period |
| `wave:` | Dependency-ordered bounded batch | Ready batch; membership and dependencies determine completion |
| `autopilot:` | Continuous oldest-first delivery loop, serial or fleet | Continuing execution policy with explicit scope/stop limits |
| `feature:` | Design/implement/validate; feature-origin PR remains draft absent delivery consent | Implementation work separate from authorization to deliver |
| `plan:`, `issue:`, `portfolio:` | Planning, triage, relationship and project hygiene | Work preparation and ordering; not approval |
| `ship-it:`, `spec-2-prod:` | Explicit governed delivery routing with live approval/scope evidence | Delivery outcome; candidate vocabulary migration only |
| `release:`, `deploy:` | Release lifecycle and staged deployment | Publication versus deployment to a named destination |
| `audit:`, `investigate:`, `rca:` | Read-only assessment and diagnosis | Evidence assessment, with distinct purpose |
| `approved`, `copilot-agent` | Issue authority and assignment intent | Authorization and actual assignment are different states |
| `size:*`, risk tiers | Derived classification and policy gates | Consequence/scope controls, not execution duration estimates |
| Sprint/wave labels | Release grouping and traceability | Keep until label policy is deliberately migrated |
| Merge queue | Exact integration-tree checks and serialized landing | Parallel preparation does not authorize parallel merges |
| `vX.Y.Z` tag and public publish | Versioned release and transformed public payload | Verified release identity; merge/issue closure is not delivery |

The current routing disallows dual authoritative prefixes. Do not use
`fleet: ship-it:` or assume the proposed prefixes are aliases today.
Any future parallelism option must be orthogonal to outcome, preserve separate
branch/worktree lanes, and keep dependent and release-affecting merges serialized.

## Proposed intent contracts

Each issue is a design proposal, not a mandate to add another prefix.
Naming overlap must be resolved before routing implementation.

| Proposal | Requested outcome and completion unit | Default boundary | Existing overlap / open decision | Issue |
| --- | --- | --- | --- | --- |
| `prepare:` | An actionable bounded work packet | Assessment; no approval or implementation | `plan:`, `issue:`, `portfolio:`; explicit permission for metadata writes | #3626 |
| `spec:` | A testable specification with alternatives and acceptance | Spec artifacts only; generation is not approval | PRD/spec synthesis and design debate | #3627 |
| `build:` | Approved scope implemented and validated | Draft handoff absent separate delivery consent | `feature:`; compile-only meaning may justify `implement:` instead | #3628 |
| `review:` | Findings and disposition for artifacts/outcomes | Read-only; no implicit GitHub APPROVED review | `audit:`, advisory code review, post-delivery learning | #3629 |
| `deliver:` | Approved scope reaches verified target outcome | Explicit delivery authority; every boundary revalidated | `ship-it:`/`spec-2-prod:`; rename versus alias unresolved | #3630 |
| `ship:` | Validated immutable release published and verified | Publication authority; no implementation scope expansion | `release:`, `deploy:`, `ship-it:`; separate prefix may be unnecessary | #3631 |

If both are adopted, `deliver:` owns the whole outcome; `ship:` owns only
publication of a ready artifact. Do not give both identical scope.
`build:` must not silently mean compile in one context and end-to-end delivery
in another. `review:` must not silently submit approval or fix findings.

## Completion and authorization model

A proposed work packet records source issue/spec revision, approved scope and
non-goals, owner, dependencies, required evidence, destination, current authority
and execution budgets. Track the last verified state, not just the last activity.

| State | Exit evidence | Does not imply |
| --- | --- | --- |
| Prepared | Scope/dependencies/acceptance and next decision defined | Implementation authorization |
| Specified | Versioned testable contracts and rollout/rollback design | Approved spec or generated approval |
| Authorized | Current qualified issue/spec authority | Feature-origin delivery consent unless separately validated |
| Implemented | In-scope change and positive/negative test evidence | Ready status, merge or production |
| Validated | Fresh checks for the correct revision/tree | Approval or correctness of a different artifact |
| Integrated | Verified queue merge against intended base | Release/tag creation |
| Published | Intended version/artifact available at destination | Healthy runtime or adoption |
| Verified | Required target smoke/health/behavior evidence | Permission for further scope |
| Closed | Traceable acceptance and delivery ledger | Erasing unresolved follow-up work |

Blocked, paused, limited and cancelled are explicit non-success outcomes.
Budget exhaustion records a checkpoint. An authorized scope change invalidates
affected evidence and requires a new acceptance contract.

Solo-dev stays zero routine human PR reviews through XL, after applicable
explicit intake and delivery authority. XXL and other explicit human boundaries
remain. Prefixes, labels, green tests, generated comments and parallel execution
cannot manufacture consent. Existing feature-origin markers, live receipts,
delivery holds and trusted default-branch governance remain authoritative.

## Suggested AI SDLC vocabulary

These are conceptual terms first, not a request to register additional prefixes.

| Term | Meaning | Avoid confusing with |
| --- | --- | --- |
| Outcome | Observable user/operational result | Number of tasks completed |
| Work packet | Bounded source scope, decisions, constraints and evidence | A pasted agent prompt |
| Change | One cohesive reviewable implementation | A planning period |
| Ready batch | Explicit dependency-compatible set of actionable work | Every issue in a backlog |
| Dependency frontier | Work whose prerequisites are currently satisfied | Maximum concurrency |
| Acceptance contract | Measurable positive/negative requirements | Deadline or vague "done" |
| Evidence bundle | Revision/target-bound checks and artifacts | A dispatch marker |
| Decision record | Alternatives, rationale and accepted constraints | Implementation authorization |
| Checkpoint | Durable verified progress and resumable next action | Success or a fresh restart |
| Blocker | Named unmet condition, owner and recovery action | Mere age or inactivity |
| Execution budget | Time/cost/retry/concurrency limits | Acceptance criteria |
| Publication | Making an immutable release available | Merge or production health |
| Verification window | Required runtime observation after publication | An arbitrary sprint |
| Review period | Scheduled priority/outcome/learning assessment | Mandatory release interval |
| Completion ledger | Source-to-change-to-release-to-target evidence | Closed issue count |

### Lifecycle and control verbs

The conceptual lifecycle is prepare -> specify -> decide -> implement ->
verify -> publish -> observe -> learn. This is not a mandatory sequence of
prefixes or additional approvals. Iteration may revisit earlier stages;
`deliver:` would own the authorized end-to-end outcome rather than introduce
a separate engine for every stage.

| Verb | Bounded outcome | Authority / stop boundary | Existing overlap |
| --- | --- | --- | --- |
| Verify | Acceptance or production evidence for an exact revision and target | Gather/report proof; no automatic fix, approval or deployment | `test:`, `audit:`, release gates |
| Resume | Continue from a verified checkpoint | Recheck live authority, target, blockers and budget; never inherit revoked consent | Control-loop continuation, PR lifecycle |
| Reconcile | Difference between intended and actual state, with a correction plan | Read-only by default; corrections require explicit write authority | Governance/drift audits |
| Recover | Restore a failed delivery or service | Bounded approved remediation; destructive rollback/cutover needs applicable authority | `rca:`, `bug:`, build guard |
| Observe | Runtime health, adoption, cost and reliability evidence | Defined target/window/budget; monitoring does not mutate service | Operational monitoring |
| Learn | Durable guidance from outcomes and recurring signatures | Existing opt-in contract, not automatic policy rewriting | Already supported `learn:` |
| Decompose | Independent scopes and a dependency graph | Planning only; child work does not inherit approval automatically | `plan:`, scope validation, proposed `prepare:` |
| Decide | Recorded choice, alternatives and constraints | Decision acceptance is not implementation/delivery consent | Design debate |
| Pause | Execution checkpoint and suspended new side effects | Handle in-flight work explicitly; no promise of undoing published changes | Delivery hold, control-loop stop |
| Cancel | Terminate a scope and record outstanding effects | Separate rollback/cleanup authority; cancellation is not successful completion | Control-loop cancellation |
| Retire | Safely remove an obsolete capability | Dependency, retention, ownership and rollback checks before authorized removal | `chore:`, decommissioning |
| Implement | Code change for approved specification | Validation and draft handoff absent delivery authority | Clearer candidate than ambiguous `build:` |
| Publish | Make a validated immutable release available | Explicit destination/version authority and verified results | `release:`, proposed `ship:` |

Pause, cancel, resume and recover are control actions, not mandatory lifecycle
stages. Observation time can be a required acceptance condition; it is not
the same as calendar-based sprint completion.

### Suggested new intents

Prioritize debate of `verify:`, `resume:` and `reconcile:` because their exits
are distinct: fresh proof, safe continuation, and intended-versus-actual
alignment. A proposal must define input evidence, read/write permissions,
non-success outcomes and deterministic routing before it becomes supported.

For `verify:`, test stale revision and wrong-target rejection; for `resume:`,
test revoked authorization, exhausted budgets and changed dependencies; for
`reconcile:`, test report-only operation and separately authorized corrections.

Consider `implement:` as an alternative within #3628, not an additional synonym
for `build:`. Reserve build terminology for compilation/artifact production
unless its broader implementation meaning is explicitly selected.
Likewise, compare `publish:` with `ship:` in #3631 before choosing either.
Keep recover, observe, decompose, decide, pause, cancel and retire as vocabulary
unless existing routes cannot express their required boundary.

`learn:` is already supported; it is not a new-intent proposal. None of the
other verbs in this section is registered as a prefix by this document.
Do not create aliases solely to replace one ambiguous word with another.

### Keyword index

These are documentation/search keywords, not parser tokens, routing aliases
or delivery directives.

| Search concept | Keywords |
| --- | --- |
| Work units | AI SDLC, time-based, time-boxed, completion-based, outcome-based, bounded scope, review period, ready batch |
| Definition | prepare, spec, specify, decompose, decide, work packet, acceptance contract, dependency frontier |
| Implementation | build, implement, change, artifact, positive/negative tests |
| Evidence | review, verify, evidence bundle, exact revision, target identity, completion ledger |
| Delivery | deliver, ship, publish, release, production verification, rollback readiness |
| Continuation | resume, checkpoint, reconcile, drift, blocker, execution budget |
| Operational control | recover, pause, cancel, retire, in-flight effects, retention |
| Outcomes and learning | observe, verification window, learn, adoption, reliability, cost per outcome |

## Validation and migration

Measure per-scope lead time, execution versus waiting/blocked time, failure and
recovery, cost, rework, and verified production outcomes. Compare similar
scopes/risk tiers; faster generation or more PRs does not prove better delivery.
Audit a complete packet through acceptance and publication, including revoked
authority, stale evidence, dependency failure and exhausted-budget scenarios.

Before adding a token, require a distinct boundary, deterministic parser,
positive/negative routing tests, known read/write effects, documented target
state and reuse of existing policy helpers. Update canonical/distributed
instructions, skills, workflows, downstream installers and examples together
where applicable; regenerate tracked manifests when distributed assets change.
A docs-only proposal does not require that runtime migration.

Retain existing prefixes during a deliberate compatibility period. Do not
rewrite issue labels, approval records or source markers automatically.
Neither a rename nor an alias may broaden authority. Quoted/fenced/bulleted/
embedded examples, dual prefixes, defer modifiers and unauthorized actors must
remain non-executable or explicitly rejected.

## Approval boundary

The user authorized comparison documentation and six proposal issues.
Naming decisions, parser aliases, workflow changes, label migrations and runtime
execution require separate explicit approval and approved implementation specs.
