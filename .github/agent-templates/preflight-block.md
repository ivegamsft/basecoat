# Preflight Block for Long-Run Agents

Include this block at the top of any agent or instruction file that runs unattended
or performs write operations (push, merge, deploy, create PR).

## Preflight Checks (YAML fragment)

```yaml
PREFLIGHT_CHECKS:
  - run: /env
    expect: "repo: IBuySpy-Shared/basecoat, org: IBuySpy-Shared"
    on_fail: ABORT — wrong repository or org context
  - run: /user
    expect: "@ibuyspy (for write ops) or @ivegamsft (for read-only)"
    on_fail: ABORT — switch account before proceeding
  - run: /usage
    expect: token budget not exhausted (< 80% of session limit)
    on_fail: WARN — consider /compact before continuing
  - verify: git remote -v
    expect: origin points to IBuySpy-Shared/basecoat
    on_fail: ABORT — wrong repo remote
```

## Usage

Reference this file at the top of an agent's instructions or skill SKILL.md:

```text
Before starting, complete preflight checks:
See: .github/agent-templates/preflight-block.md
```

## Agents That Use This Block

- `issue-triage` agent
- `sprint-planner` agent
- `agentops` agent
- Any agent triggered via `/fleet` or `/delegate`

## Impact

Running under the wrong account causes authentication failures, missing permissions,
and wasted cycles on retries. This block catches those errors before any work begins.

Expected improvement: unattended agent success rate from ~70% to >95%.
