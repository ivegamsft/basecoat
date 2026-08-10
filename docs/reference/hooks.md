# Agent Lifecycle Hooks Specification

Defines a portable hook model for Base Coat basecoat-10-core-agents so memory, telemetry, error handling, and session rotation can be attached to agent execution without modifying every agent prompt.

> **Tracking:** Issue [#145](https://github.com/IBuySpy-Shared/basecoat/issues/145)

---

## 1. Why Hooks Exist

Hooks provide controlled interception points around an agent session, tool execution, and context lifecycle.

They exist to solve recurring operational needs:

- Load memory and project context before work begins
- Persist handoff state when a session ends or rotates
- Enforce guardrails before risky tool calls
- Capture failures and learn from them after the fact
- Detect loops, budget exhaustion, and degraded sessions early
- Emit consistent telemetry without embedding logging logic into every agent

A hook system should be **optional, composable, and failure-tolerant**. If a hook fails, the agent should degrade gracefully rather than crash.

---

## 2. Hook Points

| Hook | When It Fires | Use Cases | Platform Support |
|------|---------------|-----------|-----------------|
| `SessionStart` | Agent session begins | Inject memory, load project context, set persona | ✅ All platforms |
| `SessionEnd` | Session ending or rotating | Save handoff state, persist memory, cleanup | ✅ All (`Stop` in VS Code/CLI) |
| `UserPromptSubmitted` | User submits a prompt | Audit requests, inject system context | ✅ All platforms |
| `PreToolUse` | Before any tool call | Validate permissions, inject known-fix warnings, log | ✅ All platforms |
| `PostToolUse` | After tool completes | Track errors, update knowledge base, detect loops | ✅ All platforms |
| `SubagentStart` | A subagent is spawned | Track nested agent usage, init subagent resources | ✅ VS Code / CLI |
| `SubagentStop` | A subagent completes | Aggregate results, clean up subagent resources | ✅ VS Code / CLI |
| `PreCompact` | Before context compaction | Save full state before lossy compression | ✅ All platforms |
| `PostCompact` | After compaction | Verify critical context preserved | ⚠️ BaseCoat extension only |
| `OnError` | Tool call fails | Log to error KB, check retry policy | ✅ All (`errorOccurred` in VS Code/CLI) |
| `OnBudgetExceeded` | Token budget threshold hit | Force session rotation, trigger handoff | ⚠️ BaseCoat extension only |

> **Note on BaseCoat extensions:** `PostCompact` and `OnBudgetExceeded` are BaseCoat-defined concepts not natively supported by current platform runtimes. Implement them via application logic in agent guidance or basecoat-10-core-mcp middleware rather than native hook basecoat-10-core-config files.

### `SessionStart`

Runs once at the beginning of an agent session.

Typical responsibilities:

- Load persistent memory relevant to the repo, issue, branch, or account
- Rehydrate a previous handoff document after session rotation
- Inject task framing such as repo conventions, current sprint context, or persona guidance
- Initialize telemetry correlation IDs for the session

### `SessionEnd` / `Stop`

> **Platform note:** VS Code and Copilot CLI call this event `Stop`. Use `Stop` in `.github/hooks/*.json` config. Use `SessionEnd` in BaseCoat agent guidance prose and basecoat-10-core-mcp patterns. Semantics are identical.

Runs when a session is about to terminate normally or rotate into a fresh session.

Typical responsibilities:

- Persist learned facts, summaries, or handoff notes
- Flush buffered telemetry and tool traces
- Record unresolved blockers for the next session
- Clean up temporary runtime state created by hook infrastructure

### `UserPromptSubmitted`

Runs immediately after the user submits a prompt, before any tools are invoked.

Typical responsibilities:

- Audit and log user requests for compliance analysis
- Inject repo conventions, sprint context, or task framing before the agent begins
- Detect prompt patterns that trigger specific workflows (e.g., "deploy" → arm watchdog)
- Block or flag prompts that violate policy before they reach the agent

### `PreToolUse`

Runs before any tool invocation is sent.

Typical responsibilities:

- Check whether the tool is allowed in the current mode or repo
- Warn about known failure patterns before expensive calls
- Add contextual hints, such as "this build often fails unless restore ran first"
- Record intent for audit and measurement

### `PostToolUse`

Runs after a tool completes, regardless of success or failure.

Typical responsibilities:

- Capture outputs, exit status, latency, and token cost
- Detect repeated failing patterns that indicate a loop
- Update success and failure knowledge bases
- Enrich future reasoning with newly learned constraints

### `SubagentStart`

Runs when a subagent is spawned by the parent agent.

Typical responsibilities:

- Track nested agent invocations for telemetry and cost attribution
- Initialize subagent-scoped resources or context
- Log the parent→child relationship for audit trails

### `SubagentStop`

Runs when a subagent completes, before returning control to the parent.

Typical responsibilities:

- Aggregate subagent results and pass summaries to parent context
- Clean up subagent-scoped resources
- Record subagent duration and output basecoat-90-quality-quality metrics

### `PreCompact`

Runs immediately before context is compacted or summarized.

Typical responsibilities:

- Save the full working state before lossy compression occurs
- Snapshot open todos, current plan, key file paths, and unresolved errors
- Generate a structured handoff payload for the next session

### `PostCompact`

Runs immediately after compaction finishes.

Typical responsibilities:

- Verify that critical state survived compaction
- Re-inject missing anchors such as issue number, branch name, or open blockers
- Record compaction basecoat-90-quality-quality metrics for later tuning

### `OnError` / `errorOccurred`

> **Platform note:** VS Code and Copilot CLI call this event `errorOccurred`. Use `errorOccurred` in `.github/hooks/*.json` config. Use `OnError` in BaseCoat prose and basecoat-10-core-mcp patterns.

Runs when a tool call or hook-managed action fails.

Typical responsibilities:

- Normalize the error into a reusable failure signature
- Check retry policy and fallback guidance
- Store actionable failure context in an error knowledge base
- Suppress duplicate alerts when the same failure repeats rapidly

### `OnBudgetExceeded`

Runs when token usage crosses a configured threshold.

Typical responsibilities:

- Trigger session rotation before output basecoat-90-quality-quality degrades further
- Save a compact but complete handoff summary
- Block additional large context loads or expensive tool calls
- Emit telemetry so budget tuning can be improved later

---

## 3. Hook Response Types

Hooks do not need to behave the same way. A useful framework supports a small set of standard outcomes.

| Response Type | Behavior | Typical Uses |
|---------------|----------|--------------|
| Pass-through | Hook runs and execution continues unchanged | Logging, telemetry, passive checks |
| Inject context | Adds `additionalContext` to the next reasoning step | Memory recall, known-fix hints, repo conventions |
| Block | Prevents the action from continuing | Budget exceeded, unsafe tool, loop detected |
| Modify | Transforms input or output | Compression, redaction, normalization |

### Pass-through

The hook observes the event, records data, and returns control without changing execution.

Use when:

- Measuring latency or token usage
- Auditing tool usage
- Recording session metadata

### Inject context

The hook appends extra context for the next reasoning step.

Use when:

- Loading persistent memory on `SessionStart`
- Surfacing known error workarounds on `PreToolUse`
- Reattaching preserved context on `PostCompact`

Example:

```json
{
  "action": "injectContext",
  "additionalContext": [
    "Repo convention: run pwsh tests/run-tests.ps1 before merge.",
    "Known fix: package step may require deleting stale dist artifacts first."
  ]
}
```

### Block

The hook stops execution and returns a reason.

Use when:

- A tool is disallowed in the current environment
- The agent exceeded its budget and must rotate
- A loop detector sees repeated failing commands

Example:

```json
{
  "action": "block",
  "reason": "Token budget exceeded at 82% of effective window; rotate session before continuing."
}
```

### Modify

The hook changes the input or output before control returns to the agent.

Use when:

- Redacting secrets from tool output
- Compressing verbose logs before they enter context
- Normalizing error objects into a consistent structure

Example:

```json
{
  "action": "modify",
  "modifiedOutput": {
    "summary": "dotnet restore failed due to private feed auth",
    "redacted": true
  }
}
```

---

## 4. Common Hook Contract

A portable hook contract keeps the framework implementation-neutral while still giving enough structure for tooling.

### Event Envelope

```json
{
  "hook": "PostToolUse",
  "timestamp": "2025-04-27T18:42:31Z",
  "sessionId": "sess_01J...",
  "agent": "basecoat-10-core-backend-dev",
  "repository": "IBuySpy-Shared/basecoat",
  "branch": "feat/145-hooks-framework",
  "budget": {
    "usedTokens": 78124,
    "effectiveLimit": 160000
  },
  "tool": {
    "name": "powershell",
    "success": false,
    "durationMs": 6422
  }
}
```

### Response Envelope

```json
{
  "action": "passThrough",
  "priority": 50,
  "additionalContext": [],
  "warnings": [],
  "metadata": {
    "hookId": "anti-loop-detector"
  }
}
```

Suggested fields:

- `action` — `passThrough`, `injectContext`, `block`, or `modify`
- `priority` — used for ordering when multiple hooks run on the same event
- `additionalContext` — optional context to inject into the next reasoning step
- `warnings` — non-blocking notices for the agent runtime
- `modifiedInput` / `modifiedOutput` — only present for modify responses
- `metadata` — diagnostic fields that should not affect reasoning semantics

---

## 5. Implementation Patterns

### Registering Hooks

A Base Coat deployment can register hooks in three common ways:

1. **`mcp.json`** — route hook logic through basecoat-10-core-mcp tools or middleware
2. **`hooks.json`** — declare file-based hook handlers for runtimes that support native hook configs
3. **Code-based registration** — use application code when the host runtime exposes an SDK

#### Pattern A: `mcp.json`

Use this when the runtime exposes extensibility through basecoat-10-core-mcp servers or wrapper tools.

```json
{
  "hooks": {
    "SessionStart": [
      { "tool": "memory.load_session_memory", "priority": 10 },
      { "tool": "telemetry.begin_trace", "priority": 90 }
    ],
    "PostToolUse": [
      { "tool": "errors.capture_tool_outcome", "priority": 20 },
      { "tool": "loops.detect_repeat_failures", "priority": 80 }
    ]
  }
}
```

#### Pattern B: `.github/hooks/*.json` (Native Platform Format)

Use this when targeting VS Code, Copilot CLI, or the Copilot Cloud Agent directly. Store files in `.github/hooks/` in the repository root. This is the **recommended format for BaseCoat deployments** — it works across all three surfaces without a custom runtime.

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "./scripts/validate-tool.sh",
        "powershell": "./scripts/validate-tool.ps1",
        "cwd": ".",
        "timeoutSec": 10
      }
    ],
    "postToolUse": [
      {
        "type": "command",
        "bash": "./scripts/telemetry-hook.sh",
        "powershell": "./scripts/telemetry-hook.ps1",
        "timeoutSec": 5
      }
    ],
    "Stop": [
      {
        "type": "command",
        "bash": "./scripts/session-end.sh",
        "powershell": "./scripts/session-end.ps1",
        "timeoutSec": 15
      }
    ]
  }
}
```

> **Cloud Agent:** Only `bash` commands are honored in the ephemeral Linbasecoat-10-core-ux sandbox. `powershell` entries are silently ignored. Use the cross-platform `command` field as a fallback.

#### Onboarding hook packs

For repository onboarding, treat `.github/hooks/*.json` as **pack files** that can be turned on or off by profile. Keep the profile manifest in `.github/basecoat-hook-profiles.json` and let each profile enable whole packs instead of hand-editing individual handlers.

Recommended pack breakdown:

- `10-session-memory.json` - `SessionStart` and `Stop`
- `20-tool-guardrails.json` - `preToolUse` and `postToolUse`
- `30-error-and-budget.json` - `errorOccurred` plus budget threshold handling via `postToolUse`
- `40-lane-closeout.json` - safe `Stop`-time WIP capture, push, and terminal-state reporting

Example profile manifest:

```json
{
  "version": 1,
  "defaultProfile": "standard",
  "profiles": {
    "none": { "enabledHookPacks": [] },
    "memory": { "enabledHookPacks": ["10-session-memory"] },
    "guardrails": {
      "enabledHookPacks": ["20-tool-guardrails", "30-error-and-budget"]
    },
    "lane-closeout": {
      "enabledHookPacks": ["40-lane-closeout"]
    },
    "standard": {
      "enabledHookPacks": [
        "10-session-memory",
        "20-tool-guardrails",
        "30-error-and-budget",
        "40-lane-closeout"
      ]
    }
  }
}
```

| Profile | Enabled packs | Platform support |
|---|---|---|
| `none` | none | n/a |
| `memory` | `10-session-memory` | VS Code, Copilot CLI, Cloud Agent (bash only) |
| `guardrails` | `20-tool-guardrails`, `30-error-and-budget` | VS Code, Copilot CLI, Cloud Agent (bash only) |
| `lane-closeout` | `40-lane-closeout` | VS Code, Copilot CLI, Cloud Agent (bash only) |
| `standard` | all four packs | VS Code, Copilot CLI, Cloud Agent (bash only) |

Safe defaults for onboarding:

- `SessionStart` / `Stop` should be pass-through stubs until the repo adds memory persistence or telemetry logic.
- `preToolUse` / `postToolUse` should default to non-blocking guardrail stubs.
- `errorOccurred` should normalize or forward errors without crashing the runtime.
- Budget threshold handling should use a dedicated `postToolUse` stub because there is no native `OnBudgetExceeded` event in `.github/hooks/*.json`.
- Safe lane closeout may capture and push WIP plus write a local ledger, but it
  must never rebase, merge, close PRs, delete branches, remove worktrees, or
  publish status paths that look sensitive.

Validation rules for onboarding packs:

1. Use `Stop` instead of `SessionEnd` in native JSON files.
2. Use `errorOccurred` instead of `OnError` in native JSON files.
3. Do not emit `OnBudgetExceeded` in native JSON files; map budget handling to `postToolUse`.
4. Require bash handlers for Cloud Agent compatibility and PowerShell handlers for local Windows sessions.

#### Agent-Scoped Hooks (VS Code Preview)

Hooks can be declared directly in an `.agent.md` YAML frontmatter. They run only when that specific agent is active and supplement any workspace-level hooks.

```yaml
---
name: basecoat-30-ai-guardrail
description: "basecoat-30-ai-guardrail validation agent..."
hooks:
  PostToolUse:
    - type: command
      command: "./scripts/validate-output.sh"
  Stop:
    - type: command
      command: "./scripts/session-cleanup.sh"
---
```

Enable with `chat.useCustomAgentHooks: true` in VS Code settings. This is the right pattern for agent-specific lifecycle behavior (e.g., `deploy-watchdog` arming/disarming, `basecoat-10-core-memory-curator` load/persist).

#### Pattern C: Code-Based Registration

Use this when the host runtime has a programmable middleware layer.

```javascript
runtime.hooks.register('SessionStart', async (event) => {
  const memory = await loadMemory(event.repository, event.branch);
  return {
    action: 'injectContext',
    additionalContext: memory
  };
});
```

### Cross-Platform Notes

#### Platform Name Mapping

BaseCoat uses consistent hook names in basecoat-10-core-documentation and basecoat-10-core-mcp patterns. When writing native hook basecoat-10-core-config files, use the platform names in the table below:

| BaseCoat Name | VS Code / Copilot CLI Name | Cloud Agent | Notes |
|---|---|---|---|
| `SessionStart` | `SessionStart` | ✅ | Identical |
| `SessionEnd` | `Stop` | ✅ | Name differs — use `Stop` in JSON basecoat-10-core-config |
| `UserPromptSubmitted` | `UserPromptSubmit` | ✅ | Minor name variant |
| `PreToolUse` | `preToolUse` | ✅ | camelCase in JSON basecoat-10-core-config |
| `PostToolUse` | `postToolUse` | ✅ | camelCase in JSON basecoat-10-core-config |
| `SubagentStart` | `SubagentStart` | ❌ | VS Code / CLI only |
| `SubagentStop` | `SubagentStop` | ❌ | VS Code / CLI only |
| `PreCompact` | `PreCompact` | ❌ | VS Code / CLI only |
| `PostCompact` | — | — | BaseCoat extension, not in platform |
| `OnError` | `errorOccurred` | ✅ | Name differs — use `errorOccurred` in JSON basecoat-10-core-config |
| `OnBudgetExceeded` | — | — | BaseCoat extension, implement via basecoat-10-core-mcp middleware |

| Runtime | Hook Pattern | basecoat-10-core-config Location | Notes |
|--------|--------------|----------------|-------|
| VS Code (Preview) | Native JSON + agent frontmatter | `.github/hooks/*.json` | Recommended for interactive sessions |
| Copilot CLI | Native JSON | `.github/hooks/*.json`, `~/.copilot/hooks/` | Same format; also supports user-level hooks |
| Copilot Cloud Agent | Native JSON (bash only) | `.github/hooks/*.json` in cloned repo | No user-level hooks; ephemeral sandbox; bash only |
| Claude Code | Native hooks | `.claude/settings.json` | VS Code also reads this location |
| basecoat-10-core-mcp middleware | Pattern A (`mcp.json`) | Configured in basecoat-10-core-mcp server | Use for non-file-based runtimes |

#### GitHub Copilot

For interactive VS Code sessions: use `.github/hooks/*.json` (Pattern B). For the Copilot Cloud Agent: same format, bash only. For programmatic MCP-based integrations: use Pattern A.

The cleanest native integration is `.github/hooks/*.json` — no wrapper needed. For more complex logic (context injection, loop detection), wrap behavior as basecoat-10-core-mcp tools and route through Pattern A.

#### Claude Code

Claude Code reads `.claude/settings.json` and `.github/hooks/*.json`. VS Code also reads the Claude Code settings files, so hooks defined there apply to both runtimes. Map BaseCoat names using the Platform Name Mapping table above.

#### Codex / Other Runtimes

Use Pattern B (declarative `hooks.json`) with the `command` cross-platform field. Keep handlers small, deterministic, and side-effect-free so basecoat-10-core-config remains portable.

### Error Handling in Hooks

Hooks must never crash the agent runtime.

Required behavior:

- Catch all exceptions inside each hook
- Emit diagnostics to telemetry or a debug log
- Return pass-through when recovery is safe
- Only block when the hook has a deliberate policy reason, not because the hook itself broke
- Avoid recursive hook invocation loops unless explicitly supported

Recommended pattern:

```javascript
async function safeRunHook(handler, event) {
  try {
    return await handler(event);
  } catch (error) {
    logHookFailure(event.hook, error);
    return {
      action: 'passThrough',
      warnings: [`Hook failed: ${error.message}`]
    };
  }
}
```

### Hook Ordering

When multiple hooks are registered for the same event, evaluate them in deterministic order.

Recommended ordering rules:

1. Sort by ascending `priority` (lower number runs first)
2. If priorities tie, sort by stable registration order
3. `block` ends the chain unless the runtime explicitly supports "continue after block" for telemetry-only hooks
4. `modify` passes its transformed payload to the next hook in the chain
5. `injectContext` responses are accumulated unless a later hook explicitly overwrites them

Example order for `PreToolUse`:

1. permission validator (`priority: 10`)
2. budget guard (`priority: 20`)
3. known-fix injector (`priority: 50`)
4. telemetry logger (`priority: 90`)

This order ensures hard policy checks run before advisory enrichment and logging.

---

## 6. Integration with Base Coat Features

Hooks become valuable when they connect to other Base Coat patterns instead of operating in isolation.

### Memory Persistence → `SessionStart` / `SessionEnd`

**Flow:**

1. `SessionStart` loads repo, branch, or issue-scoped memory
2. Agent works with enriched context
3. `SessionEnd` persists learned facts, unresolved blockers, and handoff notes

Example:

```json
{
  "SessionStart": [
    { "tool": "memory.load_relevant_facts", "priority": 10 }
  ],
  "SessionEnd": [
    { "tool": "memory.persist_session_summary", "priority": 20 }
  ]
}
```

### Error Knowledge Base → `PreToolUse` / `PostToolUse`

**Flow:**

1. `PreToolUse` checks whether the current tool or command matches a known failure signature
2. If so, the hook injects a warning or workaround
3. `PostToolUse` stores the observed outcome back into the knowledge base

Example use cases:

- warn that packaging often fails if `dist/` contains a stale archive
- recommend authentication steps before a cloud CLI call
- record new failure signatures for later reuse

### Anti-Loop Detection → `PostToolUse`

Loop detection is usually outcome-based, so `PostToolUse` is the right anchor.

Detect patterns such as:

- same command failing 3 times with the same error text
- alternating between two tools without progress
- repeated compaction with no reduction in context pressure

Typical response:

```json
{
  "action": "block",
  "reason": "Loop detected: identical failing command executed 3 times in 6 minutes. Escalate or change strategy."
}
```

### Session Rotation → `OnBudgetExceeded`

When the session crosses a budget threshold, hooks should rotate before basecoat-90-quality-quality collapses.

Recommended sequence:

1. block new large context loads
2. trigger `PreCompact`
3. persist handoff state
4. rotate session
5. trigger `SessionStart` in the fresh session
6. verify restored anchors in `PostCompact`

### Telemetry → All Hooks

Every hook point can emit telemetry. See `docs/reference/TELEMETRY.md` for the full telemetry integration guide, including basecoat-40-azure-azure Application Insights configuration.

Suggested measurements:

| Hook | Metrics |
|------|---------|
| `SessionStart` | memory hits, session bootstrap latency, agent name, model |
| `SessionEnd` / `Stop` | session duration, total tool calls, persisted facts |
| `UserPromptSubmitted` | prompt category (no content), session phase |
| `PreToolUse` | tool category, policy checks, warnings injected |
| `PostToolUse` | tool name, duration ms, success/fail, agent name |
| `SubagentStart` | subagent name, parent agent, invocation depth |
| `SubagentStop` | subagent duration, result summary |
| `PreCompact` | pre-compaction token load, handoff size |
| `PostCompact` | retained anchors, compression ratio |
| `OnError` / `errorOccurred` | normalized error class, recurrence count |
| `OnBudgetExceeded` | trigger threshold, rotation frequency |

**Privacy rule:** Never include prompt content, file contents, or user-identifying data in telemetry payloads. Log only structural metadata: agent names, tool names, timestamps, durations, and success/fail signals.

#### basecoat-40-azure-azure Application Insights via Hooks (opt-in)

Users can route BaseCoat telemetry to their own basecoat-40-azure-azure Application Insights workspace by setting `APPINSIGHTS_CONNECTION_STRING` in their environment. Hook scripts check for this variable and POST custom events to the App Insights ingestion API. If the variable is not set, the hook silently passes through.

```json
{
  "version": 1,
  "hooks": {
    "postToolUse": [
      {
        "type": "command",
        "bash": "./scripts/telemetry-hook.sh",
        "powershell": "./scripts/telemetry-hook.ps1",
        "timeoutSec": 5
      }
    ],
    "Stop": [
      {
        "type": "command",
        "bash": "./scripts/telemetry-hook.sh",
        "powershell": "./scripts/telemetry-hook.ps1",
        "timeoutSec": 5
      }
    ]
  }
}
```

See issue [#1172](https://github.com/IBuySpy-Shared/basecoat/issues/1172) for the full design and implementation plan.

---

## 7. Recommended Runtime Behavior

A minimal but robust Base Coat hook runner should follow these rules:

1. Hooks are opt-in and independently configurable
2. Each hook runs in isolation and cannot crash the main agent
3. Responses are normalized into a shared contract before the runtime acts on them
4. Blocking policies are explicit and auditable
5. All mutations are traceable in telemetry
6. Session-rotation hooks preserve enough state for a clean handoff
7. Sensitive data should be redacted before hook output is stored or reinjected

### Suggested Defaults

| Concern | Default |
|--------|---------|
| Hook timeout | 1-3 seconds for synchronous hooks |
| Failure behavior | Pass-through with warning |
| Ordering | Lowest priority value first |
| Context injection limit | Keep hook-injected context small and task-specific |
| Storage | Persist summaries and signatures, not raw sensitive output |
| Budget trigger | Warn at ~70%, rotate by ~80% of effective limit |

---

## 8. Example End-to-End Flow

```text
SessionStart
  └─ load memory, bootstrap telemetry, inject repo conventions

PreToolUse
  └─ validate tool policy, inject known-fix hints

Tool executes

PostToolUse
  └─ capture result, update error KB, score for loop behavior

... repeated tool usage ...

OnBudgetExceeded
  └─ block further expensive work, trigger rotation

PreCompact
  └─ persist full handoff state before compression

PostCompact
  └─ verify issue number, branch, blockers, and next step survived

SessionEnd
  └─ flush telemetry, persist memory, cleanup runtime state
```

This is the intended control loop: hooks add guardrails and continuity around the agent, while the agent remains focused on task execution.

---

## 9. Design Guidance for Base Coat Authors

When adding hook support to a Base Coat-aligned runtime:

- Start with `SessionStart`, `PostToolUse`, and `OnBudgetExceeded` first; they provide the highest operational value
- Keep hook handlers narrowly scoped; one hook should own one concern
- Prefer structured outputs over free-form prose so downstream automation can reason over results
- Treat hook-added context as scarce; inject only what improves the next decision
- Version hook contracts if they will be shared across runtimes
- Document which hooks are advisory versus policy-enforcing

---

## Related References

- [`docs/token-optimization.md`](../guides/token-optimization.md) — Token budget, compaction, and context handoff patterns
- [`docs/../architecture/multi-agent-orchestration-patterns.md`](../architecture/multi-agent-orchestration-patterns.md) — Session handoff and coordination patterns across basecoat-10-core-agents
- [`instructions/basecoat-20-lang-governance.instructions.md`](/instructions/basecoat-20-lang-governance.instructions.md) — Always-on basecoat-20-lang-governance and safety constraints
- Issue [#145](https://github.com/IBuySpy-Shared/basecoat/issues/145) — Tracking issue for lifecycle hook specification
