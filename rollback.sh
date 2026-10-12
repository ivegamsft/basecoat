#!/usr/bin/env bash
# rollback.sh — Roll a consumer repo back to a specific BaseCoat release tag.
#
# Re-runs the sibling sync.sh for an explicit release tag, so the staged payload,
# consumer projections, and guidance-lock/v1 match a fresh sync of that tag.
# Locally modified BaseCoat-owned files stop rollback (GUIDANCE_CONTENT_MODIFIED),
# foreign-owned entries are untouched, and any failure restores the prior install and pin,
# except GUIDANCE_LOCK_BUSY (lease reclaimed as stale), which keeps the backup instead.
#
# Run from the root of a consumer repository.
#
# Usage:
#   BASECOAT_REPO=https://github.com/my-org/basecoat.git bash rollback.sh v3.25.0
#   bash rollback.sh v3.25.0
#   bash rollback.sh            # show current version and recent tags
#
# Environment variables:
#   BASECOAT_REPO        HTTPS clone URL of the BaseCoat repo (default: .basecoat.yml source)
#   BASECOAT_TARGET_DIR  Directory in consumer repo (default: .github/base-coat)

set -euo pipefail

SOURCE_REPO="${BASECOAT_REPO:-}"
TARGET_DIR="${BASECOAT_TARGET_DIR:-.github/base-coat}"
TAG="${1:-}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "Run this inside a git repository" >&2
  exit 1
fi

FULL_TARGET="${REPO_ROOT}/${TARGET_DIR}"

# ── Show current version and available tags if no tag given ──────────────────

