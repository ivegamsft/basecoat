# Soft-Fork Subtask Isolation Pattern

**Status**: Foundational guidance

**Tracking**: Issue #2009

**Applies to**: Multi-subtask single-session work in BaseCoat operators and multi-agent fleet orchestration

**Companion documents**: [token-optimization.md](../guides/token-optimization.md), [context-rot-runbook.md](context-rot-runbook.md), `.github/instructions/cost-optimization.instructions.md`

## Overview

The **soft-fork** pattern enables operators to isolate and execute related subtasks **within a single session** by activating and deactivating focused context (skills, instruction frontmatter, or artifacts) per subtask without branching or creating new worktree sessions.

This pattern optimizes against **branch/session churn** and **context bloat**. It is neither staying-put (carrying all context forever) nor hard-forking (creating new sessions). Instead, it trades off:

- Lower session count (cost per branch/session overhead)
- Faster task handoff (no session startup)
- Unified artifact lifecycle (all output in one session)
- Requires explicit context cleanup between subtasks
- Router spine must remain stable across all subtasks

## Decision Table: Stay vs Compact vs Soft-Fork vs Hard-Fork

Use this table to decide which pattern fits your multi-subtask session:

| Situation | Pattern | Why | Token Cost | Branch/Session Count |
|-----------|---------|-----|------------|----------------------|
| Single objective, one deliverable, <4K transient tokens per subtask | **Stay** | No overhead; context stays active | Baseline (9.1M) | 1 |
| Single objective, phase transition (triage→impl→merge), <150 events per phase | **Compact** | Drop transient context, keep router spine | +5–10% | 1 |
| 2–5 related subtasks in same repo, each needs isolated context (skills/docs), same operator | **Soft-fork** | Toggle context per subtask; unify output | +15–25% | 1 |
| Unrelated domains, different operators, or >5 subtasks | **Hard-fork** | New session/branch avoids context explosion | +30–50% per session | 2+ |
| Cleanup-driven branching (e.g., "start fresh to drop stale context") | **Compact or soft-fork** | Don't create branches just for cleanup; compact and reuse | Same-session cost | 1 |

**Cost comparison (rough, per 8-hour session)**:

- Stay: 9–15M tokens (1 session, no compaction)
- Compact (2×): 15–22M tokens (1 session, 2 phases)
- Soft-fork (3 subtasks): 18–28M tokens (1 session, 3 subtask cycles)
- Hard-fork (2 sessions): 28–40M tokens (2 separate sessions)

---

## Rationale & Tradeoffs

### Why Soft-Fork?

1. **Branch churn is expensive**: Each new branch adds infrastructure cost (worktree overhead, CI setup per branch, merge queue timing).
2. **Context carrying is also expensive**: Leaving all subtask context active inflates token spend by 35–50%.
3. **Session startup is expensive**: Each new session re-sends instruction files, project structure, and baseline context.

Soft-fork occupies the middle ground: one session, but toggled context per subtask.

### When **Not** to Soft-Fork

- **Different objectives**: If subtasks belong to different features or epics, hard-fork (new branch/session).
- **Different operators**: If subtasks will be handed off to another person/team, hard-fork so they have clean context.
- **>5 subtasks**: Context toggle overhead exceeds hard-fork savings; split into 2–3 hard-fork sessions instead.
- **Safety-critical flows**: If a subtask failure would corrupt the session state (e.g., data migration), hard-fork for isolation.

---

## Operator Workflow

### Phase 0: Plan (Before Soft-Fork)

1. **Identify related subtasks**: List 2–5 tasks in the same repo that serve one feature/epic.
2. **Verify same operator**: Soft-fork is single-operator only; if handoff is planned, hard-fork instead.
3. **Scan for shared dependencies**: If subtask N depends on output from subtask N-1, plan the order upfront.
4. **Create a `ROUTER_SPINE` artifact**: A single markdown file (or checklist) that tracks:
   - [ ] Subtask 1: Status, next artifact path
   - [ ] Subtask 2: Status, next artifact path
   - [ ] Subtask 3: Status, next artifact path
   - Global decision checkpoints (e.g., "merge PR before proceeding to subtask 2?")

**Example**:

