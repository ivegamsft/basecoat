# Release Manager — Detail Reference

## Version Bump Classification

| Signal | Bump |
|---|---|
| Label `breaking-change` or PR title contains `BREAKING CHANGE` | major |
| Label `enhancement` or `feature`, or title starts with `feat` | minor |
| Label `bug` or `fix`, or title starts with `fix`, `docs`, `chore` | patch |

```bash
IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"
case "${BUMP}" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac
NEXT_VERSION="${MAJOR}.${MINOR}.${PATCH}"
```

## Key Commands

```bash
# Get current version and last tag
CURRENT_VERSION=$(jq -r '.version' version.json)
LAST_TAG="v${CURRENT_VERSION}"

# Collect merged PRs since last tag
TAG_DATE=$(git log -1 --format=%aI "${LAST_TAG}")
gh pr list --state merged --base main --search "merged:>=${TAG_DATE}" \
  --json number,title,labels,body,mergedAt --limit 200

# Update version.json
jq --arg v "${NEXT_VERSION}" --arg d "${RELEASE_DATE}" \
  '.version = $v | .releaseDate = $d' version.json > version.json.tmp && mv version.json.tmp version.json

# Commit, tag, push, release
git add version.json CHANGELOG.md
git commit -m "chore: bump version to v${NEXT_VERSION}"
git tag "v${NEXT_VERSION}"
git push origin main
git push origin "v${NEXT_VERSION}"
gh release create "v${NEXT_VERSION}" --title "v${NEXT_VERSION}" --notes "${NOTES}"
```

## CHANGELOG Format (Keep a Changelog)

```markdown
## <NEXT_VERSION> - <RELEASE_DATE>

### Added
- <entries from feat PRs>

### Changed
- <entries from refactor/enhancement PRs>

### Fixed
- <entries from fix PRs>

### Removed
- <entries from removal PRs>
```

Heading format: `## X.Y.Z - YYYY-MM-DD` (no `v` prefix). Omit empty sections.

## PR-Based Review Mode (`--pr`)

```bash
BRANCH="release/v${NEXT_VERSION}"
git checkout -b "${BRANCH}"
git push origin "${BRANCH}"
gh pr create --base main --head "${BRANCH}" --title "chore: release v${NEXT_VERSION}"
```

In `--pr` mode, the release is published only after the version-bump PR merges and the tag is pushed from the merged commit. Do not tag or publish from the unmerged review branch.

## Dry Run Output

```text
DRY RUN — Release v<NEXT_VERSION>
  Bump type: <major|minor|patch>
  Current:   <CURRENT_VERSION>
  Next:      <NEXT_VERSION>
  PRs:       <count> merged since <LAST_TAG>
  CHANGELOG: <preview of new section>
```

## Error Conditions

| Condition | Action |
|---|---|
| `version.json` missing or malformed | Stop with error |
| No merged PRs since last release | Stop — nothing to release |
| Git tag already exists for computed version | Stop — version collision |
| `gh` CLI not authenticated | Stop with error |
| CHANGELOG.md missing | Create with standard header before adding entry |
| Dirty working tree | Stop with error — require clean state |
