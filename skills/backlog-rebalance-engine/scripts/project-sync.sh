#!/usr/bin/env bash
# project-sync.sh — Idempotent backlog-rebalance-engine project sync
# Aligns project status and delivery metadata with policy validation, freeze-window
# guardrails, rollback artifact output, and reason-coded per-item changelog.

set -euo pipefail

OWNER=""
PROJECT_TITLE=""
REPO=""
FILTER_LABEL=""
ISSUE_LIST_FILE=""
DRY_RUN=false
STATUS_OPEN="Todo"
STATUS_CLOSED="Done"
MAX_RETRIES=3
TARGET_PRIORITY_LABEL=""
TARGET_SPRINT_LABEL=""
TARGET_WAVE_LABEL=""
FREEZE_WINDOW=false
ALLOW_FREEZE_OVERRIDE=false
ROLLBACK_ARTIFACT_PATH=""
CHANGE_LOG_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; shift 2 ;;
    --project) PROJECT_TITLE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --label) FILTER_LABEL="$2"; shift 2 ;;
    --issue-list) ISSUE_LIST_FILE="$2"; shift 2 ;;
    --status-open) STATUS_OPEN="$2"; shift 2 ;;
    --status-closed) STATUS_CLOSED="$2"; shift 2 ;;
    --target-priority-label) TARGET_PRIORITY_LABEL="$2"; shift 2 ;;
    --target-sprint-label) TARGET_SPRINT_LABEL="$2"; shift 2 ;;
    --target-wave-label) TARGET_WAVE_LABEL="$2"; shift 2 ;;
    --freeze-window) FREEZE_WINDOW=true; shift ;;
    --allow-freeze-override) ALLOW_FREEZE_OVERRIDE=true; shift ;;
    --rollback-artifact-path) ROLLBACK_ARTIFACT_PATH="$2"; shift 2 ;;
    --change-log-path) CHANGE_LOG_PATH="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$OWNER" || -z "$PROJECT_TITLE" || -z "$REPO" ]]; then
  echo "Usage: $0 --owner <org> --project <title> --repo <owner/repo> [--label <sprint:N>] [--issue-list <file>] [--target-priority-label <priority:...>] [--target-sprint-label <sprint:N>] [--target-wave-label <wave:N>] [--freeze-window] [--allow-freeze-override] [--rollback-artifact-path <path>] [--change-log-path <path>] [--dry-run]" >&2
  exit 1
fi

test_policy_label() {
  local family="$1"
  local value="$2"
  [[ -z "$value" ]] && return 0
  case "$family" in
    priority) [[ "$value" =~ ^priority:(critical|high|medium|low)$ ]] ;;
    sprint) [[ "$value" =~ ^sprint:[0-9]+$ ]] ;;
    wave) [[ "$value" =~ ^wave:[0-9]+$ ]] ;;
    *) return 1 ;;
  esac
}

for pair in \
  "priority:$TARGET_PRIORITY_LABEL" \
  "sprint:$TARGET_SPRINT_LABEL" \
  "wave:$TARGET_WAVE_LABEL"; do
  family="${pair%%:*}"
  value="${pair#*:}"
  if ! test_policy_label "$family" "$value"; then
    echo "POLICY_INVALID_TARGET_LABEL: invalid $family target '$value'" >&2
    exit 1
  fi
done

gh_api_with_retry() {
  local attempt=1
  while [[ $attempt -le $MAX_RETRIES ]]; do
    if "$@"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 10
  done
  return 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Resolving project: '$PROJECT_TITLE' for owner '$OWNER'..."
project_data="$(gh project list --owner "$OWNER" --format json --limit 100 2>/dev/null)"
project_number="$(echo "$project_data" | jq -r --arg title "$PROJECT_TITLE" '.projects[] | select(.title == $title) | .number' | head -1)"
if [[ -z "$project_number" || "$project_number" == "null" ]]; then
  echo "Project not found: $PROJECT_TITLE" >&2
  exit 1
fi

project_node_id="$(
  gh api graphql -f query='
    query($owner: String!, $number: Int!) {
      organization(login: $owner) { projectV2(number: $number) { id } }
    }
  ' -f owner="$OWNER" -F number="$project_number" --jq '.data.organization.projectV2.id' 2>/dev/null || true
)"
if [[ -z "$project_node_id" || "$project_node_id" == "null" ]]; then
  project_node_id="$(
    gh api graphql -f query='
      query($owner: String!, $number: Int!) {
        user(login: $owner) { projectV2(number: $number) { id } }
      }
    ' -f owner="$OWNER" -F number="$project_number" --jq '.data.user.projectV2.id' 2>/dev/null || true
  )"
fi
if [[ -z "$project_node_id" || "$project_node_id" == "null" ]]; then
  echo "Could not resolve project node ID for project number $project_number." >&2
  exit 1