```markdown
## Soft-Fork: BaseCoat Cost-Opt Initiative

### Router Spine
- Current subtask: skill-deactivation-contract
- Previous: router-spine-definition (Done; output in docs/operations/soft-fork-subtask-isolation.md)
- Next: escalation-rules (blocked until skill-deactivation reviewed)

### Subtask 1: Router Spine Definition
- [ ] Define router spine (stable context) — DONE
- [ ] Artifact: docs/operations/soft-fork-subtask-isolation.md

### Subtask 2: Skill Activation/Deactivation
- [ ] Write skill contract (what loads/unloads per subtask)
- [ ] Artifact: TBD (pending subtask 1)

### Subtask 3: Escalation & Handoff
- [ ] Document hard-fork trigger rules
- [ ] Artifact: TBD

### Global Checkpoint
- PRs: Merge cost-optimization-guidance PR before moving to subtask 3
```

### Phase 1: Activate (Subtask Start)

1. **Update ROUTER_SPINE**: Set `Current subtask: <name>`.
2. **Load task-specific context only**:
   - Push one focused instruction file or skill if needed.
   - Load only files/examples relevant to this subtask.
   - Keep system prompts, global instructions, and project structure (baseline) active.
3. **Confirm scope**: Ask the agent: "This subtask is isolated to [X]. If scope expands to [Y], we escalate to hard-fork."

### Phase 2: Execute

1. **Bounded execution**: Agent completes the subtask and produces artifacts (code, docs, analysis).
2. **Record decision checkpoints**: If a decision affects next subtasks (e.g., "use this file format for all outputs"), log it in ROUTER_SPINE.
3. **No context bleeding**: Don't accumulate output context from prior subtasks unless explicitly needed.

### Phase 3: Deactivate (Subtask End)

1. **Offload artifacts**: Move output to a persistent location (file, artifact path, issue comment).
2. **Clear task context**: Drop task-specific instructions, skills, and temporary docs.
3. **Update ROUTER_SPINE**:

   ```markdown
   ### Subtask 1: [Done]
   - Status: ✓ Done
   - Output: docs/operations/soft-fork-subtask-isolation.md
   - Impact on next subtasks: Skills must implement activation/deactivation contracts
   ```

4. **Escalation check**: Does output quality or scope suggest hard-fork is now needed? If yes, escalate before moving to phase 1 of the next subtask.

### Phase 4: Handoff (Between Subtasks)

1. **Compact (optional)**: If session events exceed 300 or ratio exceeds 300x, run `/compact` before switching subtasks. Keep ROUTER_SPINE and artifact paths active.
2. **Load next subtask context**: Push focused instructions for subtask N+1.
3. **Reference prior output**: Link to subtask N artifacts so the new context is aware of decisions/formats.

---

## Skill Activation/Deactivation Contract

### Activation (Per Subtask)

When starting a subtask, bind these explicitly:

```yaml
# Pseudo-instruction frontmatter (for subtask context isolation)
---
name: Soft-Fork Subtask N
parent_session_issue: "#2009"
router_spine: "path/to/router-spine-artifact"
visibility: internal  # or scoped to specific team
active_skills:
  - skill-1: cost-optimization-guidance (isolated doc load)
  - skill-2: fleet-patterns-reference (isolated context)
always_active_baseline:
  - router
  - project-structure
  - global-instructions
scope_boundary: "Subtask N only; if scope expands to [X], escalate to hard-fork"
---
```

### Deactivation (Per Subtask)

After subtask execution, explicitly unload:

```yaml
---
name: Subtask N Complete
deactivation_checklist:
  - Artifact path recorded: /path/to/output
  - Task-specific instructions cleared
  - Temporary docs dropped
  - Decision log updated in router-spine
  - Quality checkpoint passed (output != degraded)
escalation_flag: "No — proceed to subtask N+1" or "Yes — hard-fork required"
---
```

### Anti-Pattern: Persistent Skill Payload

**Do NOT**: Leave all skills active from every subtask. This recreates the "context bloat" problem soft-fork solves.

**Do**: Unload skill context after each subtask. Re-load only if the next subtask reuses it.

Example:

