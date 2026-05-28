# VS Code Harness Context Assembly Contract

## Purpose

This contract defines deterministic prompt-context assembly for VS Code harness runs, including source ordering, truncation behavior, and tie-break rules.

Use this document when changing prompt assembly, compaction, or transcript retention logic.

## Deterministic assembly order

The harness must assemble context in this exact order:

1. **System instruction layer**
   - Platform/system instruction
   - Harness-level runtime policy and guardrails
2. **Developer instruction layer**
   - Repository and task-scoped developer instructions
3. **Tool contract layer**
   - Tool registry metadata and callable schemas
4. **Workspace metadata layer**
   - Repository root, branch, environment and runtime capabilities
5. **User conversation layer**
   - Chronological user and assistant turns from oldest to newest
6. **Tool transcript layer**
   - Tool calls and tool results, grouped by round and ordered chronologically
7. **Memory and retrieval layer**
   - Retrieved memory entries and scoped supporting context
8. **Active request layer**
   - Latest user request and explicit constraints for the current turn

If a source appears in multiple layers, the earliest layer in this list has priority.

## Truncation and compaction policy

Compaction is allowed only at round boundaries.

Compaction must trigger when any trigger in [Agent Testing Harness](./AGENT_TESTING_HARNESS.md#context-compaction-and-preservation-guarantees) is met.

When compaction runs, these items are **non-droppable** and must remain verbatim:

- System instruction layer
- Developer instruction layer
- Latest user request and explicit constraints
- Final assistant outputs from the two most recent turns
- Tool calls and results from the four most recent rounds
- Active budget counters (turns, rounds, tool calls, retries, elapsed time)

All remaining history is compacted in this order:

1. Drop oldest compactable tool transcripts first.
2. Replace older user/assistant turns with summaries, oldest-first.
3. Further compress summaries while preserving unresolved constraints and open intents.

## Tie-break and conflict rules

If truncation pressure requires choosing between candidates with equal priority:

1. Preserve newer content over older content.
2. Preserve content with unresolved constraints over resolved content.
3. Preserve content with tool provenance over content without provenance.
4. Preserve user-authored constraints over assistant-authored elaborations.

## Behavioral guarantees

- Compaction must be deterministic for identical inputs and configuration.
- Two identical runs must produce identical retained context blocks after compaction.
- No in-flight tool result may be dropped before it is appended and visible to the next turn.

## Verification checklist for assembly logic changes

When prompt assembly logic changes, verify all of the following:

- Assembly order still matches the deterministic contract above.
- Non-droppable fields remain verbatim after compaction.
- Tie-break behavior is deterministic and stable across repeated runs.
- Benchmark and behavioral harness docs remain consistent with this contract.
- Eval or benchmark evidence is attached for any threshold or retention change.

## Related harness docs

- [Agent Testing Harness](./AGENT_TESTING_HARNESS.md)
- [Behavioral Evaluation (Phase 1)](./BEHAVIORAL_EVAL.md)
- [VS Code Harness Benchmarks](./VS_CODE_HARNESS_BENCHMARKS.md)
