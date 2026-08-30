# Prompt Engineer Agent — Detail Reference

Full patterns and standards for `agents/basecoat-10-core-prompt-engineer.agent.md`.

## Prompt Structure Patterns

- **Role-Task-Format (RTF)** — assign a role, describe the task, specify the output format. Best for straightforward single-turn prompts.
- **Context-Instruction-Example-Constraint (CIEC)** — provide context first, then instructions, then examples, then constraints. Use when the model needs background knowledge.
- **Persona-then-rules** — open with a persona definition, follow with behavioral rules. Effective for agents that must maintain a consistent voice.
- Always place the most important constraint closest to the end of the prompt — models attend more strongly to recent tokens.
- Use markdown structure (headings, lists, fenced blocks) to create visual separation that models can parse reliably.

## Few-Shot Example Design

- Include 2–5 examples that cover the representative range of inputs.
- Each example should demonstrate both the input format and the expected output format.
- Include at least one edge case or boundary condition.
- Label examples explicitly: `### Example 1: <scenario name>`.
- Keep examples concise — they consume context window. Trim to the minimum that demonstrates the pattern.
- Place examples after instructions but before constraints so the model sees the pattern before the guardrails.

## Chain-of-Thought Guidance

- Use chain-of-thought when the task requires multi-step reasoning, math, or logical deduction.
- Add an explicit instruction: "Think step by step before answering."
- For complex tasks, provide a worked example that shows the reasoning trace.
- Consider "think aloud then answer" format: reasoning in a `<thinking>` block, final answer outside it.
- Avoid chain-of-thought for simple retrieval or formatting tasks — it wastes tokens without improving accuracy.

## System Prompt Design

- System prompts set behavioral boundaries — they are not suggestions, they are rules.
- Open with identity and purpose: "You are X. Your job is to Y."
- Follow with hard constraints: what the agent must never do, always do, and how to handle ambiguity.
- Define the output contract: format, length, structure, and any required metadata.
- Include fallback behavior: what to do when input is ambiguous, out of scope, or adversarial.
- Keep system prompts under 1,500 tokens when possible — every system token competes with user context.

## Token Optimization

- Replace verbose phrases with concise equivalents: "You should make sure to" → "Ensure".
- Use structured formats (tables, YAML, lists) instead of prose paragraphs for rules and constraints.
- Deduplicate instructions that appear in multiple sections.
- Move static reference data (error catalogs, schemas) into tool calls or retrieval rather than embedding in the prompt.
- Measure token count before and after optimization. Target ≥20 % reduction on first pass.
- Never sacrifice clarity for brevity — an ambiguous short prompt is worse than a clear long one.

## A/B Testing Prompts

- Define a clear evaluation metric before testing (accuracy, format compliance, tone, latency).
- Test one variable at a time: structure, examples, constraints, or model parameters.
- Use a fixed evaluation set of ≥20 diverse inputs for consistency.
- Record results in a structured format: prompt version, metric scores, failure cases.
- Promote the winning variant and archive the loser with its test results for future reference.

## Prompt Versioning

- Version prompts with semantic versioning: `MAJOR.MINOR.PATCH`.
- `MAJOR` — behavioral change (different output structure, new constraints that alter results).
- `MINOR` — refinement (better examples, improved clarity, no behavioral change).
- `PATCH` — cosmetic (typo fixes, formatting).
- Store prompt versions in a changelog or version-controlled file alongside the prompt.
- Tag each version with: date, author, rationale, and test results summary.

## GitHub Issue Filing

File a GitHub Issue immediately when any of the following are discovered. Do not defer. Use the shared command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Prompt Engineering]`
- **Base labels:** `prompt-engineering,tech-debt`
- **Category options:** `<ambiguous instruction | token waste | missing constraint | untested edge case | version drift>`
- **File:** `<path/to/file.ext>`

| Finding | Labels |
|---|---|
| Prompt produces inconsistent outputs on similar inputs | `prompt-engineering,tech-debt` |
| System prompt exceeds 2,000 tokens without justification | `prompt-engineering,optimization` |
| Missing few-shot examples for a complex task | `prompt-engineering,tech-debt` |
| Prompt version deployed without test results | `prompt-engineering,quality` |
| Constraint contradiction between system prompt and agent instructions | `prompt-engineering,tech-debt` |
