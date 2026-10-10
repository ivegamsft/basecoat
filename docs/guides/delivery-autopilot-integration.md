# Delivery Autopilot Integration

`delivery-autopilot` provides an approve-once orchestration scaffold across agent, skill, and script layers.

See [Spec-to-Production Pipeline](spec-to-production.md) for the complete
workflow/label/tag trace and dated operational gaps. The scaffold is not a
guarantee that every handoff is automatic.

## Assets

1. Agent: `agents/basecoat-60-workflow-delivery-autopilot.agent.md`
2. Skill: `skills/delivery-autopilot/SKILL.md`
3. Scripts:
   - `scripts/delivery-autopilot/evaluate-status.ps1`
   - `scripts/delivery-autopilot/execute-merge.ps1`
   - `scripts/delivery-autopilot/build-escalation-payload.ps1`

## Workflow Integration Path

1. `pr-auto-merge-executor.yml` uses readiness posture and merge policy.
2. `post-merge-release-chain.yml` receives merge outcomes and dispatches an
   evidence-only, dry-run validation gate plus source-repository packaging.
   Dispatch evidence is not production completion or release-tag creation.
3. `automation-stuck-state-watchdog.yml` scans stalled stages and opens/updates
   escalation issues. It does not deploy releases.

## Approved-Issue Assignment Recovery

Approved issues use one serialized worker for direct approval, forwarded
approval, and watchdog recovery. The worker records assignment attempts and
observed state in the issue's status comment; that comment and labels are not
approval evidence. Watchdog recovery is read-only by default. Do not set
`BASECOAT_AGENT_ASSIGNMENT_RECOVERY_ENABLED` to `true` until a genuinely
authorized, controlled assignment test is available and explicitly in scope.
Do not create an approval or assign a test issue merely to exercise recovery.
Without that live acceptance evidence, keep recovery writes disabled and report
the live acceptance as blocked.

The worker requires `pull-requests: read` to revalidate forwarded approvals and
read genuine execution evidence. Repeated sweeps preserve the first verified
assignment timestamp within the approval epoch; unrelated activity cannot
postpone the assignment-to-execution SLA. Once execution is observed, that
stage no longer escalates (and its existing escalation resolves); PR readiness
and release progress remain tracked by their separate stages.

## Validation

Run:

```powershell
pwsh -NoProfile -File tests/delivery-autopilot-tests.ps1
```

The test suite verifies:

- required agent/skill/eval coverage exists
- helper scripts emit deterministic dry-run JSON
- integration documentation references the canonical workflow chain
