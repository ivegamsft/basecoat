#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <tag> <version> [notes-file]" >&2
  exit 1
fi

tag="$1"
version="$2"
notes_file="${3:-release-notes.md}"
base_branch="${RELEASE_NOTES_BASE_BRANCH:-main}"
gh_pr_json_file="${RELEASE_NOTES_PR_JSON_FILE:-}"
changelog_file="${RELEASE_NOTES_CHANGELOG_FILE:-CHANGELOG.md}"

has_section_body() {
  awk '
    NR == 1 { next }
    /^[[:space:]]*$/ { next }
    { found = 1; exit 0 }
    END { exit found ? 0 : 1 }
  ' "$1"
}

extract_version_section() {
  local section_file="$1"

  awk -v tag="${tag}" -v version="${version}" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    BEGIN { capture = 0; found = 0 }
    {
      if ($0 ~ /^##[[:space:]]+/) {
        heading = $0
        normalized = heading
        sub(/^##[[:space:]]+/, "", normalized)
        gsub(/\[/, "", normalized)
        gsub(/\]/, "", normalized)
        split(normalized, parts, " - ")
        heading_version = trim(parts[1])

        if (capture == 1) {
          exit 0
        }

        if (heading_version == tag || heading_version == version) {
          capture = 1
          found = 1
          print $0
          next
        }
      }

      if (capture == 1) {
        print $0
      }
    }
    END { if (found == 0) exit 2 }
  ' "${changelog_file}" > "${section_file}"
}

extract_unreleased_section() {
  local section_file="$1"

  awk '
    BEGIN { capture = 0; found = 0 }
    {
      if ($0 ~ /^##[[:space:]]+/) {
        heading = $0
        sub(/^##[[:space:]]+/, "", heading)

        if (capture == 1) {
          exit 0
        }

        if (heading == "Unreleased") {
          capture = 1
          found = 1
          print $0
          next
        }
      }

      if (capture == 1) {
        print $0
      }
    }
    END { if (found == 0) exit 2 }
  ' "${changelog_file}" > "${section_file}"
}

write_git_history_notes() {
  local previous_tag range from_label

  previous_tag="$(git tag --list 'v*.*.*' --sort=-v:refname | grep -Fxv "${tag}" | head -n 1 || true)"
  range="${GITHUB_SHA:-HEAD}"
  from_label="initial commit"

  if [[ -n "${previous_tag}" ]]; then
    range="${previous_tag}..${GITHUB_SHA:-HEAD}"
    from_label="${previous_tag}"
  fi

  {
    printf '## %s\n\n' "${version}"
    printf '_Auto-generated from commit history since %s._\n\n' "${from_label}"
    printf '### Changes\n\n'
    git log --no-merges --pretty='- %s (%h)' "${range}" || true
  } > "${notes_file}"

  if ! grep -q '^-' "${notes_file}"; then
    printf -- '- No commits found in selected range.\n' >> "${notes_file}"
  fi
}

write_grouped_pr_notes() {
  local merged_since previous_tag from_label pr_json

  merged_since="2000-01-01T00:00:00Z"
  from_label="initial commit"
  previous_tag="$(git tag --list 'v*.*.*' --sort=-v:refname | grep -Fxv "${tag}" | head -n 1 || true)"
  if [[ -n "${previous_tag}" ]]; then
    merged_since="$(git log -1 --format=%aI "${previous_tag}")"
    from_label="${previous_tag}"
  fi

  if [[ -n "${gh_pr_json_file}" && -f "${gh_pr_json_file}" ]]; then
    pr_json="$(cat "${gh_pr_json_file}")"
  else
    pr_json="$(gh pr list --state merged --base "${base_branch}" --search "merged:>=${merged_since}" --json number,title,labels,mergedAt --limit 200)"
  fi

  if [[ -z "${pr_json}" || "${pr_json}" == "[]" ]]; then
    return 1
  fi

  PR_JSON="${pr_json}" python - "$notes_file" "$version" "${from_label}" <<'PY'
import json
import re
import os
import sys
from pathlib import Path

output = Path(sys.argv[1])
version = sys.argv[2]
from_label = sys.argv[3]

prs = json.loads(os.environ["PR_JSON"])
if not prs:
    sys.exit(1)

order = [
    "Breaking Changes",
    "Added",
    "Changed",
    "Fixed",
    "Removed",
    "Documentation",
    "Testing",
    "CI",
    "Maintenance",
    "Other",
]

groups = {name: [] for name in order}

def title_text(pr):
    labels = " ".join((label.get("name", "") for label in pr.get("labels", [])))
    return f"{pr.get('title', '')} {labels}".lower()

def matches(title, patterns):
    return any(pattern.search(title) for pattern in patterns)

def bucket(pr):
    text = title_text(pr)
    title = pr.get("title", "").lower()

    if "breaking change" in text or "breaking-change" in text:
        return "Breaking Changes"
    if matches(title, [re.compile(r"^(feat|feature)(\([^)]+\))?:")]) or any(
        label in {"enhancement", "feature"} for label in (label.get("name", "").lower() for label in pr.get("labels", []))
    ):
        return "Added"
    if matches(title, [re.compile(r"^(fix|bug|hotfix)(\([^)]+\))?:")]) or any(
        label in {"bug", "fix"} for label in (label.get("name", "").lower() for label in pr.get("labels", []))
    ):
        return "Fixed"
    if matches(title, [re.compile(r"^(remove|revert)(\([^)]+\))?:")]) or any(
        label in {"remove", "removed", "removal", "revert"} for label in (label.get("name", "").lower() for label in pr.get("labels", []))
    ):
        return "Removed"
    if matches(title, [re.compile(r"^(refactor|perf|performance)(\([^)]+\))?:")]) or "refactor" in text:
        return "Changed"
    if matches(title, [re.compile(r"^(docs|doc)(\([^)]+\))?:")]) or any(
        label in {"docs", "documentation"} for label in (label.get("name", "").lower() for label in pr.get("labels", []))
    ):
        return "Documentation"
    if matches(title, [re.compile(r"^(test|tests)(\([^)]+\))?:")]) or any(
        label in {"test", "tests", "testing"} for label in (label.get("name", "").lower() for label in pr.get("labels", []))
    ):
        return "Testing"
    if matches(title, [re.compile(r"^(ci|build)(\([^)]+\))?:")]) or any(
        label in {"ci", "build"} for label in (label.get("name", "").lower() for label in pr.get("labels", []))
    ):
        return "CI"
    if matches(title, [re.compile(r"^(chore|maintenance)(\([^)]+\))?:")]) or any(
        label in {"chore", "maintenance"} for label in (label.get("name", "").lower() for label in pr.get("labels", []))
    ):
        return "Maintenance"
    return "Other"

for pr in prs:
    groups[bucket(pr)].append(pr)

lines = [
    f"## {version}",
    "",
    f"_Auto-generated from merged PRs since {from_label}._",
    "",
]

for group in order:
    entries = groups[group]
    if not entries:
        continue
    lines.append(f"### {group}")
    lines.append("")
    for pr in entries:
        lines.append(f"- {pr.get('title', '').strip()} (#{pr.get('number')})")
    lines.append("")

content = "\n".join(lines).rstrip() + "\n"
if content.count("\n- ") == 0:
    sys.exit(1)

output.write_text(content, encoding="utf-8")
PY
}

if [[ -f CHANGELOG.md ]] && extract_version_section "release-section.md" && has_section_body "release-section.md"; then
  cp "release-section.md" "${notes_file}"
elif [[ -f CHANGELOG.md ]] && extract_unreleased_section "release-section.md" && has_section_body "release-section.md"; then
  {
    printf '## %s\n\n' "${version}"
    printf '_Derived from `## Unreleased` in CHANGELOG.md because a `%s` section was not found._\n\n' "${version}"
    tail -n +2 "release-section.md"
  } > "${notes_file}"
elif write_grouped_pr_notes; then
  :
else
  write_git_history_notes
fi

rm -f "release-section.md"