fi

echo "Resolving Status field..."
fields_json="$(gh api graphql -f query='
  query($id: ID!) {
    node(id: $id) {
      ... on ProjectV2 {
        fields(first: 20) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id name
              options { id name }
            }
          }
        }
      }
    }
  }
' -f id="$project_node_id" --jq '.data.node.fields.nodes')"

status_field_id="$(echo "$fields_json" | jq -r '.[] | select(.name=="Status") | .id' | head -1)"
option_open_id="$(echo "$fields_json" | jq -r --arg s "$STATUS_OPEN" '.[] | select(.name=="Status") | .options[] | select(.name==$s) | .id' | head -1)"
option_closed_id="$(echo "$fields_json" | jq -r --arg s "$STATUS_CLOSED" '.[] | select(.name=="Status") | .options[] | select(.name==$s) | .id' | head -1)"
[[ -z "$status_field_id" || "$status_field_id" == "null" ]] && { echo "Status field not found in project." >&2; exit 1; }
[[ -z "$option_open_id" || "$option_open_id" == "null" ]] && { echo "Status option not found: $STATUS_OPEN" >&2; exit 1; }
[[ -z "$option_closed_id" || "$option_closed_id" == "null" ]] && { echo "Status option not found: $STATUS_CLOSED" >&2; exit 1; }

echo "Fetching current project items..."
gh project item-list "$project_number" --owner "$OWNER" --format json --limit 2000 > "$tmp/board.json" 2>/dev/null || echo '{"items":[]}' > "$tmp/board.json"

if [[ -n "$ISSUE_LIST_FILE" ]]; then
  cp "$ISSUE_LIST_FILE" "$tmp/issues.json"
else
  label_args=()
  [[ -n "$FILTER_LABEL" ]] && label_args=(--label "$FILTER_LABEL")
  gh issue list --repo "$REPO" --state all --limit 500 "${label_args[@]}" --json number,url,title,state,labels > "$tmp/issues.json"
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
if [[ -z "$ROLLBACK_ARTIFACT_PATH" ]]; then
  ROLLBACK_ARTIFACT_PATH="./artifacts/backlog-rebalance-rollback-${timestamp}.json"
fi
if [[ -z "$CHANGE_LOG_PATH" ]]; then
  CHANGE_LOG_PATH="./artifacts/backlog-rebalance-changelog-${timestamp}.json"
fi
mkdir -p "$(dirname "$ROLLBACK_ARTIFACT_PATH")" "$(dirname "$CHANGE_LOG_PATH")"

jq -n '[]' > "$tmp/plan.json"
freeze_block_count=0

