#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.github/base-coat}"
STATE_FILE_NAME="${2:-.sync-state.json}"
PROTECT_CUSTOMIZED="${PROTECT_CUSTOMIZED:-true}"
SET_ARCHIVE_READ_ONLY="${SET_ARCHIVE_READ_ONLY:-true}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Run this inside a git repository." >&2
  exit 1
fi

full_target_dir="$repo_root/$TARGET_DIR"
manifest_path="$full_target_dir/asset-manifest.json"
state_path="$full_target_dir/$STATE_FILE_NAME"

if [[ ! -d "$full_target_dir" ]]; then
  echo "Target directory not found: $full_target_dir (nothing to clean)."
  exit 0
fi
if [[ ! -f "$manifest_path" ]]; then
  echo "asset-manifest.json not found in $full_target_dir — skipping cleanup."
  exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print tolower($1)}'
  else
    shasum -a 256 "$f" | awk '{print tolower($1)}'
  fi
}

# Build current managed file list from manifest + fixed root files that sync copies.
jq -r '.assets[].path' "$manifest_path" | sort -u > "$tmpdir/current-managed.txt"
for root_file in README.md CHANGELOG.md version.json asset-manifest.json basecoat-metadata.json INVENTORY.md; do
  if [[ -f "$full_target_dir/$root_file" ]]; then
    echo "$root_file" >> "$tmpdir/current-managed.txt"
  fi
done
sort -u "$tmpdir/current-managed.txt" -o "$tmpdir/current-managed.txt"

removed=0
skipped_customized=0
skipped_unverified=0

if [[ -f "$state_path" ]]; then
  jq -r '.managedFiles[]?.path' "$state_path" | sort -u > "$tmpdir/prev-managed.txt"

  while IFS= read -r old_rel; do
    [[ -z "$old_rel" ]] && continue
    if grep -Fxq "$old_rel" "$tmpdir/current-managed.txt"; then
      continue
    fi
    old_full="$full_target_dir/$old_rel"
    if [[ ! -f "$old_full" ]]; then
      continue
    fi

    if [[ "$PROTECT_CUSTOMIZED" == "true" ]]; then
      prev_sha="$(jq -r --arg p "$old_rel" '.managedFiles[]? | select(.path==$p) | (.sha256 // "")' "$state_path" | head -1)"
      curr_sha="$(sha256_file "$old_full")"
      if [[ -z "$prev_sha" || -z "$curr_sha" ]]; then
        echo "SKIP unverified stale file (missing hash): $old_rel"
        skipped_unverified=$((skipped_unverified + 1))
        continue
      fi
      if [[ "$prev_sha" != "$curr_sha" ]]; then
        echo "SKIP customized stale file: $old_rel"
        skipped_customized=$((skipped_customized + 1))
        continue
      fi
    fi

    rm -f "$old_full"
    echo "Removed stale managed file: $old_rel"
    removed=$((removed + 1))
  done < "$tmpdir/prev-managed.txt"
fi

if [[ "$SET_ARCHIVE_READ_ONLY" == "true" && -d "$full_target_dir/docs/archive" ]]; then
  find "$full_target_dir/docs/archive" -type f -exec chmod a-w {} + || true
  echo "Set archive files read-only under docs/archive."
fi

# Write new state snapshot
{
  echo "{"
  echo "  \"schemaVersion\": \"1\","
  echo "  \"generatedAt\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
  echo "  \"targetDir\": \"$TARGET_DIR\","
  echo "  \"managedFiles\": ["
  first=true
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    full="$full_target_dir/$rel"
    [[ -f "$full" ]] || continue
    sha="$(sha256_file "$full")"
    if [[ "$first" == true ]]; then
      first=false
    else
      echo ","
    fi
    printf "    {\"path\":\"%s\",\"sha256\":\"%s\"}" "$rel" "$sha"
  done < "$tmpdir/current-managed.txt"
  echo ""
  echo "  ]"
  echo "}"
} > "$state_path"

echo "Cleanup complete. Removed=$removed, SkippedCustomized=$skipped_customized, SkippedUnverified=$skipped_unverified, StateFile=$state_path"

