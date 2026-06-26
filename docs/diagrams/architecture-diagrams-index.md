# Architecture Diagrams

Visual reference for BaseCoat's architecture, memory model, and process flows.

Most whiteboard-style diagrams are authored in
[Excalidraw](https://aka.ms/excalidraw). Open any `.excalidraw` file directly at
[**aka.ms/excalidraw**](https://aka.ms/excalidraw) (drag-and-drop or use File → Open).
The Markdown pages in this index use live Mermaid blocks and render directly in the
docs site.

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

## MCP & Integration Surfaces

| Diagram | Description |
|---|---|
| [basecoat-mcp-topology-and-extension-surface.md](basecoat-mcp-topology-and-extension-surface.md) | Component view of the read-only BaseCoat MCP server, the transport-flexible metrics MCP server, and the separate Copilot Extension HTTP surface |
| [basecoat-mcp-and-metrics-data-flow.md](basecoat-mcp-and-metrics-data-flow.md) | End-to-end read paths for inventory/search/read plus the metrics fetch path and local override behavior |
| [mcp-metrics-build-and-deploy-flow.md](mcp-metrics-build-and-deploy-flow.md) | PR validation, GHCR publish, Azure Container Apps deploy, and health verification for the metrics MCP service |

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
| [orchestrator-dispatch-fan-in-conflict-resolution.md](orchestrator-dispatch-fan-in-conflict-resolution.md) | Orchestrator dispatch sequence, branch status lifecycle (`in_progress`, `blocked`, retry, `resolved`), and conflict tie-break decision flow |
| [copilot-extension-oauth-and-tool-invocation-flow.md](copilot-extension-oauth-and-tool-invocation-flow.md) | OAuth callback middleware path, tool invocation status branches, and health/ping observability flow for `mcp/basecoat-extension/src/app.ts` |

## Validation & Testing

| Diagram | Description |
|---|---|
| [e2e-validation-lifecycle.md](e2e-validation-lifecycle.md) | E2E gate funnel, pass/fail branching, test scope map |

---

!!! tip "Viewing diagrams"
    Excalidraw files open natively in VS Code with the
    [Excalidraw extension](https://marketplace.visualstudio.com/items?itemName=pomdtr.excalidraw-editor),
    or in the browser at [aka.ms/excalidraw](https://aka.ms/excalidraw).
    Mermaid-based `.md` diagram pages render inline in the docs site and can be read
    directly in GitHub or VS Code without exporting assets.

!!! note "Inline architecture diagrams"
    The [Architecture Overview](../architecture/overview.md) page contains live
    Mermaid diagrams that render directly in the docs site — no download required.