issue_count="$(jq 'length' "$tmp/issues.json")"
for ((i=0; i<issue_count; i++)); do
  issue="$(jq -c ".[$i]" "$tmp/issues.json")"
  number="$(echo "$issue" | jq -r '.number')"
  url="$(echo "$issue" | jq -r '.url')"
  title="$(echo "$issue" | jq -r '.title')"
  state="$(echo "$issue" | jq -r '.state')"
  expected_option_id="$option_open_id"
  expected_status="$STATUS_OPEN"
  [[ "$state" == "CLOSED" ]] && { expected_option_id="$option_closed_id"; expected_status="$STATUS_CLOSED"; }

  item_id="$(jq -r --arg u "$url" '.items[] | select(.content.url==$u) | .id' "$tmp/board.json" | head -1)"
  current_option_id="$(jq -r --arg u "$url" '.items[] | select(.content.url==$u) | (.fieldValues.nodes[]? | select(.field.name=="Status") | .optionId) // ""' "$tmp/board.json" | head -1)"
  [[ "$current_option_id" == "null" ]] && current_option_id=""

  target_priority="$(echo "$issue" | jq -r --arg d "$TARGET_PRIORITY_LABEL" '.targetMetadata.priority // .targetPriorityLabel // .target_priority_label // $d // ""')"
  target_sprint="$(echo "$issue" | jq -r --arg d "$TARGET_SPRINT_LABEL" '.targetMetadata.sprint // .targetSprintLabel // .target_sprint_label // $d // ""')"
  target_wave="$(echo "$issue" | jq -r --arg d "$TARGET_WAVE_LABEL" '.targetMetadata.wave // .targetWaveLabel // .target_wave_label // $d // ""')"

  for f in priority sprint wave; do
    v=""
    [[ "$f" == "priority" ]] && v="$target_priority"
    [[ "$f" == "sprint" ]] && v="$target_sprint"
    [[ "$f" == "wave" ]] && v="$target_wave"
    if ! test_policy_label "$f" "$v"; then
      echo "POLICY_INVALID_TARGET_LABEL: invalid $f target '$v' for issue #$number" >&2
      exit 1
    fi
  done

  reason_codes='[]'
  actions='[]'

  if [[ -z "$item_id" ]]; then
    reason_codes="$(echo "$reason_codes" | jq '. + ["ADD_TO_PROJECT"]')"
    actions="$(echo "$actions" | jq --arg st "$expected_status" --arg to "$expected_option_id" '. + [{"type":"project_add","expectedStatus":$st,"toOptionId":$to}]')"
  elif [[ "$current_option_id" != "$expected_option_id" ]]; then
    reason_codes="$(echo "$reason_codes" | jq '. + ["STATUS_MISMATCH"]')"
    actions="$(echo "$actions" | jq --arg id "$item_id" --arg from "$current_option_id" --arg to "$expected_option_id" '. + [{"type":"status_update","itemId":$id,"fromOptionId":$from,"toOptionId":$to}]')"
  else
    reason_codes="$(echo "$reason_codes" | jq '. + ["STATUS_ALREADY_ALIGNED"]')"
  fi

  for family in priority sprint wave; do
    regex="^${family}:"
    target=""
    [[ "$family" == "priority" ]] && target="$target_priority"
    [[ "$family" == "sprint" ]] && target="$target_sprint"
    [[ "$family" == "wave" ]] && target="$target_wave"
    if [[ -z "$target" ]]; then
      reason_codes="$(echo "$reason_codes" | jq --arg f "${family^^}" '. + ["METADATA_NO_TARGET_\($f)"]')"
      continue
    fi
    existing="$(echo "$issue" | jq -c --arg re "$regex" '[.labels[]?.name // .labels[]? // empty | select(test($re))]')"
    aligned="$(echo "$existing" | jq --arg t "$target" 'length == 1 and .[0] == $t')"
    if [[ "$aligned" == "true" ]]; then
      reason_codes="$(echo "$reason_codes" | jq --arg f "${family^^}" '. + ["METADATA_ALREADY_ALIGNED_\($f)"]')"
      continue
    fi
    reason_codes="$(echo "$reason_codes" | jq --arg f "${family^^}" '. + ["METADATA_MUTATION_\($f)"]')"
    actions="$(echo "$actions" | jq --arg fam "$family" --arg add "$target" --argjson rm "$existing" '. + [{"type":"metadata_replace","family":$fam,"remove":$rm,"add":$add}]')"
    if [[ "$FREEZE_WINDOW" == "true" && "$ALLOW_FREEZE_OVERRIDE" != "true" ]]; then
      reason_codes="$(echo "$reason_codes" | jq '. + ["POLICY_FREEZE_WINDOW_BLOCK"]')"
      freeze_block_count=$((freeze_block_count + 1))
    fi
  done

  entry="$(jq -n \
    --argjson n "$number" \
    --arg u "$url" \
    --arg t "$title" \
    --argjson rc "$reason_codes" \
    --argjson ac "$actions" \
    '{issueNumber:$n, issueUrl:$u, title:$t, reasonCodes:$rc, actions:$ac}')"
  jq --argjson e "$entry" '. + [$e]' "$tmp/plan.json" > "$tmp/plan.next.json"
  mv "$tmp/plan.next.json" "$tmp/plan.json"
done

if [[ $freeze_block_count -gt 0 ]]; then
  jq -n --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --arg repo "$REPO" --arg project "$PROJECT_TITLE" \
    '{generatedAt:$ts, repo:$repo, project:$project, freezeWindow:true, blocked:true, operations:[]}' > "$ROLLBACK_ARTIFACT_PATH"
  cp "$tmp/plan.json" "$CHANGE_LOG_PATH"
  echo "POLICY_FREEZE_WINDOW_BLOCK: metadata mutation blocked; rerun with --allow-freeze-override." >&2
  exit 1
fi

added=0
updated=0
skipped=0
jq -n '[]' > "$tmp/rollback.json"

