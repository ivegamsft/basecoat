---
issue: 3499
title: "Activate the repository-scoped native merge queue"
status: draft
author: ibuyspy
created: 2026-10-05
labels: ["governance", "priority:high"]
---

# PRD: Repository-scoped native queue activation

## Problem and outcome

Readiness PR #3506 adds merge-group checks to `main`. The repository still has
no native merge queue, so prepared stacked pull requests cannot enter GitHub's
serialized queue. This layer declares and safely deploys only the repository's
`main` queue ruleset; it does not alter the policy pack or merge executor.

## Scope

- Require the six current solo-dev `main.required_checks` contexts and the
  observed cloud-agent guard check.
- Add an active repository ruleset for `refs/heads/main` with no bypass actors,
  `ALLGREEN` grouping, squash, and one entry at a time.
- Provide read-only local validation, a live read-only preflight, explicit
  apply, snapshot-backed rollback, and focused regression tests.
- Preserve existing branch protections and organization/enterprise rulesets.

## Out of scope

- Changing `merge_queue_posture`, required approvals, the executor, or release
  and production gates.
- Directly merging pull requests or applying rulesets as part of this PR.
- Bypassing queue checks, organization/enterprise rules, or human review
  boundaries.

## Success criteria

1. The declared checks exactly match the six canonical solo-dev main checks and
   the cloud-agent check context observed from a successful GitHub Actions run.
2. Apply fails closed until #3506 and this declarative ruleset are merged,
   readiness workflows are on `main`,
   strict main protection still includes every current required status, and the
   observed cloud-agent check is successful.
3. Writes target only the named repository-owned ruleset; rollback refuses if
   the ruleset changed after apply.
4. Existing inherited review, signed-commit, status, and production controls are
   left untouched.
5. After parent authorization and apply, a queued pull request reports all
   required checks on its generated merge-group commit before delivery.

## References

- Readiness: [#3506](https://github.com/IBuySpy-Shared/basecoat/pull/3506)
- Source issue: [#3499](https://github.com/IBuySpy-Shared/basecoat/issues/3499)
- Spec: [Native queue activation contract](../../spec/synthesized/issue-3499-queue-activation.spec.md)
