#!/usr/bin/env bash

set -euo pipefail

SOURCE_REPO="${BASECOAT_REPO:-https://github.com/YOUR-ORG/basecoat.git}"
SOURCE_REF="${BASECOAT_REF:-main}"
TARGET_DIR="${BASECOAT_TARGET_DIR:-.github/base-coat}"
ALLOWED_DOCS_TOP_LEVEL=("reference" "guides" "agents" "diagrams")

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

validate_workflow_directory() {
  local workflows_dir="$1"
  [[ -d "$workflows_dir" ]] || return 0

  local failures=()
  local workflow_file=""
  local block_scalar_pattern='^[[:space:]]*(run|script):[[:space:]]*[|>][-+]?[[:space:]]*($|#)'

  while IFS= read -r workflow_file; do
    [[ -n "$workflow_file" ]] || continue

    if command -v ruby >/dev/null 2>&1; then
      if ! ruby -e "require 'yaml'; YAML.safe_load(File.read(ARGV[0]), permitted_classes: [], aliases: true)" "$workflow_file" >/dev/null 2>&1; then
        failures+=("$(basename "$workflow_file"): malformed YAML")
        continue
      fi
    fi

    local line_number=0
    local in_literal_block=0
    local literal_block_indent=-1
    local line=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      line_number=$((line_number + 1))

      local indent=0
      if [[ "$line" =~ ^([[:space:]]*) ]]; then
        indent=${#BASH_REMATCH[1]}
      fi

      local trimmed="$line"
      trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
      trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

      if (( in_literal_block )); then
        if [[ -z "$trimmed" || $indent -gt $literal_block_indent ]]; then
          continue
        fi
        in_literal_block=0
        literal_block_indent=-1
      fi

      if [[ "$line" =~ $block_scalar_pattern ]]; then
        in_literal_block=1
        literal_block_indent=$indent
        continue
      fi

      if [[ "$line" =~ ^[[:space:]]*uses:[[:space:]]*(.+)$ ]]; then
        local uses_ref="${BASH_REMATCH[1]}"
        uses_ref="${uses_ref%%#*}"
        uses_ref="${uses_ref#"${uses_ref%%[![:space:]]*}"}"
        uses_ref="${uses_ref%"${uses_ref##*[![:space:]]}"}"

        if [[ "${uses_ref:0:1}" == "\"" || "${uses_ref:0:1}" == "'" ]]; then
          local quote_char="${uses_ref:0:1}"
          uses_ref="${uses_ref:1}"
          if [[ "${uses_ref: -1}" == "$quote_char" ]]; then
            uses_ref="${uses_ref:0:${#uses_ref}-1}"
          fi
        fi

        if [[ "$uses_ref" == ./.github/base-coat/workflows/* ]]; then
          failures+=("$(basename "$workflow_file"):$line_number invalid reusable workflow reference '$uses_ref' (must use ./.github/workflows/<file>.yml for local reusable workflows)")
          continue
        fi

        if [[ ( "$uses_ref" == ./*.yml || "$uses_ref" == ./*.yaml ) && "$uses_ref" != ./.github/workflows/* ]]; then
          failures+=("$(basename "$workflow_file"):$line_number invalid local workflow path '$uses_ref' (local reusable workflows must be under ./.github/workflows/)")
        fi
      fi
    done < "$workflow_file"
  done < <(find "$workflows_dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

  if (( ${#failures[@]} > 0 )); then
    echo "Workflow validation failed before sync. Invalid workflow definitions detected:" >&2
    for failure in "${failures[@]}"; do
      echo " - $failure" >&2
    done
    exit 1
  fi
}

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

for item in README.md CHANGELOG.md version.json asset-manifest.json instructions skills prompts agents templates; do
  rm -rf "$REPO_ROOT/$TARGET_DIR/$item"
  if [[ -e "$TMP_DIR/source/$item" ]]; then
    cp -R "$TMP_DIR/source/$item" "$REPO_ROOT/$TARGET_DIR/$item"
  fi
done

# Copy workflows from .github/base-coat/workflows/ in source
if [[ -d "$TMP_DIR/source/.github/base-coat/workflows" ]]; then
  validate_workflow_directory "$TMP_DIR/source/.github/base-coat/workflows"
  rm -rf "$REPO_ROOT/$TARGET_DIR/workflows"
  cp -R "$TMP_DIR/source/.github/base-coat/workflows" "$REPO_ROOT/$TARGET_DIR/workflows"
fi

# Legacy cleanup: basecoat-metadata.json was previously distributed.
rm -f "$REPO_ROOT/$TARGET_DIR/basecoat-metadata.json"

# Copy only basic documentation (not full docs tree)
rm -rf "$REPO_ROOT/$TARGET_DIR/docs"
mkdir -p "$REPO_ROOT/$TARGET_DIR/docs"
for doc_subdir in reference guides diagrams; do
  src_path="$TMP_DIR/source/docs/$doc_subdir"
  tgt_path="$REPO_ROOT/$TARGET_DIR/docs/$doc_subdir"
  if [[ -d "$src_path" ]]; then
    cp -R "$src_path" "$tgt_path"
  fi
done
if [[ -f "$TMP_DIR/source/docs/agents/AGENTS.md" ]]; then
  mkdir -p "$REPO_ROOT/$TARGET_DIR/docs/agents"
  cp "$TMP_DIR/source/docs/agents/AGENTS.md" "$REPO_ROOT/$TARGET_DIR/docs/agents/AGENTS.md"
elif [[ -f "$TMP_DIR/source/docs/agents/agents.md" ]]; then
  mkdir -p "$REPO_ROOT/$TARGET_DIR/docs/agents"
  cp "$TMP_DIR/source/docs/agents/agents.md" "$REPO_ROOT/$TARGET_DIR/docs/agents/AGENTS.md"
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
# Accepts both INVENTORY.md and inventory.md (Phase 3+4 rename to lowercase)
if [[ -f "$TMP_DIR/source/docs/reference/INVENTORY.md" ]]; then
  cp "$TMP_DIR/source/docs/reference/INVENTORY.md" "$REPO_ROOT/$TARGET_DIR/INVENTORY.md"
elif [[ -f "$TMP_DIR/source/docs/reference/inventory.md" ]]; then
  cp "$TMP_DIR/source/docs/reference/inventory.md" "$REPO_ROOT/$TARGET_DIR/INVENTORY.md"
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
  find "$REPO_ROOT/$TARGET_DIR/agents" -maxdepth 1 -name '*.agent.md' -exec cp {} "$REPO_ROOT/.github/agents/" \;
fi

# Seed release-notes template into downstream-customizable location.
# Never overwrite local customizations.
managed_release_template="$REPO_ROOT/$TARGET_DIR/templates/release-notes/default.md"
custom_release_template="$REPO_ROOT/.github/release-notes/templates/default.md"
if [[ -f "$managed_release_template" ]] && [[ ! -f "$custom_release_template" ]]; then
  mkdir -p "$(dirname "$custom_release_template")"
  cp "$managed_release_template" "$custom_release_template"
fi

# Seed intake contract templates into downstream-customizable locations.
# Never overwrite local customizations.
managed_pr_template="$REPO_ROOT/$TARGET_DIR/templates/intake/PULL_REQUEST_TEMPLATE.md"
custom_pr_template="$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md"
if [[ -f "$managed_pr_template" ]] && [[ ! -f "$custom_pr_template" ]]; then
  mkdir -p "$(dirname "$custom_pr_template")"
  cp "$managed_pr_template" "$custom_pr_template"
fi

managed_issue_template="$REPO_ROOT/$TARGET_DIR/templates/intake/issue.md"
custom_issue_template="$REPO_ROOT/.github/ISSUE_TEMPLATE/issue.md"
if [[ -f "$managed_issue_template" ]] && [[ ! -f "$custom_issue_template" ]]; then
  mkdir -p "$(dirname "$custom_issue_template")"
  cp "$managed_issue_template" "$custom_issue_template"
fi

# Optional cleanup pass for stale managed files from prior versions.
# Uses hash snapshoting to avoid deleting customized files.
if [[ -x "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" ]]; then
  "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" "$TARGET_DIR"
elif [[ -f "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" ]]; then
  bash "$REPO_ROOT/scripts/cleanup-basecoat-upgrade.sh" "$TARGET_DIR"
fi

echo "Base Coat synced into $TARGET_DIR"
