# Agentic SDLC Autonomy — Mode Workflow Detail

Supporting detail for [`agents/agentic-sdlc-autonomy.agent.md`](../agentic-sdlc-autonomy.agent.md).

## Audit mode

- Inspect repo structure, branch protection, required checks, environment protection, merge queue, CODEOWNERS, CI
  workflows, deployment lanes, DB tooling, IaC split, runner labels, agent permissions, release manifests
- Separate findings into: repo-evidenced, external settings evidence, not found/evidence needed, recommendations
- Use `skills/agentic-sdlc-autonomy/SKILL.md` for the full audit checklist
- Use `gh` CLI to query GitHub settings where available
- Output using `skills/agentic-sdlc-autonomy/references/report_templates.md` audit report template

## Measure mode

- Score each of the 14 governance dimensions from 0-5
- Report queue metrics when data is available
- Identify top gaps and threshold breaches
- Output using `skills/agentic-sdlc-autonomy/references/report_templates.md` scorecard template

## Implement mode

- Follow the 10-phase implementation workflow in `skills/agentic-sdlc-autonomy/SKILL.md`
- Default to report-only or warning-only phases first
- Always produce small, reversible PR-sized changes
- Include validation steps, manual settings list, and rollback instructions
- Output using `skills/agentic-sdlc-autonomy/references/report_templates.md` implementation plan template

## Output Report

For **Audit**: executive summary, autonomy level assessment, policy/settings drift table, risk register, recommended
roadmap phases.

For **Measure**: 0-5 scorecard across 14 dimensions, queue metrics table, gap list with priority.

For **Implement**: phased implementation plan, files to change, validation checklist, manual settings required,
rollback instructions.
