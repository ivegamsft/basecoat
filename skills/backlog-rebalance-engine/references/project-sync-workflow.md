# Project Sync Workflow

## Overview

The project-sync capability onboards mapped work items into GitHub Project boards and keeps
item status aligned with the rebalance plan. All operations are idempotent: re-running against
the same issue list produces no net changes.

## 1) Resolve Target Project

Identify the GitHub Project (v2) to sync into.

```bash
gh project list --owner <org-or-user> --format json \
  | jq '.projects[] | select(.title | test("<project-title>"))'
```

Record the numeric project ID (`projectId`) for subsequent GraphQL calls.

## 2) Fetch Current Project Items

Pull the full item list from the board before writing anything. This is the idempotency
reference snapshot.

```bash
gh project item-list <projectId> --owner <org-or-user> --format json --limit 500
```

Build a lookup map keyed by content URL (issue URL) to detect existing items.

## 3) Resolve Rebalance Issue List

Collect issues targeted by the rebalance plan. Common sources:

- Output of the `backlog-burndown` skill.
- `gh issue list` filtered by sprint/wave labels.
- A saved issue-number list from a prior rebalance run.

```bash
gh issue list --repo <owner/repo> --label "sprint:<n>" --state open --json number,url,title,state
```

## 4) Validate Metadata Mutation Policy

Before applying any write:

1. Validate target labels (global arguments and item-level overrides):
   - `priority:(critical|high|medium|low)`
   - `sprint:<number>`
   - `wave:<number>`
2. Build a deterministic mutation plan per issue:
   - compare existing label families to target values
   - decide **replace** (remove family labels + add target) or **skip**
3. If freeze-window mode is active and metadata label changes are planned, block the run unless an
   explicit freeze override flag is set.

## 5) Classify Each Issue

For each issue in the rebalance list, classify against the current board snapshot:

| Classification | Condition |
|---|---|
| **add** | Issue URL not found in board snapshot |
| **update** | Issue URL found; board status differs from expected status |
| **skip** | Issue URL found; board status already matches expected status |

Expected status mapping:

| Issue state | Expected board status |
|---|---|
| `OPEN` | `Todo` |
| `CLOSED` | `Done` |

## 6) Apply Changes (Add / Update / Metadata Mutation)

### Add a new item

```bash
gh project item-add <projectId> --owner <org-or-user> --url <issue-url>
```

### Update item status

Use the GraphQL `updateProjectV2ItemFieldValue` mutation with the `Status` field.

```bash
gh api graphql -f query='
  mutation UpdateStatus($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $projectId,
      itemId: $itemId,
      fieldId: $fieldId,
      value: { singleSelectOptionId: $optionId }
    }) {
      projectV2Item { id }
    }
  }
' -f projectId="$PROJECT_NODE_ID" -f itemId="$ITEM_ID" \
  -f fieldId="$STATUS_FIELD_ID" -f optionId="$OPTION_ID"
```

### Update delivery metadata labels

For each metadata family (`priority`, `sprint`, `wave`) with a target:

1. Remove existing labels in that family.
2. Add the target label.
3. Emit reason code `METADATA_MUTATION_<FAMILY>`.

## 7) Freeze-Window Guardrail

When freeze mode is enabled, metadata label mutations are blocked unless an explicit override is
provided. The run exits non-zero with reason code `POLICY_FREEZE_WINDOW_BLOCK`.

## 8) Emit Sync Report and Change Log

After processing all items, emit a structured report:

```text
Sync complete: added=<n> updated=<n> skipped=<n>
```

Followed by a per-classification breakdown if any items were added or updated:

```text
Added items:
  #<number>  <title>

Updated items:
  #<number>  <title>  (<old-status> -> <new-status>)
```

If all items were skipped, emit:

```text
Sync complete: added=0 updated=0 skipped=<n>
No changes required -- board is already aligned with rebalance plan.
```

Additionally, emit a JSON change log with per-item reason codes and planned/applied mutations.

## 9) Rollback Artifact

Generate one rollback artifact per run (JSON), including inverse operations for every applied
mutation:

- project item add -> delete item
- status update -> restore previous status option
- label remove -> add label back
- label add -> remove label

## 10) Idempotency Guarantee

A second run on an unchanged issue list must produce `added=0 updated=0`.
The snapshot-before-write pattern in step 2 enforces this guarantee without additional flags.

## Error Handling

| Condition | Action |
|---|---|
| Project not found | Exit non-zero with message "Project not found: TITLE" |
| Issue already in project (add race) | Catch duplicate error; count as `skipped` |
| Status field option not found | Exit non-zero with message "Status option not found: NAME" |
| Invalid metadata target label | Exit non-zero with reason code `POLICY_INVALID_TARGET_LABEL` |
| Freeze-window block | Exit non-zero with reason code `POLICY_FREEZE_WINDOW_BLOCK` |
| Rate limit hit | Back off 10 s and retry up to 3 times |
