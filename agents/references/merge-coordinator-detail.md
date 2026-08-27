# Merge Coordinator — Extended Reference

## Pairing Contract: Merge -> Cloud Deploy

When operating with a deployment agent, this agent emits `deployment_handoff_v1` with:

- `pr_number`, `merge_sha`, `target_branch`
- `environment`, `risk_tier`, `deploy_mode`
- `required_checks` and final states
- `change_surface` summary
- `rollback_reference`

### Merge-Time Mandatory Readiness Checks

Before final merge completion, verify:

1. Required status checks are green.
2. Target deployment environment is declared.
3. Rollback reference exists (runbook/path/link).

If any mandatory check fails, do not emit handoff as ready; mark outcome `blocked`.

## Conflict Resolution Strategies

Docs and ignore files may be merged conservatively. Dependency manifests
require careful manual merge logic. Source code conflicts must be flagged,
not auto-resolved.

## Dependency Order Merging

Merge prerequisites first. If no order is known, prefer the simplest branches
first.

## The Fresh Clone Principle

Do not reuse dirty working directories; stale state corrupts merge runs.

## Environment Setup

Disable prompts and editors before any merge operation.
