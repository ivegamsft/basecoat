#!/usr/bin/env bash
# triage-issues.sh — Automated GitHub issue triage (bash equivalent of triage-issues.ps1)
#
# Usage:
#   bash triage-issues.sh [--repo owner/repo] [--scope open|closed|all] [--issue N] [--dry-run] [--limit N]
#
# Requires: gh CLI, jq, awk

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
REPO=""
SCOPE="open"
ISSUE_NUMBER=0
DRY_RUN=false
LIMIT=100
ACTION_COUNT=0
CLOSE_COUNT=0
REOPEN_COUNT=0
LABEL_COUNT=0
COMMENT_COUNT=0
HUMAN_REVIEW=()

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)    REPO="$2";           shift 2 ;;
    --scope)   SCOPE="$2";          shift 2 ;;
    --issue)   ISSUE_NUMBER="$2";   shift 2 ;;
    --dry-run) DRY_RUN=true;        shift ;;
    --limit)   LIMIT="$2";          shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Resolve repo from git remote if not provided
if [[ -z "$REPO" ]]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)
  if [[ -z "$REPO" ]]; then
    echo "Error: could not determine repo. Pass --repo owner/repo" >&2
    exit 1
  fi
fi

echo ""
echo "=== Issue Triage — $REPO ==="
[[ "$DRY_RUN" == "true" ]] && echo "[DRY-RUN MODE — no changes will be written]"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

invoke_gh() {
  local action_type="$1"; shift
  if [[ "$DRY_RUN" == "true" ]] && [[ "$action_type" == "write" ]]; then
    echo "[DRY-RUN] gh $*" >&2
    return 0
  fi
  gh "$@" 2>/dev/null || true
}

add_label() {
  local n="$1" label="$2" reason="$3"
  echo "  [+label] #$n ← $label ($reason)"
  invoke_gh write issue edit "$n" --repo "$REPO" --add-label "$label"
  ((LABEL_COUNT++)) || true
  ((ACTION_COUNT++)) || true
}

remove_label_from_issue() {
  local n="$1" label="$2" reason="$3"
  echo "  [-label] #$n ← remove $label ($reason)"
  invoke_gh write issue edit "$n" --repo "$REPO" --remove-label "$label"
  ((ACTION_COUNT++)) || true
}

post_comment() {
  local n="$1" body="$2" reason="$3"
  echo "  [comment] #$n — $reason"
  invoke_gh write issue comment "$n" --repo "$REPO" --body "$body"
  ((COMMENT_COUNT++)) || true
  ((ACTION_COUNT++)) || true
}

close_issue() {
  local n="$1" reason="$2" comment="$3"
  echo "  [close] #$n — $reason"
  [[ -n "$comment" ]] && post_comment "$n" "$comment" "$reason"
  invoke_gh write issue close "$n" --repo "$REPO"
  ((CLOSE_COUNT++)) || true
  ((ACTION_COUNT++)) || true
}

reopen_issue() {
  local n="$1" reason="$2" comment="$3"
  echo "  [reopen] #$n — $reason"
  [[ -n "$comment" ]] && post_comment "$n" "$comment" "$reason"
  invoke_gh write issue reopen "$n" --repo "$REPO"
  ((REOPEN_COUNT++)) || true
  ((ACTION_COUNT++)) || true
}

flag_for_human() {
  local n="$1" reason="$2"
  echo "  [flag] #$n → needs human review: $reason"
  HUMAN_REVIEW+=("#$n: $reason")
}

# Token overlap (Jaccard) — basic awk implementation
token_overlap() {
  local a="${1,,}" b="${2,,}"
  echo "$a $b" | awk '
  {
    n = split($0, words, /[ ,.:;!?\t\n]+/)
    stop["the"]=1;stop["a"]=1;stop["an"]=1;stop["is"]=1;stop["it"]=1;stop["in"]=1
    stop["on"]=1;stop["at"]=1;stop["to"]=1;stop["for"]=1;stop["of"]=1;stop["and"]=1
    stop["or"]=1;stop["but"]=1;stop["with"]=1;stop["that"]=1;stop["this"]=1
    stop["fix"]=1;stop["issue"]=1;stop["bug"]=1;stop["error"]=1;stop["help"]=1
    for (i=1;i<=n;i++) {
      w = words[i]
      if (length(w) > 2 && !stop[w]) all[w]++
    }
    mid = int(n/2)
    for (i=1;i<=mid;i++) { w = words[i]; if (length(w)>2 && !stop[w]) setA[w]=1 }
    for (i=mid+1;i<=n;i++) { w = words[i]; if (length(w)>2 && !stop[w]) setB[w]=1 }
    inter = 0
    for (w in setA) if (setB[w]) inter++
    union_size = 0
    for (w in all) union_size++
    if (union_size > 0) printf "%.2f\n", inter/union_size
    else print "0.00"
  }'
}

