#!/usr/bin/env bash
# project-sync.sh — Idempotent backlog-rebalance-engine project sync
# Onboards rebalanced issues into a GitHub Project board and aligns item status.
# Emits a sync report: added=<n> updated=<n> skipped=<n>
#
# Usage:
#   ./project-sync.sh --owner <org> --project <title> --repo <owner/repo> \
#     [--label <sprint:N>] [--issue-list <file>] [--dry-run]

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)        OWNER="$2";             shift 2 ;;
    --project)      PROJECT_TITLE="$2";     shift 2 ;;
    --repo)         REPO="$2";              shift 2 ;;
    --label)        FILTER_LABEL="$2";      shift 2 ;;
    --issue-list)   ISSUE_LIST_FILE="$2";   shift 2 ;;
    --status-open)  STATUS_OPEN="$2";       shift 2 ;;
    --status-closed) STATUS_CLOSED="$2";   shift 2 ;;
    --dry-run)      DRY_RUN=true;           shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$OWNER" || -z "$PROJECT_TITLE" || -z "$REPO" ]]; then
  echo "Usage: $0 --owner <org> --project <title> --repo <owner/repo> [--label <sprint:N>] [--issue-list <file>] [--dry-run]" >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Resolve project node ID
echo "Resolving project: '$PROJECT_TITLE' for owner '$OWNER'..."
PROJECT_DATA=$(gh project list --owner "$OWNER" --format json --limit 100 2>/dev/null)
PROJECT_NUMBER=$(echo "$PROJECT_DATA" | jq -r --arg title "$PROJECT_TITLE" \
  '.projects[] | select(.title == $title) | .number' | head -1)

if [[ -z "$PROJECT_NUMBER" ]]; then
  echo "Project not found: $PROJECT_TITLE" >&2
  exit 1
fi

PROJECT_NODE_ID=$(gh api graphql -f query='
  query($owner: String!, $number: Int!) {
    organization(login: $owner) {
      projectV2(number: $number) { id }
    }
  }
' -f owner="$OWNER" -F number="$PROJECT_NUMBER" --jq '.data.organization.projectV2.id' 2>/dev/null || \
gh api graphql -f query='
  query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) { id }
    }
  }
' -f owner="$OWNER" -F number="$PROJECT_NUMBER" --jq '.data.user.projectV2.id')

if [[ -z "$PROJECT_NODE_ID" ]]; then
  echo "Could not resolve project node ID for project number $PROJECT_NUMBER." >&2
  exit 1
fi

