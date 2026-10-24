#!/usr/bin/env bash
# Shared release label policy gate for every tag publisher (#3843).
#
# Usage: scripts/release-label-gate.sh <publisher> <tag> <output.json>
#
# Runs the same classifier as the PR and merge-group release-label gate
# (scripts/merge-group-release-labels.cjs release-coverage, #3595/#3829) over
# the exact previous-tag..tag range and fails closed when the policy rejects
# the release, the history is incomplete, or the tag moved. Report-only: it
# never creates, moves, or pushes refs. Callers must check out full history
# with tags. Set EXPECTED_TAG_SHA to bind the decision to a specific commit.
# When GITHUB_OUTPUT is set, prev_tag is written for downstream revalidation.
set -euo pipefail

publisher="${1:-}"
tag="${2:-}"
output_file="${3:-}"

fail() {
  echo "::error title=Release label policy gate blocked ${publisher:-publisher}::$1"
  echo "::error::${publisher:-publisher} will not publish ${tag:-the tag}. Fix release labels or exemptions on the listed PRs, then re-run this workflow."
  exit 1
}

if [[ -z "$publisher" || -z "$tag" || -z "$output_file" ]]; then
  fail "Usage: release-label-gate.sh <publisher> <tag> <output.json>"
fi
if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "Tag '$tag' is not a release semver tag (vX.Y.Z)."
fi
if [[ "$(git rev-parse --is-shallow-repository)" != "false" ]]; then
  fail "Repository history is shallow; the exact release range cannot be proven."
fi

tag_sha="$(git rev-parse --verify --quiet "refs/tags/${tag}^{commit}" || true)"
if [[ -z "$tag_sha" ]]; then
  fail "Tag $tag is not present locally; the release range cannot be proven."
fi
if [[ -n "${EXPECTED_TAG_SHA:-}" && "$tag_sha" != "${EXPECTED_TAG_SHA}" ]]; then
  fail "Tag $tag resolves to $tag_sha but this run is bound to ${EXPECTED_TAG_SHA}."
fi

# Previous release is the next lower semver tag, so re-publishing an older tag
# evaluates its own window rather than failing ancestry against a newer tag.
prev_tag="$(git --no-pager tag --list 'v*.*.*' --sort=-v:refname | awk -v t="${tag}" 'seen { print; exit } $0 == t { seen = 1 }')"
if [[ -z "$prev_tag" ]]; then
  echo "::warning::No previous semver tag found; skipping wave/sprint label coverage gate."
  exit 0
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "prev_tag=${prev_tag}" >> "$GITHUB_OUTPUT"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Release labels, skip-release-label-gate and dependencies count as covered;
# more than 10% uncovered fails, exactly 10% warns.
if ! node "${script_dir}/merge-group-release-labels.cjs" release-coverage "${prev_tag}" "${tag}" "${output_file}"; then
  fail "Release label coverage for ${prev_tag}..${tag} did not pass the release label policy."
fi
echo "Release label policy gate passed for ${publisher}: ${prev_tag}..${tag}."
