# Delivery Autopilot Integration

`delivery-autopilot` provides an approve-once orchestration scaffold across agent, skill, and script layers.

## Assets

1. Agent: `agents/basecoat-60-workflow-delivery-autopilot.agent.md`
2. Skill: `skills/delivery-autopilot/SKILL.md`
3. Scripts:
   - `scripts/delivery-autopilot/evaluate-status.ps1`
   - `scripts/delivery-autopilot/execute-merge.ps1`
   - `scripts/delivery-autopilot/build-escalation-payload.ps1`

## Workflow Integration Path

1. `pr-auto-merge-executor.yml` uses readiness posture and merge policy.
2. `post-merge-release-chain.yml` receives merge outcomes and dispatches release gating.
3. `automation-stuck-state-watchdog.yml` consumes escalation payloads for stalled stage remediation.

## Validation

Run:

```powershell
pwsh -NoProfile -File tests/delivery-autopilot-tests.ps1
```

The test suite verifies:

- required agent/skill/eval coverage exists
- helper scripts emit deterministic dry-run JSON
- integration documentation references the canonical workflow chain
