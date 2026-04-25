# Release Process

This document describes how versioned releases of Basecoat are cut,
tagged, and published. Follow this process for every release regardless
of size.

---

## Overview

Basecoat uses **semantic versioning** (`MAJOR.MINOR.PATCH`). The source
of truth for the current version is `version.json` at the repo root.
The authoritative human-readable history is `CHANGELOG.md`.

---

## Version Artifacts

| Artifact | Location | Update Trigger |
|----------|----------|---------------|
| Current version | `version.json` | Every release |
| Human-readable history | `CHANGELOG.md` | Every release |
| Git tag | `v<version>` on `main` | After version-bump PR merges |
| GitHub Release | GitHub Releases page | After git tag is pushed |

These four artifacts must always be in sync. The `version-check.yml`
CI workflow enforces consistency between `version.json` and `CHANGELOG.md`
on every PR.

---

## Release Cadence

- **Sprint releases** (minor bumps): cut at the end of each sprint
- **Hotfixes** (patch bumps): cut ad-hoc when a defect is found in the
  current release
- **Breaking changes** (major bumps): planned, announced in an issue first,
  require explicit human approval before tagging

---

## Step-by-Step Process

### 1. Confirm `main` is Green

All CI checks on `main` must pass before starting a release:

```bash
gh run list --repo ivegamsft/basecoat --branch main --limit 5
```

If any workflow is failing, fix it before proceeding.

### 2. Use the Release Manager Agent (Recommended)

The `release-manager` agent automates Steps 3–7. Invoke it with:

```
Bump type: minor          # or major / patch
PR mode: pr               # opens a version-bump PR for review
Dry run: true             # preview first — recommended
```

Preview the release:

```
Bump type: minor
Dry run: true
```

Execute:

```
Bump type: minor
Dry run: false
PR mode: pr
```

### 3. Manual Process (if not using the agent)

#### 3a. Collect Merged PRs Since Last Tag

```bash
LAST_TAG=$(git describe --tags --abbrev=0)
echo "Last tag: $LAST_TAG"

gh pr list \
  --repo ivegamsft/basecoat \
  --state merged \
  --json number,title,mergedAt \
  --jq "[.[] | select(.mergedAt > \"$(git log $LAST_TAG -1 --format=%cI)\")]"
```

#### 3b. Update `version.json`

Edit `version.json`:

```json
{
    "name": "base-coat",
    "version": "<new-version>",
    "releaseDate": "<YYYY-MM-DD>",
    "notes": "<one-line sprint summary>"
}
```

#### 3c. Update `CHANGELOG.md`

Prepend a new entry before the previous most-recent entry:

```markdown
## <new-version> — <YYYY-MM-DD>

- <change description>
- <change description>
```

Follow [Keep a Changelog](https://keepachangelog.com) conventions:
- **Added** for new features
- **Changed** for changes to existing functionality
- **Fixed** for bug fixes
- **Removed** for removed features

#### 3d. Open Version-Bump PR

```bash
git checkout -b chore/release-<new-version>
git add version.json CHANGELOG.md
git commit -m "chore(release): bump to v<new-version>"
git push origin chore/release-<new-version>
gh pr create --title "chore(release): v<new-version>" --base main
```

#### 3e. Merge and Tag

After the PR merges to `main`:

```bash
git checkout main && git pull
git tag -a "v<new-version>" -m "Release v<new-version>"
git push origin "v<new-version>"
```

#### 3f. Publish GitHub Release

The `release.yml` workflow fires automatically on `v*.*.*` tag push and
publishes the GitHub Release. To publish manually:

```bash
gh release create "v<new-version>" \
  --repo ivegamsft/basecoat \
  --title "Release v<new-version>" \
  --generate-notes \
  --verify-tag
```

---

## Semver Rules

| Bump | When to use |
|------|-------------|
| `patch` | Bug fixes, documentation corrections, no new features |
| `minor` | New agents, skills, instructions — backward-compatible additions |
| `major` | Breaking changes to the sync contract, file layout, or agent interfaces |

**When in doubt, use `minor`.** Consumers pin to a release tag; a minor bump
never breaks them.

---

## Tag Immutability

> **Never force-push or delete a tag once it is pushed.**

Tags are permanent. If a mistake is made after tagging:

1. Do NOT delete or move the tag
2. Fix the mistake on `main`
3. Cut a new patch release with the fix

---

## Rollback

If a release is discovered to be broken after publishing:

1. Open a GitHub issue describing the defect
2. Fix on a `fix/<issue>-<slug>` branch
3. Merge via PR to `main`
4. Cut a patch release

Do not retract releases or delete tags. Consumers may already be pinned to
the broken version; deleting it breaks their sync.

---

## CI Integration

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `version-check.yml` | PR to `main`, push to `main` | Validates `version.json` ↔ `CHANGELOG.md` consistency |
| `release.yml` | Push `v*.*.*` tag | Builds source archive, publishes GitHub Release |
| `pr-validation.yml` | PR to `main` | Markdownlint, secret scan, agent structure checks |

---

## Checklist

Use this checklist for every release:

```markdown
## Release Checklist — v<version>

- [ ] main is green (all CI workflows passing)
- [ ] All sprint PRs merged
- [ ] version.json bumped to <version>
- [ ] CHANGELOG.md entry added for <version>
- [ ] Version-bump PR opened, reviewed, and merged
- [ ] Git tag v<version> created and pushed
- [ ] GitHub Release published with release notes
- [ ] release.yml CI completed successfully
- [ ] version-check.yml passes on main post-merge
```
