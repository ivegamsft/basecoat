# Operational agent ownership and interactions

Status: documentation-only proposal for #3696. The owner requested suggestions,
replacement/augmentation analysis and interaction design, not implementation.
No agent profile, router, workflow, collector, permission or runtime changes
are authorized by this document or its merge.

## Question and product constraints

Which operational capabilities should BaseCoat add, consolidate or enhance
without duplicating specialists or concentrating write authority?

[PRODUCT.md](../../PRODUCT.md) requires composability, evidence before action,
visible guardrails and local ownership. Existing profiles are evidence of
declared responsibilities, not proof of deployed automation or healthy systems.
[Custom agent profiles](https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-custom-agents)
provide reusable behavior and tools; they do not independently schedule
continuous monitoring or enforce platform permissions.

## Design debate

| Option | Evidence and scope | User/accessibility impact | Risks |
| --- | --- | --- | --- |
| Enhance existing owners | Catalog already contains planning, gates, delivery, rollout and AgentOps specialists; add bounded evidence contracts | Fewer entry points; consistent plain-language status and handoffs | Profiles become broad unless ownership and exclusions are explicit |
| Add focused specialists | Runner registration/capacity/routing has a distinct operational boundary | Discoverable diagnosis with readable evidence and recovery steps | Duplicate monitoring, privileged tools and extra routing/evaluation cost |
| One autonomous operations agent | Coordinator can route concerns, but cannot safely inherit every owner's authority | Simple entry point but opaque responsibility | Concentrated credentials, conflicting fixes and large blast radius |

Recommendation: enhance existing owners, add at most one runner-operations
specialist initially, and retain a thin coordinator. Reject a broad autonomous
operations owner. Consider an API-contract investigator only if repeated demand
justifies an independent profile rather than a skill used by existing owners.

## Replace, augment or enhance

The following are proposals, not findings that existing agents should be deleted.

| Capability | Existing assets / evidence | Proposed treatment | Boundary |
| --- | --- | --- | --- |
| Runner readiness and recovery | [Health workflow](../../.github/workflows/runner-health-observability.yml), [collector](../../scripts/report-runner-health.ps1), [CI audit](../../agents/basecoat-50-security-ci-audit.agent.md), [self-healing CI](../../agents/basecoat-60-workflow-self-healing-ci.agent.md) | Augment collectors and add a runner-operations diagnostic owner | Collector monitors; specialist interprets; provisioner owns registration |
| Dependency unblock planning | [Delivery gap mapper](../../agents/basecoat-10-core-delivery-gap-mapper.agent.md), [backlog autopilot](../../agents/basecoat-60-workflow-backlog-autopilot.agent.md) | Enhance graph classification and prerequisite-first handoff | Do not replace deployed-workcell [blocker monitor](../../agents/basecoat-10-core-dependency-blocker-monitor.agent.md) |
| Credential/access readiness | [Gate diagnostician](../../agents/basecoat-60-workflow-gate-diagnostician.agent.md), CI audit | Enhance capability probes and explicit unknown/denied states | Propose least privilege; never grant access merely because dry-run is false |
| Delivery evidence reconciliation | [Ship-it control loop](../../agents/basecoat-60-workflow-ship-it-control-loop.agent.md), [release readiness](../../agents/basecoat-60-workflow-release-readiness-chair.agent.md) | Enhance commit/check/package/deployment joins | Control loop records state; readiness assesses; neither overrides admission |
| Consumer drift diagnosis | [Rollout BaseCoat](../../agents/basecoat-60-workflow-rollout-basecoat.agent.md), CI audit | Augment provenance/access collection and rollout handoff | Upgrade owner changes payload; audit owner reports gaps |
| Agent capability readiness | [AgentOps](../../agents/basecoat-10-core-agentops.agent.md) | Enhance tool/auth/integration and evaluation readiness | Not individual feature execution or an authorization issuer |
| API capability investigation | Gate diagnostician, [API designer](../../agents/basecoat-10-core-api-designer.agent.md), [contract testing](../../agents/basecoat-10-core-contract-testing.agent.md) | Start as a reusable investigation procedure; optional later specialist | Unsupported contract is not fixed by invented guarantees or unsafe probes |

Replace repeated manual polling, duplicate alert generation and success-shaped
fallbacks with shared deterministic collectors and one incident owner. Do not
replace platform branch protection, environment gates, IaC, runner provisioners
or canonical approval records with agent judgments.

Do not consolidate aliases based on filenames alone. Before retiring a profile,
inventory callers, distribution overlays, routing and evaluations; provide an
approved compatibility migration and prove behavior coverage. No profile is
deprecated by this proposal.

## Proposed interaction contract

This is a logical evidence packet, not an implemented schema or new durable store.

| Field | Required meaning |
| --- | --- |
| Scope | Authorized repository/project/environment and requested operation |
| Identity | Incident/correlation ID and immutable run/head/artifact identifiers |
| Evidence | Source, observation time, collection command/API, revision and freshness policy |
| Observation | `observed`, `denied`, `unavailable` or `stale`; never coerce missing data to zero |
| Assessment | `ready`, `degraded`, `blocked` or `unknown`, with a reason and bounded applicability |
| Ownership | One responsible specialist, prerequisite edges and next-action owner |
| Action | Read-only diagnosis or specifically authorized recovery, expected preconditions and rollback |
| Bounds | Deadline, retry budget, attempt history and cancellation/stop condition |
| Result | Verified outcome, evidence references and unresolved work; no implied approval |

Evidence inherits source access controls. Store only scoped references and
necessary facts, not tokens, registration credentials, full private logs or
unnecessary source bodies. Unknown access prohibits reading or redistributing
restricted evidence; a service credential does not expand actor authority.

## Interaction sequence

