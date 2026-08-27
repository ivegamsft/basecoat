# Prompt Coach — Detail Reference

## Scoring Rubric

| Dimension | Question | 0 | 5 | 10 |
|---|---|---|---|---|
| Clarity | Is the intent unambiguous? | Goal is unclear or mixed | Main task is understandable but fuzzy in places | Goal and success criteria are explicit |
| Specificity | Are constraints and expectations explicit? | Few actionable constraints | Some constraints exist but gaps remain | Constraints, scope, and expectations are concrete |
| Structure | Is information organized for LLM consumption? | Disorganized wall of text | Some structure, but ordering is uneven | Well-ordered sections, bullets, and format cues |
| Token efficiency | Could the same intent be expressed more concisely? | Heavy filler or duplication | Some unnecessary wording remains | Concise with little or no wasted context |
| Completeness | Are edge cases and format requirements addressed? | Missing output needs and edge cases | Covers core case only | Covers edge cases, output contract, and boundaries |

## Common Anti-Patterns

| Anti-pattern | Why it hurts | Coaching response |
|---|---|---|
| "Be creative" without constraints | Produces broad, inconsistent outputs | Add audience, tone, length, and success constraints |
| Contradictory instructions such as "be brief" and "explain in detail" | Forces trade-offs the model cannot resolve cleanly | Ask the user to rank priorities or split the task |
| Missing output format | Model may answer in an unusable shape | Add explicit sections, schema, or bullet requirements |
| Excessive preamble | Wastes tokens and buries the real task | Trim background and move the task closer to the end |
| Negative-only instructions | Leaves the model unsure what good looks like | Pair prohibitions with positive guidance and examples |
| Role-play that conflicts with the task | Persona can override the actual objective | Remove or narrow the persona so it serves the task |

## Suggested Prompt Templates

### Task + Constraints + Output

Best for drafting, summarization, and transformation tasks.

- Task: what to do
- Context: essential background only
- Constraints: scope, tone, must-do and must-not-do rules
- Output: required structure, length, and formatting

### Evaluation Prompt

Best for critique, grading, or review workflows.

- Goal: what is being evaluated
- Rubric: criteria and scoring scale
- Evidence rule: cite the exact prompt text that triggered feedback
- Output: scorecard, findings, and recommended edits

### Extraction or Classification Prompt

Best for structured data tasks.

- Input definition
- Allowed labels or schema
- Decision rules and edge-case handling
- Output format with a strict example

### Iterative Refinement Prompt

Best when the user wants a coach instead of a one-shot rewrite.

- Assess the current prompt
- Identify the top 2-3 improvements
- Explain the rationale
- Propose a revised version
- Rescore and summarize the delta

## Example: Scoring a Prompt

Given this input prompt:

```text
Write a summary of the document.
```

The coach produces a scorecard:

```markdown
| Dimension        | Score | Notes                                  |
|------------------|-------|----------------------------------------|
| Clarity          | 3     | "Document" is ambiguous — which one?   |
| Specificity      | 2     | No length, audience, or format target  |
| Structure        | 4     | Single sentence, no sections           |
| Token efficiency | 8     | Very concise                           |
| Completeness     | 2     | No output format or edge-case handling |
| **Total**        | **19/50** |                                    |
```

Top improvement: add the document reference, target audience, desired length, and output format.

## Before and After Comparison

When presenting a revision:

1. Show the original prompt or the relevant excerpt.
2. Show the revised prompt.
3. Summarize expected gains in a short delta table.
4. Call out any trade-offs, such as added specificity increasing token count.

Use this delta format:

| Dimension | Before | After | Why it improved |
|---|---|---|---|
| Clarity | 5 | 8 | Task and audience were made explicit |
| Specificity | 4 | 8 | Added format and constraint details |

## Working Style

- Be interactive and iterative.
- Assume users are learning prompt design, not just asking for a rewrite.
- Teach reusable patterns the user can apply to future prompts.
- If a prompt is fundamentally underspecified, ask for the smallest missing detail set before rescoring.
- Stop iterating when gains become marginal or the user says the prompt is good enough.

## Repository Integrations

- Review agent, instruction, prompt, or skill files in this repository for prompt quality issues.
- Pair with `instructions/basecoat-50-security-token-economics.instructions.md` when token budget awareness matters.
- When a prompt registry workflow exists, hand off optimized prompts for versioning and comparison across revisions.
