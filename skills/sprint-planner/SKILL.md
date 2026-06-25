---
name: sprint-planner
compatibility: [github-copilot-cli]
description: "Compatibility routing skill for sprint planning requests that resolve to skill(sprint-planner). USE FOR: sprint goal decomposition, wave/dependency planning, issue breakdown planning, and next-sprint commitment shaping. DO NOT USE FOR: implementing product code changes, CI/build remediation, or production incident response."
---
# Sprint Planner Skill

Use this skill as the compatibility surface for runtimes that invoke `skill(sprint-planner)`.

## Purpose

- Ensure `sprint-planner` is discoverable as a skill entrypoint.
- Route sprint planning tasks to the `@sprint-planner` agent workflow.
- Keep sprint decomposition behavior aligned with the existing planner agent,
  including milestone and GitHub Project tracking setup.

## Invocation

Use this skill when requests include sprint planning goals such as:

- "Break this sprint goal into issues and dependencies."
- "Plan the next sprint from backlog priorities."
- "Map work into waves with acceptance criteria."

## Delegation Pattern

1. Collect sprint scope, constraints, and success criteria.
2. Delegate decomposition to `@sprint-planner`.
3. Produce:
   - issue list with labels and owners,
   - sprint milestone and project board association for every issue,
   - dependency/wave map,
   - acceptance criteria per item,
   - carry-forward notes for blocked work.

## Related Assets

- Agent: `agents/basecoat-10-core-sprint-planner.agent.md`
- Skill: `skills/sprint-management/SKILL.md`
- Instruction: `instructions/basecoat-10-core-intent-routing.instructions.md`