1. A deterministic scheduled/event collector or explicit request supplies
   evidence. A custom agent profile is not itself a scheduler.
2. The coordinator validates scope and freshness, deduplicates by stable
   incident/resource identity, and selects one specialist. Read-only collection
   may run independently; conflicting writes have one serialized owner.
3. The specialist diagnoses and classifies the next step as actionable in
   current authority, decision-needed, or external-capability unavailable.
4. For dependencies, expand verified prerequisite edges; process ready leaves
   before dependents. Do not invent edges or skip a prerequisite because the
   parent is older. Independent ready branches may continue within scope.
5. The coordinator passes a bounded handoff, not its credentials or implicit
   authority. The receiver revalidates actor, target and evidence before action.
6. An authorized deterministic executor performs recovery or an issue/PR lane
   delivers a proposed change. Policy approval, secrets and IaC remain separate.
7. Independent checks/canaries establish the result. The specialist returns
   verified evidence; failed/unknown verification never resolves the incident.
8. The coordinator checkpoints progress and continues other ready work or
   reports the precise remaining decision/blocker. Delivery closure follows
   source acceptance, not agent completion or a successful command alone.

No runtime implementation can infer its write approval from this sequence.
One bounded coordinator owns deduplication/checkpointing; agents must not
recursively spawn overlapping coordinators or independently close the same issue.

## Scenario: runner capacity and configuration

Collector -> runner-operations -> gate diagnostician or IaC/provisioner owner
-> bounded validation -> control-loop evidence.

Augment repository inventory with paginated organization/group visibility and
declared expected capability pools. Distinguish unregistered, offline, busy,
ineligible and unknown; ephemeral pools require expected capacity/provisioning
signals rather than a fixed list of runner names. Validate OS/architecture,
labels, group repository access and workflow routing. Registration availability
alone does not establish service health or job eligibility.

Use an independent monitoring lane, not solely the self-hosted pool being
monitored. A proposed bounded canary per required capability class proves
execution; host service/disk/network/image telemetry comes from infrastructure.
Canaries consume resources and need explicit policy, timeout and cleanup.
The current daily report is evidence collection, not proof of these extensions.

API denied -> gate diagnosis with required capability and access owner.
Online but canary fails -> host/routing investigation, not repeated registration.
Capacity exhausted -> provisioning/capacity owner, not a flaky-test repair.
Code failure on a healthy runner -> broken-build/self-healing CI owner.
Runner-operations proposes bounded recovery; registration tokens remain with
the provisioner. No credential widening or infrastructure creation outside IaC.

## Scenario: prerequisite and unsupported API

Gap mapper -> verified dependency graph -> contract investigation ->
design decision or ready implementation leaf -> backlog autopilot.

Issue #3400 depends on remaining #3616 persistence, then #3617 runtime and #3618
release acceptance. Owner-selected option 1 retains GitHub milestones.
Projects APIs offer planning views but do not establish conditional mutation.
An investigator distinguishes documented support, observed behavior and unproven
assumptions; live mutation experiments need separately authorized scope.

Report the exact invariant and tested alternatives. Preserve live-write gates,
but identify safe read-only/design work instead of stopping at a parent label.
Changing acceptance or pin semantics requires a decision; filing a proposal
does not resolve that decision or certify platform capability.

## Scenario: access and consumer drift

Collector -> gate diagnostician/CI audit -> access owner, or rollout owner
when drift is actually measured -> upgrade PR -> provenance validation.

Repository-scoped workflow tokens may not read downstream repositories.
Denied lookup means unknown posture, not zero drift or a healthy consumer.
Use approved least-privilege capabilities; never copy local CLI credentials
into workflow secrets. After access is restored, re-collect before proposing
an upgrade. Rollout owns the isolated upgrade lane and version provenance.
Audit remains independent and does not claim rollout success.

## Scenario: delivery and agent readiness

AgentOps readiness -> bounded task assignment -> check/package/deployment
evidence -> ship-it control loop -> release-readiness assessment.

AgentOps checks declared tools, configured integration access and evaluations
for the selected environment. Available tools do not prove credentials work.
Unknown readiness blocks affected side effects, not unrelated read-only work.

Join evidence by exact commit, workflow attempt, package digest, deployment
target and release identifiers. Distinguish implemented, validated, merged,
packaged, deployed and production-verified. Pending gates remain pending;
missing publication evidence is not success. Release-readiness does not create
new mandatory human reviews for already authorized XS-XL delivery.

## Evaluation and adoption proposal

Start with contracts and collectors, not profile proliferation. A future approved
implementation should separately deliver runner evidence, owner handoffs and
catalog/evaluation updates; normal source/runtime distribution rules apply.

Required evaluation cases include:

- Partial pagination, inaccessible org groups, ephemeral churn, offline/busy
  runners, wrong labels, and canary failure despite an online API status.
- Missing permissions, stale evidence, repeated events, lost responses,
  exhausted retries and explicit cancellation with no new side effects.
- Cyclic or unknown prerequisite graphs, one blocked branch alongside an
  independent ready branch, and unsupported API assumptions.
- Green merge with missing package/deployment evidence, mismatched digests,
  failed production verification and unauthorized recovery attempts.
- Misrouted ownership, duplicate incident actions, source content requesting
  credential expansion, and false closure after an unverifiable result.

Measure diagnosis accuracy, false-ready/false-closure rates, duplicate actions,
handoff latency, recovery verification and token overhead against current
behavior. Owner-defined thresholds and shadow comparison precede opt-in recovery.
Readable tables, descriptive links and explicit unknown states are required;
no status may rely on color alone.

Rollback disables proposed recovery and restores routing while preserving audit
evidence. Retire overlapping profiles only after approved migration and passing
coverage. Approval of this documentation does not authorize any implementation.
