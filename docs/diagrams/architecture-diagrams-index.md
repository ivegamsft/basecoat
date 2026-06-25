# Architecture Diagrams

Visual reference for BaseCoat's architecture, memory model, and process flows.

All diagrams are authored in [Excalidraw](https://aka.ms/excalidraw) — an open-source
whiteboarding tool. Open any `.excalidraw` file directly at
[**aka.ms/excalidraw**](https://aka.ms/excalidraw) (drag-and-drop or use File → Open).

## Start here

If you only need the gist, read these three first:

| Diagram | Takeaway |
|---|---|
| [execution-hierarchy.excalidraw](execution-hierarchy.excalidraw) | Shows the layered execution stack and where guardrails fire |
| [intent-routing.excalidraw](intent-routing.excalidraw) | Shows when BaseCoat takes the fast path vs the full path |
| [agentic-workflow-lifecycle.excalidraw](agentic-workflow-lifecycle.excalidraw) | Shows the trigger → filter → agent → buffer → safe output flow |

---

## Architecture

| Diagram | Description |
|---|---|
| [execution-hierarchy.excalidraw](execution-hierarchy.excalidraw) | 5-layer execution stack from user intent to output |
| [multi-agent-orchestration.excalidraw](multi-agent-orchestration.excalidraw) | LangGraph StateGraph fan-out/fan-in pattern |
| [asset-taxonomy.excalidraw](asset-taxonomy.excalidraw) | Four primitive asset types: agents, skills, instructions, prompts |

## Memory Model

| Diagram | Description |
|---|---|
| [memory-lookup-hierarchy.excalidraw](memory-lookup-hierarchy.excalidraw) | L0–L4 memory layer lookup and retrieval cost |
| [two-tier-memory-model.excalidraw](two-tier-memory-model.excalidraw) | Personal vs shared memory tiers |
| [memory-promotion-flow.excalidraw](memory-promotion-flow.excalidraw) | Pattern promotion and demotion ladder |

## Process Flows

| Diagram | Description |
|---|---|
| [intent-routing.excalidraw](intent-routing.excalidraw) | Fast-path vs deep-reasoning routing decision |
| [turn-budget-protocol.excalidraw](turn-budget-protocol.excalidraw) | Token budget enforcement and graceful degradation |
| [agentic-workflow-lifecycle.excalidraw](agentic-workflow-lifecycle.excalidraw) | PR trigger → filter → agent → buffer → safe output |
| [bootstrap-flow.excalidraw](bootstrap-flow.excalidraw) | 4-phase bootstrap script: repo, memory, secrets, validation |
| [queue-rebalancer-dependency-dag-and-lane-gates.excalidraw](queue-rebalancer-dependency-dag-and-lane-gates.excalidraw) | Queue rebalancer dependency DAG, unblock lane flow, and gate outcomes (`gate:no-tests`, `gate:needs-check-in`) with stalled-chain handling ([notes](queue-rebalancer-dependency-dag-and-lane-gates.md)) |

## Validation & Testing

| Diagram | Description |
|---|---|
| [e2e-validation-lifecycle.md](e2e-validation-lifecycle.md) | E2E gate funnel, pass/fail branching, test scope map |

---

!!! tip "Viewing diagrams"
    Excalidraw files open natively in VS Code with the
    [Excalidraw extension](https://marketplace.visualstudio.com/items?itemName=pomdtr.excalidraw-editor),
    or in the browser at [aka.ms/excalidraw](https://aka.ms/excalidraw).
    To embed a diagram in a doc, export it as SVG from Excalidraw and place the file
    in `docs/diagrams/`, then reference it with standard Markdown image syntax.

!!! note "Inline architecture diagrams"
    The [Architecture Overview](../architecture/overview.md) page contains live
    Mermaid diagrams that render directly in the docs site — no download required.
