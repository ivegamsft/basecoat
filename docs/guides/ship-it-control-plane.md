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

## How to Use

### Workflow Dispatch

Run **Ship-it Intent Dispatch** with:

- `intent`: `ship-it`, `spec-2-prod`, or `onboarding-conductor`
- `goal`: objective statement
- `target_repo`: `owner/repo`
- `risk_band`: `low|medium|high|critical`
- `profile`: `solo-dev|team-dev|regulated-team` (used by onboarding-conductor)
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

## Governance Expectations

1. Do not bypass required checks for risky goals.
2. Keep merge operations serialized for release-affecting work.
3. Record rollout and rollback evidence links in sprint issues.
4. Capture post-release learnings before closeout.

## Learning Log (Implementation)

1. **Command + dispatch pairing improves adoption**: issue comments reduce operator friction, while workflow dispatch keeps structured control.
2. **Risk labels make queue triage faster**: simple labels are easy to query and useful for downstream dashboards.
3. **Artifact-first orchestration scales**: parent/child issue generation provides a stable handoff surface for existing orchestrator agents.
4. **`gh label create` requires positional label names**: using `--name` fails in automation and must be avoided.
5. **Live seed run validated governance shape**: initial execution created one parent issue and three sprint issues, then grouped them in Project #13.
6. **Onboarding conductor flow needs explicit remediation hooks**: dispatch failures now open or update a remediation issue to keep follow-up actionable.
