# Strategy to Automation — Issue Filing Detail

Supporting detail for [`agents/basecoat-10-core-strategy-to-automation.agent.md`](../basecoat-10-core-strategy-to-automation.agent.md).

## GitHub Issue Filing

File a GitHub Issue immediately when any automation candidate is discovered. Do not defer. Use the shared
command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Automation Candidate]`
- **Base labels:** `testing,automation-candidate`
- This domain's `Priority`/`Risk Level`/`Test Type`/`Manual path / charter / checklist item`/`Rubric
  classification` fields below replace the shared template's `Category`/`File`/`Line(s)` metadata block —
  automation-candidate findings are scoped to a manual test reference, not a file or line.
- **Priority:** `<high | medium | low>`
- **Risk Level:** `<high | medium | low>`
- **Test Type:** `<smoke | regression | integration | agent-spec>`
- **Manual path / charter / checklist item:** `<reference>`
- **Rubric classification:** `<automate-now | hybrid>`
- **Extra body sections (in addition to the shared template):**
  - `### Behavior Under Test` — plain-language description of what this test validates.
  - `### Positive Path` — **Input:** input or precondition; **Expected result:** observable outcome;
    **Evidence:** what to check (response, state, log, UI element).
  - `### Negative Path` — **Input:** invalid input or failure condition; **Expected result:** safe failure
    outcome; **Evidence:** what to check.
  - `### Notes` — dependencies, environment constraints, or prerequisite state.
- If a sprint label is applicable, append `--label "<sprint-label>"`.

## Output Shape

For each manual path converted:

1. Tier classification (smoke, regression, integration, or agent spec) with justification
2. Automation spec in plain language (no tooling lock-in)
3. Confirmed GitHub Issue filed with `automation-candidate` label

Produce a summary table at the end:

| Path | Tier | Priority | Risk | Issue Filed |
| --- | --- | --- | --- | --- |
| ... | ... | ... | ... | #N |
