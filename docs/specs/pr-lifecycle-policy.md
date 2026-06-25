# PR Lifecycle Execution Policy

## Objective

Define a single policy contract for PR lifecycle behavior across intent routing so feature execution can run in predictable `none`, `standard`, or `full` modes.

## Policy Modes

| Mode | Primary behavior | Safety contract |
|---|---|---|
| `none` | No PR lifecycle automation; work can stay local or branch-only | Do not create, update, merge, or clean PR-linked branches automatically |
| `standard` | Single-PR default workflow for implementation requests | Allow create or update PR flow, but defer full closeout and cleanup automation |
| `full` | End-to-end PR lifecycle with merge and cleanup governance | Require merge readiness and only permit cleanup for merged or explicitly closed PRs |

## Intent Parsing Contract

The `pr-lifecycle=<none|standard|full>` modifier is first-class for implementation intents and is not limited to `pr:` routing.

### Feature intent behavior

1. Parse `pr-lifecycle` in `feature:` messages as an explicit lifecycle override.
2. Accept only `none`, `standard`, or `full`.
3. If `feature:` text contains PR language but omits `pr-lifecycle`, default to `standard`.
4. If no PR language is present and no modifier is provided, no PR lifecycle policy is inferred.

PR language examples include phrases such as:

- create a PR
- open a pull request
- merge after checks
- include PR lifecycle

### PR intent behavior

`pr:` remains an authoritative routing prefix. When combined with `pr-lifecycle`, apply the same enum contract while keeping PR-state-driven cleanup rules.

## Rules vs Actions Execution Contract

| Concern | Rules | Actions |
|---|---|---|
| Label and metadata normalization | Preferred | Not required |
| Required-check and merge-readiness evaluation | Not sufficient | Required |
| Branch cleanup safety checks | Not sufficient | Required |
| Portfolio rollup reporting | Not sufficient | Required |

## Default and Error Handling

| Condition | Expected result |
|---|---|
| `pr-lifecycle` value in allowed enum | Route with selected lifecycle mode |
| Invalid value (for example `pr-lifecycle=fast`) | Fail routing with explicit allowed-value guidance |
| `feature:` with PR language and no modifier | Route with `pr-lifecycle=standard` |
| `feature:` with no PR language and no modifier | No lifecycle mode inferred |

## Merge and Cleanup Guardrails

1. Merge operations require required-check readiness and policy gate satisfaction.
2. Cleanup actions run only after merged or explicitly closed PR status is confirmed.
3. Any waived control must include reason, owner, and expiry evidence.
