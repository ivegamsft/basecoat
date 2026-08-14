#!/usr/bin/env bash
set -uo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo_root" ]] || exit 0
cd "$repo_root" || exit 0

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]] || exit 0

git_dir="$(git rev-parse --absolute-git-dir 2>/dev/null || true)"
[[ -n "$git_dir" ]] || exit 0
ledger_dir="$git_dir/basecoat/lane-closeout"
mkdir -p "$ledger_dir"
ledger_prefix="$(printf '%s' "$branch" | LC_ALL=C sed -E 's/[^A-Za-z0-9._-]+/-/g; s/^-+//; s/-+$//' | cut -c1-60 | sed -E 's/-+$//')"
[[ -n "$ledger_prefix" ]] || ledger_prefix="lane"
ledger=""
status_file=""
status_error_file=""

json_escape() {
  awk 'BEGIN { ORS="" }
    {
      if (NR > 1) printf "\\n"
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      gsub(/\r/, "\\r")
      gsub(/\t/, "\\t")
      printf "%s", $0
    }'
}

stash_sensitivity_key() {
  local ref="$1" part
  [[ -n "$ref" ]] || return 0
  for suffix in '^{tree}' '^2^{tree}' '^3^{tree}'; do
    part="$(git rev-parse "${ref}${suffix}" 2>/dev/null || true)"
    [[ -n "$part" ]] && printf '%s' "${part:0:8}"
  done
}

write_ledger() {
  local state="$1" head="$2" dirty="$3" wip_ref="$4" snapshot="$5"
  local pushed="$6" restored="$7" next_action="$8" error="${9:-}"
  local lane_json state_json head_json wip_json snapshot_json snapshot_content_key next_json error_json
  lane_json="$(printf '%s' "$branch" | json_escape)"
  state_json="$(printf '%s' "$state" | json_escape)"
  head_json="$(printf '%s' "$head" | json_escape)"
  wip_json="$(printf '%s' "$wip_ref" | json_escape)"
  snapshot_json="$(printf '%s' "$snapshot" | json_escape)"
  snapshot_content_key="$(stash_sensitivity_key "$snapshot")"
  next_json="$(printf '%s' "$next_action" | json_escape)"
  error_json="$(printf '%s' "$error" | json_escape)"
  cat > "$ledger" <<EOF
{
  "mode": "safe",
  "lane": "$lane_json",
  "head": "$head_json",
  "dirty": $dirty,
  "terminalState": "$state_json",
  "wipRef": "$wip_json",
  "snapshot": "$snapshot_json",
  "snapshotContentKey": "$snapshot_content_key",
  "pushSucceeded": $pushed,
  "restoreSucceeded": $restored,
  "nextAction": "$next_json",
  "error": "$error_json",
  "updatedAt": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
}
EOF
}

sha256_utf8() {
  local digest=""
  if command -v sha256sum >/dev/null 2>&1; then
    digest="$(printf '%s' "$branch" | sha256sum | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    digest="$(printf '%s' "$branch" | shasum -a 256 | awk '{print $1}')"
  elif command -v openssl >/dev/null 2>&1; then
    digest="$(printf '%s' "$branch" | openssl dgst -sha256 | awk '{print $NF}')"
  else
    return 1
  fi

  digest="$(printf '%s' "$digest" | tr 'A-F' 'a-f')"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 1
  printf '%s' "$digest"
}

if ! branch_hash_full="$(sha256_utf8)"; then
  ledger="$ledger_dir/${ledger_prefix}-hash-unavailable.json"
  write_ledger "PARKED" "" "true" "" "" "false" "true" \
    "Install sha256sum, shasum, or openssl, then rerun lane-closeout." \
    "Unable to compute the required raw UTF-8 SHA-256 lane key."
  exit 0
fi

branch_hash="${branch_hash_full:0:12}"
ledger_name="${ledger_prefix}-${branch_hash}.json"
ledger="$ledger_dir/$ledger_name"
status_file="$ledger_dir/.${ledger_name}.status"
status_error_file="$ledger_dir/.${ledger_name}.status-error"
trap 'rm -f "$status_file" "$status_error_file"' EXIT

stash_key() {
  local ref="$1" part
  for suffix in '^{tree}' '^2^{tree}' '^3^{tree}'; do
    part="$(git rev-parse "${ref}${suffix}" 2>/dev/null || true)"
    [[ -n "$part" ]] && printf '%s' "${part:0:8}"
  done
}

stash_is_retained() {
  local ref="$1"
  [[ -n "$ref" ]] &&
    git stash list --format='%H' 2>/dev/null | grep -Fqx "$ref"
}

head="$(git rev-parse HEAD 2>/dev/null || true)"
if ! git status --porcelain=v1 -z --untracked-files=all >"$status_file" 2>"$status_error_file"; then
  status_error="$(cat "$status_error_file" 2>/dev/null || true)"
  write_ledger "PARKED" "$head" "true" "" "" "false" "true" \
    "Repair the status inspection failure, then rerun lane-closeout." \
    "Unable to inspect lane status: $status_error"
  exit 0
fi

if [[ ! -s "$status_file" ]]; then
  if git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    git push origin "$branch" >/dev/null 2>&1
  else
    git push --set-upstream origin "$branch" >/dev/null 2>&1
  fi
  if [[ $? -eq 0 ]]; then
    write_ledger "PARKED" "$head" "false" "" "" "true" "true" \
      "Run lane-closeout in full mode to resolve PR and gate state."
  else
    write_ledger "PARKED" "$head" "false" "" "" "false" "true" \
      "Repair authentication or remote configuration, then rerun lane-closeout."
  fi
  exit 0
fi

