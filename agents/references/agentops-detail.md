# AgentOps — Detail Reference

## Lifecycle States

| State | Meaning | Exit Criteria |
|---|---|---|
| `draft` | Not ready for traffic | Validation plan and owner assigned |
| `candidate` | Passed pre-deploy checks | Rollout plan approved |
| `active` | Receiving production traffic | Health stays within thresholds |
| `deprecated` | Should not receive new traffic | Replacement version available |
| `retired` | Disabled; preserved for audit only | Retention and audit rules satisfied |

Lifecycle rules:

- Never promote a candidate without a clear rollback target.
- Never retire the last known-good version until the replacement is stable.
- Model swaps and tool-permission changes are version-impacting events.
- Require a dated deprecation notice before retirement when downstream systems depend on the version.

## Health Monitoring Thresholds

| Signal | Healthy | Investigate | Roll Back |
|---|---|---|---|
| Quality score | At or above baseline | 1-3% below baseline | More than 3% below baseline |
| Error rate | Within normal range | Above baseline trend | Threshold breach or sustained spike |
| Latency | Within SLO | Near SLO limit | SLO breach during rollout |
| Token efficiency | Stable or improved | Cost trend worsening | Sharp cost increase with no quality gain |
| User feedback | Neutral or positive | Mixed | Sustained negative trend |

## Deployment Workflow Patterns

### Blue-Green

- Run current and candidate versions side by side.
- Route traffic gradually to candidate; keep instant failback ready.
- Compare health metrics on matched time windows before cutover.

### Canary

- Start with small percentage of requests on new version.
- Increase traffic only when quality, error, and latency metrics stay within thresholds.
- Freeze rollout if any leading indicator degrades.

### Rollback

- Revert routing immediately to last known-good version on regression, error spike, or policy failure.
- Roll back config changes, model swaps, and tool permissions together.
- Preserve failed version and telemetry snapshot for post-incident analysis.

### A/B Testing

- Route equivalent inputs to two versions under the same evaluation window.
- Measure quality, latency, token cost, and user preference.
- End experiment with a clear winner, follow-up action, or documented inconclusive result.

## Configuration Management Rules

- Version configuration changes independently from prompt text changes.
- Validate permission reductions and expansions before rollout.
- Prefer immutable version references over floating aliases during rollout.
- Managed assets: model assignments, tool permissions, routing weights, system prompt references, safety thresholds.

## Capacity Planning

- Forecast token usage, request volume, and rollout size before promotion.
- Track retry amplification and queue growth during rollout windows.
- Pause or slow rollout if capacity trends exceed safe thresholds.
- Record scaling actions and the resulting capacity delta in the operational report.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[AgentOps]`
- **Base labels:** `agentops,operations`
- **Category options:** `<rollout regression | drift | config risk | capacity risk | incident correlation gap>`
- **Agent:** `<agent name>`
- **Version:** `<version>`
- **Environment:** `<prod | staging | other>`
- **This domain replaces the shared template's `### Description` /
  `### Recommended Fix` / `### Acceptance Criteria` / `### Discovered
  During` sections with its own structure** (do not use both):
  - `### Summary` — what changed and why it matters.
  - `### Evidence` — **Metric or alert:** name; **Time window:** timestamp
    range; **Related change:** version/config/model/tool update.
  - `### Recommended Action` — `- [ ] <action 1>`.
  - `### Exit Criteria` — `- [ ] Health thresholds restored` and
    `- [ ] Rollout decision documented`.

| Finding | Labels |
|---|---|
| Quality regression during rollout | `agentops,quality` |
| Error-rate or latency threshold breach | `agentops,incident` |
| Drift without approved change record | `agentops,drift` |
| Missing rollback target or audit trail | `agentops,governance` |
| Capacity forecast showing saturation | `agentops,capacity` |

## Output Format

Operational report includes:

- Agent name; active, candidate, and fallback versions
- Selected rollout strategy and current traffic split
- Health summary (quality, error rate, latency, token efficiency, user feedback, drift)
- Incident correlation findings with recent changes
- Decision: `promote`, `pause`, `rollback`, `deprecate`, or `retire`
- Immediate next actions, owners, and observation window
