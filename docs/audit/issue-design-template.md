# Design & Debate Template for CI/CD Learnings

Use this template when opening an issue to log one of the 9 CI/CD learnings. The goal is **debate and design**, not implementation. Discussion happens async in issue threads; consensus is documented in the issue description over time.

---

## Template: [Learning Title]

**Related finding:** See `docs/audit/ci-cd-findings-2026-06-14.md`

### Problem Statement

*Describe the bottleneck or opportunity this learning identifies. 1-2 paragraphs, plain language.*

- **Current behavior:** What happens today?
- **Symptom:** How does this manifest as a problem?
- **Underlying cause:** What's the root structural issue?

### Debate Prompt

*Open questions for async discussion. Design team adds comments; maintainer synthesizes into consensus.*

1. **Question 1:** ?
2. **Question 2:** ?
3. **Question 3:** ?

### Design Principles

*Constraints and values that should guide the solution.*

- Principle 1: ...
- Principle 2: ...
- Principle 3: ...

### Success Criteria

*How will we know this learning has been acted on?*

- [ ] Design document published
- [ ] Consensus reached on open questions
- [ ] Implementation plan ready
- [ ] Related PRs linked in issue

### Design Notes

*Maintained over time as debate progresses. Captures decisions, tradeoffs, and rationale.*

```markdown
[Will be filled in during debate phase]
```

### Related Issues / PRs

- Related findings: `docs/audit/ci-cd-findings-2026-06-14.md`
- Reactive PRs (sprint:35-reactive-debt): See label
- Design docs: (will be linked as published)

### Timeline

- **Logged:** 2026-06-14
- **Debate phase:** Sprint 35–36
- **Design phase:** Sprint 36
- **Implementation:** Sprint 37+

---

## Example: Issue #1661 (Merge Bottleneck — Per-Agent Lanes)

### Problem Statement

All agents serialize through a shared merge queue. When one agent's PRs encounter validation failures, all downstream work blocks. Velocity appears high (13.6 PRs/day) but is misleading — many merges succeed despite broken validation gates because gates are bypassed manually.

- **Current behavior:** All agents compete for a single merge queue; no prioritization or isolation
- **Symptom:** Merge delays cascade; unrelated agents are blocked when one agent's PR has issues
- **Underlying cause:** No logical separation of agent responsibilities; shared queue assumes all work has equal risk profile

### Debate Prompt

1. **Should each agent type have its own merge pool?** (e.g., code-review lane, deploy lane, maintenance lane)
2. **How many independent lanes can we maintain operationally?** (cost, observability, complexity)
3. **Which gates apply globally vs. per-lane?** (e.g., secret scanning global; agent-specific validation per-lane)

### Design Principles

- **Isolation:** Failures in one lane must not cascade to others
- **Observability:** Each lane should have its own metrics and alerting
- **Prioritization:** Critical paths (deploy, security) should not wait on routine updates
- **Simplicity:** Number of lanes should be minimal; each lane should have clear ownership

### Success Criteria

- [ ] Design document published describing lane topology
- [ ] Consensus on which agent categories map to which lanes
- [ ] Cost estimate for per-lane monitoring/automation
- [ ] Rollout plan for lanes (one at a time vs. parallel)
- [ ] Implementation PRs linked back to this issue

### Design Notes

```markdown
[Debate comments and consensus will be added here during Sprint 35–36]
```

### Related Issues / PRs

- Related findings: See `docs/audit/ci-cd-findings-2026-06-14.md` section "1. Merge Bottleneck"
- Reactive PRs: #1641, #1642, #1643 (tagged sprint:35-reactive-debt)
- Dependent issues: #1662 (PR merge + cloud agent pairing), #1667 (dedicated sessions)

### Timeline

- **Logged:** 2026-06-14
- **Debate window:** Sprint 35 (ends 2026-06-21)
- **Design phase:** Sprint 36 (design spec due 2026-07-05)
- **Implementation:** Sprint 37+ (design links in PRs)

---

## Workflow: How Issues Progress

### Initial Issue (Day 0)

Opening an issue:

```markdown
## [Title]

**Status:** Debate Phase
**Assigned to:** Maintainer (facilitator)

[Use template above; fill in Problem Statement, Debate Prompt, Design Principles, Success Criteria]

👉 **Next:** Invite comments; respond to all questions with context.
```

### After First Pass (Day 3–7)

Early debate comments:

```markdown
## Design Notes

### Thread 1: [Question 1]
- Comment A (contributor): "I think we should..."
- Comment B (maintainer): "Good point, but we also need to consider..."
- Synthesized: "Consensus seems to be [X], pending feedback on [Y]"

### Thread 2: [Question 2]
- (debate continues)
```

### After Design Phase (Day 14+)

Consensus documented:

```markdown
## Design Notes

### ✅ CONSENSUS REACHED

**Decision 1:** [Choice made and rationale]
**Decision 2:** [Choice made and rationale]
**Tradeoffs:** [What we're giving up, why it's worth it]

### Architecture Sketch

[Pseudocode, data flow diagram, or detailed proposal]

### Implementation roadmap

1. [Step 1]
2. [Step 2]
3. [Step 3]

### Implementation PRs (link them here as they land)

- #XXXX — [PR title]
- #YYYY — [PR title]
```

---

## Standards for Discussion Phases

### During Debate Phase

- ✅ **Do:** Ask clarifying questions; surface assumptions; propose alternatives
- ✅ **Do:** Link evidence (metrics, logs, PRs) to support your view
- ✅ **Do:** Acknowledge good points you disagree with; explain why you still prefer another approach
- ❌ **Don't:** Demand immediate implementation; debate IS the work in this phase
- ❌ **Don't:** Veto without explanation; propose a counter-option instead

### During Design Phase

- ✅ **Do:** Write architecture; publish pseudocode or data flows; define success metrics
- ✅ **Do:** Document tradeoffs and non-goals
- ✅ **Do:** Reference earlier debate threads (link comments) when decisions rest on them
- ❌ **Don't:** Skip past consensus to implementation code; design docs are the deliverable here
- ❌ **Don't:** Re-debate settled questions; open a new issue if scope changed

### After Design Phase

- ✅ **Do:** Create implementation PRs with clear reference back to issue (e.g., "Implements #1661")
- ✅ **Do:** Link implementation PRs in the issue's "Related Issues / PRs" section
- ✅ **Do:** Use design docs as acceptance criteria (PR passes if it matches the design)
- ❌ **Don't:** Change the design mid-implementation without opening a new issue
- ❌ **Don't:** Merge implementation PRs before design consensus is documented (pinned comment in issue)