# Resolve Status field ID and option IDs
echo "Resolving Status field..."
FIELDS_JSON=$(gh api graphql -f query='
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
' -f id="$PROJECT_NODE_ID" --jq '.data.node.fields.nodes')

STATUS_FIELD_ID=$(echo "$FIELDS_JSON" | jq -r '.[] | select(.name == "Status") | .id')
OPTION_OPEN_ID=$(echo "$FIELDS_JSON" | jq -r \
  --arg s "$STATUS_OPEN" '.[] | select(.name == "Status") | .options[] | select(.name == $s) | .id')
OPTION_CLOSED_ID=$(echo "$FIELDS_JSON" | jq -r \
  --arg s "$STATUS_CLOSED" '.[] | select(.name == "Status") | .options[] | select(.name == $s) | .id')

if [[ -z "$STATUS_FIELD_ID" ]]; then
  echo "Status field not found in project." >&2
  exit 1
fi
if [[ -z "$OPTION_OPEN_ID" ]]; then
  echo "Status option not found: $STATUS_OPEN" >&2
  exit 1
fi
if [[ -z "$OPTION_CLOSED_ID" ]]; then
  echo "Status option not found: $STATUS_CLOSED" >&2
  exit 1
fi

# Snapshot current board items
echo "Fetching current project items..."
gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 2000 \
  > "$TMP/board.json" 2>/dev/null || echo '{"items":[]}' > "$TMP/board.json"

# Resolve rebalance issue list
if [[ -n "$ISSUE_LIST_FILE" ]]; then
  cp "$ISSUE_LIST_FILE" "$TMP/issues.json"
else
  LABEL_ARGS=()
  if [[ -n "$FILTER_LABEL" ]]; then
    LABEL_ARGS=(--label "$FILTER_LABEL")
  fi
  gh issue list --repo "$REPO" --state all --limit 500 "${LABEL_ARGS[@]}" \
    --json number,url,title,state > "$TMP/issues.json"
fi

# Build board lookup: url -> {itemId, statusOptionId}
jq -r '.items[] | [.content.url, .id, .fieldValues.nodes[]? | select(.field.name == "Status") | .optionId // ""] | @tsv' \
  "$TMP/board.json" 2>/dev/null > "$TMP/board-lookup.tsv" || true

declare -A BOARD_ITEM_IDS
declare -A BOARD_ITEM_STATUS

while IFS=$'\t' read -r url item_id option_id; do
  [[ -z "$url" ]] && continue
  BOARD_ITEM_IDS["$url"]="$item_id"
  BOARD_ITEM_STATUS["$url"]="$option_id"
done < "$TMP/board-lookup.tsv"

# Process issues
ADDED=0
UPDATED=0
SKIPPED=0
ADDED_LIST=()
UPDATED_LIST=()

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

ISSUES=$(jq -c '.[]' "$TMP/issues.json")

while IFS= read -r issue; do
  number=$(echo "$issue" | jq -r '.number')
  url=$(echo "$issue" | jq -r '.url')
  title=$(echo "$issue" | jq -r '.title')
  state=$(echo "$issue" | jq -r '.state')

  expected_option_id="$OPTION_OPEN_ID"
  expected_status_name="$STATUS_OPEN"
  if [[ "$state" == "CLOSED" ]]; then
    expected_option_id="$OPTION_CLOSED_ID"
    expected_status_name="$STATUS_CLOSED"
  fi

  if [[ -z "${BOARD_ITEM_IDS[$url]+_}" ]]; then
    # Item not on board — add
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] add #$number $title"
    else
      NEW_ITEM_ID=$(gh_api_with_retry gh api graphql -f query='
        mutation($projectId: ID!, $contentId: ID!) {
          addProjectV2ItemById(input: { projectId: $projectId, contentId: $contentId }) {
            item { id }
          }
        }
      ' -f projectId="$PROJECT_NODE_ID" -f contentId="$(gh api repos/"$REPO"/issues/"$number" --jq '.node_id')" \
        --jq '.data.addProjectV2ItemById.item.id' 2>/dev/null || echo "")

      if [[ -n "$NEW_ITEM_ID" ]]; then
        # Set initial status
        gh_api_with_retry gh api graphql -f query='
          mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
            updateProjectV2ItemFieldValue(input: {
              projectId: $projectId, itemId: $itemId,
              fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
            }) { projectV2Item { id } }
          }
        ' -f projectId="$PROJECT_NODE_ID" -f itemId="$NEW_ITEM_ID" \
          -f fieldId="$STATUS_FIELD_ID" -f optionId="$expected_option_id" > /dev/null 2>&1 || true
      fi
    fi
    ADDED=$((ADDED + 1))
    ADDED_LIST+=("#$number  $title")

  elif [[ "${BOARD_ITEM_STATUS[$url]}" != "$expected_option_id" ]]; then
    # Item on board with wrong status — update
    item_id="${BOARD_ITEM_IDS[$url]}"
    old_option="${BOARD_ITEM_STATUS[$url]}"
    old_name=$(echo "$FIELDS_JSON" | jq -r \
      --arg o "$old_option" '.[] | select(.name == "Status") | .options[] | select(.id == $o) | .name' 2>/dev/null || echo "unknown")

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] update #$number $title ($old_name -> $expected_status_name)"
    else
      gh_api_with_retry gh api graphql -f query='
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projectId, itemId: $itemId,
            fieldId: $fieldId, value: { singleSelectOptionId: $optionId }
          }) { projectV2Item { id } }
        }
      ' -f projectId="$PROJECT_NODE_ID" -f itemId="$item_id" \
        -f fieldId="$STATUS_FIELD_ID" -f optionId="$expected_option_id" > /dev/null 2>&1 || true
    fi
    UPDATED=$((UPDATED + 1))
    UPDATED_LIST+=("#$number  $title  ($old_name -> $expected_status_name)")

  else
    # Already in sync — skip
    SKIPPED=$((SKIPPED + 1))
  fi
done <<< "$ISSUES"

# Emit sync report
echo ""
echo "Sync complete: added=$ADDED updated=$UPDATED skipped=$SKIPPED"

if [[ ${#ADDED_LIST[@]} -gt 0 ]]; then
  echo ""
  echo "Added items:"
  for item in "${ADDED_LIST[@]}"; do echo "  $item"; done
fi

if [[ ${#UPDATED_LIST[@]} -gt 0 ]]; then
  echo ""
  echo "Updated items:"
  for item in "${UPDATED_LIST[@]}"; do echo "  $item"; done
fi

if [[ $ADDED -eq 0 && $UPDATED -eq 0 ]]; then
  echo "No changes required -- board is already aligned with rebalance plan."
fi
