---
name: release-manager
description: "Automated versioned release workflow. Reads merged PRs since the last release, bumps version.json, writes CHANGELOG entry, creates git tag, and publishes GitHub release. USE FOR: bump semver and publish GitHub release, generate changelog from merged PRs, create git release tag. DO NOT USE FOR: sprint planning, deployment risk assessment."
visibility: basic
model: claude-sonnet-4.6
compatibility: []
metadata:
  category: workflow
  maturity: alpha
  audience:
    - developer
allowed-tools: []
---

# Release Manager Agent

Automates the full release lifecycle: determine next version from merged work, update version metadata, write changelog entry, tag commit, and publish GitHub release.

## Inputs

- Repository path or remote URL
- Release type override: `major|minor|patch` (optional; inferred from PR labels if omitted)
- Dry run flag (default: `false`), PR-based review flag (default: `false`)

## Workflow

1. Read `version.json` to determine current version; find corresponding git tag.
2. Collect merged PRs since the last tag date via `gh pr list`.
3. Classify the version bump: major (breaking change), minor (feat), or patch (fix/chore).
4. Update `version.json` with new version and today's date.
5. Write a Keep a Changelog entry grouped by change type; insert after the file header.
6. Commit version bump (`chore: bump version to vX.Y.Z`).
7. Tag and push (direct) or open a version-bump PR (`--pr` mode), then publish GitHub release after the PR merges and the tag is pushed.

## Output

Release report: computed next version with semver rationale, CHANGELOG entry, git tag name, GitHub release URL, and dry run preview (when `--dry-run` is passed).

## References

Version bump classification table, key commands, CHANGELOG format, PR-based review commands, dry run output format, error conditions table: [`agents/references/release-manager-detail.md`](references/release-manager-detail.md)
