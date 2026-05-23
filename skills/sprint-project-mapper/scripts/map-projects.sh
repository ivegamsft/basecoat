#!/usr/bin/env bash
set -euo pipefail

REPO=""
LIMIT=300
MERGE_THRESHOLD=0.65

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --merge-threshold) MERGE_THRESHOLD="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
fi
if [[ -z "$REPO" ]]; then
  echo "Could not resolve repo. Pass --repo owner/repo." >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Collecting issues and PRs from $REPO..."
gh issue list --repo "$REPO" --state all --limit "$LIMIT" \
  --json number,title,labels,state,createdAt,closedAt > "$TMP/issues.json"
gh pr list --repo "$REPO" --state all --limit "$LIMIT" \
  --json number,title,labels,state,createdAt,mergedAt,author,additions,deletions > "$TMP/prs.json"

# Build normalized record set for grouping
jq '
def normlabel:
  ascii_downcase
  | if test("^sprint[:/\\-]?[0-9]+$") then "sprint:" + (capture("([0-9]+)$")[0])
    elif test("^wave[:/\\-]?[0-9]+$") then "wave:" + (capture("([0-9]+)$")[0])
    elif test("^(project|proj|epic|initiative)[:/\\-].+$") then "project:" + (split(":")[-1] // split("/")[-1] // .)
    elif test("^area/.+$") then .
    elif test("^(priority|type)/.+$") then .
    else empty end;

def first_match(arr; pat):
  (arr | map(select(test(pat))) | .[0]);

[
  .[] | {
    kind: "issue",
    number,
    title,
    state,
    createdAt,
    closedAt,
    tags: ((.labels // []) | map(.name | normlabel)),
    group: (
      ((.labels // []) | map(.name | normlabel)) as $t
      | [
          first_match($t; "^project:"),
          first_match($t; "^sprint:"),
          first_match($t; "^wave:"),
          first_match($t; "^area/")
        ]
      | map(select(. != null))
      | if length == 0 then ["unmapped"] else . end
      | join("|")
    )
  }
]' "$TMP/issues.json" > "$TMP/grouped-issues.json"

jq '
[
  .[] | {
    kind: "pr",
    number,
    title,
    state,
    mergedAt,
    additions,
    deletions,
    loc: ((.additions // 0) + (.deletions // 0)),
    tags: ((.labels // []) | map(.name | ascii_downcase))
  }
]' "$TMP/prs.json" > "$TMP/grouped-prs.json"

# Aggregate issue-first groups
jq -s '
  (.[0] | group_by(.group) | map({
    group: .[0].group,
    issue_count: length,
    closed_count: map(select(.state == "CLOSED")) | length,
    tags: (map(.tags[]) | unique)
  })) as $groups
  |
  (.[1]) as $prs
  |
  $groups
  | map(
      . as $g
      | . + {
          pr_count: (
            $prs
            | map(select(((.tags | join(",")) | contains(($g.tags | join(","))))) )
            | length
          ),
          merged_pr_count: (
            $prs
            | map(select(.mergedAt != null and ((.tags | join(",")) | contains(($g.tags | join(","))))))
            | length
          ),
          loc_changed: (
            $prs
            | map(select(((.tags | join(",")) | contains(($g.tags | join(","))))) | .loc)
            | add // 0
          )
      }
    )
' "$TMP/grouped-issues.json" "$TMP/grouped-prs.json" > "$TMP/report.json"

echo ""
echo "=== Sprint/Project Mapping Report: $REPO ==="
jq -r '
  .[]
  | .significant = (((.issue_count >= 5 or .merged_pr_count >= 3) and (.loc_changed >= 200 or (.group|test("sprint:|wave:|project:")))))
  | [ .group, (.issue_count|tostring), (.pr_count|tostring), (.merged_pr_count|tostring), (.loc_changed|tostring), (.closed_count|tostring), (.significant|tostring) ]
  | @tsv
' "$TMP/report.json" | awk 'BEGIN{print "Group\tIssues\tPRs\tMergedPRs\tLOC\tClosed\tSignificant"} {print}'

echo ""
echo "=== Release-note-ready groups ==="
jq -r '
  .[]
  | .significant = (((.issue_count >= 5 or .merged_pr_count >= 3) and (.loc_changed >= 200 or (.group|test("sprint:|wave:|project:")))))
  | select(.significant == true)
  | "- **\(.group)**: \(.issue_count) issues, \(.merged_pr_count) merged PRs, \(.loc_changed) LOC changed."
' "$TMP/report.json"

echo ""
echo "=== Debate Guidance ==="
echo "Use references/metrics-formulas.md similarity + confidence rules to decide merge vs split for adjacent groups."

