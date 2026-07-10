# Token Economics — Context Routing Reference

## Context Loading Priority Order

Load context in this order — stop when the task is sufficiently specified:

1. `copilot-instructions.md` or equivalent always-on rules (L0/L1)
2. Glob-scoped instructions matching the current file type or path (L1)
3. Cached pattern from L2 hot index if confidence ≥ 0.80 (L2)
4. Prior session coverage via `store_memory` recall (L3)
5. Long-form reference docs, architecture ADRs (L4)

Never load all tiers speculatively. Fetch only until the task is answerable.

## Context Loading Discipline

- Load only what is needed for the current task.
- Reuse context already loaded in the session when it is still current.
- Prefer incremental reads over repeated full-file reads.
- Summarize large context before handing it to a higher-tier model.
- Break broad work into smaller steps when doing so reduces total token spend.
- Prefer the cheapest model tier that can complete the task reliably.

## Fast Path (L2 Hit)

If the L2 pattern bundle matches with confidence ≥ 0.80:

- Execute the pattern directly without loading full L3/L4 context
- Use the turn budget from the bundle catalog
- Do not re-read files already loaded in the session

## Full HRM Traversal (No L2 Hit)

If confidence < 0.80 after TRM Pass 2:

- Emit an `EscalationQuery` to L3 (see `instructions/basecoat-10-core-memory-index.instructions.md`)
- If L3 has no coverage, proceed to L4 — read reference docs targeted to the task
- If L4 has no coverage, this is a Novel task — state it, estimate turn budget, proceed

## Context Handoff Patterns

- Compress context before handing off to a sub-agent (keep < 2,000 tokens in the handoff)
- Include only: task description, current state, blockers, files touched so far
- Do not re-attach large reference docs — let the sub-agent load them as needed