```markdown
// WRONG (context bloat)
Subtask 1 loads: skill-cost-opt, skill-fleet-patterns, skill-merge-policy
Subtask 2 loads: skill-cost-opt, skill-fleet-patterns, skill-merge-policy, skill-brand-guidelines
// Now 4 skills are stacked.

// RIGHT (clean activation/deactivation)
Subtask 1 loads: skill-cost-opt
Subtask 1 deactivates: skill-cost-opt (output saved)
Subtask 2 loads: skill-brand-guidelines
Subtask 2 deactivates: skill-brand-guidelines (output saved)
// Only one skill active at a time.
```

---

## Escalation Rule: Soft-Fork → Hard-Fork

Move to **hard-fork** (new session/branch) **immediately** if any of these occur:

| Signal | Action |
|--------|--------|
| Scope expands beyond the original 2–5 subtasks | Stop soft-fork; create new session |
| Output quality degrades after subtask 3 | Compact or hard-fork; context rot suspected |
| Subtask introduces unplanned handoff (operator change) | Create new session for incoming operator |
| Session events exceed 500 without producing final artifacts | Hard-fork; existing session is too bloated |
| Subtask requires a different operator role (e.g., security review vs. implementation) | Create scoped hard-fork for that role |
| Skill context exceeds 20% of the session's input token budget | Decompose into hard-fork sessions |

**Escalation action**:

1. Save all artifacts and ROUTER_SPINE to persistent paths.
2. Create a new session/branch with link to prior session's ROUTER_SPINE.
3. Do **not** copy the entire history; reference artifact paths instead.

---

## Worked Example: BaseCoat Cost-Optimization Initiative

### Setup

**Objective**: Reduce BaseCoat session costs by 35–50% through three related subtasks.

**Subtasks**:

1. Define soft-fork pattern (this doc)
2. Build skill activation/deactivation contract
3. Create escalation decision tree & anti-patterns list

**Operator**: Same throughout (internal engineering)

**ROUTER_SPINE**: `docs/operations/COST-OPT-SOFT-FORK-SESSION.md`

### Execution Phases

#### Subtask 1: Define Soft-Fork Pattern

**Phase 1 — Activate**:

- Load: `cost-optimization.instructions.md`, `token-optimization.md` (context only)
- Create: `docs/operations/soft-fork-subtask-isolation.md` (this document)
- Scope boundary: "Define rationale, decision table, workflow, and anti-patterns for soft-fork only."

**Phase 2 — Execute**:

- Write sections: Rationale, Decision Table, Workflow, Skill Contract, Escalation Rules, Example.
- Validate against cost-optimization.instructions.md principles.

**Phase 3 — Deactivate**:

- Output: `docs/operations/soft-fork-subtask-isolation.md` (saved)
- Clear task-specific docs from context
- Update ROUTER_SPINE:

    ```markdown
    ### Subtask 1: Soft-Fork Pattern Definition ✓ Done
    - Output: docs/operations/soft-fork-subtask-isolation.md
    - Next blocker: Skills team must implement skill-deactivation contract
    ```

**Phase 4 — Handoff Check**:

- No hard-fork trigger; proceed to subtask 2.

---

#### Subtask 2: Skill Activation/Deactivation Contract

**Phase 1 — Activate**:

- Load: Subtask 1 output (`soft-fork-subtask-isolation.md`)
- Load: `agents-skills-dev.instructions.md` (skill frontmatter reference)
- Create: `docs/guides/skill-context-lifecycle.md` (new doc for this subtask)
- Scope boundary: "Define skill loading/unloading patterns; reference soft-fork as parent pattern."

**Phase 2 — Execute**:

- Write: Skill activation contract (frontmatter, metadata)
- Write: Deactivation checklist
- Write: Anti-patterns (persistent payloads, cross-skill context bleed)
- Validate via agents-skills-dev.instructions.md

**Phase 3 — Deactivate**:

- Output: `docs/guides/skill-context-lifecycle.md` (saved)
- Clear: `agents-skills-dev.instructions.md` from active context
- Update ROUTER_SPINE:

    ```markdown
    ### Subtask 2: Skill Context Lifecycle ✓ Done
    - Output: docs/guides/skill-context-lifecycle.md
    - Cross-reference: Linked from soft-fork-subtask-isolation.md
    - Next: Subtask 3 — finalize escalation rules
    ```

**Phase 4 — Handoff Check**:

- Events: 280 (under 300 threshold)
- Quality: Output integrates cleanly with subtask 1
- Proceed to subtask 3 without compaction.

