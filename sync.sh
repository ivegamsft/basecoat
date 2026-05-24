#!/usr/bin/env bash

set -euo pipefail

SOURCE_REPO="${BASECOAT_REPO:-https://github.com/YOUR-ORG/basecoat.git}"
SOURCE_REF="${BASECOAT_REF:-main}"
TARGET_DIR="${BASECOAT_TARGET_DIR:-.github/base-coat}"

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

for item in README.md CHANGELOG.md version.json asset-manifest.json basecoat-metadata.json instructions skills prompts agents; do
  rm -rf "$REPO_ROOT/$TARGET_DIR/$item"
  cp -R "$TMP_DIR/source/$item" "$REPO_ROOT/$TARGET_DIR/$item"
done

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

# INVENTORY.md moved to docs/reference/ in v3.11.0 — copy from new location to target root for backwards compat
if [[ -f "$TMP_DIR/source/docs/reference/INVENTORY.md" ]]; then
  cp "$TMP_DIR/source/docs/reference/INVENTORY.md" "$REPO_ROOT/$TARGET_DIR/INVENTORY.md"
fi

# Remove agent taxonomy subdirs from staging — they contain only index
# READMEs with relative links that break outside the source repo
for tax_dir in models orchestrator tasks types; do
  rm -rf "$REPO_ROOT/$TARGET_DIR/agents/$tax_dir"
done

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
  find "$REPO_ROOT/$TARGET_DIR/agents" -maxdepth 1 -name '*.agent.md' -exec cp {} "$REPO_ROOT/.github/agents/" \;
fi

# Optional cleanup pass for stale managed files from prior versions.
# Uses hash snapshoting to avoid deleting customized files.
if [[ -x "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" ]]; then
  "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" "$TARGET_DIR"
elif [[ -f "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" ]]; then
  bash "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" "$TARGET_DIR"
fi

echo "Base Coat synced into $TARGET_DIR"
