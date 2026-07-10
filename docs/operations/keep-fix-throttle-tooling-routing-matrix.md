# Keep/Fix/Throttle Tooling Routing Matrix

This runbook defines default execution-mode routing for issue [#2048](https://github.com/ivegamsft/basecoat/issues/2048) (workstream 3 of epic #1452).

## Routing matrix by execution mode

| Mode | Default use | Entry signal | Constraints | Escalation trigger |
|---|---|---|---|---|
| local | Single-repo edits and short validation loops where full command output is needed immediately | Narrow file scope, low fan-out, short runtime | Keep changes scoped and avoid long-lived orchestration loops in main thread | Task runtime or fan-out exceeds local loop efficiency |
| background | Long-running validations, broad scans, or delegated work that should not block main session decisions | Parallelizable subtasks, monitorable progress | Main session remains decision-focused; use one kickoff and `/tasks` monitoring | Subtask needs privileged environment or external systems unavailable locally |
| cloud | Heavy or isolated execution requiring clean remote environment and reproducible runs | Environment parity, longer jobs, dependency isolation needs | Use for prepared workloads with clear handoff contract | Requires human judgment checkpoint before irreversible actions |
| manual | High-risk or ambiguous operations requiring explicit operator control | Tier 3/4 risk, policy uncertainty, production-impacting action | Two-person or explicit approval gates apply where required | N/A (terminal mode for the step) |

## Enforcement points

1. **Task intake:** classify requested work to one default mode before tool execution.
2. **Mid-run drift check:** if runtime shape changes (scope, risk, or environment need), reroute once and record why.
3. **Pre-merge gate:** confirm final route was policy-compliant and no high-risk step bypassed manual requirements.
4. **Post-run telemetry:** capture route selected, reroute count, and intervention reason to support overhead reduction tracking.

## Exceptions and override policy

| Condition | Allowed override | Required note |
|---|---|---|
| SLA-sensitive unblock where default mode would miss delivery window | local -> background or cloud | Reason + expected latency gain |
| Missing capability in current mode (for example environment, credentials, compute) | local/background -> cloud | Missing capability and verification path |
| Risk reclassification during execution | any -> manual | Risk tier change and approver |
| Repeated orchestration churn | background/local -> manual checkpoint then reroute | Churn symptom and corrective route |

Overrides are permitted only when they reduce risk or execution overhead relative to the default route.

## Usage examples

| Scenario | Recommended mode |
|---|---|
| Small documentation + one lint pass | local |
| Repo-wide audit with multiple independent checks | background |
| Reproducible long-running CI-like validation in isolated environment | cloud |
| Production-affecting governance or release control action | manual |