---

#### Subtask 3: Escalation Rules & Anti-Patterns

**Phase 1 — Activate**:

- Load: Subtask 1 & 2 outputs
- Create: Addendum section in `soft-fork-subtask-isolation.md` (this document)
- Scope boundary: "Add escalation table, anti-patterns, final validation."

**Phase 2 — Execute**:

- Write: Escalation decision table (signals and actions)
- Write: Anti-patterns checklist
- Add worked example to this document

**Phase 3 — Deactivate**:

- Output: Updated `soft-fork-subtask-isolation.md` (saved)
- Clear: Task context
- Update ROUTER_SPINE:

    ```markdown
    ### Subtask 3: Escalation & Anti-Patterns ✓ Done
    - Output: docs/operations/soft-fork-subtask-isolation.md (updated with sections 2–3)
    - Validation: All links and cross-refs verified
    - Status: Ready for PR
    ```

**Phase 4 — Final Checkpoint**:

- Session events: 310 (crossed 300 threshold)
- No hard-fork triggered (quality remained high)
- All artifacts saved
- PR ready to open

---

## Anti-Patterns

### 1. Cleanup-Driven Forking

**Anti-pattern**: "I'll create a new branch/session just to drop old context."

**Fix**: Use `/compact` or soft-fork's deactivation phase. Branching for cleanup is wasteful infrastructure churn.

### 2. Skill Payload Persistence

**Anti-pattern**: Leave all skills active across all subtasks to "avoid reloading."

**Fix**: Deactivate skills after each subtask. Re-load is cheap; carrying 5 active skills for 3 subtasks is expensive.

### 3. Silent Context Bleed

**Anti-pattern**: Subtask 2 quietly inherits subtask 1's docs without logging it in ROUTER_SPINE.

**Fix**: Explicitly record shared artifacts in ROUTER_SPINE's decision log.

### 4. Over-Scoped Soft-Fork

**Anti-pattern**: Try to fit 8 unrelated tasks into one soft-fork session to "save branches."

**Fix**: Use hard-fork (new session) after 5 subtasks or scope shift. Session inflation damages quality.

---

## Cost Observability & Validation

### Metrics to Track During Soft-Fork

| Metric | Target | Red Flag |
|--------|--------|----------|
| Events per subtask | <100 | >150 suggests context rot |
| Input/output ratio (input tokens per output token) | <200x | >300x escalates to hard-fork |
| Artifact count | 1–2 per subtask | >3 suggests scope creep |
| Skill load/unload pairs | 1:1 | Mismatch indicates payload persistence |
| ROUTER_SPINE updates | 3–4 per session | <1 suggests poor handoff hygiene |

### Validation Checklist

Before opening a PR for a soft-fork session:

- [ ] All subtask outputs saved to persistent paths
- [ ] ROUTER_SPINE documents dependencies and decision points
- [ ] No skill payloads persisted across subtask boundaries
- [ ] Escalation rule check: No hard-fork signals present
- [ ] Session events < 500; token ratio < 300x
- [ ] Cross-references validated (all linked artifacts exist)
- [ ] Artifacts merge-ready (no draft or WIP markers)

---

## Integration with Cost-Optimization Guidance

This pattern **complements** the five cost-optimization patterns in `.github/instructions/cost-optimization.instructions.md`:

| Pattern | Soft-Fork Role |
|---------|---|
| **Compact at phase transitions** | Use within subtask phases; escalate to hard-fork if compaction insufficient |
| **Reuse sprint templates** | ROUTER_SPINE acts as a reusable soft-fork template |
| **File references only** | Load per-subtask files, not pasted blocks |
| **Delegate scan/research** | Each subtask can delegate to background agents; re-aggregate in ROUTER_SPINE |
| **Model choice secondary** | Use cheaper models within subtasks; upshift only on quality red flags |

---

## References

- **Cost-Optimization Guidance**: `.github/instructions/cost-optimization.instructions.md`
- **Token Optimization**: `docs/guides/token-optimization.md`
- **Context-Rot Runbook**: `docs/operations/context-rot-runbook.md`
- **Skills Development**: `.github/instructions/agents-skills-dev.instructions.md`
- **Session-Per-Task (complementary pattern)**: `docs/operations/session-per-task.md`