# ---------------------------------------------------------------------------
# Fetch issues
# ---------------------------------------------------------------------------
ISSUE_JSON_FILE=$(mktemp)
trap "rm -f $ISSUE_JSON_FILE" EXIT

if [[ "$ISSUE_NUMBER" -gt 0 ]]; then
  gh issue view "$ISSUE_NUMBER" --repo "$REPO" \
    --json number,title,body,labels,state,closedAt,createdAt,assignees > "$ISSUE_JSON_FILE"
  ISSUES_ARRAY="[$(<"$ISSUE_JSON_FILE")]"
else
  FETCH_STATE=("open")
  [[ "$SCOPE" == "closed" ]] && FETCH_STATE=("closed")
  [[ "$SCOPE" == "all" ]]    && FETCH_STATE=("open" "closed")

  ISSUES_ARRAY="[]"
  for STATE in "${FETCH_STATE[@]}"; do
    BATCH=$(gh issue list --repo "$REPO" --state "$STATE" --limit "$LIMIT" \
      --json number,title,body,labels,state,closedAt,createdAt,assignees 2>/dev/null || echo "[]")
    ISSUES_ARRAY=$(jq -s 'add' <(echo "$ISSUES_ARRAY") <(echo "$BATCH"))
  done

  # Filter closed to last 30 days
  if [[ "$SCOPE" != "open" ]]; then
    CUTOFF=$(date -u -d "30 days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
             date -u -v-30d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
             echo "")
    if [[ -n "$CUTOFF" ]]; then
      ISSUES_ARRAY=$(echo "$ISSUES_ARRAY" | jq --arg cutoff "$CUTOFF" \
        '[.[] | select(.state == "OPEN" or (.closedAt != null and .closedAt > $cutoff))]')
    fi
  fi
fi

ISSUE_COUNT=$(echo "$ISSUES_ARRAY" | jq 'length')
echo "Fetched $ISSUE_COUNT issues to triage."
echo ""

TYPE_LABELS=("bug" "enhancement" "documentation" "chore" "security" "question")
PRIORITY_LABELS=("priority/critical" "priority/high" "priority/medium" "priority/low")
BAD_TITLES=("bug" "fix" "issue" "help" "todo" "test" "asdf" "qwerty" "untitled" "new issue" "please fix" "broken" "error")

