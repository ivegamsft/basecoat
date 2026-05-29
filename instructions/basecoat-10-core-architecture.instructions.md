---
description: "Use when making architectural decisions, designing APIs, creating system diagrams, or establishing cross-cutting patterns. Covers ADRs, diagram standards, API design, agent collaboration, and review gates."
applyTo: "src/**,lib/**,app/**,packages/**,**/iac/**,docs/architecture/**,docs/adr/**,docs/api/**"
---

# Architecture Standards

Use this instruction for any work that introduces, changes, or evaluates architectural decisions, system boundaries, API contracts, or cross-cutting concerns.

## Architecture Decision Records (ADRs)

### When to Write an ADR

- Any change that introduces a new technology, framework, or external dependency.
- Any change that alters a service boundary, data flow, or integration pattern.
- Any change that modifies authentication, authorization, or trust boundary topology.
- Any change where two reasonable engineers would choose differently — capture the reasoning.
- Reversing or superseding a previous ADR.

### ADR Format

Every ADR lives in `docs/adr/` and follows this structure:

```markdown
# ADR-<NNN>: <Title>

## Status
Proposed | Accepted | Deprecated | Superseded by ADR-<NNN>

## Context
What is the problem or situation that requires a decision?

## Decision
What is the change that we are proposing or have agreed to?

## Consequences
What are the positive, negative, and neutral effects of this decision?

## Alternatives Considered
What other options were evaluated and why were they rejected?
```

- Number ADRs sequentially. Never reuse a number.
- Keep the title concise — one line describing the decision, not the problem.
- Link related ADRs in the Consequences section when a decision constrains or enables future choices.

### ADR Review Gates

- Every ADR in `Proposed` status must be reviewed by at least one other agent or human before moving to `Accepted`.
- ADRs that affect more than one service boundary require review from the architect agent and the backend-dev agent.
- An ADR must be merged before the implementation PR that depends on it.

## Diagram Standards

### Syntax and Tooling

- All architecture diagrams use **Mermaid** syntax so they render in Markdown without external tools.
- Store diagram source in the same Markdown file where it is referenced — do not use external image files for architecture diagrams.
- Every diagram must have a title that describes what it shows.

### C4 Model Levels

Use the C4 model to organize diagram scope:

| Level | Name | Shows | When to Use |
|-------|------|-------|-------------|
| 1 | System Context | The system as a box, its users, and external systems it interacts with | README, project overview, stakeholder communication |
| 2 | Container | Applications, data stores, and message brokers inside the system boundary | Service decomposition, deployment planning |
| 3 | Component | Major components within a single container and their interactions | Detailed design within a service |
| 4 | Code | Class or module relationships within a component | Only when needed for complex algorithms or patterns |

- Start at Level 1 for any new system or major feature. Add Level 2 when multiple containers exist.
- Level 3 and Level 4 diagrams are optional and should only be created when complexity demands them.

### Diagram Content Rules

- Label every arrow with the protocol or interaction type (e.g., `HTTPS`, `gRPC`, `async/queue`).
- Show trust boundaries as explicit grouping boxes.
- Include data stores and their technology (e.g., `PostgreSQL`, `Redis`, `Blob Storage`).
- Do not include implementation details like class names or function signatures in Level 1 or Level 2 diagrams.

## API Design Principles

- Define API contracts before implementation. The contract is the source of truth — not the code.
- Use OpenAPI 3.x for REST APIs. Store specs in `docs/api/` or alongside the service they describe.
- Follow resource-oriented design: nouns for resources, HTTP verbs for actions.
- Version APIs in the URL path (`/v1/`, `/v2/`) when breaking changes are unavoidable.
- Every endpoint must document request shape, response shape, error responses, and authentication requirements.
- Delegate detailed API design work to the **api-designer agent** when available. The api-designer agent owns contract authoring; the architect agent owns the decision of which APIs are needed and how they fit together.

## Agent Collaboration

The architect agent coordinates with other agents at key decision points:

| Decision Type | Lead Agent | Collaborators |
|---------------|-----------|---------------|
| Service boundaries and decomposition | architect | backend-dev, data-tier |
| API contract design | api-designer | architect, backend-dev, frontend-dev |
| User-facing workflows and navigation | ux | architect, frontend-dev |
| Data model and persistence strategy | data-tier | architect, backend-dev |
| Security architecture and trust boundaries | architect | security reviewer, backend-dev |
| Infrastructure and deployment topology | architect | platform/infra agents |

### Collaboration Rules

- The architect agent defines the high-level structure; specialist agents own the detailed implementation within their domain.
- When the ux agent identifies a workflow that requires new capabilities, the architect agent evaluates whether existing services can support it or whether new boundaries are needed.
- The api-designer agent must not introduce new service boundaries without architect review.
- Cross-cutting concerns (logging, auth, observability) are proposed by the architect agent and implemented by the relevant dev agents.

## Review Gates for Architectural Decisions

Every architectural change must pass through the appropriate gate before merging:

| Change Scope | Required Review | Approval Needed |
|-------------|----------------|-----------------|
| New service or container | ADR + architect review + backend-dev review | Both must approve |
| New external dependency | ADR + architect review | Architect must approve |
| API contract change (breaking) | ADR + api-designer review + consumer agent review | All must approve |
| API contract change (additive) | api-designer review | api-designer must approve |
| Database schema change | data-tier review + backend-dev review | Both must approve |
| Infrastructure topology change | ADR + architect review | Architect must approve |

- No architectural change ships without its ADR in `Accepted` status.
- If a review gate is skipped due to urgency, file a GitHub Issue tagged `tech-debt` and `architecture` to retroactively document the decision within one sprint.
