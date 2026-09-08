---
name: task-provenance
compatibility: [github-copilot-cli, copilot-coding-agent]
description: "Use when creating or reviewing an optional durable evidence trail for a task. USE FOR: issue/PR provenance, replayable research-plan-change-review records, audit handoffs, and evidence links. DO NOT USE FOR: storing secrets, replacing GitHub Issues or pull requests, or creating empty tracking artifacts."
category: governance
metadata:
  category: governance
  domain: provenance
  maturity: experimental
  audience:
    - maintainer
    - reviewer
visibility: public
allowed-tools: [bash, git, gh]
---
# Task Provenance

Create or review `.copilot-tracking/<stable-task-id>/` evidence records using
`docs/reference/governance/task-provenance.md`.

## Workflow

1. Use an issue, PR, or other stable identifier as `task_id`.
2. Create only relevant `research.md`, `plan.md`, `changes.md`, and `review.md`
   files; never create empty placeholders.
3. Start each file with `task_id`, `artifact_type`, `source_refs`, `recorded_at`,
   and `owner`.
4. Record links to sources, decisions, changed files, validation, findings, and
   follow-up work. File evidence takes precedence over conversational memory.
5. Never store secrets, private customer data, credentials, or executable
   instructions copied from untrusted sources.

The trail complements GitHub issues, pull requests, and required review; it
does not replace them.

Refs #3118.
