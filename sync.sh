#!/usr/bin/env bash

set -euo pipefail

SOURCE_REPO="${BASECOAT_REPO:-https://github.com/YOUR-ORG/basecoat.git}"
SOURCE_REF="${BASECOAT_REF:-main}"
TARGET_DIR="${BASECOAT_TARGET_DIR:-.github/base-coat}"
ALLOWED_DOCS_TOP_LEVEL=("reference" "guides" "agents")

sanitize_agent_for_cli() {
  local src="$1"
  local dest="$2"
  local header
  local has_tools=0
  local has_allowed_tools=0
  local map_allowed_tools=0

  header="$(awk '
    BEGIN { d = 0 }
    /^---$/ { d++; next }
    d == 1 { print }
    d == 2 { exit }
  ' "$src")"

  if grep -q '^tools:' <<<"$header"; then
    has_tools=1
  fi
  if grep -q '^allowed-tools:' <<<"$header"; then
    has_allowed_tools=1
  fi
  if [[ "$has_tools" -eq 0 && "$has_allowed_tools" -eq 1 ]]; then
    map_allowed_tools=1
  fi

  awk -v map_allowed_tools="$map_allowed_tools" '
    BEGIN {
      in_frontmatter = 0
      frontmatter_started = 0
      keep = 0
    }

    /^---$/ {
      if (frontmatter_started == 0) {
        frontmatter_started = 1
        in_frontmatter = 1
        print
        next
      }
      if (in_frontmatter == 1) {
        in_frontmatter = 0
        print
        print ""
        next
      }
    }

    {
      if (in_frontmatter == 1) {
        if ($0 ~ /^[A-Za-z0-9_-]+:/) {
          key = $0
          sub(/:.*/, "", key)
          keep = 0
          if (key == "name" || key == "description" || key == "tools" || key == "mcp-servers") {
            keep = 1
          } else if (key == "allowed-tools" && map_allowed_tools == 1) {
            keep = 1
            sub(/^allowed-tools:/, "tools:")
          }
        }
        if (keep == 1) {
          print
        }
        next
      }
      print
    }
  ' "$src" > "$dest"
}

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "Run this inside a git repository" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Cloning $SOURCE_REPO#$SOURCE_REF"
if ! git clone --depth 1 --branch "$SOURCE_REF" "$SOURCE_REPO" "$TMP_DIR/source" >/dev/null 2>&1; then
  # In CI for private GitHub repos, anonymous clone can fail. Retry with an auth
  # header when either GITHUB_TOKEN or GH_TOKEN is available.
  token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  if [[ "$SOURCE_REPO" =~ ^https://github\.com/ ]] && [[ -n "$token" ]]; then
    auth_header="$(printf 'x-access-token:%s' "$token" | base64 | tr -d '\r\n')"
    if ! git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $auth_header" \
      clone --depth 1 --branch "$SOURCE_REF" "$SOURCE_REPO" "$TMP_DIR/source" >/dev/null 2>&1; then
      echo "Failed to clone $SOURCE_REPO#$SOURCE_REF (anonymous and token-auth attempts failed)." >&2
      exit 1
    fi
  else
    echo "Failed to clone $SOURCE_REPO#$SOURCE_REF." >&2
    exit 1
  fi
fi

mkdir -p "$REPO_ROOT/$TARGET_DIR"

for item in README.md CHANGELOG.md version.json asset-manifest.json instructions skills prompts agents; do
  rm -rf "$REPO_ROOT/$TARGET_DIR/$item"
  cp -R "$TMP_DIR/source/$item" "$REPO_ROOT/$TARGET_DIR/$item"
done

# Legacy cleanup: basecoat-metadata.json was previously distributed.
rm -f "$REPO_ROOT/$TARGET_DIR/basecoat-metadata.json"

# Copy only basic documentation (not full docs tree)
rm -rf "$REPO_ROOT/$TARGET_DIR/docs"
mkdir -p "$REPO_ROOT/$TARGET_DIR/docs"
for doc_subdir in reference guides; do
  if [[ -d "$TMP_DIR/source/docs/$doc_subdir" ]]; then
    cp -R "$TMP_DIR/source/docs/$doc_subdir" "$REPO_ROOT/$TARGET_DIR/docs/$doc_subdir"
  fi
done
if [[ -f "$TMP_DIR/source/docs/agents/AGENTS.md" ]]; then
  mkdir -p "$REPO_ROOT/$TARGET_DIR/docs/agents"
  cp "$TMP_DIR/source/docs/agents/AGENTS.md" "$REPO_ROOT/$TARGET_DIR/docs/agents/AGENTS.md"
fi

for path in "$REPO_ROOT/$TARGET_DIR/docs"/*; do
  [[ -e "$path" ]] || continue
  entry="$(basename "$path")"
  allowed=false
  for allowed_entry in "${ALLOWED_DOCS_TOP_LEVEL[@]}"; do
    if [[ "$entry" == "$allowed_entry" ]]; then
      allowed=true
      break
    fi
  done

  if [[ "$allowed" == false ]]; then
    echo "Docs scope validation failed: unexpected docs entry synced: $entry" >&2
    exit 1
  fi
done

if [[ -d "$REPO_ROOT/$TARGET_DIR/docs/agents" ]]; then
  for path in "$REPO_ROOT/$TARGET_DIR/docs/agents"/*; do
    [[ -e "$path" ]] || continue
    entry="$(basename "$path")"
    if [[ "$entry" != "AGENTS.md" ]]; then
      echo "Docs scope validation failed: docs/agents must only contain AGENTS.md, found: $entry" >&2
      exit 1
    fi
  done
fi

# INVENTORY.md moved to docs/reference/ in v3.11.0 — copy from new location to target root for backwards compat
if [[ -f "$TMP_DIR/source/docs/reference/INVENTORY.md" ]]; then
  cp "$TMP_DIR/source/docs/reference/INVENTORY.md" "$REPO_ROOT/$TARGET_DIR/INVENTORY.md"
fi

# Remove agent taxonomy subdirs from staging — they contain only index
# READMEs with relative links that break outside the source repo
for tax_dir in models orchestrator tasks types; do
  rm -rf "$REPO_ROOT/$TARGET_DIR/agents/$tax_dir"
done

# Remove eval metadata from synced agents to avoid leaking internal test files.
find "$REPO_ROOT/$TARGET_DIR/agents" -maxdepth 1 -type f -name '*.agent.eval.yaml' -delete

# Copy Copilot-discoverable directories to their standard paths
# Only copy flat agent/instruction/prompt/skill files — not taxonomy subdirs
mkdir -p "$REPO_ROOT/.github"
for copilot_dir in instructions prompts skills; do
  if [[ -d "$REPO_ROOT/$TARGET_DIR/$copilot_dir" ]]; then
    rm -rf "$REPO_ROOT/.github/$copilot_dir"
    cp -R "$REPO_ROOT/$TARGET_DIR/$copilot_dir" "$REPO_ROOT/.github/$copilot_dir"
  fi
done

# Also copy skills to .agents/skills/ for cross-client interop (Agent Skills spec)
if [[ -d "$REPO_ROOT/$TARGET_DIR/skills" ]]; then
  mkdir -p "$REPO_ROOT/.agents"
  rm -rf "$REPO_ROOT/.agents/skills"
  cp -R "$REPO_ROOT/$TARGET_DIR/skills" "$REPO_ROOT/.agents/skills"
fi

# Agents: copy only *.agent.md files (skip taxonomy subdirs like models/, tasks/, types/)
if [[ -d "$REPO_ROOT/$TARGET_DIR/agents" ]]; then
  rm -rf "$REPO_ROOT/.github/agents"
  mkdir -p "$REPO_ROOT/.github/agents"
  while IFS= read -r agent_file; do
    sanitize_agent_for_cli "$agent_file" "$REPO_ROOT/.github/agents/$(basename "$agent_file")"
  done < <(find "$REPO_ROOT/$TARGET_DIR/agents" -maxdepth 1 -type f -name '*.agent.md' | sort)
fi

# Optional cleanup pass for stale managed files from prior versions.
# Uses hash snapshoting to avoid deleting customized files.
if [[ -x "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" ]]; then
  "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" "$TARGET_DIR"
elif [[ -f "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" ]]; then
  bash "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" "$TARGET_DIR"
fi

echo "Base Coat synced into $TARGET_DIR"