# ---------------------------------------------------------------------------
# Process each issue
# ---------------------------------------------------------------------------
for i in $(seq 0 $((ISSUE_COUNT - 1))); do
  ISSUE_OBJ=$(echo "$ISSUES_ARRAY" | jq ".[$i]")
  N=$(echo "$ISSUE_OBJ" | jq -r '.number')
  TITLE=$(echo "$ISSUE_OBJ" | jq -r '.title')
  BODY=$(echo "$ISSUE_OBJ" | jq -r '.body // ""')
  STATE=$(echo "$ISSUE_OBJ" | jq -r '.state')
  LABELS=$(echo "$ISSUE_OBJ" | jq -r '[.labels[].name] | join(",")')
  CREATED_AT=$(echo "$ISSUE_OBJ" | jq -r '.createdAt')
  CLOSED_AT=$(echo "$ISSUE_OBJ" | jq -r '.closedAt // ""')
  IS_OPEN=$([[ "$STATE" == "OPEN" || "$STATE" == "open" ]] && echo "true" || echo "false")

  echo "--- #$N: $TITLE ---"

  # -------------------------------------------------------------------------
  # Check 1: Validity
  # -------------------------------------------------------------------------
  TITLE_LOWER="${TITLE,,}"
  TITLE_LEN=${#TITLE}
  BODY_LEN=${#BODY}
  IS_BAD_TITLE=false
  for bt in "${BAD_TITLES[@]}"; do
    [[ "$TITLE_LOWER" == "$bt" ]] && IS_BAD_TITLE=true && break
  done
  [[ "$TITLE_LEN" -lt 5 ]] && IS_BAD_TITLE=true
  [[ "$BODY_LEN" -lt 20 && "$IS_OPEN" == "true" ]] && IS_BAD_TITLE=true

  if [[ "$IS_BAD_TITLE" == "true" && "$IS_OPEN" == "true" ]]; then
    close_issue "$N" "Invalid: title/body is gibberish or unactionable" \
      "Closing as invalid: the title or body does not contain enough information to act on. Please reopen with a clear description, steps to reproduce, and expected/actual behavior."
    add_label "$N" "invalid" "Issue is unactionable"
    continue
  fi

  # Reopen wrongly closed valid issues
  if [[ "$IS_OPEN" == "false" ]] && echo "$LABELS" | grep -q "invalid"; then
    if echo "$BODY" | grep -qi "steps to reproduce\|expected\|actual\|error\|stack trace" && [[ "$BODY_LEN" -gt 100 ]]; then
      reopen_issue "$N" "Reopening: was closed invalid but contains valid reproduction steps" \
        "Reopening: this issue was closed as invalid but contains valid reproduction steps. Please re-triage."
      remove_label_from_issue "$N" "invalid" "Issue is valid"
      add_label "$N" "needs-triage" "Needs re-triage after reopen"
    fi
  fi

  # Missing required fields
  if [[ "$IS_OPEN" == "true" && "$BODY_LEN" -lt 50 ]]; then
    add_label "$N" "needs-info" "Body too short"
    post_comment "$N" "This issue needs more detail:\n- [ ] Description of the problem\n- [ ] Steps to reproduce (for bugs)\n- [ ] Expected vs actual behavior\n- [ ] Environment (OS, version, etc.)" "needs-info comment"
  fi

  # -------------------------------------------------------------------------
  # Check 2: Duplicate Detection
  # -------------------------------------------------------------------------
  if [[ "$IS_OPEN" == "true" ]]; then
    SEARCH_TERMS=$(echo "$TITLE" | tr ' ' '+' | tr -cd 'a-zA-Z0-9+')
    CANDIDATES=$(gh issue list --repo "$REPO" --state open --search "$SEARCH_TERMS" \
      --json number,title 2>/dev/null || echo "[]")
    CANDIDATE_COUNT=$(echo "$CANDIDATES" | jq 'length')

    for j in $(seq 0 $((CANDIDATE_COUNT - 1))); do
      CAND_N=$(echo "$CANDIDATES" | jq -r ".[$j].number")
      CAND_TITLE=$(echo "$CANDIDATES" | jq -r ".[$j].title")
      [[ "$CAND_N" == "$N" ]] && continue

      OVERLAP=$(token_overlap "$TITLE" "$CAND_TITLE")
      OVERLAP_INT=$(echo "$OVERLAP * 100" | awk '{printf "%d", $1}')

      if [[ "$OVERLAP_INT" -gt 80 ]]; then
        CANONICAL=$([[ "$N" -lt "$CAND_N" ]] && echo "$N" || echo "$CAND_N")
        DUP=$([[ "$N" -gt "$CAND_N" ]] && echo "$N" || echo "$CAND_N")
        if [[ "$DUP" == "$N" ]]; then
          close_issue "$N" "Duplicate of #$CANONICAL (overlap $OVERLAP)" \
            "Duplicate of #$CANONICAL — closing in favor of the original tracker. All updates should go to #$CANONICAL."
          add_label "$N" "duplicate" "Token overlap $OVERLAP"
        fi
        break
      elif [[ "$OVERLAP_INT" -gt 50 ]]; then
        flag_for_human "$N" "Possible duplicate of #$CAND_N (overlap $OVERLAP)"
      fi
    done
  fi

  # -------------------------------------------------------------------------
  # Check 3: Closed Issue Verification
  # -------------------------------------------------------------------------
  if [[ "$IS_OPEN" == "false" ]] && \
     ! echo "$LABELS" | grep -qE "wontfix|duplicate|invalid"; then
    LINKED_PRS=$(gh pr list --repo "$REPO" --state merged \
      --search "closes #$N fixes #$N resolves #$N" \
      --json number 2>/dev/null || echo "[]")
    PR_COUNT=$(echo "$LINKED_PRS" | jq 'length')
    if [[ "$PR_COUNT" -eq 0 ]]; then
      reopen_issue "$N" "Closed without merged PR or resolution evidence" \
        "Reopening: no merged pull request was found that closes this issue. If resolved another way, please add a comment with the evidence."
      add_label "$N" "needs-verification" "No linked PR found"
    fi
  fi

  # -------------------------------------------------------------------------
  # Check 4: Label and Type Enforcement
  # -------------------------------------------------------------------------
  if [[ "$IS_OPEN" == "true" ]]; then
    HAS_TYPE=false
    HAS_PRIORITY=false
    for lbl in "${TYPE_LABELS[@]}"; do
      echo "$LABELS" | grep -q "^$lbl$\|,$lbl$\|^$lbl,\|,$lbl," && HAS_TYPE=true && break
    done
    for lbl in "${PRIORITY_LABELS[@]}"; do
      echo "$LABELS" | grep -q "$lbl" && HAS_PRIORITY=true && break
    done

    INFERRED_TYPE=""
    if [[ "$HAS_TYPE" == "false" ]]; then
      if echo "$TITLE $BODY" | grep -qiE "error|crash|fail|broken|regression|wrong|incorrect"; then
        INFERRED_TYPE="bug"
      elif echo "$TITLE" | grep -qiE "add|support|allow|feature|request|improve|enhance|new"; then
        INFERRED_TYPE="enhancement"
      elif echo "$TITLE" | grep -qiE "doc|readme|guide|typo|spelling|documentation"; then
        INFERRED_TYPE="documentation"
      elif echo "$TITLE $BODY" | grep -qiE "CVE|vuln|secret|injection|XSS|CSRF|security"; then
        INFERRED_TYPE="security"
      elif echo "$TITLE" | grep -qiE "refactor|cleanup|debt|upgrade|bump|chore|dependency"; then
        INFERRED_TYPE="chore"
      elif echo "$TITLE" | grep -qiE "how|why|what|clarify|explain|question"; then
        INFERRED_TYPE="question"
      fi

      if [[ -n "$INFERRED_TYPE" ]]; then
        add_label "$N" "$INFERRED_TYPE" "Inferred from title/body"
      else
        add_label "$N" "needs-triage" "Missing type label — could not infer"
        post_comment "$N" "This issue is missing a type label. Please apply one of: \`bug\`, \`enhancement\`, \`documentation\`, \`chore\`, \`security\`, or \`question\`." "missing type"
      fi
    fi

    if [[ "$HAS_PRIORITY" == "false" ]]; then
      if [[ "$INFERRED_TYPE" == "security" ]] || echo "$LABELS" | grep -q "security"; then
        add_label "$N" "priority/critical" "Security auto-escalation"
        post_comment "$N" "Priority escalated to **critical**: security issues are automatically assigned critical priority per triage policy." "auto-escalate security"
      else
        add_label "$N" "needs-triage" "Missing priority label"
      fi
    fi
  fi

  # -------------------------------------------------------------------------
  # Check 5: Title Quality
  # -------------------------------------------------------------------------
  if [[ "$IS_OPEN" == "true" ]]; then
    TITLE_BAD=false
    [[ "$TITLE_LEN" -lt 10 ]] && TITLE_BAD=true
    for bt in "${BAD_TITLES[@]}"; do
      [[ "$TITLE_LOWER" == "$bt" ]] && TITLE_BAD=true && break
    done
    echo "$TITLE" | grep -qE '^\s*[a-z]{1,6}\s*$' && TITLE_BAD=true

    if [[ "$TITLE_BAD" == "true" ]]; then
      SUGGESTED=$(echo "$BODY" | grep -m1 '.\{10\}' | cut -c1-80 || echo "Please provide a descriptive title")
      post_comment "$N" "**Title improvement suggested**\n\nThe current title \`$TITLE\` is too generic.\n\nSuggested: \`$SUGGESTED\`\n\nPlease update the title. The agent will not rename it automatically." "poor title"
    fi
  fi

  # -------------------------------------------------------------------------
  # Check 7: Relationship Audit
  # -------------------------------------------------------------------------
  if [[ "$IS_OPEN" == "true" ]] && echo "$BODY" | grep -qE '#[0-9]+'; then
    if ! echo "$BODY" | grep -qiE "blocked by|depends on|part of|closes|fixes|resolves|duplicate of|related to"; then
      REF_ISSUE=$(echo "$BODY" | grep -oE '#[0-9]+' | head -1)
      post_comment "$N" "This issue references $REF_ISSUE without a relationship keyword. Consider adding: \`Blocked by $REF_ISSUE\`, \`Depends on $REF_ISSUE\`, \`Part of $REF_ISSUE\`, or \`Related to $REF_ISSUE\`." "missing relationship keyword"
    fi
    echo "$BODY" | grep -qiE "blocked by #[0-9]+" && add_label "$N" "blocked" "Blocked by referenced issue"
  fi

  # -------------------------------------------------------------------------
  # Check 8: Branch Connection
  # -------------------------------------------------------------------------
  if [[ "$IS_OPEN" == "true" ]]; then
    MATCHED_BRANCH=$(gh api "repos/$REPO/branches" --paginate --jq '.[].name' 2>/dev/null | \
      grep -E "^(feat|fix|chore|copilot)/$N-" | head -1 || true)
    if [[ -n "$MATCHED_BRANCH" ]]; then
      PR_FOR_BRANCH=$(gh pr list --repo "$REPO" --head "$MATCHED_BRANCH" --json number 2>/dev/null || echo "[]")
      PR_BR_COUNT=$(echo "$PR_FOR_BRANCH" | jq 'length')
      if [[ "$PR_BR_COUNT" -eq 0 ]]; then
        post_comment "$N" "**Open branch found without a linked PR**\n\nBranch \`$MATCHED_BRANCH\` exists but no pull request is linked.\n\nTo create one:\n\`\`\`bash\ngh pr create --head $MATCHED_BRANCH --base main --title \"$TITLE\" --body \"Closes #$N\"\n\`\`\`" "branch without PR"
      fi
    fi
  fi

  # -------------------------------------------------------------------------
  # Check 9: Priority Review
  # -------------------------------------------------------------------------
  if [[ "$IS_OPEN" == "true" ]]; then
    NOW_EPOCH=$(date +%s)
    CREATED_EPOCH=$(date -d "$CREATED_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED_AT" +%s 2>/dev/null || echo "$NOW_EPOCH")
    AGE_DAYS=$(( (NOW_EPOCH - CREATED_EPOCH) / 86400 ))

    HAS_PRIORITY_ANY=false
    for lbl in "${PRIORITY_LABELS[@]}"; do
      echo "$LABELS" | grep -q "$lbl" && HAS_PRIORITY_ANY=true && break
    done

    if [[ "$AGE_DAYS" -gt 90 ]] && \
       ! echo "$LABELS" | grep -qE "stale|priority/critical|priority/high|blocked"; then
      add_label "$N" "stale" "Open >90 days"
      post_comment "$N" "This issue has been open for $AGE_DAYS days with no recent activity. Adding \`stale\` label. Comment to keep it active." "stale policy"
    fi

    if echo "$LABELS" | grep -q "security" && ! echo "$LABELS" | grep -q "priority/critical"; then
      add_label "$N" "priority/critical" "Security without critical priority"
    fi

    if echo "$LABELS" | grep -q "bug" && [[ "$AGE_DAYS" -gt 30 ]] && [[ "$HAS_PRIORITY_ANY" == "false" ]]; then
      add_label "$N" "priority/high" "Bug open >30 days without priority"
    fi

    if [[ "$HAS_PRIORITY_ANY" == "false" ]]; then
      add_label "$N" "priority/low" "No priority set; applying floor"
    fi
  fi

done

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo ""
echo "=== Triage Report ==="
echo "Issues scanned  : $ISSUE_COUNT"
echo "Actions taken   : $ACTION_COUNT"
echo "Closed          : $CLOSE_COUNT"
echo "Reopened        : $REOPEN_COUNT"
echo "Labels applied  : $LABEL_COUNT"
echo "Comments posted : $COMMENT_COUNT"
echo "Human review    : ${#HUMAN_REVIEW[@]}"

if [[ "${#HUMAN_REVIEW[@]}" -gt 0 ]]; then
  echo ""
  echo "--- Needs Human Review ---"
  for item in "${HUMAN_REVIEW[@]}"; do
    echo "  $item"
  done
fi
