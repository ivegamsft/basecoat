# Exploratory Charter — GitHub Issue Filing Detail

Supporting detail for [`agents/basecoat-10-core-exploratory-charter.agent.md`](../basecoat-10-core-exploratory-charter.agent.md).

File a GitHub Issue immediately when a finding is a strong automation candidate. Do not defer. Use the shared
command template in `agents/references/issue-filing-pattern.md` with:

- **Title prefix:** `[Automation Candidate]`
- **Base labels:** `testing,automation-candidate`
- **This domain's `Priority`/`Risk Level`/`Test Type` fields below replace the shared template's
  `Category`/`File`/`Line(s)` metadata block** — exploratory charter findings are scoped to a session, not a file
  or line. The shared template's `### Description` and `### Acceptance Criteria` sections are still used as-is.
- **Priority:** `<high | medium | low>`
- **Risk Level:** `<high | medium | low>`
- **Test Type:** `<smoke | regression | integration | exploratory>`
- **Extra body sections (in addition to the shared template):**
  - `### Charter Reference` — **Mission:** `<charter mission statement>`; **Session date / time box:** `<date and
    duration>`; **Finding:** `<what was observed>`.
  - `### Notes` — reproduction steps summary, environment, or any prerequisite state.
- If a sprint label is applicable, append `--label "<sprint-label>"`.
