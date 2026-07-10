# Multi-Agent Orchestration Patterns for BaseCoat

## Overview

This document explores production-grade multi-agent orchestration patterns from the [ai-hedge-fund](https://github.com/virattt/ai-hedge-fund) project and documents their applicability to BaseCoat. The ai-hedge-fund project is a sophisticated proof-of-concept for AI-powered trading systems that orchestrates 19+ specialized agents (investment specialists, analysts, risk managers, portfolio managers) using LangGraph state-machine workflows.

**Key Context**: ai-hedge-fund runs as both CLI and web application, using LangGraph StateGraph for deterministic workflow routing, Pydantic models for structured outputs, and a fan-out/fan-in pattern where parallel specialist agents feed into aggregator nodes.

## AI-Hedge-Fund Architecture

### High-Level System Design

The ai-hedge-fund system employs a layered multi-agent architecture:

1. **Specialist Agents** (19 agents)
   - 13 investment personality agents (Warren Buffett, Cathie Wood, Michael Burry, etc.)
   - 4 analytical agents (Valuation, Sentiment, Fundamentals, Technicals)
   - 1 news sentiment agent

2. **Aggregator Agents** (2 agents)
   - Risk Management Agent: Aggregates analyst signals, calculates volatility-adjusted position limits
   - Portfolio Management Agent: Final decision maker, synthesizes all signals into trading orders

3. **State Management**
   - `AgentState` TypedDict with messages, data, and metadata
   - Custom merge operators for composable state accumulation
   - JSON-serializable decision outputs

4. **Execution Flow**
   - Start node → Parallel specialist agents → Risk manager → Portfolio manager → End
   - Specialist agents write signals to `analyst_signals` dict
   - Risk manager aggregates volatility/correlation analysis
   - Portfolio manager performs final decision synthesis

### Core Technical Stack

- **LangGraph**: StateGraph for deterministic workflow orchestration
- **LangChain**: LLM calls, message handling, prompt templates
- **Pydantic**: Structured, JSON-serializable decision models
- **Python async**: Potential for parallel agent execution
- **CLI + Web**: Dual UI paradigm (argparse CLI, FastAPI backend with Streamlit frontend)
- **Docker**: Containerization for reproducibility

### Key Design Patterns

#### 1. State-Based Orchestration (LangGraph StateGraph)

**Pattern**: Uses TypedDict-based state with Annotated merge operators.

```python
# From src/graph/state.py
class AgentState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]  # Append-only
    data: Annotated[dict[str, any], merge_dicts]              # Dict merge
    metadata: Annotated[dict[str, any], merge_dicts]          # Dict merge

def merge_dicts(a, b) -> dict:
    return {**a, **b}
```text

**Benefits**:

- Immutable state transitions (functional programming)
- Type-safe state evolution
- Built-in composition for parallel workflows
- Deterministic execution (no side effects)

**BaseCoat Applicability**: High. Replaces manual `/approve` routing with declarative graph-based workflows.

#### 2. Composable Agents (Consistent Input/Output Contracts)

**Pattern**: Every agent accepts `AgentState` and returns modified state. Output is Pydantic model, serialized to JSON message.

```python
# From src/agents/portfolio_manager.py
class PortfolioDecision(BaseModel):
    action: Literal["buy", "sell", "short", "cover", "hold"]
    quantity: int
    confidence: int
    reasoning: str

class PortfolioManagerOutput(BaseModel):
    decisions: dict[str, PortfolioDecision]

def portfolio_management_agent(state: AgentState) -> AgentState:
    # ... process state ...
    result = PortfolioManagerOutput(decisions={...})
    message = HumanMessage(
        content=json.dumps({ticker: decision.model_dump() for ...}),
        name=agent_id
    )
    return {"messages": state["messages"] + [message], "data": state["data"]}
```text

**Benefits**:

- Runtime agent selection (`--agents agent1,agent2`)
- Clear contracts enable testing and versioning
- JSON serialization enables API exposure

**BaseCoat Applicability**: High. Enables composable CLI like `--agents code-review,security-analyst,solution-architect --skills skill1,skill2`.

#### 3. Decision Aggregation (Fan-Out/Fan-In Pattern)

**Pattern**: Start node → Parallel specialist agents → Aggregator (risk manager) → Final aggregator (portfolio manager).

```python
# From src/main.py create_workflow()
workflow = StateGraph(AgentState)
workflow.add_node("start_node", start)

# Fan-out: All analysts in parallel
for analyst_key in selected_analysts:
    node_name, node_func = analyst_nodes[analyst_key]
    workflow.add_node(node_name, node_func)
    workflow.add_edge("start_node", node_name)

# Aggregator 1: Risk manager consumes all analyst signals
for analyst_key in selected_analysts:
    node_name = analyst_nodes[analyst_key][0]
    workflow.add_edge(node_name, "risk_management_agent")

# Aggregator 2: Portfolio manager final decision
workflow.add_edge("risk_management_agent", "portfolio_manager")
workflow.add_edge("portfolio_manager", END)
```text

**Benefits**:

- Parallel specialist execution (no blocking on individual agents)
- Multi-layer aggregation enables nuanced decision-making
- Composable decision pipeline

**BaseCoat Applicability**: High. Example: Code Review → Security Analyst → Solution Architect → Decision Maker.

#### 4. Structured Outputs (Pydantic JSON-Serializable Decisions)

**Pattern**: All agents return Pydantic models with clear fields and types.

**Benefits**:

- Machine-readable, parseable decisions
- Type validation at runtime
- API-ready (JSON serialization)
- Audit trail (all decisions documented)

**BaseCoat Applicability**: High. Enables deterministic workflows and integration with downstream systems.

#### 5. Tool Abstraction Layer (Pluggable Tool Providers)

**Pattern**: Tools (like `get_prices`, `calculate_volatility`) are registered separately from agent logic.

```python
# From src/agents/risk_manager.py
prices = get_prices(ticker, start_date, end_date, api_key)  # Tool call
prices_df = prices_to_df(prices)                             # Data transformation
volatility_metrics = calculate_volatility_metrics(prices_df) # Analysis
```text

**Benefits**:

- Agents focus on logic, not data fetching
- Easy to swap providers (mock for testing, real for production)
- Clear separation of concerns

**BaseCoat Applicability**: Medium-High. Aligns with MCP server pattern (basecoat-metrics MCP).

#### 6. Dual UI Paradigm (CLI + Web Portal on Shared Backend)

**Pattern**: Single backend logic, multiple frontends:

- CLI: `poetry run python src/main.py --ticker AAPL,MSFT --selected-analysts aswath_damodaran,warren_buffett`
- Web: FastAPI backend + Streamlit frontend with visual workflow builder

**BaseCoat Applicability**: High (future). CLI now, web portal roadmap for visual agent builder and execution dashboard.

## BaseCoat Application Analysis

### High-Priority Patterns (Immediate Impact)

#### Pattern 1: Graph-Based Agent Orchestration

**Current State**: Issue #451 mentions a "queue-manager agent" but orchestration is currently manual (Copilot responds to `/approve` label).

**Proposed**: LangGraph StateGraph for orchestration instead of webhook-based approval routing.

**Impact**: Replace `/approve` workflow with declarative multi-agent pipelines (e.g., `issue-triage → code-review → security-analyst → solution-architect → decision`).

**Related Issues**: #451 (concurrency/queue management), #444 (Untools integration).

#### Pattern 2: Standardized Agent Output Schemas (Pydantic Models)

**Current State**: Agents return markdown strings, no structured format.

**Proposed**: Adopt Pydantic models for all agent outputs (related to Issue #448 Pydantic integration).

```python
class CodeReviewDecision(BaseModel):
    files_reviewed: list[str]
    severity: Literal["critical", "high", "medium", "low", "info"]
    findings: list[Finding]
    recommendation: Literal["approve", "request_changes", "comment"]
    confidence: int

class SecurityAnalysiResult(BaseModel):
    vulnerabilities: list[Vulnerability]
    risk_score: float
    remediation_steps: list[str]
    approved: bool
```text

**Impact**: Machine-readable decisions enable routing logic, parallelization, and API exposure.

**Related Issues**: #448 (Pydantic models for agents).

#### Pattern 3: Composable Agent CLI

**Current State**: Agents are invoked individually or composed manually.

**Proposed**: CLI with `--agents` and `--skills` flags.

```bash
# Run code review + security analysis in sequence
gh copilot run "issue-#450" --agents code-review,security-analyst,solution-architect

# Or with explicit skills
gh copilot run "issue-#450" --agents security-analyst --skills vulnerability-scanner,threat-model
```text

**Impact**: Enable power users to compose workflows without code changes.

**Related Issues**: #450 (this issue), #451 (queue management).

### Medium-Priority Patterns (Portal Integration)

#### Web Dashboard for Workflow Visualization

**Pattern**: Extend BaseCoat CLI with web interface showing agent execution timelines.

**Features**:

- Real-time agent execution graph
- Visual fan-out/fan-in aggregation
- Agent signal aggregation heatmap
- Decision audit trail

**Effort Estimate**: 4-6 sprints (backend: 2 sprints, frontend: 2-3 sprints, integration: 1 sprint).

#### Visual Agent Builder

**Pattern**: No-code interface to compose agents into workflows (like ai-hedge-fund's web app).

**Features**:

- Drag-drop agent selection
- Routing rules (conditional edges based on decision fields)
- Output schema visualization
- Workflow validation before execution

**Effort Estimate**: 6-8 sprints (design: 1, backend: 2, frontend: 3, testing: 1).

### Lower-Priority Patterns (Research Phase)

#### Domain-Specific Agent Personalities

**Pattern**: Extend ai-hedge-fund's "personality agents" (Warren Buffett, Cathie Wood) to software domain (e.g., "Security Officer", "Product Manager", "DevOps Engineer").

**Rationale**: Different roles bring different perspectives; orchestrating them surfaces more nuanced recommendations.

**Status**: Deferred to future research cycle.

## Example Workflow: BaseCoat Security Decision Workflow

### Scenario

A user opens Issue #500: "SQL Injection vulnerability in authentication handler." We want to orchestrate:

1. **Security Analyst** → Identifies vulnerability class, severity, root cause
2. **Vulnerability Scorer** → Calculates CVSS score, assigns priority
3. **Risk Manager** → Assesses blast radius, mitigation complexity
4. **Security Officer** → Approves remediation plan
5. **Remediation Planner** → Drafts detailed fix steps

### LangGraph Workflow Sketch

```text
┌─────────────┐
│ Start Node  │
│ (parse PR)  │
└──────┬──────┘
       │
       ├─────────────────┬──────────────────┬───────────────┐
       │                 │                  │               │
       ▼                 ▼                  ▼               ▼
┌────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Security   │  │ Code Review  │  │ Dependency   │  │ Architecture │
│ Analyst    │  │ (SAST)       │  │ Check (SCA)  │  │ Reviewer     │
└────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
     │                 │                  │                │
     │                 │                  │                │
     └─────────────────┼──────────────────┼────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Risk Manager        │
            │ (aggregates signals) │
            └──────────┬───────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │  Decision Maker      │
            │  (final approval)    │
            └──────────┬───────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │ Remediation Planner  │
            │ (drafts fix steps)   │
            └──────────┬───────────┘
                       │
                       ▼
                    [END]
```text

### State Progression

```python
# Initial state
state = {
    "messages": [
        HumanMessage(content="Security vulnerability in auth handler")
    ],
    "data": {
        "issue": {"number": 500, "title": "...", "body": "..."},
        "file_path": "src/auth.py:45-67",
        "vulnerability_class": None,
        "security_signals": {},  # Filled by parallel agents
        "risk_analysis": {},     # Filled by risk manager
        "decision": None,        # Filled by decision maker
    },
    "metadata": {"user": "alice", "repo": "basecoat"}
}

# After security analyst
state["data"]["security_signals"]["security_analyst"] = {
    "vulnerability_class": "SQL_INJECTION",
    "severity": "CRITICAL",
    "root_cause": "Unsanitized user input in query",
    "confidence": 95,
}

# After risk manager aggregation
state["data"]["risk_analysis"] = {
    "cvss_score": 9.8,
    "blast_radius": ["auth_service", "api_gateway"],
    "mitigation_complexity": "LOW",
    "recommendation": "IMMEDIATE_REMEDIATION",
}

# After decision maker
state["data"]["decision"] = {
    "approved": True,
    "priority": "P0",
    "sla": "4_hours",
    "assign_to": "security_team",
}
```text

## PoC Sketch: 3-Agent Orchestration Workflow

### Scenario: Code Quality Review Workflow

Orchestrate three agents for a pull request:

1. **Code Review Agent** → Analyzes code structure and design
2. **Performance Analyst** → Measures efficiency metrics
3. **Decision Maker** → Synthesizes into approval/rejection

### LangGraph State Definition

```python
from typing_extensions import Annotated, TypedDict, Sequence
from langchain_core.messages import BaseMessage
from pydantic import BaseModel, Field
from typing import Literal
import operator
import json

# Custom merge function
def merge_analysis(a: dict, b: dict) -> dict:
    """Merge analysis results, deeply merging nested dicts."""
    result = {**a}
    for key, value in b.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge_analysis(result[key], value)
        else:
            result[key] = value
    return result

# State definition
class CodeQualityState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
    analysis: Annotated[dict, merge_analysis]
    metadata: Annotated[dict, merge_analysis]

# Output schemas
class CodeReviewOutput(BaseModel):
    issues_found: int
    style_violations: list[str]
    design_concerns: list[str]
    recommendation: Literal["approve", "request_changes"]
    confidence: float

class PerformanceOutput(BaseModel):
    time_complexity: str
    space_complexity: str
    algorithmic_improvements: list[str]
    estimated_improvement_percent: float

class ApprovalDecision(BaseModel):
    approved: bool
    primary_concern: str | None
    required_fixes: list[str]
    approved_by: str
```text

### Agent Node Definitions

```python
from langchain_core.messages import HumanMessage, AIMessage

def code_review_agent(state: CodeQualityState) -> CodeQualityState:
    """Analyzes code for style, structure, design patterns."""
    # Pseudo-code
    code_content = state["metadata"]["pr_diff"]
    
    # Call LLM for code review
    review = call_llm(
        model="gpt-4",
        prompt=f"Review this code: {code_content}",
        response_model=CodeReviewOutput
    )
    
    # Return updated state
    message = AIMessage(content=review.model_dump_json(), name="code_review_agent")
    return {
        "messages": state["messages"] + [message],
        "analysis": {**state["analysis"], "code_review": review.model_dump()},
        "metadata": state["metadata"],
    }

def performance_analyst_agent(state: CodeQualityState) -> CodeQualityState:
    """Analyzes algorithmic complexity and performance."""
    code_content = state["metadata"]["pr_diff"]
    
    perf_analysis = call_llm(
        model="gpt-4",
        prompt=f"Analyze performance of: {code_content}",
        response_model=PerformanceOutput
    )
    
    message = AIMessage(content=perf_analysis.model_dump_json(), name="performance_analyst")
    return {
        "messages": state["messages"] + [message],
        "analysis": {**state["analysis"], "performance": perf_analysis.model_dump()},
        "metadata": state["metadata"],
    }

def decision_maker_agent(state: CodeQualityState) -> CodeQualityState:
    """Synthesizes code review and performance analysis into final decision."""
    code_review = state["analysis"]["code_review"]
    performance = state["analysis"]["performance"]
    
    # Aggregate signals
    aggregated_prompt = f"""
    Code Review: {json.dumps(code_review)}
    Performance Analysis: {json.dumps(performance)}
    
    Make a final approval decision.
    """
    
    decision = call_llm(
        model="gpt-4",
        prompt=aggregated_prompt,
        response_model=ApprovalDecision
    )
    
    message = AIMessage(content=decision.model_dump_json(), name="decision_maker")
    return {
        "messages": state["messages"] + [message],
        "analysis": {**state["analysis"], "decision": decision.model_dump()},
        "metadata": state["metadata"],
    }
```text

### Workflow Graph Construction

```python
from langgraph.graph import StateGraph, END

def create_code_quality_workflow():
    workflow = StateGraph(CodeQualityState)
    
    # Add start node
    def start_node(state):
        return state
    
    workflow.add_node("start", start_node)
    
    # Add parallel agents
    workflow.add_node("code_review", code_review_agent)
    workflow.add_node("performance_analyst", performance_analyst_agent)
    workflow.add_node("decision_maker", decision_maker_agent)
    
    # Define edges: fan-out to parallel agents
    workflow.add_edge("start", "code_review")
    workflow.add_edge("start", "performance_analyst")
    
    # Fan-in: both agents feed to decision maker
    workflow.add_edge("code_review", "decision_maker")
    workflow.add_edge("performance_analyst", "decision_maker")
    
    # Final edge
    workflow.add_edge("decision_maker", END)
    
    # Compile graph
    workflow.set_entry_point("start")
    return workflow.compile()

# Execute workflow
agent = create_code_quality_workflow()
result = agent.invoke({
    "messages": [],
    "analysis": {},
    "metadata": {
        "pr_number": 123,
        "pr_diff": "... code changes ...",
    }
})

print(result["analysis"]["decision"])
# Output:
# {
#   "approved": true,
#   "primary_concern": null,
#   "required_fixes": [],
#   "approved_by": "decision_maker"
# }
```text

### Key Points

- **State Contract**: All agents accept `CodeQualityState`, return modified state
- **Fan-Out**: `code_review_agent` and `performance_analyst_agent` execute in parallel
- **Fan-In**: Both feed into `decision_maker_agent` which aggregates signals
- **Message Trail**: Each agent appends AIMessage for audit log
- **Composability**: Easy to add/remove agents (e.g., `security_agent`) by adding node and edges
- **Type Safety**: Pydantic models ensure contract compliance

## RFC: Multi-Agent Architecture Decision

### Decision: Should BaseCoat Adopt LangGraph-Based Multi-Agent Orchestration?

### Problem Statement

Currently, BaseCoat agents are invoked individually with manual approval routing. As the agent library grows, there's no systematic way to:

- Compose agents into workflows
- Parallelize independent analyses
- Aggregate decisions from multiple perspectives
- Route based on decision content (not just labels)

This limits scalability and creates friction for power users.

### Proposed Solution

Adopt LangGraph StateGraph for deterministic multi-agent orchestration, following ai-hedge-fund patterns. Enable users to compose agents with a simple CLI flag: `--agents agent1,agent2 --skills skill1,skill2`.

### Trade-Offs Analysis

#### Option A: Multi-Agent Orchestration (LangGraph)

**Pros**:

- Deterministic, debuggable workflows (functional state machine)
- Parallel agent execution (fan-out/fan-in)
- Type-safe decision aggregation (Pydantic)
- Scalable decision routing (graph-based instead of label-based)
- Production-proven pattern (ai-hedge-fund, LangChain ecosystem)
- Easy to version and test workflows
- API-ready (JSON serializable decisions)

**Cons**:

- New dependency (langgraph, ~50KB)
- Learning curve for agent developers
- Debugging multi-agent workflows is harder than single-agent
- Potential for exponential state space in complex graphs

**Effort Estimate**:

- Phase 1 (Core): 2 sprints (LangGraph integration, agent refactor to Pydantic models)
- Phase 2 (CLI): 1 sprint (--agents flag, workflow composition)
- Phase 3 (Portal): 6-8 sprints (web dashboard, visual builder)

#### Option B: Single-Agent CLI Extensibility (Status Quo Evolution)

**Pros**:

- Simpler mental model
- Agents remain independent
- No new dependencies
- Lower maintenance burden

**Cons**:

- No parallelization benefit
- Manual composition required
- Difficult to aggregate decisions from multiple agents
- Doesn't scale to many agents

**Effort Estimate**: 1 sprint (basic `--agents` flag for sequential execution).

### Recommendation

**Adopt Option A (Multi-Agent Orchestration)** with phased rollout:

1. **Sprint 1-2**: Core LangGraph integration, Pydantic schemas (related to #448)
2. **Sprint 3**: CLI `--agents` flag for workflow composition
3. **Sprint 4+**: Portal (visual builder, dashboard)

**Rationale**: ai-hedge-fund demonstrates production readiness; LangGraph is adoption-proven in LLM ecosystem; parallelization and decision aggregation are high-value capabilities.

### Queue-Manager Agent Design (Issue #451 Context)

**Current Challenge**: Managing concurrent agent executions without blocking orchestration.

**LangGraph Solution**: Use `RunnableParallel` for true parallelization:

```python
from langgraph.graph import RunnableParallel

# Parallel execution of independent agents
parallel_agents = RunnableParallel({
    "code_review": code_review_agent,
    "security_analyst": security_analyst_agent,
    "performance_analyst": performance_analyst_agent,
})

# Then fan-in to aggregator
state = parallel_agents.invoke(state)
state = risk_manager_agent(state)
state = decision_maker_agent(state)
```text

**Queue Manager Role**: Track in-flight workflows, implement backpressure, manage resource limits.

```python
class WorkflowQueueManager:
    def __init__(self, max_concurrent: int = 10):
        self.queue = asyncio.Queue()
        self.in_flight = {}
        self.max_concurrent = max_concurrent
    
    async def submit_workflow(self, workflow_id: str, graph: CompiledGraph):
        await self.queue.put({"id": workflow_id, "graph": graph})
    
    async def process(self):
        while self.queue.qsize() < self.max_concurrent:
            item = await self.queue.get()
            asyncio.create_task(self._execute(item))
    
    async def _execute(self, item):
        try:
            result = await item["graph"].ainvoke(...)
            self.in_flight[item["id"]] = {"status": "complete", "result": result}
        except Exception as e:
            self.in_flight[item["id"]] = {"status": "failed", "error": str(e)}
```text

**Related Issues**: #451 (concurrency), #450 (this issue).

### Adoption Roadmap

#### Phase 1: Core Infrastructure (Sprints 1-2)

- [ ] Add LangGraph dependency
- [ ] Define base `AgentState` (TypedDict with message/analysis/metadata)
- [ ] Create Pydantic schema generator for agents (related #448)
- [ ] Refactor 3 pilot agents (code-review, security-analyst, solution-architect)
- [ ] Write integration tests for StateGraph

**Blocking Issues**: #448 (Pydantic models)

#### Phase 2: CLI Composition (Sprint 3)

- [ ] Add `--agents` and `--skills` flags to CLI
- [ ] Implement `parse_agents` and `parse_skills` functions
- [ ] Create workflow factory based on agent selection
- [ ] Document workflow composition examples

**Blocking Issues**: Phase 1

#### Phase 3: Portal & Visual Builder (Sprints 4-8)

- [ ] Design FastAPI backend for workflow execution
- [ ] Build React/Vue frontend for workflow visualization
- [ ] Implement drag-drop agent selection UI
- [ ] Add real-time execution graph display
- [ ] Create workflow persistence (save/load/version)

**Blocking Issues**: Phase 1, Phase 2

### Success Metrics

- Users can compose workflows with `--agents flag` (CLI adoption)
- Parallel agent execution reduces E2E latency by 30-50% vs. sequential
- All agents return Pydantic-validated decisions
- Workflow test coverage > 90%
- Portal adoption > 20% of CLI usage within 2 quarters

### Migration Plan

1. **Non-Breaking**: New orchestration runs in parallel to existing single-agent CLI
2. **Opt-In**: Users choose `--agents agent1,agent2` or use traditional single-agent mode
3. **Deprecation Timeline**: Single-agent mode supported for 2 quarters, then retired
4. **Documentation**: Migration guide for agent developers

## Related Issues

- **#451**: Concurrency & Queue Management (closely related; queue-manager agent design depends on LangGraph orchestration)
- **#448**: Pydantic Models for Agents (blocking; required for structured output schemas)
- **#444**: Untools Integration (complements tool abstraction layer; MCP servers as tools)
- **#450**: This issue (multi-agent orchestration research & RFC)

## Key Files to Study

### AI-Hedge-Fund Repository

- `src/main.py`: Entry point, workflow composition, CLI argument parsing
- `src/graph/state.py`: AgentState definition, merge operators
- `src/agents/risk_manager.py`: Example aggregator agent (consumes analyst signals)
- `src/agents/portfolio_manager.py`: Example final aggregator (decision synthesis)
- `src/utils/analysts.py`: Agent registry, configuration
- `src/agents/*.py`: Individual specialist agent implementations

### BaseCoat Repository

- `agents/basecoat-10-core-agent-designer.agent.md`: Agent authoring patterns
- `mcp/basecoat-metrics/`: MCP server pattern (tool abstraction)
- `agents/*.agent.md`: Current agent implementations (to refactor)
- `scripts/validate-basecoat.ps1`: Validation script
- `tests/run-tests.ps1`: Test harness

## Implementation Roadmap Summary

| Phase | Duration | Deliverables | Issues |
|-------|----------|--------------|--------|
| **Phase 1: Core** | 2 sprints | LangGraph integration, Pydantic schemas, 3 pilot agents | #448, #450 |
| **Phase 2: CLI** | 1 sprint | `--agents` flag, workflow composition | #450, #451 |
| **Phase 3: Portal** | 6-8 sprints | Web dashboard, visual builder, persistence | #450 |
| **Phase 4: Scale** | Ongoing | Portal adoption, additional agents/workflows | Community feedback |

## Conclusion

Multi-agent orchestration via LangGraph represents a significant upgrade to BaseCoat's capabilities, enabling parallel execution, decision aggregation, and composable workflows. The ai-hedge-fund project demonstrates production readiness. Implementation follows a phased approach with clear blocking dependencies (#448). Adoption roadmap emphasizes backward compatibility and opt-in migration.

---

**Document Version**: 1.0
**Last Updated**: 2025
**Status**: RFC (Ready for Discussion)
**Related RFC**: Issue #450 (Multi-Agent Orchestration), Issue #451 (Concurrency)

---

## Pattern: Creator-Verifier Loop

**Related issues**: #616

### Overview

The Creator-Verifier pattern pairs two specialized agents in an iterative loop:

- **Creator** (e.g., `guidance-author`) — produces a draft artifact
- **Verifier** (e.g., `guidance-reviewer`) — validates the draft against deterministic rules

The loop runs until the verifier returns `PASS` or a maximum iteration count is reached.

### When to Use

Use Creator-Verifier when:

- Output correctness can be verified deterministically (lint rules, schema checks, required sections)
- The creation task is complex enough that a single pass is unlikely to be perfect
- Human review is expensive and should only happen on already-validated drafts
- You want to surface exactly which rules failed, not just "it's wrong"

### BaseCoat Application: Guidance Authoring

```text
User describes need
      │
      ▼
guidance-author (Creator)
  - Reads conventions and templates
  - Drafts frontmatter + body sections
  - Estimates confidence %
      │
      ▼
guidance-reviewer (Verifier)
  - Checks frontmatter schema
  - Validates required sections (Inputs, Workflow, Output)
  - Applies MD031, MD036, MD040, MD047 lint rules
  - Returns PASS / FAIL with line-level findings
      │
   FAIL?────────────────────────────────────────┐
      │                                          │
   PASS                                         │
      │                                guidance-author re-drafts
      ▼                                with findings applied
Human review gate                               │
(PR / steward approval)                         │
      │                                          │
      ▼                               ◄──────────┘
  Committed                        (max 3 iterations)
```text

### LangGraph Implementation

```python
from langgraph.graph import StateGraph, END
from typing import TypedDict, Annotated, Literal
from pydantic import BaseModel
import operator

class GuidanceState(TypedDict):
    asset_type: str
    name: str
    purpose: str
    draft_content: str
    review_verdict: str          # "PASS" | "FAIL" | ""
    review_findings: list[str]
    iteration: int
    max_iterations: int

class ReviewVerdict(BaseModel):
    verdict: Literal["PASS", "FAIL"]
    findings: list[str]
    ready_to_commit: bool

def author_agent(state: GuidanceState) -> GuidanceState:
    """Draft or re-draft guidance based on findings."""
    prompt = build_author_prompt(state)
    draft = call_llm(model="claude-sonnet-4.6", prompt=prompt)
    return {**state, "draft_content": draft, "iteration": state["iteration"] + 1}

def reviewer_agent(state: GuidanceState) -> GuidanceState:
    """Validate draft and return structured verdict."""
    prompt = build_reviewer_prompt(state["draft_content"], state["asset_type"])
    result = call_llm(model="claude-sonnet-4.6", prompt=prompt, response_model=ReviewVerdict)
    return {**state, "review_verdict": result.verdict, "review_findings": result.findings}

def should_continue(state: GuidanceState) -> str:
    if state["review_verdict"] == "PASS":
        return "done"
    if state["iteration"] >= state["max_iterations"]:
        return "done"
    return "retry"

workflow = StateGraph(GuidanceState)
workflow.add_node("author", author_agent)
workflow.add_node("reviewer", reviewer_agent)
workflow.add_conditional_edges("reviewer", should_continue, {"retry": "author", "done": END})
workflow.add_edge("author", "reviewer")
workflow.set_entry_point("author")
graph = workflow.compile()
```text

### Key Design Points

- **Deterministic verifier**: the reviewer applies fixed rules (no creativity), making each
  loop iteration predictable and debuggable
- **Findings carry forward**: each re-draft receives the previous findings, so the author
  has context for corrections
- **Max iterations guard**: prevents infinite loops when a draft is pathologically broken
- **Human gate on exit**: the loop produces a validated draft, but human approval remains
  the final merge gate
- **Handoff wiring**: both agents have `handoffs:` in their frontmatter, enabling one-click
  handoff in the Copilot CLI UI

---

## Pattern: Pub-Sub Broadcast for Memory Promotion

**Related issues**: #617

### Overview

The Pub-Sub (publish-subscribe) pattern decouples memory promotion events from the
downstream workflows that react to them. A single `repository_dispatch` event on
`IBuySpy-Shared/basecoat-memory` fans out to all subscriber workflows without the
publisher knowing who is listening.

### Event Schema

When a memory is promoted (PR merged to `basecoat-memory`), the merge workflow emits:

```yaml
event: memory.promoted
domain: ci                     # one of: ci, git, authoring, process, security,
                               # portal, testing, governance, memory, infra
subject: ci:copilot-agent-pr
fact: "Copilot agent PRs show action_required..."
citations: "IBuySpy-Shared/basecoat PRs #312-314"
confidence: 0.95
promoted_by: memory-steward
timestamp: "2026-05-09T09:00:00Z"
source_repo: IBuySpy-Shared/basecoat
```text

### Publisher

The memory promotion PR merge trigger in `basecoat-memory`:

```yaml
# .github/workflows/on-memory-promoted.yml (in basecoat-memory repo)
on:
  push:
    branches: [main]
    paths: ["memories/**/*.md"]

jobs:
  broadcast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Parse promoted memory
        id: parse
        run: |
          # Extract domain/subject from changed file path
          CHANGED=$(git diff --name-only HEAD^ HEAD | grep 'memories/' | head -1)
          DOMAIN=$(echo "$CHANGED" | cut -d/ -f2)
          SUBJECT=$(basename "$CHANGED" .md)
          echo "domain=$DOMAIN" >> $GITHUB_OUTPUT
          echo "subject=$SUBJECT" >> $GITHUB_OUTPUT
      - name: Dispatch to basecoat
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.MEMORY_REPO_TOKEN }}
          script: |
            await github.rest.repos.createDispatchEvent({
              owner: 'IBuySpy-Shared',
              repo: 'basecoat',
              event_type: 'memory.promoted',
              client_payload: {
                domain: '${{ steps.parse.outputs.domain }}',
                subject: '${{ steps.parse.outputs.subject }}',
                timestamp: new Date().toISOString(),
              }
            });
```text

### Subscribers

Each subscriber workflow listens for `repository_dispatch` with `event_type: memory.promoted`:

| Subscriber Workflow | Action |
|---|---|
| `sync-memory-index.yml` | Runs `sync-shared-memory.ps1` to pull new memories to `.memory/shared/` |
| `validate-memory.yml` | Re-validates the promoted memory against scope policy |
| `update-memory-index.yml` | Regenerates `memory-index.instructions.md` with new entry |
| `notify-steward.yml` | Posts a comment to the originating contribution issue |

### Subscriber Template

```yaml
# .github/workflows/sync-memory-index.yml (in basecoat)
on:
  repository_dispatch:
    types: [memory.promoted]

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Pull promoted memory
        run: |
          pwsh scripts/sync-shared-memory.ps1 \
            -Domain "${{ github.event.client_payload.domain }}" \
            -Subject "${{ github.event.client_payload.subject }}"
        env:
          MEMORY_REPO_TOKEN: ${{ secrets.MEMORY_REPO_TOKEN }}
```text

### Key Design Points

- **Decoupled**: the publisher (`basecoat-memory`) does not reference subscribers; new
  subscribers are added by creating a workflow file — no publisher changes needed
- **Idempotent**: subscribers must handle re-delivery (use the `subject` key as an
  idempotency token)
- **Graceful failure**: subscriber failures do not affect the promotion itself or other
  subscribers
- **Audit trail**: each dispatch event appears in the Actions tab with the full payload,
  providing a promotion audit log
- **Cross-repo secret**: `MEMORY_REPO_TOKEN` must have `repo` scope on both `basecoat`
  and `basecoat-memory` to dispatch across repos

### Relationship to Creator-Verifier

In the full guidance lifecycle, the two patterns compose:

```text
guidance-author ──► guidance-reviewer ──► (PASS) ──► PR merge
                                                         │
                                               memory.promoted dispatch
                                                         │
                                         ┌───────────────┼───────────────┐
                                         ▼               ▼               ▼
                                   sync-memory      validate-memory  notify-steward
                                   (pull to .memory/shared/)
```text

The Creator-Verifier loop produces the validated guidance; the Pub-Sub broadcast propagates
it to all consumers once merged.
