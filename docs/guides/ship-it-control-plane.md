# Ship-it Control Plane (Intent to Production)

The ship-it control plane turns a single intent (`ship-it`, `spec-2-prod`, or
`onboarding-conductor`)
into governed SDLC execution artifacts with live GitHub side effects.

## What v1 Delivers

1. **Intent entrypoints**
   - Manual dispatch: `.github/workflows/ship-it-intent-dispatch.yml`
   - Issue command: comment `/ship-it` on an issue
   - Onboarding command: comment `/onboarding` on an issue
2. **Governed artifact generation**
   - Parent intent issue with governance checklist
   - Three child sprint issues with exit criteria and evidence sections
3. **Risk-aware labeling**
   - `intent-control-plane`
   - `ship-it` or `spec-2-prod`
   - `risk-low|medium|high|critical`
4. **Automation-ready outputs**
   - JSON summary: `test-results\ship-it\summary.json`
   - Markdown summary: `test-results\ship-it\summary.md`
   - Stage artifacts per sprint/phase (branch name, PR title/query, merge policy, cleanup policy)
   - Latest-main sync and predecessor-wait guardrails for each child stage
5. **Build-break detection and bounded recovery**
   - Workflow: `.github/workflows/ship-it-build-guard.yml`
   - Detector: `scripts/ship-it/build-break-detector.ps1`
   - Failure classification into recoverable vs non-recoverable categories
   - Bounded retries for recoverable failures and escalation issue creation for non-recoverable or retry-exhausted incidents
6. **Release gate enforcement and staged promotion evidence**
   - Workflow: `.github/workflows/ship-it-release-gate.yml`
   - Enforcer: `scripts/ship-it/release-gate-enforcer.ps1`
   - Risk-band-specific required gates (`lint/build/type/e2e/security/smoke`)
   - Change/risk-band artifact matrix (`spec/docs/tests/runbook/release_notes`)
   - Single artifact completeness scorecard in the evidence bundle
   - Spec drift detection with remediation suggestions
   - Runbook and release-note deltas mapped to goal IDs
   - Production cutover block when rollback validation evidence is missing
   - Evidence bundle output with immutable references and bundle digest

## How to Use

### Persistent Control-Loop Mode

Use the dedicated control-loop assets when you need bounded, repeatable wave
execution without reissuing the full ship-it prompt each cycle:

1. Agent: `agents/basecoat-60-workflow-ship-it-control-loop.agent.md`
2. Skill: `skills/ship-it-control-loop/SKILL.md`

Required control-loop inputs:

- `goal`
- `target_repo`
- `max_cycles`
- `max_retries`
- `dry_run`

Cycle output must always include: phase, task/PR/check status snapshot, retry
state, next action, and stop-condition status (`continue|complete|blocked|max_cycles|manual_stop`).

### Workflow Dispatch

Run **BaseCoat - Ship-it Intent Dispatch** with:

- `intent`: `ship-it`, `spec-2-prod`, or `onboarding-conductor`
- `goal`: objective statement
- `target_repo`: `owner/repo`
- `risk_band`: `low|medium|high|critical`
- `profile`: `solo-dev|team-dev|regulated-team|pilot-luxesite|pilot-wawkr` (used by onboarding-conductor)
- `spec_ref` (optional)
- `project_owner` + `project_number` (optional)
- `dry_run`: `false` for live side effects

> Project sync is optional. Local or CLI-authenticated runs can add generated issues
> to a GitHub Project immediately. Workflow runs may need a token with project scope
> if project fields are supplied.

### Issue Comment Command

Comment on a GitHub issue:

`/ship-it Deliver governed release for feature X`

The workflow uses write-permission checks and defaults to:

- `intent=ship-it`
- `goal=comment argument` (or issue title)
- `risk_band=medium`
- `target_repo=current repo`

For onboarding conductor intake:

`/onboarding Enable governed onboarding for this repository`

The onboarding conductor flow creates four phase issues (`Discover`, `Plan`,
`Apply`, `Validate`) and emits profile-aware desired-state diff entries in
`test-results\ship-it\summary.json`. Reruns are marker-based and update existing
issues instead of creating duplicates.

