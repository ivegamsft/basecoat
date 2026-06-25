# Kept Pattern Runbook: File-Reference-Only Context

## Intent

Reduce prompt payload size and repeated context transmission by referencing files
instead of pasting large instruction or artifact blocks into chat.

## Prerequisites

- Relevant files are committed or otherwise available by path.
- The operator can provide short context plus explicit file pointers.
- Large artifacts are summarized into one canonical markdown file when needed.

## Default Procedure

1. Replace large pasted blocks with file pointers (for example, `See: path/file`).
2. Let the executing agent load the referenced files directly.
3. For large rich artifacts, create one canonical markdown summary and reuse it.
4. Keep user prompts delta-based and avoid repeating static boilerplate.

## Decision Points

| Condition | Action |
|---|---|
| Context block is large and static | Replace with path reference |
| Artifact is binary or very large | Create canonical markdown summary first |
| Repeated instructions across turns | Use short delta prompts only |

## Rollback

If a run fails due to missing context, add only the missing file references or a
targeted summary section. Avoid full-content paste fallback unless no file access
path is possible.

## Evidence to Capture

- Largest user-message payload size in the run.
- Count of reused file references vs pasted blocks.
- Token trend before and after adopting reference-only prompts.
