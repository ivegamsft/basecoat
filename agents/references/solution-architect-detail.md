# Solution Architect Agent — Detail Reference

Full standards for `agents/basecoat-10-core-solution-architect.agent.md`.

## Required Architecture Templates

- C4 diagrams: `skills/architecture/c4-diagram-template.md`
- Architecture decisions: `skills/architecture/adr-template.md`
- Technology comparison: `skills/architecture/tech-selection-matrix-template.md`
- Risk register: `skills/architecture/risk-register-template.md`

## C4 Diagram Standards

- Use Mermaid syntax for all diagrams so they render in GitHub, IDEs, and documentation sites without external tooling.
- Always start with a **Context** diagram before diving into Container or Component levels.
- Label every element with its name, technology (where applicable), and a one-line description.
- Show data flow direction with arrows and annotate with protocol or data format (e.g., `REST/JSON`, `gRPC`, `AMQP`).
- Keep diagrams focused — split large systems across multiple diagrams rather than cramming everything into one.

## Architecture Decision Records

- Create one ADR per significant decision. Trivial choices do not need ADRs.
- A decision is significant if it is hard to reverse, affects multiple teams or services, or commits the project to a technology or pattern for more than one sprint.
- Use the status lifecycle: `Proposed` → `Accepted` → `Superseded` or `Deprecated`.
- Never delete an ADR — supersede it with a new one that references the original.

## Technology Selection

- Evaluate at least two alternatives for any technology choice that has meaningful trade-offs.
- Weight criteria by project priorities (e.g., time-to-market may outweigh raw performance for an MVP).
- Include total cost of ownership: licensing, hosting, operational complexity, and team skill availability.
- Document the decision as an ADR after the matrix is complete.

## Cross-Cutting Concerns Checklist

Review each concern and document the approach or flag a gap:

| Concern | Questions to Answer |
|---|---|
| **Authentication** | Who authenticates? What protocol (OAuth 2.0, OIDC, SAML, API keys)? Where are tokens validated? |
| **Authorization** | Role-based or attribute-based? Where are policies enforced? How are permissions managed? |
| **Observability** | What is traced (distributed tracing)? What metrics are collected? Where do logs go? What alerting exists? |
| **Data Residency** | Where is data stored geographically? Are there regulatory constraints (GDPR, HIPAA, SOC 2)? How is data sovereignty enforced? |
| **Resilience** | What happens when a dependency fails? Circuit breakers? Retries with backoff? Fallback behavior? |
| **Configuration** | How is config managed across environments? Secrets management? Feature flags? |
| **Deployment** | CI/CD pipeline? Blue-green or canary? Rollback strategy? Infrastructure as code? |

## Scalability Review

When reviewing or designing for scale, address:

- **Throughput targets** — expected requests per second, message volume, or data ingestion rate.
- **Latency targets** — p50, p95, p99 latency budgets for critical paths.
- **Statelessness** — identify stateful components and plan for horizontal scaling or state externalization.
- **Caching strategy** — what to cache, where (CDN, reverse proxy, application, database), and invalidation approach.
- **Data partitioning** — sharding strategy, partition keys, and hot-spot mitigation.
- **Single points of failure** — identify and plan redundancy or failover.
- **Cost at scale** — estimate resource costs at 1×, 10×, and 100× current load.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Architecture Risk]`
- **Base labels:** `architecture,risk`
- **This domain's `Risk Category`/`Component` fields below replace the
  shared template's `Category`/`File`/`Line(s)` metadata block** —
  architecture risks are scoped to a system/service/layer, not a specific
  file or line.
- **Risk Category:** `<single point of failure | missing auth | data residency gap | scalability bottleneck | unrecorded decision | technology lock-in>`
- **Component:** `<system, service, or layer affected>`

| Finding | Labels |
|---|---|
| Single point of failure with no failover plan | `architecture,risk,reliability` |
| Missing or inconsistent authentication/authorization | `architecture,risk,security` |
| Data residency requirement not enforced in design | `architecture,risk,compliance` |
| Scalability bottleneck with no mitigation plan | `architecture,risk,performance` |
| Significant decision made without an ADR | `architecture,risk,governance` |
| Technology choice creating vendor lock-in without documented justification | `architecture,risk,governance` |
