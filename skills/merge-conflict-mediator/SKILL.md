---
name: merge-conflict-mediator
compatibility: [github-copilot-cli]
description: "Use when a merge conflict needs a deterministic playbook for docs, config, manifests, or release artifacts. USE FOR: classify conflict types, choose a merge policy, and hand a resolution plan to merge-coordinator. DO NOT USE FOR: auto-resolving source code conflicts, silently dropping dependency changes, or bypassing human review."
category: development

visibility: public
metadata:
  category: development
  maturity: stable
  audience:
    - developer
allowed-tools: []
---
# Merge Conflict Mediator Skill

Use this skill to standardize conflict resolution decisions before `merge-coordinator`
applies them. It is intentionally conservative: if the policy is unclear, escalate.

## Inputs

- Conflict list and file paths
- Merge policy or precedence rule
- File type context (docs, config, manifest, lockfile, source)
- Optional branch freeze or release window context

## Workflow

1. Classify each conflicted file by type and risk.
2. Apply a deterministic resolution rule for low-risk file types.
3. Regenerate lockfiles or manifests only when the root inputs are known-good.
4. Escalate source-code conflicts and ambiguous merges to a human.
5. Produce a file-by-file conflict playbook for `merge-coordinator`.

## Output

```markdown
## Conflict Playbook

| File | Type | Policy | Decision |
|---|---|---|---|
| README.md | docs | merge unique sections | auto-resolve |
| package-lock.json | lockfile | regenerate from root manifest | auto-resolve |
| src/app.ts | source | manual review | escalate |
```

## PR Conflict Recovery

PR conflict routing automation labels open PRs with `mergeable_state=dirty` as `needs-conflict-fix`
and comments an agent instruction. The agent:

1. Use an isolated worktree on the PR branch; merge base into it.
2. Take the base version of `asset-manifest.json` and regenerate it with
   `pwsh scripts/generate-asset-manifest.ps1`; never hand-edit it.
3. Merge docs and config keeping both sides; hand ambiguous source conflicts to
   `merge-coordinator`.
4. Push with an attributed commit so the merge executor re-evaluates the new head.
5. Never bypass required checks, size:XXL approval, or no-merge holds.

## Guardrails

- Never silently discard dependency changes.
- Never auto-resolve source code or generated code without a policy.
- Preserve both sides of docs/config changes whenever possible.
- Escalate if the policy would violate a freeze or branch gate.

## Related Assets

- `agents/basecoat-10-core-merge-coordinator.agent.md`
- `agents/basecoat-60-workflow-release-freeze-enforcer.agent.md`
- `skills/orphaned-pr-triage/SKILL.md`
