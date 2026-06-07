# Untools Integration for BaseCoat

## Overview

This document proposes integrating **Untools** (<https://untools.co/>) decision frameworks into BaseCoat's prompt engineering and agent authoring workflows. Untools provides curated, practical thinking tools and decision-making frameworks that can improve the quality, clarity, and rigor of BaseCoat agent design and prompt optimization.

### Why Untools?

BaseCoat agents and prompts are designed to help operators think through complex problems. By embedding Untools frameworks into the agent instruction sets and decision workflows, we can:

- **Increase prompt clarity** — systematically eliminate ambiguity through first-principles thinking
- **Reduce bias** — surface hidden assumptions using the Ladder of Inference
- **Improve design quality** — apply structured thinking patterns to agent workflows
- **Enable better decision-making** — provide operators with proven mental models for reasoning about complex systems

---

## Recommendation Matrix

The following table evaluates the top 5 Untools frameworks for integration into BaseCoat workflows:

| Framework | Where to Apply | Primary Benefit | Secondary Benefit | Tradeoff | Integration Path |
|---|---|---|---|---|---|
| **First Principles Thinking** | `prompt-engineer.agent.md`, new instruction `prompt-design.instructions.md` | Systematically break down prompt requirements to core components; eliminate inherited assumptions | Reduces cognitive load on prompt engineers by providing a structured decomposition method | Requires initial discipline; can feel slow for simple prompts | Add workflow step to prompt-engineer agent |
| **Ladder of Inference** | `agent-designer.agent.md`, `guardrail.agent.md`, new instruction `assumption-validation.instructions.md` | Surface hidden assumptions in agent design; validate reasoning chains in guardrails | Improves clarity of agent decision logic; easier to debug and maintain agent behavior | Adds explicit validation step; requires clarity on observable data vs. interpretation | Extend agent workflow with assumption-surfacing checklist |
| **Six Thinking Hats** | `solution-architect.agent.md`, new instruction `multi-perspective-design.instructions.md` | Structure multi-perspective design reviews (facts, risks, benefits, creativity, process) | Enables balanced evaluation of architectural tradeoffs; reduces groupthink in design decisions | Introduces formality that may feel heavyweight for simple decisions | Create structured review template; reference in agent |
| **Issue Trees** | `sprint-planner.agent.md`, `solution-architect.agent.md`, new instruction `problem-decomposition.instructions.md` | Systematically decompose complex problems into actionable sub-problems; aligns with sprint goal-to-issues workflow | Improves sprint planning clarity; helps detect missing acceptance criteria | Overhead for well-scoped problems; can become overly granular | Extend sprint-planner workflow; link to existing agent output |
| **Second-Order Thinking** | `release-impact-advisor.agent.md`, `solution-architect.agent.md`, new instruction `consequence-mapping.instructions.md` | Anticipate long-term consequences of design and deployment decisions; improve risk assessment | Strengthens release readiness evaluation; reduces post-deployment surprises | Can cause analysis paralysis; requires discipline to act after analysis | Add checklist to release-impact-advisor workflow |

---

## Integration Design

### 1. First Principles Thinking Integration

**Purpose:** Break down complex prompt requirements to fundamental truths, reducing inherited assumptions and improving clarity.

**Integration Points:**

- **File:** `agents/basecoat-10-core-prompt-engineer.agent.md` — enhance workflow steps 1-2
- **New Asset:** Create `instructions/prompt-design.instructions.md` with explicit first-principles template
- **Trigger:** When a prompt requires revision or is handling edge cases

**Touch Points in Repository:**

```text
agents/basecoat-10-core-prompt-engineer.agent.md
  └─ Workflow step 1 (Understand intent)
     └─ Add: "Apply First Principles: break the desired behavior into atomic components"

instructions/prompt-design.instructions.md (NEW)
  └─ Section: "First Principles Prompt Decomposition"
     └─ Template: "What is the core objective? What minimal knowledge does the model need? 
                   What are the observable inputs and required outputs?"

prompts/ (reference examples, e.g., prompt-registry entries)
  └─ Link to first-principles checklist
```

**Usage Pattern (Optional):**

Before authoring a prompt, apply this 5-step decomposition:

1. **State the problem without jargon** — avoid technical terms; describe in plain language
2. **List all assumptions** — what are you assuming about the model's knowledge, context, or constraints?
3. **Challenge each assumption** — which are necessary? Which can be removed?
4. **Identify minimal requirements** — what information must the prompt contain to achieve the objective?
5. **Reconstruct the prompt** — write a focused, minimal prompt that embeds only the essential elements

---

### 2. Ladder of Inference Integration

**Purpose:** Surface hidden assumptions in agent design and guard against biased reasoning chains.

**Integration Points:**

- **File:** `agents/basecoat-10-core-agent-designer.agent.md` — enhance workflow steps 1 and 4
- **File:** `agents/basecoat-30-ai-guardrail.agent.md` — add assumption validation to guardrail checks
- **New Asset:** Create `instructions/assumption-validation.instructions.md`
- **Trigger:** When designing a new agent or validating guardrail logic

**Touch Points in Repository:**

```text
agents/basecoat-10-core-agent-designer.agent.md
  └─ Workflow step 1 (Clarify scope)
     └─ Add: "Ladder of Inference check: What observable behaviors define success? 
              What assumptions are we making about user intent?"
  └─ Workflow step 4 (Write instruction body)
     └─ Add: "Test reasoning chains: Can we trace from observable input → assumption → conclusion?"

agents/basecoat-30-ai-guardrail.agent.md
  └─ Validation rules
     └─ Add: "Assumption check: Are guardrail rules based on observable data or inference?"

instructions/assumption-validation.instructions.md (NEW)
  └─ 7-rung Ladder template: Observable data → Selection → Meaning → Assumptions → 
                             Conclusions → Beliefs → Actions
```

**Usage Pattern (Optional):**

When reviewing agent design or guardrail rules, climb the Ladder for each key decision:

| Rung | Question | Example |
|---|---|---|
| 1. Observable data | What did we observe? | "Agent output was less than 100 tokens" |
| 2. Select data | What details did we focus on? | "Focused on token count; ignored semantic coherence" |
| 3. Add meaning | What meaning did we assign? | "Assumes brevity indicates poor quality" |
| 4. Make assumptions | What must be true? | "Assumes all users prefer verbose outputs" |
| 5. Draw conclusions | What do we conclude? | "This prompt design fails for concise tasks" |
| 6. Adopt beliefs | What do we now believe? | "This agent cannot handle constraint-driven tasks" |
| 7. Take action | What action results? | "Reject this agent design; redesign the prompt" |

**Challenge each rung:** Is the step justified? What evidence supports it? Can we reframe it?

---

### 3. Six Thinking Hats Integration

**Purpose:** Structure multi-perspective design reviews to improve architectural decision quality.

**Integration Points:**

- **File:** `agents/basecoat-10-core-solution-architect.agent.md` — enhance design review workflow
- **File:** `agents/basecoat-60-workflow-release-impact-advisor.agent.md` — add perspective-based risk assessment
- **New Asset:** Create `instructions/multi-perspective-design.instructions.md`
- **Trigger:** When reviewing architectural tradeoffs or release readiness

**Touch Points in Repository:**

```text
agents/basecoat-10-core-solution-architect.agent.md
  └─ Workflow (add design review step)
     └─ "Apply Six Thinking Hats: systematically review from facts, risks, benefits, 
        creativity, and process perspectives"

agents/basecoat-60-workflow-release-impact-advisor.agent.md
  └─ Impact assessment workflow
     └─ Embed hat-based perspective check: facts about the release, risks (black), 
        opportunities (yellow), creative mitigations (green)

instructions/multi-perspective-design.instructions.md (NEW)
  └─ 6 Hats template with guided questions for each color
```

**Usage Pattern (Optional):**

When evaluating an architectural decision, structure review using 6 Hats:

| Hat | Focus | Key Questions |
|---|---|---|
| **White Hat** (Facts) | Data, information | What do we know? What data do we have? What's missing? |
| **Red Hat** (Feelings) | Intuition, emotions | How do stakeholders feel? What's the gut reaction? |
| **Black Hat** (Risks) | Critical thinking | What could go wrong? What are the pitfalls? Costs? |
| **Yellow Hat** (Benefits) | Optimism, value | What are the advantages? How does this create value? |
| **Green Hat** (Creativity) | New ideas | What alternatives exist? How can we overcome obstacles? |
| **Blue Hat** (Process) | Control, planning | What is the decision process? What's the next step? |

**Process:** Define the decision, then have reviewers "wear" each hat sequentially. Document findings from each perspective. Synthesize for final recommendation.

---

### 4. Issue Trees Integration

**Purpose:** Decompose complex problems into actionable sub-problems; strengthen sprint planning.

**Integration Points:**

- **File:** `agents/basecoat-10-core-sprint-planner.agent.md` — enhance goal decomposition workflow
- **File:** `agents/basecoat-10-core-solution-architect.agent.md` — add problem decomposition for architecture work
- **New Asset:** Create `instructions/problem-decomposition.instructions.md`
- **Trigger:** When planning a sprint goal or defining a complex project scope

**Touch Points in Repository:**

```text
agents/basecoat-10-core-sprint-planner.agent.md
  └─ Workflow step 1 (Accept sprint goal)
     └─ Add: "Decompose using Issue Tree: break goal into primary branches (major components), 
        then secondary branches (actionable tasks)"
  └─ Output
     └─ Include: Issue tree visualization (text-based) showing decomposition hierarchy

agents/basecoat-10-core-solution-architect.agent.md
  └─ System design workflow
     └─ Add: "Map architecture to issue tree; each tree branch aligns with an architecture domain"

instructions/problem-decomposition.instructions.md (NEW)
  └─ Issue Tree template: root problem → primary branches → secondary branches → actionable leaves
```

**Usage Pattern (Optional):**

To decompose a sprint goal using Issue Trees:

1. **Start with the root** — write the main problem or goal at the top
2. **Identify primary branches** — what are the major dimensions or sub-problems? (e.g., "Why is product not selling?" → Marketing, Product, Market)
3. **Secondary decomposition** — for each branch, what are the next-level causes or components?
4. **Actionable leaves** — continue subdividing until each leaf represents a task that can be assigned and estimated
5. **Map to issues** — create GitHub issues for each leaf; group leaves into epic/parent issues for branches

**Example:**

```text
Sprint Goal: "Improve agent observability"
├─ Logging
│  ├─ Add structured logging to agent runtime
│  ├─ Emit logs to central telemetry system
│  └─ Create log dashboard
├─ Metrics
│  ├─ Instrument agent decision points
│  ├─ Track response latency and tokens
│  └─ Set up metric alerts
└─ Tracing
   ├─ Add distributed tracing headers
   ├─ Export traces to observability backend
   └─ Create trace visualization UI
```

---

### 5. Second-Order Thinking Integration

**Purpose:** Anticipate long-term consequences of design and deployment decisions; improve risk assessment and release readiness.

**Integration Points:**

- **File:** `agents/basecoat-60-workflow-release-impact-advisor.agent.md` — enhance consequence analysis
- **File:** `agents/basecoat-10-core-solution-architect.agent.md` — add long-term consequence consideration to design reviews
- **New Asset:** Create `instructions/consequence-mapping.instructions.md`
- **Trigger:** When assessing release impact or designing long-lived systems

**Touch Points in Repository:**

```text
agents/basecoat-60-workflow-release-impact-advisor.agent.md
  └─ Workflow (Impact Assessment)
     └─ Add step: "Second-Order Consequences: For each first-order effect, ask: 'And then what? 
        What second and third-order consequences could emerge?'"
  └─ Risk Assessment output
     └─ Include: Consequence chain for each identified risk

agents/basecoat-10-core-solution-architect.agent.md
  └─ Design review checklist
     └─ Add: "Long-term consequence check: How does this design evolve over 1, 3, 5 years?"

instructions/consequence-mapping.instructions.md (NEW)
  └─ Consequence chain template: First-order → Second-order → Third-order effects
```

**Usage Pattern (Optional):**

When evaluating a release or design decision, apply consequence mapping:

1. **Identify the immediate action** — e.g., "Deploy new prompt engineering workflow"
2. **First-order effects** — what happens immediately? (e.g., "Prompts become clearer, users report higher satisfaction")
3. **Second-order effects** — what ripples from the first-order effects? (e.g., "Prompt engineers spend more time on edge cases; sprint velocity decreases temporarily")
4. **Third-order effects** — what emerges from the second-order effects? (e.g., "Edge case coverage improves; fewer bugs in production over time; technical debt decreases")
5. **Assess net benefit** — do second and third-order effects strengthen or undermine the first-order goal?

---

## Repository Touch Points (Concrete File Changes)

### New Files to Create

| File | Purpose | Status |
|---|---|---|
| `instructions/prompt-design.instructions.md` | First Principles for prompt engineering | Design phase |
| `instructions/assumption-validation.instructions.md` | Ladder of Inference guide | Design phase |
| `instructions/multi-perspective-design.instructions.md` | Six Thinking Hats template | Design phase |
| `instructions/problem-decomposition.instructions.md` | Issue Trees decomposition guide | Design phase |
| `instructions/consequence-mapping.instructions.md` | Second-Order Thinking checklist | Design phase |

### Existing Files to Reference (No edits yet)

| File | Integration | Reason |
|---|---|---|
| `agents/basecoat-10-core-prompt-engineer.agent.md` | First Principles Thinking | Enhance step 1 & 2 of workflow |
| `agents/basecoat-10-core-agent-designer.agent.md` | Ladder of Inference | Enhance step 1 & 4; improve assumption clarity |
| `agents/basecoat-10-core-solution-architect.agent.md` | Six Thinking Hats + Second-Order Thinking + Issue Trees | Multi-framework support for architecture work |
| `agents/basecoat-10-core-sprint-planner.agent.md` | Issue Trees | Enhance goal decomposition |
| `agents/basecoat-60-workflow-release-impact-advisor.agent.md` | Six Thinking Hats + Second-Order Thinking | Improve impact assessment rigor |
| `agents/basecoat-30-ai-guardrail.agent.md` | Ladder of Inference | Add assumption validation to guardrail checks |

---

## Validation Approach

### Quality Improvements to Measure

1. **Prompt Clarity**
   - Metric: Reduce "ambiguous prompt" issues filed against agents by >20%
   - Method: Track issues with "prompt unclear", "conflicting instructions", "edge case not covered"

2. **Assumption Clarity**
   - Metric: Increase documentation of explicit assumptions in agent design by >50%
   - Method: Audit agent files for "Assumptions" sections; compare before/after

3. **Decision Quality**
   - Metric: Decrease post-release incidents caused by unforeseen consequences by >30%
   - Method: Track incident RCAs that cite "unintended side effect" or "second-order impact"

4. **Design Speed**
   - Metric: Maintain or improve time-to-first-iteration for new agents (no regression)
   - Method: Measure from issue-open to agent-authored-and-tested

### Validation Activities

- **Phase 1 (Pilot):** Apply frameworks to 2 new agent designs (e.g., `solution-architect`, `release-impact-advisor`); collect feedback
- **Phase 2 (Adoption):** Embed frameworks in instruction files; reference in agent workflows
- **Phase 3 (Measure):** Track quality metrics; adjust guidance based on adoption feedback
- **Phase 4 (Refine):** Update instruction files with patterns that worked; deprecate frameworks that added overhead

### Documentation and Example Assets

- Create example prompts/agents annotated with framework application
- Add "Before/After" examples showing how each framework improved clarity
- Build a "Untools decision tree" showing which framework to use for which problem
- Maintain a decision log in agent files showing which frameworks were applied and why

---

## Integration Roadmap (Proposed)

### Phase 0: Design & Review (Current)

- [x] Evaluate 3-5 Untools frameworks for fit
- [x] Create this recommendation matrix and integration design
- [x] Identify concrete repository touch points
- [ ] Get stakeholder feedback on framework selections

### Phase 1: Lightweight Integration (Proposed)

- Create 5 instruction files (prompt-design, assumption-validation, multi-perspective-design, problem-decomposition, consequence-mapping)
- Add 1-2 sentences per framework to relevant agent files (references, not detailed instructions)
- Run markdown linting and tests
- Merge to main

### Phase 2: Pilot Adoption (Future)

- Apply frameworks to 2-3 new agent designs
- Collect adoption feedback; refine instruction clarity
- Track early metrics (time-to-design, assumption clarity)

### Phase 3: Full Adoption (Future)

- Embed frameworks into agent workflow steps (e.g., prompt-engineer workflow now explicitly mentions First Principles)
- Create training materials and examples
- Monitor quality metrics; iterate on framework effectiveness

---

## Dependencies & Learning Curve

- **Untools.co access:** Frameworks are free; detailed templates available on Untools (optional reference)
- **Learning curve:** Minimal for operators familiar with decision-making frameworks; ~1–2 hours per framework for deep understanding
- **Adoption overhead:** Low; frameworks are optional guidance, not mandatory. Operators can apply selectively.

---

## Next Steps

1. **Share this document** with BaseCoat stakeholders for feedback
2. **Select a pilot agent** for first-phase integration (recommend `solution-architect.agent.md` or `prompt-engineer.agent.md`)
3. **Create instruction files** per Phase 1 roadmap
4. **Update agent workflow steps** to reference frameworks (non-breaking changes)
5. **Pilot adoption** with a team and collect feedback
6. **Measure quality improvements** over next sprint cycle
7. **Iterate** based on adoption feedback

---

## References

- **Untools:** <https://untools.co/>
- **First Principles Thinking:** Fundamental decomposition for problem-solving
- **Ladder of Inference:** Surface hidden assumptions and biases
- **Six Thinking Hats:** Multi-perspective decision-making framework
- **Issue Trees:** Hierarchical problem decomposition
- **Second-Order Thinking:** Long-term consequence analysis
