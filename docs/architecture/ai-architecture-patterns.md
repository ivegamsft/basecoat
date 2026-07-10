# AI Architecture Patterns

Architecture Decision Record templates and decision frameworks for AI-augmented systems, with practical patterns for routing, orchestration, resilience, and human oversight.

> **Tracking:** Issue [#126](https://github.com/IBuySpy-Shared/basecoat/issues/126)

---

## 1. Why AI Architecture Needs Explicit Patterns

AI-augmented systems add design forces that traditional application architecture does not fully capture:

- Model quality varies by provider, version, and task type
- Latency and token cost change at runtime, not just at deploy time
- Output quality is probabilistic rather than strictly deterministic
- Safety, compliance, and auditability often require extra control points
- Failure handling must include graceful degradation, not just retries

Documenting those forces up front makes architectural decisions easier to review, safer to operate, and cheaper to evolve.

---

## 2. ADR Template for AI Systems

Use this template when a decision depends on model choice, prompt orchestration, agent topology, fallback behavior, or human review requirements.

```markdown
# ADR-{number}: {title}

## Status
{proposed | accepted | deprecated | superseded}

## Context
{What forces are at play? What problem are we solving?}

## Decision
{What is the change we're proposing/making?}

## AI-Specific Considerations
- Model dependency: {which models does this depend on?}
- Degradation path: {what happens if the model is unavailable?}
- Cost implications: {token/API cost at expected scale}
- Latency budget: {acceptable response time}
- Quality floor: {minimum acceptable output quality}

## Consequences
- Positive: {benefits}
- Negative: {tradeoffs}
- Risks: {what could go wrong}
```

### When to Write an AI ADR

Write an ADR when a change materially affects any of the following:

- Model provider or model family selection
- Prompt orchestration or agent workflow design
- Guardrail placement, policy enforcement, or human approval steps
- Cost, latency, or reliability envelopes
- Data handling constraints such as residency, retention, or redaction

### Questions the ADR Should Answer

Before accepting the decision, confirm the ADR answers these questions:

1. What happens if the preferred model is slow, unavailable, or too expensive?
2. Which part of the workflow must remain deterministic?
3. Where is quality measured, and what is the minimum acceptable bar?
4. Which decisions require audit logs, review queues, or human sign-off?
5. How can this choice be reversed if the model landscape changes?

---

## 3. Architecture Patterns

The following patterns are useful building blocks for AI-augmented software systems. They can be combined, but each one should solve a clear problem rather than add abstraction for its own sake.

### Pattern: Gateway / Router

A central entry point classifies incoming requests and routes them to the most appropriate model, toolchain, or agent.

How it works:

- A single boundary receives requests from clients or upstream services
- Routing logic selects the model or agent based on intent, policy, budget, or workload class
- The gateway can apply shared concerns such as telemetry, rate limiting, caching, and redaction

Use when:

- Multiple models are available
- Quality and cost targets vary by request type
- A/B testing, load balancing, or failover is required

Benefits:

- Centralized policy enforcement
- Easier experimentation and provider substitution
- Better control over cost and reliability

Tradeoffs:

- Can become a bottleneck if overloaded
- Adds governance complexity to the routing layer
- Poor routing logic can hide quality problems behind indirection

### Pattern: Chain of Responsibility

A request moves through an ordered sequence of handlers. Each handler validates, enriches, transforms, or blocks the request before passing it onward.

How it works:

- Each stage has one focused responsibility
- Stages can short-circuit on errors, policy violations, or sufficient confidence
- Outputs from one stage become inputs to the next stage

Use when:

- A workflow follows validation → enrichment → generation → guardrail steps
- Deterministic pre- and post-processing matters as much as the model call itself
- Teams want clear boundaries between stages

Benefits:

- Separation of concerns
- Testable stage-by-stage behavior
- Easy insertion of new validation or guardrail steps

Tradeoffs:

- Too many stages can increase latency
- Cross-stage debugging can become harder without strong tracing
- Tight coupling can emerge if each stage depends on internal details from the previous one

### Pattern: Mixture of Experts

Multiple specialized agents or models handle different classes of work, with a router selecting the best expert for each task.

How it works:

- Experts are specialized by domain, tool access, or reasoning style
- A selector chooses one expert, several experts, or an ensemble strategy
- Results may be ranked, merged, or checked before returning to the caller

Use when:

- Domain diversity exceeds what one model or agent can handle well
- Specialist prompts, tools, or policies materially improve outcomes
- Workloads differ enough to justify dedicated experts

Benefits:

- Higher quality for specialized tasks
- Better alignment between capability and workload
- Allows selective use of premium models only where needed

Tradeoffs:

- Requires good routing and evaluation logic
- Operational overhead grows with each expert
- Consistency can suffer if experts produce incompatible outputs

### Pattern: Fallback Cascade

The system tries a preferred path first, then progressively cheaper or simpler alternatives if quality, availability, or latency thresholds are not met.

How it works:

- Start with a premium or primary model
- Fall back to a cheaper or faster model when conditions require it
- Fall back again to cached, template-driven, or rule-based behavior when model use is no longer viable

Use when:

- Cost optimization matters but a quality floor must still be preserved
- The system needs graceful degradation under load or provider failure
- Some response is better than none, as long as minimum quality is maintained

Benefits:

- Improved resilience
- Better budget control
- Predictable degradation paths during incidents

Tradeoffs:

- Requires explicit quality floors for each fallback layer
- Output behavior may vary across tiers
- Teams must actively monitor whether fallbacks become the default by accident

### Pattern: Human-in-the-Loop Circuit Breaker

An automated flow runs normally until risk, ambiguity, or low confidence causes a breakpoint that requires human review before the workflow continues.

How it works:

- Automation performs the routine path end to end
- Confidence scores, policy checks, or anomaly signals trigger a review gate
- The circuit opens and blocks automated completion until a human approves, edits, or rejects the result

Use when:

- Decisions are high stakes
- Compliance requires reviewable checkpoints
- The cost of an incorrect automated action is high

Benefits:

- Reduces unsafe automation in sensitive workflows
- Creates explicit accountability and audit trails
- Focuses human attention where it adds the most value

Tradeoffs:

- Review queues can add latency and operational cost
- Confidence thresholds require tuning
- Human reviewers need enough context to make fast, consistent decisions

### Pattern: Event-Driven Agent Mesh

Independent agents communicate through events rather than direct, tightly coupled calls.

How it works:

- Agents publish domain events when work starts, finishes, or needs follow-up
- Other agents subscribe only to the event types they care about
- State coordination happens through event contracts, queues, and idempotent processing

Use when:

- Workflows are complex and span many independent agents
- Loose coupling is more important than strict request-response behavior
- Different steps can run asynchronously or in parallel

Benefits:

- Scales well across many agents and workflow branches
- Encourages clear ownership and loose coupling
- Supports asynchronous work and recovery patterns naturally

Tradeoffs:

- Harder to trace end-to-end flow without good observability
- Event schemas and delivery guarantees must be maintained carefully
- Debugging eventual consistency issues can be difficult

---

## 4. Decision Framework

When choosing between patterns, evaluate the system against these dimensions.

### 1. Latency requirements

Ask:

- Must the user wait synchronously for a result?
- Is asynchronous completion acceptable?
- Which stages can be parallelized, cached, or deferred?

Pattern bias:

- Favor **Gateway / Router** or **Fallback Cascade** for tight synchronous paths
- Favor **Event-Driven Agent Mesh** when async orchestration is acceptable
- Favor **Chain of Responsibility** when predictable stage order matters more than raw speed

### 2. Cost sensitivity

Ask:

- Is there a fixed budget, or can cost rise with quality?
- Which requests justify premium models?
- Can lower-tier outputs satisfy part of the workload?

Pattern bias:

- Favor **Fallback Cascade** when pay-per-quality must be controlled
- Favor **Gateway / Router** to steer low-value traffic to cheaper paths
- Favor **Mixture of Experts** when premium cost should be limited to specialist cases

### 3. Reliability needs

Ask:

- What is the SLA for response success and response time?
- How much model or provider failure can the system tolerate?
- Does the workflow need deterministic backup behavior?

Pattern bias:

- Favor **Fallback Cascade** for degradation and continuity
- Favor **Gateway / Router** for failover and load balancing
- Favor **Human-in-the-Loop Circuit Breaker** when reliability includes correctness, not just uptime

### 4. Complexity budget

Ask:

- Does the team have capacity to operate multiple agents, models, and pipelines?
- Is the architecture understandable by the engineers who must support it?
- Can the system be observed and debugged in production?

Pattern bias:

- Favor **Chain of Responsibility** for incremental structure with manageable complexity
- Use **Mixture of Experts** only when specialization clearly outperforms a simpler design
- Use **Event-Driven Agent Mesh** only when workflow scale truly demands it

### 5. Compliance

Ask:

- Is a full audit trail required?
- Are there data residency or retention constraints?
- Must a human approve certain classes of actions?

Pattern bias:

- Favor **Human-in-the-Loop Circuit Breaker** for mandatory review and accountability
- Favor **Gateway / Router** for centralized policy enforcement
- Favor **Chain of Responsibility** when guardrails must appear in a documented order

### Quick Selection Guide

| Primary constraint | Usually start with | Add when needed |
|--------------------|--------------------|-----------------|
| Multiple models with varying cost and quality | Gateway / Router | Fallback Cascade |
| Ordered validation and safety pipeline | Chain of Responsibility | Human-in-the-Loop Circuit Breaker |
| Broad domain specialization | Mixture of Experts | Gateway / Router |
| Cost control with minimum acceptable quality | Fallback Cascade | Gateway / Router |
| High-stakes or regulated workflows | Human-in-the-Loop Circuit Breaker | Chain of Responsibility |
| Large async multi-agent workflow | Event-Driven Agent Mesh | Mixture of Experts |

---

## 5. Anti-Patterns

Avoid these failure modes when designing AI-augmented systems.

### God Agent

One agent does everything: planning, retrieval, generation, validation, tool use, and policy decisions.

Why it fails:

- No separation of concerns
- Hard to test or tune individual responsibilities
- Small prompt changes can destabilize the whole system

Prefer:

- Split responsibilities into clearer stages or specialized agents

### Chatty Agents

Agents exchange excessive intermediate messages, repeatedly restating context or asking each other for small decisions.

Why it fails:

- Wastes tokens and increases latency
- Amplifies context drift between agents
- Creates brittle coordination loops

Prefer:

- Share structured state, concise event payloads, and clearer ownership boundaries

### Synchronous Everything

Every LLM call blocks the user path, even when work could run in parallel or in the background.

Why it fails:

- Produces poor user experience under variable model latency
- Limits throughput during spikes
- Couples product responsiveness to model performance

Prefer:

- Reserve synchronous calls for user-critical steps and move the rest to async pipelines

### No Fallback

The system depends on a single model or provider with no degradation path.

Why it fails:

- Provider outages become product outages
- Cost spikes have no safety valve
- Recovery options are limited during incidents

Prefer:

- Define model, cache, and deterministic fallback layers before launch

### Premature Optimization

The architecture introduces expert meshes, advanced routing, and orchestration layers before a simple implementation has proven the need.

Why it fails:

- Adds operational burden before value is validated
- Makes evaluation harder because too many variables change at once
- Locks the team into complexity that may never pay off

Prefer:

- Start with the simplest architecture that can meet the quality bar, then add complexity only when metrics justify it

---

## 6. Recommended Adoption Sequence

A practical rollout path keeps complexity proportional to proven need.

1. Start with a single well-instrumented path and write an AI ADR for key assumptions.
2. Add a **Gateway / Router** when model choice, routing, or provider control becomes necessary.
3. Add a **Chain of Responsibility** when validation, enrichment, and guardrails need clearer boundaries.
4. Add a **Fallback Cascade** before strict uptime or cost commitments are made.
5. Add **Human-in-the-Loop Circuit Breaker** controls before automating high-stakes actions.
6. Add **Mixture of Experts** or an **Event-Driven Agent Mesh** only after metrics show a simpler design is no longer enough.
