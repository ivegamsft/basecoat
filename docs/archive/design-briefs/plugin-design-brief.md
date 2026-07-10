# GitHub Copilot CLI Plugin: Design Brief

**Quick Reference for Plugin Initiative Design**

## Vision
Enable `/basecoat <agent-type> <task>` commands to invoke 73+ basecoat agents directly from GitHub Copilot CLI with intelligent caching, error handling, and resilience.

## Core Requirements

### Functional
- **Agent Routing**: Fuzzy matching on agent type/name
- **Concurrency**: Handle multiple concurrent agent invocations
- **Caching**: Smart caching with TTL + invalidation
- **Error Handling**: Graceful degradation + user feedback
- **Lifecycle**: Init, pre/post hooks, graceful shutdown

### Non-Functional
- **Language**: TypeScript + Node.js
- **Test Coverage**: ≥85% (>90% for core routing, >70% for integrations)
- **Performance**: <500ms for agent routing, <2s total CLI latency
- **Reliability**: 99.5% uptime (handle transient failures gracefully)

## Design Phases

### Phase 1: Architecture (2 days, 2 agents)
- **Agent #1 - solution-architect**:
  - C4 architecture diagrams
  - ADRs (agent routing, caching, error handling)
  - Risk assessment (security, perf, ops)
  - Scalability analysis (73 agents, concurrent invocations)

- **Agent #2 - backend-dev**:
  - Project structure
  - Error handling taxonomy
  - Testing strategy (≥85% coverage)
  - Plugin lifecycle management

### Deliverables
1. Architecture document (15-20 pages)
2. Project structure blueprint
3. Testing strategy & CI gates
4. Risk mitigation plan

## Key Decisions to Document (ADRs)

1. **Agent Routing**: Weighted fuzzy matching vs simple prefix matching
2. **Caching**: Time-based TTL vs event-driven invalidation
3. **Concurrency Model**: Queue-based vs async tasks
4. **Error Escalation**: User feedback vs silent fallback
5. **Plugin Initialization**: Static agent registry vs dynamic loading

## Integration Points
- GitHub Copilot CLI core (CLI arg parsing, output formatting)
- Basecoat agents (agent discovery, invocation protocol)
- Caching layer (invalidation on agent updates)

## Success Metrics
- ✅ All architectural decisions justified with trade-offs
- ✅ C4 diagrams show clear agent routing + caching + lifecycle flow
- ✅ Risk mitigation is actionable and prioritized
- ✅ Project structure is extensible for new agents
