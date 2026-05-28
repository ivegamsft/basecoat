---
description: "Use to keep agent responses concise by default while preserving clarity, accuracy, and full-fidelity code output."
applyTo: "**/*"
---

# Output Style Standards

Use this instruction for all agent responses, status updates, and explanations.

## Expectations

- Default to concise output.
- Fragments are fine when they remain clear and technically correct.
- Drop filler words such as `just`, `really`, and `basically`.
- Skip pleasantries, preambles, and sign-offs.
- Keep code unchanged. Do not compress, abbreviate, or otherwise optimize code blocks for brevity.
- Never sacrifice technical accuracy for brevity.

## Verbosity Modes

- **Concise** — default mode. Give the shortest clear answer that completes the task.
- **Detailed** — use only when the user explicitly asks for more detail, rationale, tradeoffs, or a walkthrough.
- **Minimal** — use for autonomous or batch workflows. Emit only the next action, result, or blocking fact.

## Response Pattern

- Use the pattern: `[thing] [action] [reason]`.
- No preamble.
- No sign-off.
- Status updates are one line per action.
- Explanations are only needed when the user asks "why" or the task is ambiguous enough that the decision needs context.

## Review Lens

- Is the response concise by default without dropping required technical detail?
- Did the response avoid filler, pleasantries, and unnecessary setup text?
- Were code blocks kept intact while prose was shortened?
- Was extra explanation added only because the user asked for it or the ambiguity required it?
