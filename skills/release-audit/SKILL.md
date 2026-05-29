---
name: release-audit
description: "Use when reviewing release readiness, changelog quality, version bumps, tags, or publish completeness. USE FOR: audit a release candidate, verify semver and changelog entries, check tag and release note completeness, review rollback readiness. DO NOT USE FOR: cutting the release, planning sprint work, debugging product bugs, deployment troubleshooting."
compatibility:
  editors:
    - vscode
  platforms:
    - github
metadata:
  category: "Uncategorized"
  tags: ["uncategorized"]
  maturity: "beta"
  audience: ["developers"]
allowed-tools: ["bash", "git", "grep", "find"]
---

# Release Audit Skill

Review release candidates for versioning, changelog quality, tagging, and publish completeness.

## USE FOR

- Auditing a release PR before merge
- Checking semver bumps against merged work
- Verifying changelog entries, release notes, and tag naming
- Confirming the release package or publish step is complete

## DO NOT USE FOR

- Cutting or publishing the release
- Planning sprint work or backlogs
- Debugging unrelated product defects
- Deployment troubleshooting after a release is live

## Workflow

1. Confirm the version bump matches the merged work.
2. Check changelog coverage, grouping, and link quality.
3. Verify tags, release notes, and artifact references.
4. Review rollback notes and publish completeness.
5. Report any missing release prerequisites with evidence.

## Output

Return:

- Release verdict: ready, ready with notes, or block
- Findings with severity and evidence
- Missing release checklist items
- Suggested fix or follow-up action

## Related Agent

Use with `release-manager` agent.
