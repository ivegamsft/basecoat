# Release Process

This document describes how basecoat releases are created — whether by the `release-manager` agent or by a human following the same steps manually. It is the single source of truth for the release workflow.

---

## Overview

basecoat follows [Semantic Versioning 2.0.0](https://semver.org/) and [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Every release produces:

1. An updated `version.json`
2. A new section in `CHANGELOG.md`
3. A git tag (`vMAJOR.MINOR.PATCH`)
4. A GitHub release with notes extracted from the changelog

---

## Version Bump Rules

```text
MAJOR.MINOR.PATCH
```

| Increment | When | Examples |
|---|---|---|
| **MAJOR** | Breaking change to consuming repo contract — file moves, schema changes, removed required files | Renaming `instructions/` to `standards/`, changing `version.json` schema |
| **MINOR** | New agents, skills, instructions, templates, or non-breaking additions | Adding `agents/release-manager.agent.md`, new skill folder |
| **PATCH** | Bug fixes, typos, CI tweaks, documentation corrections | Fixing a broken link, correcting a regex in a workflow |

When in doubt, prefer the lower bump. A `feat` that adds content without changing contracts is `minor`, not `major`.

---

## Prerequisites

Before starting a release, verify:

- [ ] All PRs for the release are merged to `main`
- [ ] CI is green on `main` — no failing checks
- [ ] No secrets, tokens, or PII in any merged content
- [ ] `gh` CLI is installed and authenticated (`gh auth status`)
- [ ] Working tree is clean (`git status` shows no changes)

---

## Release Steps

### 1. Identify What Changed

List merged PRs since the last release tag:

```bash
CURRENT_VERSION=$(jq -r '.version' version.json)
LAST_TAG="v${CURRENT_VERSION}"

gh pr list \
  --state merged \
  --base main \
  --search "merged:>=$(git log -1 --format=%aI ${LAST_TAG})" \
  --json number,title,labels \
  --limit 200
```

Review the list. Determine the appropriate bump level using the rules above.

### 2. Bump `version.json`

Update the `version`, `releaseDate`, and optionally the `notes` field:

```json
{
    "name": "base-coat",
    "version": "X.Y.Z",
    "releaseDate": "YYYY-MM-DD",
    "notes": "Brief summary of what this release includes."
}
```

### 2a. Optional per-asset version bumps

If you changed versioned assets and want independent asset SemVer bumps:

```powershell
# Preview version bumps
pwsh scripts/bump-asset-versions.ps1 -BaseRef origin/main

# Apply bumps
pwsh scripts/bump-asset-versions.ps1 -BaseRef origin/main -Apply
```

Then regenerate the asset manifest:

```powershell
pwsh scripts/generate-asset-manifest.ps1
```

### 3. Update `CHANGELOG.md`

Add a new section immediately after the preamble, above existing entries. Follow this format:

```markdown
## X.Y.Z - YYYY-MM-DD

### Added
- Description of new feature (#PR)

### Changed
- Description of change (#PR)

### Fixed
- Description of bug fix (#PR)
```

**Rules:**

- Use the heading format `## X.Y.Z - YYYY-MM-DD` (no `v` prefix — matches existing convention)
- Group entries under `Added`, `Changed`, `Fixed`, `Removed` per Keep a Changelog
- Omit empty groups — do not include `### Removed` if nothing was removed
- Each entry references its PR number: `(#42)`
- Preserve all existing content below the new section unchanged
- If a single-line-per-PR style is already in use (as in prior releases), maintain that style for consistency

When a changelog section is unavailable for the target version, the release workflow
falls back to grouped merged-PR notes. Those notes are organized by PR type/category
(`Added`, `Changed`, `Fixed`, `Removed`, plus supporting groups like `Documentation`,
`Testing`, `CI`, and `Maintenance`) before committing to a commit-history fallback.

### 4. Commit the Version Bump

```bash
git add version.json CHANGELOG.md
git commit -m "chore: bump version to vX.Y.Z"
```

### 5. Choose: Direct Tag or PR Review

#### Option A — Direct Tag (for maintainers)

```bash
git push origin main
git tag vX.Y.Z
git push origin vX.Y.Z
```

#### Option B — Release PR (for team review)

```bash
git checkout -b release/vX.Y.Z
git push origin release/vX.Y.Z

gh pr create \
  --base main \
  --head release/vX.Y.Z \
  --title "chore: release vX.Y.Z" \
  --body "Bumps version to X.Y.Z and adds CHANGELOG entry. Once merged, tag with:
\`\`\`
git tag vX.Y.Z && git push origin vX.Y.Z
\`\`\`"
```

After the PR is merged, pull `main` and create the tag:

```bash
git checkout main && git pull origin main
git tag vX.Y.Z
git push origin vX.Y.Z
```

### 6. Publish GitHub Release

Pushing a `v*.*.*` tag triggers the `release.yml` and `package-basecoat.yml` workflows automatically. These workflows:

1. Build a source archive (`basecoat-vX.Y.Z.zip`)
2. Extract release notes from `CHANGELOG.md` (prefers `## X.Y.Z`, then falls back to `## Unreleased`)
3. If no changelog section exists, generate grouped release notes from merged PRs since the last tag
4. Create a GitHub release with the archive and notes

If neither changelog section nor merged PR list is available, the workflow auto-generates release notes from commit history as a final fallback.

If you need to create the release manually (e.g., workflows are disabled):

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file release-notes.md \
  --repo ivegamsft/basecoat
```

### 7. Post-Release Verification

After the release is published:

- [ ] GitHub release page shows correct notes and artifacts
- [ ] `package-basecoat.yml` workflow completed successfully
- [ ] `release.yml` workflow completed successfully
- [ ] Tag `vX.Y.Z` appears in the repository's tag list
- [ ] `version.json` on `main` reflects the released version

---

## Using the Release Manager Agent

The `release-manager` agent (`agents/release-manager.agent.md`) automates Steps 1–6 above. Invoke it with:

- **Default (direct tag):** The agent identifies merged PRs, bumps the version, writes the changelog, commits, tags, and publishes.
- **With PR review:** Pass the PR-based review flag to have the agent open a release PR instead of tagging directly.
- **Dry run:** Preview what the release would contain without making any changes.

The agent follows the same rules documented here. It does not invent its own conventions.

---

## Hotfix Releases

For urgent fixes that cannot wait for a full sprint cycle:

1. Branch from the latest release tag: `git checkout -b fix/<issue>-<desc> vX.Y.Z`
2. Apply the fix, commit with `fix(<scope>): <description>`
3. Open a PR to `main`
4. After merge, follow the normal release steps with a `patch` bump

---

## Rollback

If a release introduces a critical issue:

1. Revert the problematic commit(s) on `main`
2. Follow the release steps with a new `patch` version
3. Do **not** delete or move existing tags — they are immutable history
4. Note the rollback in the CHANGELOG entry for the new version

---

## FAQ

**Q: Can I skip the CHANGELOG?**
No. Every tagged release must have a corresponding CHANGELOG entry. The `version-check.yml` workflow enforces that `version.json` and CHANGELOG headings stay in sync.

**Q: What if I need to re-release the same version?**
Don't. Increment the patch version instead. Semver versions are immutable.

**Q: What if the release workflow fails?**
Check the Actions tab. The `release.yml` workflow uses `gh release create` on first publish and `gh release upload` + `gh release edit` if the release already exists. You can re-run the workflow or create the release manually.

**Q: Who can cut a release?**
Per `docs/GOVERNANCE.md`, CI/CD changes (including releases) are decided by the repo owner. In practice, anyone with push access to `main` and tag permissions can follow this process.

---

## Related Documents

| Document | Purpose |
|---|---|
| `docs/GOVERNANCE.md` | Versioning policy, sprint process, decision-making |
| `CONTRIBUTING.md` | Branch naming, commit format, PR process |
| `version.json` | Machine-readable current version |
| `CHANGELOG.md` | Human-readable release history |
| `.github/workflows/release.yml` | Tag-triggered release automation |
| `.github/workflows/package-basecoat.yml` | Tag-triggered packaging and artifact upload |
| `.github/workflows/version-check.yml` | CI check for version/CHANGELOG consistency |
| `agents/release-manager.agent.md` | Agent that automates this process |
