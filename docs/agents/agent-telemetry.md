# Agent Telemetry and Observability Framework

Defines an observability framework for Base Coat agent operations so teams can debug failures, tune performance, manage spend, and satisfy audit expectations without rebuilding telemetry from scratch for every workflow.

> **Tracking:** Issue [#115](https://github.com/IBuySpy-Shared/basecoat/issues/115)

---

## 1. Why Agent Observability Matters

Agent systems are multi-step, stateful, and tool-driven. When they fail or become expensive, the failure is rarely isolated to a single prompt.

Observability matters because it enables teams to:

- Debug session failures, loops, retries, and degraded tool behavior
- Optimize prompts, routing, tool usage, and session handoff policies
- Control token burn, per-task cost, and runaway execution patterns
- Support compliance, auditability, and operational review requirements

A practical observability model should cover the three core pillars:

- **Metrics** for volume, cost, latency, completion, and reliability trends
- **Traces** for end-to-end visibility across sessions, subtasks, and tool calls
- **Logs** for detailed event history and failure investigation

---

## 2. Key Metrics

The following metrics provide a compact operational baseline.

| Metric | Description | Collection Point |
|--------|-------------|-----------------|
| Token usage per session | Input + output tokens | Every LLM call |
| Tool call count | Tools invoked per task | PostToolUse hook |
| Error rate | Failed tool calls / total | OnError hook |
| Session duration | Wall-clock time per session | SessionStart/End |
| Task completion rate | Successfully finished / started | SessionEnd |
| Loop detection count | Anti-loop triggers fired | PostToolUse |
| Handoff frequency | Session rotations per task | OnBudgetExceeded |
| Cost per task | Token cost in USD | SessionEnd aggregation |

Recommended interpretation guidance:

- Treat token usage, session duration, and cost per task as the primary efficiency signals
- Treat error rate, loop detection count, and handoff frequency as instability signals
- Treat task completion rate as the top-level service health metric for agent workflows

---

## 3. Distributed Tracing

Tracing should model the full execution tree rather than only the final answer.

### Trace Spans

Use a nested span hierarchy:

- **Session** → the full agent runtime window
- **Task** → a scoped user objective or work packet inside the session
- **SubTask** → delegated steps, retries, or child agent work
- **Tool Call** → individual tool executions with latency and outcome data

### Correlation IDs

Every session should have a stable `session_id` and a trace-level correlation ID that links related sessions in the same handoff chain.

Use correlation IDs to:

- Tie together session rotations caused by budget limits or failures
- Follow parent/child agent relationships across delegated work
- Reconstruct execution history for audit or incident review

### Context Propagation

When one agent invokes another, propagate the active trace context so downstream work inherits:

- Parent trace ID
- Parent span ID
- Task or work-item identifier
- Budget or policy metadata relevant to the child run

Without context propagation, handoffs become disconnected events instead of a single observable workflow.

### Sampling Strategy

High-volume environments should not trace every event at full fidelity forever.

Use a sampling policy such as:

- Full sampling for errors, loops, budget events, and stuck sessions
- Higher sampling for newly deployed agents or experimental tools
- Lower baseline sampling for routine successful sessions
- Tail-based retention for traces that exceed cost, duration, or error thresholds

---

## 4. Structured Logging

Logs should be machine-readable and operationally consistent.

### Log Levels

- **DEBUG** — tool input/output, raw hook decisions, verbose diagnostics
- **INFO** — task state changes, session lifecycle events, normal summaries
- **WARN** — retries, degraded fallbacks, elevated latency, soft budget pressure
- **ERROR** — failed tool calls, unhandled exceptions, aborted tasks

### Required Fields

Every log event should include at minimum:

- `session_id`
- `timestamp`
- `agent_name`
- `event_type`

Commonly useful additional fields include `trace_id`, `span_id`, `task_id`, `tool_name`, `status`, `duration_ms`, and `token_count`.

### Sensitive Data Redaction

Logs must avoid retaining secrets, credentials, private prompts, and regulated user content unless explicitly required and protected.

Redaction policy should:

- Remove tokens, secrets, and auth headers before persistence
- Mask prompt fragments or tool output that may contain sensitive business data
- Preserve enough metadata for debugging without storing raw confidential payloads

### Rotation and Retention

Log retention should match operational and compliance needs.

A practical baseline is:

- Short retention for verbose DEBUG logs
- Longer retention for INFO and WARN operational history
- Policy-driven retention for ERROR logs tied to incidents or audits
- Rotation by size and time window to prevent uncontrolled disk growth

---

## 5. Dashboard Design

Dashboards should support both live operations and retrospective analysis.

### Real-Time Views

Operational dashboards should surface:

- Active sessions
- Error rate
- Token burn rate

These views help operators spot saturation, tool failures, or cost spikes while a workflow is still in progress.

### Historical Views

Trend dashboards should show:

- Cost trends
- Completion rates
- Most-used tools

These views help identify which agents are efficient, which tools are expensive, and which workflows need redesign.

### Alerts

Alerting should trigger on the most actionable conditions:

- Budget exceeded
- Error spike
- Loop detected
- Session stuck

Alerts should link back to the relevant trace, summary metrics, and recent logs so responders can move from notification to diagnosis quickly.

---

## 6. Integration with Hooks

Hooks are the natural collection points for agent telemetry.

| Hook | Telemetry Responsibility |
|------|--------------------------|
| `SessionStart` | Begin trace span and log session metadata |
| `PostToolUse` | Record tool metrics and update the active span |
| `OnError` | Log error event and increment the error counter |
| `SessionEnd` | Close spans and emit summary metrics |
| `OnBudgetExceeded` | Alert and record a budget event |

### `SessionStart`

Use `SessionStart` to create the root session span, initialize correlation IDs, and capture immutable metadata such as agent name, repo, branch, model, and policy context.

### `PostToolUse`

Use `PostToolUse` to emit tool latency, success/failure state, token impact when available, and loop-detection counters after each tool execution.

### `OnError`

Use `OnError` to normalize failures into structured events, increment error metrics, and preserve enough trace context to support retries or postmortem review.

### `SessionEnd`

Use `SessionEnd` to flush final counters, calculate session duration, compute cost per task, mark completion state, and close outstanding trace spans.

### `OnBudgetExceeded`

Use `OnBudgetExceeded` to emit alerts, record forced handoff events, and preserve budget exhaustion details for later tuning.

---

## 7. Implementation Options

Teams can adopt observability in stages based on complexity and scale.

### Lightweight

JSON log files combined with periodic analysis scripts.

Best for local development, low-volume internal agents, or early prototypes.

Characteristics:

- Minimal dependencies
- Easy to inspect manually
- Good fit for nightly summaries or ad hoc analysis
- Limited real-time visibility and cross-session tracing

### Medium

OpenTelemetry SDK piping into a local collector and dashboard.

Best for teams that want standardized metrics, traces, and logs without committing to a single vendor immediately.

Characteristics:

- Portable instrumentation model
- Better trace visualization and correlation
- Supports local and hosted backends
- Requires collector and dashboard operations

### Enterprise

Azure Monitor, Application Insights, or Datadog integration.

Best for production environments that need central monitoring, alerting, access controls, and long-term operational reporting.

Characteristics:

- Managed dashboards and alert pipelines
- Strong integration with enterprise security and retention controls
- Better support for fleet-wide observability across many agents and repos
- Higher implementation and platform cost

---

## 8. Recommended Adoption Path

A staged rollout keeps telemetry useful without overengineering the first implementation.

1. Start with structured JSON logs and summary metrics at hook boundaries
2. Add trace IDs and correlation IDs before introducing child-agent orchestration at scale
3. Promote high-value metrics into dashboards and alerts once usage patterns stabilize
4. Move to OpenTelemetry or enterprise monitoring when session volume, cost, or compliance needs justify it

The goal is not maximum data collection. The goal is actionable visibility into how agents spend time, use tools, incur cost, and fail in production.