For `profile=pilot-luxesite`, phase artifacts carry explicit lane metadata:

1. `Discover` -> `pilot-luxesite-baseline-remediation`
2. `Plan` -> `pilot-luxesite-artifact-contract`
3. `Apply` -> `pilot-luxesite-stabilization`
4. `Validate` -> `pilot-luxesite-release-readiness`

For `profile=pilot-wawkr`, phase artifacts carry canary-specific lane metadata:

1. `Discover` -> `pilot-wawkr-canary-baseline`
2. `Plan` -> `pilot-wawkr-canary-contract`
3. `Apply` -> `pilot-wawkr-canary-deployment`
4. `Validate` -> `pilot-wawkr-canary-validation`

## Governance Expectations

1. Do not bypass required checks for risky goals.
2. Keep merge operations serialized for release-affecting work.
   Child stages must sync from the latest `main` before they start and wait for the
   prior stage to close before opening or updating a PR.
3. Record rollout and rollback evidence links in sprint issues.
4. Capture post-release learnings before closeout.
5. Run branch cleanup audit after merged PRs on `main` (workflow trigger) and review audit logs.
6. Treat non-recoverable build-break classifications as escalation events; do not loop retries beyond configured retry budget.
7. Block stage promotion when required release gates fail for the selected risk band.
8. Require rollback runbook and rollback validation evidence before production cutover.

## Build Guard Behavior

The build guard can run two ways:

1. `workflow_run` trigger after failed `BaseCoat - Ship-it Intent Dispatch` or `BaseCoat - PR Validation` runs
2. Manual `workflow_dispatch` with explicit retry counters and branch/workflow filters

Detector outputs:

- `test-results\ship-it\build-break-summary.json`
- `test-results\ship-it\build-break-summary.md`
- Uploaded artifact: `ship-it-build-break`

Action policy:

- **Recoverable + retry budget available**: `action=retry`, rerun failed jobs
- **Non-recoverable**: `action=escalate`, open or update a remediation issue
- **Recoverable + retry budget exhausted**: `action=escalate`, stop retries and require fix-forward intervention

## Release Gate Behavior

Release gate workflow:

- `.github/workflows/ship-it-release-gate.yml`

Release gate outputs:

- `test-results\ship-it\promotion-evidence-bundle.json`
- `test-results\ship-it\promotion-evidence-bundle.md`
- Uploaded artifact: `ship-it-release-gate`

Action policy:

- **All required gates passing + policy checks satisfied**: `promotion_allowed=true`
- **Any required gate failing**: promotion blocked
- **Missing environment protection or required approvals**: promotion blocked
- **Production without validated rollback path**: promotion blocked
- **Missing required artifacts for current risk/change profile**: promotion blocked
- **Spec drift between contract and implementation goal IDs**: promotion blocked

Artifact evidence bundle now includes:

- `artifact_completeness.scorecard` (machine-readable)
- runbook and release-note delta maps keyed by goal ID
- spec drift report (`missing_from_spec`, `missing_from_implementation`, remediation suggestions)

When the execution lane is `pilot-luxesite`, release gate enforcement also requires:

- `lint`, `build`, `type`, `e2e`, `security`, `smoke` gates
- `spec`, `docs`, `tests`, `runbook`, `release_notes` artifacts

## Learning Log (Implementation)

1. **Command + dispatch pairing improves adoption**: issue comments reduce operator friction, while workflow dispatch keeps structured control.
2. **Risk labels make queue triage faster**: simple labels are easy to query and useful for downstream dashboards.
3. **Artifact-first orchestration scales**: parent/child issue generation provides a stable handoff surface for existing orchestrator agents.
4. **`gh label create` requires positional label names**: using `--name` fails in automation and must be avoided.
5. **Live seed run validated governance shape**: initial execution created one parent issue and three sprint issues, then grouped them in Project #13.
6. **Onboarding conductor flow needs explicit remediation hooks**: dispatch failures now open or update a remediation issue to keep follow-up actionable.
7. **Pilot lane overlays keep onboarding deterministic**: luxesite pilot runs now emit lane-aware stage artifacts and enforce strict gate/artifact overlays in release gate checks.
