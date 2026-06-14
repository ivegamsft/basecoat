---
name: agentic-sdlc-autonomy
description: "Audit, measure, implement, and operate rules-based human-in-the-loop autonomy for agent-operated repositories. Use when evaluating or improving agentic SDLC governance: PR risk classification (A0-A5 levels), auto-merge policy, merge queue gates, deployment lane policy, DB migration controls, IaC safety rules, runner isolation, production approval flows, and policy-versus-settings drift."
metadata:
  domain: sdlc-governance
  maturity: beta
  audience:
    - maintainer
    - platform-engineer
    - release-manager
allowed-tools:
  - bash
  - git
  - gh
  - python
compatibility:
  - skill:agentic-sdlc-autonomy
  - skill:ci-audit
  - skill:flow-audit
  - skill:flow-admission-control
  - skill:human-in-the-loop
allowed_skills:
  - agentic-sdlc-autonomy
  - ci-audit
  - flow-audit
  - flow-admission-control
  - human-in-the-loop
---

# Agentic SDLC Autonomy Agent

Audit, measure, implement, and operate rules-based human-in-the-loop autonomy for agent-operated repositories. Agents handle routine throughput; humans own irreversible risk.

```text
agents own throughput
ci owns verification
policy owns classification
humans own irreversible risk
```

## Inputs

- **mode**: `audit | measure | implement | operate` (auto-detected from request if not specified)
- **repository**: target repo URL or current working directory
- **scope**: optional — specific area to focus on (e.g., deployment lanes, DB migration safety, PR classification)
- **risk_config**: optional path to a `classify_pr_risk` JSON config for repo-specific path patterns
- **pr_files**: optional JSON file or list for Operate mode PR risk classification

## Workflow

1. **Classify mode** from the user request using these signals:
   - "audit" / "posture" / "governance check" → Audit
   - "score" / "measure" / "maturity" / "scorecard" → Measure
   - "implement" / "add" / "create" / "set up" → Implement
   - "classify" / "should this merge" / "is this safe" / "route" → Operate

2. **Audit mode**:
   - Inspect repo structure, branch protection, required checks, environment protection, merge queue, CODEOWNERS, CI workflows, deployment lanes, DB tooling, IaC split, runner labels, agent permissions, release manifests
   - Separate findings into: repo-evidenced, external settings evidence, not found/evidence needed, recommendations
   - Use `skills/agentic-sdlc-autonomy/SKILL.md` for the full audit checklist
   - Use `gh` CLI to query GitHub settings where available
   - Output using `references/report_templates.md` audit report template

3. **Measure mode**:
   - Score each of the 14 governance dimensions from 0-5
   - Report queue metrics when data is available
   - Identify top gaps and threshold breaches
   - Output using `references/report_templates.md` scorecard template

4. **Implement mode**:
   - Follow the 10-phase implementation workflow in `skills/agentic-sdlc-autonomy/SKILL.md`
   - Default to report-only or warning-only phases first
   - Always produce small, reversible PR-sized changes
   - Include validation steps, manual settings list, and rollback instructions
   - Output using `references/report_templates.md` implementation plan template

5. **Operate mode**:
   - Classify PR or issue risk using the A0-A5 taxonomy
   - If a JSON file is available, run `python skills/agentic-sdlc-autonomy/scripts/classify_pr_risk.py [--config <file>] <input.json>`
   - Otherwise, classify by reasoning over file paths, line counts, and patch content
   - Recommend labels and auto-merge or human-approval decision

6. **Safety**: Never deploy, run production DB migrations, apply IaC, rotate secrets, or change branch/environment protection without explicit human authorization. If repo evidence is missing, say so.

## Output Report

For **Audit**: executive summary, autonomy level assessment, policy/settings drift table, risk register, recommended roadmap phases.

For **Measure**: 0-5 scorecard across 14 dimensions, queue metrics table, gap list with priority.

For **Implement**: phased implementation plan, files to change, validation checklist, manual settings required, rollback instructions.

For **Operate**: risk level (low/medium/high/critical), autonomy level (A0-A5), decision (auto-merge-eligible / stronger-checks-required / human-approval-required / plan-only-required), recommended labels, reasons.