if [[ -z "$TAG" ]]; then
  VERSION_FILE="${FULL_TARGET}/version.json"
  CURRENT="unknown"
  if [[ -f "$VERSION_FILE" ]] && command -v jq >/dev/null 2>&1; then
    CURRENT="$(jq -r '.version // "unknown"' "$VERSION_FILE")"
  elif [[ -f "$VERSION_FILE" ]]; then
    CURRENT="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" | head -1 | grep -o '"[^"]*"$' | tr -d '"')"
  fi
  echo "Current BaseCoat version: v${CURRENT}"
  echo ""
  echo "Recent release tags:"
  CONFIG_FILE="${REPO_ROOT}/.basecoat.yml"
  if [[ -z "$SOURCE_REPO" && -f "$CONFIG_FILE" ]]; then
    SOURCE_REPO="$(awk -v bom=$'\xef\xbb\xbf' '
      NR == 1 && index($0, bom) == 1 { $0 = substr($0, length(bom) + 1) }
      /^source:/ { sub(/\r$/, ""); sub(/^source:[[:space:]]*/, ""); sub(/[[:space:]]+#.*$/, ""); print; exit }' "$CONFIG_FILE" | tr -d "\"'")"
  fi
  if [[ -n "$SOURCE_REPO" ]]; then
    git ls-remote --tags --sort='-version:refname' "$SOURCE_REPO" 'v*' 2>/dev/null \
      | grep -oP 'v[\d.]+$' \
      | head -10 \
      | sed 's/^/  /' || echo "  (could not fetch tags — check BASECOAT_REPO)"
  else
    echo "  (no source configured - set BASECOAT_REPO or 'source:' in .basecoat.yml)"
  fi
  echo ""
  echo "Usage: bash rollback.sh <tag>"
  echo "       e.g.: bash rollback.sh v3.25.0"
  exit 0
fi

# ── Normalise tag ─────────────────────────────────────────────────────────────

[[ "$TAG" == v* ]] || TAG="v${TAG}"

# ── Show prior version ────────────────────────────────────────────────────────

VERSION_FILE="${FULL_TARGET}/version.json"
PRIOR="unknown"
if [[ -f "$VERSION_FILE" ]] && command -v jq >/dev/null 2>&1; then
  PRIOR="$(jq -r '.version // "unknown"' "$VERSION_FILE")"
elif [[ -f "$VERSION_FILE" ]]; then
  PRIOR="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" | head -1 | grep -o '"[^"]*"$' | tr -d '"')"
fi

echo "Rolling back BaseCoat: v${PRIOR} -> ${TAG}"
echo "Source : ${SOURCE_REPO:-.basecoat.yml source}"
echo "Target : ${FULL_TARGET}"
echo ""

# ── Re-sync the target tag through sync.sh ────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/sync.sh"
if [[ ! -f "$SYNC_SCRIPT" ]]; then
  echo "rollback.sh requires sync.sh beside it (${SYNC_SCRIPT}) to replay projections and guidance-lock/v1." >&2
  exit 1
fi

LOCK_HELPER=""
for candidate in "${SCRIPT_DIR}/scripts/guidance-lock.sh" "${REPO_ROOT}/.github/base-coat/scripts/guidance-lock.sh"; do
  [[ -f "$candidate" ]] && { LOCK_HELPER="$candidate"; break; }
done
if [[ -z "$LOCK_HELPER" ]]; then
  echo "rollback.sh requires scripts/guidance-lock.sh beside it or in .github/base-coat/scripts." >&2
  exit 1
fi
# shellcheck source=scripts/guidance-lock.sh
source "$LOCK_HELPER"

BACKUP_DIR="$(mktemp -d)"
LEASE=""
cleanup() { guidance_exit_lease "$LEASE"; rm -rf "$BACKUP_DIR"; }
trap cleanup EXIT

# Snapshot every tree sync.sh may write. The guidance-lock lease is held from snapshot through
# the .basecoat.yml pin and inherited by sync.sh, so no concurrent writer can commit in between.
LEASE="$(guidance_enter_lease "$REPO_ROOT")"
LEASE_DIR="${LEASE%%|*}"
CONFIG_FILE="${REPO_ROOT}/.basecoat.yml"
if [[ -f "$CONFIG_FILE" ]]; then cp -p "$CONFIG_FILE" "${BACKUP_DIR}/basecoat.yml"; fi
SNAPSHOT_PATHS=(.github/base-coat .github/agents .github/agent-references \
  .github/instructions .github/prompts .github/skills .agents/skills "$TARGET_DIR")
for i in "${!SNAPSHOT_PATHS[@]}"; do
  SNAPSHOT_PATH="${REPO_ROOT}/${SNAPSHOT_PATHS[$i]}"
  mkdir -p "${BACKUP_DIR}/${i}"
  if [[ -d "$SNAPSHOT_PATH" ]]; then
    touch "${BACKUP_DIR}/${i}.existed"
    find "$SNAPSHOT_PATH" -mindepth 1 -maxdepth 1 ! -path "$LEASE_DIR" -exec cp -a {} "${BACKUP_DIR}/${i}/" \;
  fi
done

restore_snapshots() {
  for i in "${!SNAPSHOT_PATHS[@]}"; do
    SNAPSHOT_PATH="${REPO_ROOT}/${SNAPSHOT_PATHS[$i]}"
    if [[ -d "$SNAPSHOT_PATH" ]]; then
      find "$SNAPSHOT_PATH" -mindepth 1 -maxdepth 1 ! -path "$LEASE_DIR" -exec rm -rf {} +
    fi
    if [[ -e "${BACKUP_DIR}/${i}.existed" ]]; then
      mkdir -p "$SNAPSHOT_PATH"
      cp -a "${BACKUP_DIR}/${i}/." "${SNAPSHOT_PATH}/"
    else
      rmdir "$SNAPSHOT_PATH" 2>/dev/null || true
    fi
  done
  if [[ -f "${BACKUP_DIR}/basecoat.yml" ]] && ! cmp -s "${BACKUP_DIR}/basecoat.yml" "$CONFIG_FILE"; then
    cat "${BACKUP_DIR}/basecoat.yml" > "$CONFIG_FILE"
  fi
}

# Pin the ref sync actually installed (known-bad tags redirect to a fixed tag). Written in
# place so file permissions are honoured; a failure restores the prior install.
write_pin() {
  local provenance="${REPO_ROOT}/.github/base-coat/.source-provenance.json" installed_ref=""
  if [[ -f "$provenance" ]]; then
    installed_ref="$(grep -o '"requestedRef"[[:space:]]*:[[:space:]]*"[^"]*"' "$provenance" | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
  fi
  if [[ -n "$installed_ref" ]]; then TAG="$installed_ref"; fi
  [[ -f "${BACKUP_DIR}/basecoat.yml" ]] || return 0
  awk -v tag="$TAG" -v bom=$'\xef\xbb\xbf' '
    { line = $0; prefix = ""
      if (NR == 1 && index(line, bom) == 1) { prefix = bom; line = substr(line, length(bom) + 1) }
      if (line ~ /^ref:/) { cr = (line ~ /\r$/) ? "\r" : ""; print prefix "ref: " tag cr; found = 1; next }
      print $0 }
    END { if (!found) print "ref: " tag }' "${BACKUP_DIR}/basecoat.yml" > "${BACKUP_DIR}/basecoat.yml.new" &&
    cat "${BACKUP_DIR}/basecoat.yml.new" > "$CONFIG_FILE" &&
    echo "Updated .basecoat.yml ref pin to ${TAG}"
}

SYNC_STATUS=0
BASECOAT_REF="$TAG" BASECOAT_TARGET_DIR="$TARGET_DIR" BASECOAT_GUIDANCE_LEASE="$LEASE" bash "$SYNC_SCRIPT" || SYNC_STATUS=$?
if ! grep -qxF "token=${LEASE#*|}" "${LEASE_DIR}/owner" 2>/dev/null; then
  trap - EXIT
  echo "GUIDANCE_LOCK_BUSY lease='${LEASE_DIR}' reason='lease reclaimed as stale during sync' syncExitCode='${SYNC_STATUS}'; rollback to ${TAG} was NOT restored or pinned to avoid overwriting a concurrent writer. Backup kept at '${BACKUP_DIR}'." >&2
  exit 1
fi
if [[ "$SYNC_STATUS" -ne 0 ]] || ! write_pin; then
  restore_snapshots
  echo "Rollback to ${TAG} failed (sync exit code ${SYNC_STATUS}); restored the previous payload, projections, guidance lock, and .basecoat.yml pin." >&2
  exit 1
fi

echo ""
echo "Rolled back to ${TAG} successfully."
echo "  Run 'git diff --stat' to review changes before committing."
