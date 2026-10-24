#!/usr/bin/env bash
# Dispatch PR triage for an automation-created or automation-edited PR (#3859).
#
# Events caused by GITHUB_TOKEN never start new workflow runs, so a PR written
# with github.token never reaches the pull_request_target size labeler. The
# workflow_dispatch event is the documented exception, so this helper dispatches
# the labeler explicitly. The labeler re-dispatches the merge executor after
# labeling, which covers the merge-eligibility re-evaluation the delivery queue
# depends on. pull_request checks (CI) cannot be replayed this way; they only run
# when the PR is written with GH_AW_GITHUB_TOKEN.
#
# Usage: bash .github/base-coat/scripts/dispatch-pr-triage.sh <pr-number>
# Env:
#   AUTOMATION_TOKEN_CONFIGURED  "true" when GH_AW_GITHUB_TOKEN wrote the PR.
#   DISPATCH_GH_TOKEN            Token with actions: write; defaults to GH_TOKEN.
set -euo pipefail

pr_number="${1:-}"
if [[ ! "$pr_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "::warning::No pull request number to triage; skipping the PR size labeler dispatch."
  exit 0
fi

if [[ "${AUTOMATION_TOKEN_CONFIGURED:-false}" != "true" ]]; then
  echo "::warning::GH_AW_GITHUB_TOKEN is not configured, so PR #${pr_number} was written with github.token. pull_request_target and pull_request workflows (size labeler, reviewer assignment, CI) will not trigger on their own; dispatching the size labeler explicitly."
fi

export GH_TOKEN="${DISPATCH_GH_TOKEN:-${GH_TOKEN:-}}"
repository="${GITHUB_REPOSITORY:-}"
if [[ -z "$repository" ]]; then
  repository="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi
workflow_paths="$(gh api --paginate "repos/${repository}/actions/workflows?per_page=100" \
  --jq '.workflows[] | select(.state == "active") | .path')"

# Consumer installs rename the labeler with a basecoat- prefix.
for workflow in pr-size-labeler.yml basecoat-pr-size-labeler.yml; do
  if grep -Fxq ".github/workflows/${workflow}" <<< "$workflow_paths"; then
    gh workflow run "$workflow" --repo "$repository" -f "pr_number=${pr_number}"
    echo "Dispatched ${workflow} for PR #${pr_number}."
    exit 0
  fi
done

echo "::warning::No PR size labeler workflow is installed; PR #${pr_number} was not dispatched for triage."
