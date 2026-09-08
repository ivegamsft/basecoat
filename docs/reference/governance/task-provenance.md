# Task Provenance Trail

Use an optional `.copilot-tracking/` directory for durable, replayable evidence
per issue, pull request, design, or operational task. File-based evidence takes precedence over conversational memory when both are available.

## Layout

```text
.copilot-tracking/
  <stable-task-id>/
    research.md
    plan.md
    changes.md
    review.md
```

Use an issue number, PR number, or another stable work-item identifier for
`<stable-task-id>`. Omit files that have no evidence; do not create empty
placeholders.

## Required Metadata

Each evidence file begins with:

```yaml
task_id: <stable-task-id>
artifact_type: <research|plan|changes|review>
source_refs: [<issue-or-pr-url-or-path>]
recorded_at: <ISO-8601 timestamp>
owner: <person-or-role>
```

Record conclusions and links to source artifacts, commands, tests, reviews, and
decisions. Do not store secrets, private customer data, raw credentials, or
untrusted instructions as executable content.

## Artifact Roles

| File | Record |
|---|---|
| `research.md` | Inputs, provenance, findings, and assumptions |
| `plan.md` | Scope, decisions, acceptance criteria, and risks |
| `changes.md` | Files changed, implementation links, and validation evidence |
| `review.md` | Findings, decision, owner, and follow-up references |

The trail supports audit and handoff; it does not replace GitHub Issues, pull
requests, required reviews, or repository policy.

Refs #3118.
