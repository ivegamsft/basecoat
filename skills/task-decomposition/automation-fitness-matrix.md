# Automation Fitness Matrix

Use this decision tree to categorize work as **automatable**, **research**, or **deferred**. This guides whether a task should be delegated to a sub-agent or handled differently.

---

## Decision Tree

### START: Evaluate the Task

```
Is the task concrete and have a clear success criteria?
│
├─ NO  → Go to "Research Candidate" section
│
└─ YES → Continue
        │
        Can the task be executed by a single agent in a single session (<5 min)?
        │
        ├─ YES  → Likely NOT worth decomposing. Execute directly with one agent.
        │         (Exception: if user explicitly asks for parallelism, still decompose.)
        │
        └─ NO   → Continue
                 │
                 Does the task have clearly separable sub-problems that can run in parallel?
                 │
                 ├─ NO  → Linear task. Decompose into sequential steps for clarity,
                 │        but keep in a single agent if possible to avoid context switching.
                 │
                 └─ YES → Continue
                         │
                         Does each sub-problem have independent success criteria?
                         │
                         ├─ NO  → Sub-problems are tightly coupled. Keep as one task.
                         │
                         └─ YES → **AUTOMATABLE for Decomposition**
                                 → Proceed with multi-agent parallel execution
```

---

## Automation Fitness Quadrant

Plot tasks on this matrix to assess decomposability:

```
                   HIGH
                    │
    Clarity of    │ [AUTOMATE NOW]
    Success        │ • Clear acceptance criteria
    Criteria       │ • Parallel sub-tasks possible
                    │ • Low coupling
                    │
                    ├─────────────────────────────
                    │ [RESEARCH FIRST]         [DEFER / ESCALATE]
                    │ • Ambiguous success      • Unclear success criteria
                    │ • High complexity        • Cannot decompose safely
                    │ • Research > execution   • Needs human input
                    │
                    │ [EXECUTE SYNC]
                    │ • Clear criteria
                    │ • Single-step or tightly coupled
                    │ • <5 min to complete
                   LOW
                    └──────────────────────────────
                        LOW                HIGH
                    Task Complexity / Coupling
```

---

## Category Definitions

### 1. AUTOMATABLE (Green: Go!)

**Characteristics:**
- Success criteria are **specific and measurable** (e.g., "all tests pass", "API returns 200", "user can log in")
- Task can be **split into 2+ independent sub-tasks**
- Each sub-task can be owned by a single agent
- Estimated time per sub-task is **5–30 minutes**
- No human decision-making required mid-flight

**Action:** Decompose and delegate to sub-agents in parallel.

**Example:**
```
Task: "Add OAuth login to the API"
Breakdown:
1. Backend agent: Implement OAuth provider integration
2. Frontend agent: Add login UI component
3. Code-review agent: Review both changes for security

Sub-tasks are independent (can run in parallel) and have clear success criteria (tests pass, no security issues).
→ AUTOMATABLE ✓
```

---

### 2. RESEARCH REQUIRED (Yellow: Plan First)

**Characteristics:**
- Success criteria are **unclear or ambiguous**
- The work involves **exploring unknowns** (e.g., "find the best way to...", "investigate why...")
- Task requires **learning or validation** before execution
- Estimated time is high and undefined
- Output may be a decision or recommendation, not a working artifact

**Action:** Use a planning or research agent first. Once unknowns are resolved, re-evaluate for automation.

**Example:**
```
Task: "Improve API performance"
Issues:
- No measurement baseline (unclear success criteria: "improve by how much?")
- Unknown bottleneck (need to profile first)
- Decision needed on strategy (caching? async? database tuning?)

Action: Use performance-analyst or research agent to:
1. Profile the API
2. Identify the bottleneck
3. Recommend optimization strategy
Then return to decomposition with clearer criteria.
→ RESEARCH REQUIRED 🔍
```

---

### 3. DEFERRED / ESCALATE (Red: Not Ready)

**Characteristics:**
- Success criteria **cannot be defined** without human input or stakeholder alignment
- Task involves **architectural or policy decisions** that require consensus
- Work depends on **external factors** out of scope (e.g., waiting for upstream API, third-party SLA)
- Estimated effort is **very high** (>2 hours per sub-task) or **undefined**
- Risk or scope is too broad for autonomous execution

**Action:** Escalate to stakeholders, document assumptions, or defer until preconditions are met.

**Example:**
```
Task: "Migrate the entire system to Kubernetes"
Issues:
- Architectural decision: do we migrate to AKS, EKS, or GKE? (needs stakeholder input)
- Cost implications and budget approval needed
- Timeline depends on infrastructure provisioning
- Tightly coupled to org-wide DevOps standards

Action: Escalate to architecture review. Once approved:
1. Define migration phases and success metrics
2. Return to decomposition
→ DEFERRED / ESCALATE 🛑
```

---

## Criteria Checklist

### To Classify a Task, Answer These Questions

| Criterion | Yes = Automatable | No = Escalate / Research |
|---|---|---|
| Are acceptance criteria **specific and measurable**? | ✓ | ✗ |
| Can the work be **split into 2+ independent sub-tasks**? | ✓ | ✗ |
| Each sub-task: **<30 min estimated time**? | ✓ | ✗ |
| Is there a **clear owner agent** for each sub-task? | ✓ | ✗ |
| **No mid-flight human decisions** needed? | ✓ | ✗ |
| Are sub-tasks **loosely coupled** (no hard blocker chains)? | ✓ | ✗ |
| Is the **scope bounded and known**? | ✓ | ✗ |
| Are there **no unresolved dependencies** or unknowns? | ✓ | ✗ |

**Scoring:**
- 7–8 ✓s → **AUTOMATE NOW**
- 5–6 ✓s → **AUTOMATE with caution** (consider adding a validation gate)
- 3–4 ✓s → **RESEARCH FIRST** (clarify unknowns, then re-score)
- 0–2 ✓s → **DEFER / ESCALATE** (not ready for automation)

---

## Examples By Category

### Automatable
- "Add validation to user registration form" (clear criteria: form validates email, password, returns 200)
- "Refactor service to use dependency injection" (clear criteria: all tests pass, no behavioral changes)
- "Update documentation for API v2" (clear criteria: all endpoints documented, no TBD placeholders)

### Research Required
- "Improve system latency" (needs baseline measurement first)
- "Reduce cloud costs" (needs cost analysis first)
- "Redesign database schema for scalability" (needs performance analysis first)

### Deferred / Escalate
- "Migrate to a new programming language" (needs architectural decision and org alignment)
- "Adopt a new authentication provider" (needs security and compliance review)
- "Restructure the entire team's Git workflow" (needs stakeholder consensus)

---

## Next Steps

Once you've classified a task:

1. **AUTOMATABLE** → Use `complex-task-breakdown-template.md` to create sub-tasks and prompts
2. **RESEARCH** → Use a planning or research agent; loop back here once unknowns are resolved
3. **DEFERRED** → Document the blocker; escalate to stakeholders or defer until preconditions are met
