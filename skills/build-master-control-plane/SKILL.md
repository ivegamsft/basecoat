---
name: build-master-control-plane
description: "Use when defining or operating a build-master control plane that keeps merges flowing while containing CI breakage. USE FOR: lane-state policy, break-fix eligibility, retry/revert thresholds, and escalation rules. DO NOT USE FOR: direct code implementation, bypassing branch protection, or approving high-risk fixes without policy gates."
compatibility: ["agent:build-master", "agent:merge-coordinator", "agent:ci-failure-escalation"]
visibility: "internal"
---

# Build Master Control Plane Skill

Use this skill to design and run a safe background merge control plane with a
paired cloud break-fix worker.

## Reference Files

| File | Purpose |
| --- | --- |
| [`references/state-machine.md`](references/state-machine.md) | Lane/global state definitions and transitions |
| [`references/policy-matrix.md`](references/policy-matrix.md) | Break-fix eligibility, retry budgets, and escalation thresholds |

## Workflow

1. Map PRs into lanes and assign risk tiers.
2. Merge serialized per lane only when pre-merge policy gates are green.
3. Detect and classify post-merge failures by lane and blast radius.
4. Dispatch cloud break-fix worker only for allow-listed low/medium-risk failures.
5. Keep healthy lanes moving while pausing impacted lanes by policy.
6. Resume paused lanes only after fix PR verification and policy checks.
7. Escalate to blocking issue/global hold when thresholds are exceeded.

## Agent Pairing

- `build-master`
- `merge-coordinator`
- `broken-build-troubleshooter`
- `ci-failure-escalation`
