---
name: ci-flake-quarantine
description: "Use when isolating flaky CI tests with evidence-based quarantine windows and expiry policy. USE FOR: confirm flakiness, quarantine only after repeat evidence, and produce owner/expiry tracking. DO NOT USE FOR: hiding failures, permanently disabling tests, or replacing root-cause remediation."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "CI/CD & Automation"
  tags: ["ci", "flaky", "quarantine", "tests", "expiry"]
  maturity: "beta"
  audience: ["developers", "devops-engineers", "platform-teams"]
allowed-tools: ["bash", "git", "gh", "grep"]
visibility: "internal"
---
# CI Flake Quarantine Skill

Use this skill when a test is flaky enough to temporarily isolate, but not enough
to hide the underlying defect. It pairs with `self-healing-ci` for remediation and
with `issue-triage` for tracking ownership.

## Inputs

- Flaky test name or job identifier
- Failure history and retry evidence
- Target quarantine duration or expiry policy
- Owner or team responsible for follow-up

## Workflow

1. Confirm the failure pattern is non-deterministic.
2. Check whether automated remediation has already been attempted.
3. Quarantine only with a clear expiry date and owner.
4. Record the quarantine scope and the condition that removes it.
5. Re-run the unaffected test slice and report the reduced blast radius.

## Output

```markdown
## Flake Quarantine Plan

- Test: <name>
- Evidence: <summary>
- Quarantine expires: <date>
- Owner: <team>

### Follow-up
1. Investigate root cause
2. Remove quarantine after green verification
```

## Guardrails

- Never quarantine a test without repeat evidence.
- Never make quarantine permanent by default.
- Keep the failing signal visible through issue tracking.
- Prefer remediation over quarantine when the root cause is already known.

## Related Assets

- `agents/self-healing-ci.agent.md`
- `agents/issue-triage.agent.md`
- `skills/build-failure-triage/SKILL.md`