plan_count="$(jq 'length' "$tmp/plan.json")"
for ((i=0; i<plan_count; i++)); do
  entry="$(jq -c ".[$i]" "$tmp/plan.json")"
  number="$(echo "$entry" | jq -r '.issueNumber')"
  title="$(echo "$entry" | jq -r '.title')"
  changed=false
  action_count="$(echo "$entry" | jq '.actions | length')"

  for ((j=0; j<action_count; j++)); do
    action="$(echo "$entry" | jq -c ".actions[$j]")"
    action_type="$(echo "$action" | jq -r '.type')"

    if [[ "$action_type" == "project_add" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[dry-run] add #$number $title"
      else
        content_node_id="$(gh api "repos/$REPO/issues/$number" --jq '.node_id' 2>/dev/null)"
        new_item_id="$(gh_api_with_retry gh api graphql -f query='
          mutation($projectId: ID!, $contentId: ID!) {
            addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) { item { id } }
          }
        ' -f projectId="$project_node_id" -f contentId="$content_node_id" --jq '.data.addProjectV2ItemById.item.id' 2>/dev/null || true)"
        if [[ -n "$new_item_id" && "$new_item_id" != "null" ]]; then
          to_option_id="$(echo "$action" | jq -r '.toOptionId')"
          gh_api_with_retry gh api graphql -f query='
            mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
              updateProjectV2ItemFieldValue(input: {
                projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
              }) { projectV2Item { id } }
            }
          ' -f projectId="$project_node_id" -f itemId="$new_item_id" -f fieldId="$status_field_id" -f optionId="$to_option_id" >/dev/null 2>&1 || true
          jq --arg id "$new_item_id" --argjson n "$number" '. + [{"type":"project_remove","itemId":$id,"issueNumber":$n}]' "$tmp/rollback.json" > "$tmp/rollback.next.json"
          mv "$tmp/rollback.next.json" "$tmp/rollback.json"
        fi
      fi
      added=$((added + 1))
      changed=true
      continue
    fi

    if [[ "$action_type" == "status_update" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[dry-run] update status #$number $title"
      else
        item_id="$(echo "$action" | jq -r '.itemId')"
        to_option_id="$(echo "$action" | jq -r '.toOptionId')"
        from_option_id="$(echo "$action" | jq -r '.fromOptionId')"
        gh_api_with_retry gh api graphql -f query='
          mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
            updateProjectV2ItemFieldValue(input: {
              projectId: $projectId, itemId: $itemId, fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
            }) { projectV2Item { id } }
          }
        ' -f projectId="$project_node_id" -f itemId="$item_id" -f fieldId="$status_field_id" -f optionId="$to_option_id" >/dev/null 2>&1 || true
        if [[ -n "$from_option_id" ]]; then
          jq --arg id "$item_id" --arg opt "$from_option_id" --argjson n "$number" '. + [{"type":"status_restore","itemId":$id,"optionId":$opt,"issueNumber":$n}]' "$tmp/rollback.json" > "$tmp/rollback.next.json"
          mv "$tmp/rollback.next.json" "$tmp/rollback.json"
        fi
      fi
      updated=$((updated + 1))
      changed=true
      continue
    fi

    if [[ "$action_type" == "metadata_replace" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        echo "[dry-run] metadata #$number $(echo "$action" | jq -r '.family')"
      else
        while IFS= read -r rm; do
          [[ -z "$rm" || "$rm" == "null" ]] && continue
          gh_api_with_retry gh issue edit "$number" --repo "$REPO" --remove-label "$rm" >/dev/null 2>&1 || true
          jq --argjson n "$number" --arg label "$rm" '. + [{"type":"label_add","issueNumber":$n,"label":$label}]' "$tmp/rollback.json" > "$tmp/rollback.next.json"
          mv "$tmp/rollback.next.json" "$tmp/rollback.json"
        done < <(echo "$action" | jq -r '.remove[]?')
        add_label="$(echo "$action" | jq -r '.add')"
        gh_api_with_retry gh issue edit "$number" --repo "$REPO" --add-label "$add_label" >/dev/null 2>&1 || true
        jq --argjson n "$number" --arg label "$add_label" '. + [{"type":"label_remove","issueNumber":$n,"label":$label}]' "$tmp/rollback.json" > "$tmp/rollback.next.json"
        mv "$tmp/rollback.next.json" "$tmp/rollback.json"
      fi
      updated=$((updated + 1))
      changed=true
      continue
    fi
  done

  if [[ "$changed" != "true" ]]; then
    skipped=$((skipped + 1))
  fi
done

jq -n \
  --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg repo "$REPO" \
  --arg project "$PROJECT_TITLE" \
  --argjson dry "$([[ "$DRY_RUN" == "true" ]] && echo true || echo false)" \
  --argjson freeze "$([[ "$FREEZE_WINDOW" == "true" ]] && echo true || echo false)" \
  --argjson ops "$(cat "$tmp/rollback.json")" \
  --argjson added "$added" \
  --argjson updated "$updated" \
  --argjson skipped "$skipped" \
  '{generatedAt:$ts, repo:$repo, project:$project, dryRun:$dry, freezeWindow:$freeze, operations:$ops, summary:{added:$added, updated:$updated, skipped:$skipped}}' > "$ROLLBACK_ARTIFACT_PATH"

cp "$tmp/plan.json" "$CHANGE_LOG_PATH"

echo
echo "Sync complete: added=$added updated=$updated skipped=$skipped"
echo "Rollback artifact: $ROLLBACK_ARTIFACT_PATH"
echo "Change log: $CHANGE_LOG_PATH"
if [[ $added -eq 0 && $updated -eq 0 ]]; then
  echo "No changes required -- board is already aligned with rebalance plan."
fi
