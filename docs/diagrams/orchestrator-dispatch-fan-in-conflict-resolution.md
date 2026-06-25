# Orchestrator Dispatch, Fan-In, and Conflict Resolution Flow

Visual reference for orchestrator fan-out/fan-in execution and tie-break handling.

- Primary source terminology:
  `agents/basecoat-10-core-orchestrator.agent.md` and
  `docs/agents/multi-agent-workflows.md`

## 1. Subtask Dispatch and Fan-In Sequence

```mermaid
sequenceDiagram
    participant U as User Request
    participant O as Orchestrator
    participant A as Sub-Agent A
    participant B as Sub-Agent B
    participant C as Sub-Agent C
    participant T as Tie-Break Reviewer

    U->>O: Complex request
    O->>O: Plan scope, envelopes, budgets
    par Dispatch independent branches
        O->>A: task_envelope(task_id=A, status=in_progress)
        O->>B: task_envelope(task_id=B, status=in_progress)
        O->>C: task_envelope(task_id=C, status=in_progress)
    end

    A-->>O: response_envelope(status=completed, evidence=strong)
    B-->>O: response_envelope(status=blocked, blockers=[...])
    O->>B: retry dispatch with retry_context
    B-->>O: response_envelope(status=completed)
    C-->>O: response_envelope(status=completed, conclusion conflicts)

    O->>O: Fan-in aggregation and dedupe
    O->>O: Detect contradiction during conflict_review
    O->>T: Tie-break pass with focused scope
    T-->>O: Evidence-backed decision
    O-->>U: Finalized answer + branch statuses + residual risks
```

## 2. Branch Status Lifecycle

```mermaid
stateDiagram-v2
    [*] --> in_progress
    in_progress --> blocked: blocker or missing dependency
    blocked --> retry: retry_context prepared
    retry --> in_progress: re-dispatch accepted
    in_progress --> resolved: acceptance_results pass
    retry --> resolved: retry succeeds
    blocked --> failed: hard blocker persists
    failed --> [*]
    resolved --> [*]
```

## 3. Conflict-Resolution Decision Flow

```mermaid
flowchart TD
    A[Fan-in aggregation complete] --> B{CR-1 Contract validity}
    B -->|Missing required fields/evidence| B1[Mark partial or blocked<br/>Request targeted retry_context]
    B -->|Valid envelopes| C{CR-2 Evidence strength}

    C -->|One branch has stronger reproducible evidence| C1[Prefer stronger branch]
    C -->|Evidence mixed| D{CR-3 Policy gate}

    D -->|Policy conflict present| D1[Apply tool confirmation policy]
    D -->|No policy conflict| E{CR-4 Unresolved tie}

    E -->|Resolved after one tie-break pass| E1[Apply tie-break decision]
    E -->|Still mixed| E2[Surface both interpretations<br/>Record residual risk + next verification]

    B1 --> Z[Finalize branch table]
    C1 --> Z
    D1 --> Z
    E1 --> Z
    E2 --> Z
    Z --> F[Publish finalized response]
```