is_sensitive_path() {
  printf '%s\n' "$1" | grep -Eiq '(^|[/\\])(credentials?|secrets?)([/\\]|$)|(^|[/\\])(\.env(\..*)?|id_rsa|id_ed25519|[^/\\]+\.(pem|key|pfx|p12))$'
}

sensitive_path=""
while IFS= read -r -d '' status_record; do
  status_code="${status_record:0:2}"
  path="${status_record:3}"
  if is_sensitive_path "$path"; then
    sensitive_path="$path"
    break
  fi
  if [[ "$status_code" == *R* || "$status_code" == *C* ]]; then
    original_path=""
    IFS= read -r -d '' original_path || true
    if is_sensitive_path "$original_path"; then
      sensitive_path="$original_path"
      break
    fi
  fi
done < "$status_file"

previous_ledger_snapshot=""
previous_ledger_content_key=""
previous_ledger_snapshot_was_retained=false
if [[ -f "$ledger" ]] &&
  grep -q '"nextAction":[[:space:]]*".*sensitive-path' "$ledger"; then
  previous_ledger_snapshot="$(
    sed -n 's/^[[:space:]]*"snapshot":[[:space:]]*"\([^"]*\)".*$/\1/p' "$ledger" |
      head -n 1
  )"
  previous_ledger_content_key="$(
    sed -n 's/^[[:space:]]*"snapshotContentKey":[[:space:]]*"\([^"]*\)".*$/\1/p' "$ledger" |
      head -n 1
  )"
  if stash_is_retained "$previous_ledger_snapshot"; then
    previous_ledger_snapshot_was_retained=true
  fi
fi

stash_before="$(git rev-parse --verify refs/stash 2>/dev/null || true)"
if ! git stash push --include-untracked --message "basecoat safe lane capture: $branch" --quiet; then
  write_ledger "PARKED" "$head" "true" "" "" "false" "false" \
    "Inspect the lane and rerun lane-closeout; no cleanup was attempted." \
    "Unable to create a safe WIP snapshot."
  exit 0
fi

stash_after="$(git rev-parse --verify refs/stash 2>/dev/null || true)"
if [[ -z "$stash_after" || "$stash_after" == "$stash_before" ]]; then
  if [[ -n "$stash_before" &&
    "$previous_ledger_snapshot" == "$stash_before" &&
    "$previous_ledger_snapshot_was_retained" == true ]]; then
    restored=true
    if [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
      if ! git stash apply --index "$previous_ledger_snapshot" --quiet; then
        restored=false
      fi
    fi
    if [[ "$restored" == true ]]; then
      next_action="Review sensitive-path candidate before publishing WIP: retained sensitive-path candidate"
    else
      next_action="Restore the retained stash manually before continuing."
    fi
    write_ledger "PARKED" "$head" "true" "" "$previous_ledger_snapshot" "false" "$restored" \
      "$next_action"
    exit 0
  fi
  write_ledger "PARKED" "$head" "true" "" "" "false" "true" \
    "Capture submodule or unsupported WIP manually, then rerun lane-closeout." \
    "git stash did not create a new WIP snapshot."
  exit 0
fi

snapshot="$stash_after"
tree="$(stash_key "$snapshot")"
sensitivity_key="$(stash_sensitivity_key "$snapshot")"
previous_snapshot="$(git rev-parse 'stash@{1}' 2>/dev/null || true)"
duplicate_sensitive=false
if [[ -z "$sensitive_path" && -f "$ledger" ]] &&
  grep -q '"nextAction":[[:space:]]*".*sensitive-path' "$ledger" &&
  [[ -n "$previous_ledger_content_key" &&
    "$previous_ledger_content_key" == "$sensitivity_key" ]]; then
  sensitive_path="retained sensitive-path candidate"
  if [[ "$previous_ledger_snapshot_was_retained" == true &&
    "$(stash_key "$previous_ledger_snapshot")" == "$tree" ]]; then
    previous_snapshot="$previous_ledger_snapshot"
    duplicate_sensitive=true
  else
    previous_snapshot=""
  fi
fi
if [[ -n "$sensitive_path" && -n "$previous_snapshot" && "$(stash_key "$previous_snapshot")" == "$tree" ]]; then
  duplicate_sensitive=true
fi
safe_branch="$(printf '%s' "$branch" | sed -E 's/[^A-Za-z0-9._\/-]+/-/g' | cut -c1-80 | sed -E 's/[-\/]+$//')"
wip_ref="wip/${safe_branch}-${tree}"
pushed=false

if [[ -z "$sensitive_path" ]]; then
  if git ls-remote --exit-code --heads origin "refs/heads/$wip_ref" >/dev/null 2>&1; then
    pushed=true
  elif git push origin "${snapshot}:refs/heads/$wip_ref" >/dev/null 2>&1; then
    pushed=true
  fi
fi

restored=false
if git stash apply --index "$snapshot" --quiet; then
  restored=true
  if [[ ("$duplicate_sensitive" == true || -z "$sensitive_path") && "$(git rev-parse 'stash@{0}' 2>/dev/null || true)" == "$snapshot" ]]; then
    git stash drop --quiet 'stash@{0}' || true
    if [[ "$duplicate_sensitive" == true ]]; then
      snapshot="$previous_snapshot"
    fi
  fi
fi

if [[ -n "$sensitive_path" ]]; then
  next_action="Review sensitive-path candidate before publishing WIP: $sensitive_path"
elif [[ "$restored" != true ]]; then
  next_action="Restore the retained stash manually before continuing."
elif [[ "$pushed" != true ]]; then
  next_action="Repair remote publishing, then push the recorded WIP snapshot."
else
  next_action="Run the lane-closeout skill in full mode."
fi

write_ledger "PARKED" "$head" "true" "$wip_ref" "$snapshot" "$pushed" "$restored" "$next_action"
exit 0
