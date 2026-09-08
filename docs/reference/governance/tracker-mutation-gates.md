# Tracker Mutation Gates

Apply this contract before writing GitHub issues, pull requests, labels,
milestones, assignees, project fields, or project status.

## Autonomy Tiers

| Tier | Rule |
|---|---|
| `read-only` | Inspect and summarize only |
| `routine-write` | Reversible deterministic comment or label with current attributable evidence |
| `acknowledgement-gated` | Requires explicit maintainer or issue-owner acknowledgement |
| `human-review-gated` | Requires human approval for the specific mutation or repository policy |

## Default Matrix

| Mutation class | Tier | Gate |
|---|---|---|
| Deterministic progress comment or label | `routine-write` | Current signal and policy |
| Remove blocker, risk, or `needs-*` label | `acknowledgement-gated` | Acknowledgement or workflow-owned resolution evidence |
| Close/reopen issue; change priority, risk, owner, or project state | `human-review-gated` | Human confirmation or explicit repository policy |
| Mark PR ready, approve, merge, or change merge intent | `human-review-gated` | Merge policy and required review |

Do not silently downgrade a mutation to a less restrictive tier.

## Decision Record

```text
mutation_class: <comment|label|state|project|merge-intent>
target: <issue-or-pr-url>
autonomy_tier: <read-only|routine-write|acknowledgement-gated|human-review-gated>
gate_required: <none|maintainer-ack|human-review|repo-policy>
gate_source: <comment-url|review-url|workflow-input|policy-path>
decision: <write|block|draft-only>
reason: <short explanation>
```

For any gated write with no verifiable `gate_source`, select `block` or
`draft-only`. Missing permission, acknowledgement, review, fresh target state,
or unambiguous intent must stop the write. Refresh stale state once, then block
if it changed. Read-only analysis and draft planning remain allowed.

Refs #3119.
