#!/usr/bin/env bash

set -euo pipefail

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

# Resolve the upstream source repo and ref.
# Precedence: BASECOAT_REPO/BASECOAT_REF env vars > repo-root .basecoat.yml > built-in default.
read_basecoat_yml_value() {
  # $1 = top-level key. Emits its value from .basecoat.yml, ignoring comment
  # lines, indented (nested) keys, inline "# ..." comments, and surrounding quotes.
  # A genuine read/sed failure is propagated (non-zero return); a missing file or
  # absent key yields empty output with success so callers fall through to defaults.
  local key="$1"
  local config="$REPO_ROOT/.basecoat.yml"
  [[ -f "$config" ]] || return 0

  local matches
  # Strip a leading UTF-8 BOM on line 1 (Windows-authored configs) before matching.
  local bom=$'\xEF\xBB\xBF'
  matches="$(sed -n "1s/^${bom}//;s/^${key}:[[:space:]]*//p" "$config")" || return 1

  local first="${matches%%$'\n'*}"
  first="${first%$'\r'}"
  printf '%s' "$first" \
    | sed -e 's/^#.*$//' -e 's/[[:space:]]\{1,\}#.*$//' -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"
}

read_basecoat_yml_map_value() {
  local section="$1"
  local key="$2"
  local config="$REPO_ROOT/.basecoat.yml"
  [[ -f "$config" ]] || return 0

  local bom=$'\xEF\xBB\xBF'
  sed "1s/^${bom}//" "$config" | awk -v section="$section" -v key="$key" '
    $0 ~ "^[[:space:]]*#" { next }
    $0 ~ "^[A-Za-z0-9_-]+:[[:space:]]*$" {
      current=$0
      sub(/:.*/, "", current)
      in_section=(current == section)
      next
    }
    in_section && $0 ~ "^[[:space:]]{2,}[^#][^:]*:[[:space:]]*" {
      entry=$0
      sub(/^[[:space:]]*/, "", entry)
      separator=index(entry, ":")
      map_key=substr(entry, 1, separator - 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", map_key)
      gsub(/^["'\'']|["'\'']$/, "", map_key)
      if (map_key != key) { next }
      value=substr(entry, separator + 1)
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]+#.*$/, "", value)
      sub(/[[:space:]]+$/, "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      print value
      exit
    }
  '
}

redact_repo_url() {
  # Strip any "user[:password]@" userinfo and any "?query"/"#fragment" (which may
  # carry a token) from an http(s) URL so credential-bearing clone URLs are never
  # logged. Only the display value is sanitized; git clone still uses the original.
  # Scheme match is case-insensitive (URI schemes are case-insensitive) and portable.
  printf '%s' "$1" \
    | sed -E -e 's#([Hh][Tt][Tt][Pp][Ss]?://)[^/@]*@#\1#' -e 's|[?#].*$||'
}

SOURCE_REPO="${BASECOAT_REPO:-}"
SOURCE_REPO_ORIGIN="env"
if [[ -z "$SOURCE_REPO" ]]; then
  SOURCE_REPO="$(read_basecoat_yml_value source)"
  if [[ -n "$SOURCE_REPO" ]]; then
    SOURCE_REPO_ORIGIN=".basecoat.yml"
  else
    echo "No BaseCoat source configured. Set 'source:' in .basecoat.yml or the BASECOAT_REPO env var." >&2
    exit 1
  fi
fi

SOURCE_REF="${BASECOAT_REF:-}"
SOURCE_REF_ORIGIN="env"
if [[ -z "$SOURCE_REF" ]]; then
  SOURCE_REF="$(read_basecoat_yml_value ref)"
  if [[ -n "$SOURCE_REF" ]]; then
    SOURCE_REF_ORIGIN=".basecoat.yml"
  else
    SOURCE_REF="main"
    SOURCE_REF_ORIGIN="default"
  fi
fi

# Known-bad release tag redirect (version drift guard).
TARGET_REF="$(read_basecoat_yml_map_value known_bad_releases "$SOURCE_REF")"
if [[ -z "$TARGET_REF" && "$SOURCE_REF" == "v3.30.4" ]]; then
  TARGET_REF="v3.30.5"
fi
if [[ -n "$TARGET_REF" ]]; then
  echo "WARNING: Requested ref '$SOURCE_REF' is a known-bad release tag (version drift). Auto-upgrading sync source to '$TARGET_REF'. Update your .basecoat.yml pin to '$TARGET_REF' or newer." >&2
  SOURCE_REF="$TARGET_REF"
  SOURCE_REF_ORIGIN="redirect"
fi

SOURCE_MIRROR="${BASECOAT_MIRROR:-}"
SOURCE_MIRROR_ORIGIN="env"
if [[ -z "$SOURCE_MIRROR" ]]; then
  SOURCE_MIRROR="$(read_basecoat_yml_value mirror)"
  if [[ -n "$SOURCE_MIRROR" ]]; then
    SOURCE_MIRROR_ORIGIN=".basecoat.yml"
  else
    SOURCE_MIRROR_ORIGIN="unset"
  fi
fi
FETCH_REPO="${SOURCE_MIRROR:-$SOURCE_REPO}"

echo "Resolved BaseCoat source '$(redact_repo_url "$SOURCE_REPO")' (from $SOURCE_REPO_ORIGIN), ref '$SOURCE_REF' (from $SOURCE_REF_ORIGIN)"
if [[ -n "$SOURCE_MIRROR" ]]; then
  echo "Using corporate mirror '$(redact_repo_url "$SOURCE_MIRROR")' (from $SOURCE_MIRROR_ORIGIN) for immutable fetches."
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

echo "Cloning $(redact_repo_url "$FETCH_REPO")#$SOURCE_REF"
clone_source() {
  if [[ "$SOURCE_REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
    git init "$TMP_DIR/source" >/dev/null 2>&1 \
      && git -C "$TMP_DIR/source" remote add origin "$FETCH_REPO" \
      && git -C "$TMP_DIR/source" fetch --depth 1 origin "$SOURCE_REF" >/dev/null 2>&1 \
      && git -C "$TMP_DIR/source" checkout --detach FETCH_HEAD >/dev/null 2>&1
  else
    git clone --depth 1 --branch "$SOURCE_REF" "$FETCH_REPO" "$TMP_DIR/source" >/dev/null 2>&1
  fi
}

if ! clone_source; then
  # Private source authentication is opt-in and bound to one explicit HTTPS
  # authority so a consumer delivery token is never forwarded to a mirror.
  token="${BASECOAT_FETCH_TOKEN:-}"
  trusted_authority="${BASECOAT_FETCH_HOST:-}"
  if [[ "$FETCH_REPO" =~ ^(https://[^/]+)(/|$) ]] && [[ -n "$token" ]]; then
    auth_origin="${BASH_REMATCH[1]}/"
    auth_authority="${BASH_REMATCH[1]#https://}"
    normalized_auth_authority="$(printf '%s' "$auth_authority" | tr '[:upper:]' '[:lower:]')"
    normalized_trusted_authority="$(printf '%s' "$trusted_authority" | tr '[:upper:]' '[:lower:]')"
    if [[ -z "$trusted_authority" || "$normalized_auth_authority" != "$normalized_trusted_authority" ]]; then
      echo "Authenticated fetch retry refused for untrusted authority in $(redact_repo_url "$FETCH_REPO")" >&2
      exit 1
    fi
    auth_header="$(printf 'x-access-token:%s' "$token" | base64 | tr -d '\r\n')"
    rm -rf "$TMP_DIR/source"
    if [[ "$SOURCE_REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
      auth_ok=false
      if git init "$TMP_DIR/source" >/dev/null 2>&1 \
        && git -C "$TMP_DIR/source" remote add origin "$FETCH_REPO" \
        && git -c "http.${auth_origin}.extraheader=AUTHORIZATION: basic $auth_header" \
          -C "$TMP_DIR/source" fetch --depth 1 origin "$SOURCE_REF" >/dev/null 2>&1 \
        && git -C "$TMP_DIR/source" checkout --detach FETCH_HEAD >/dev/null 2>&1; then
        auth_ok=true
      fi
    elif git -c "http.${auth_origin}.extraheader=AUTHORIZATION: basic $auth_header" \
      clone --depth 1 --branch "$SOURCE_REF" "$FETCH_REPO" "$TMP_DIR/source" >/dev/null 2>&1; then
      auth_ok=true
    else
      auth_ok=false
    fi
    if [[ "$auth_ok" != true ]]; then
      echo "Failed to clone $(redact_repo_url "$FETCH_REPO")#$SOURCE_REF (anonymous and token-auth attempts failed)." >&2
      exit 1
    fi
  else
    echo "Failed to clone $(redact_repo_url "$FETCH_REPO")#$SOURCE_REF." >&2
    exit 1
  fi
fi

SOURCE_COMMIT="$(git -C "$TMP_DIR/source" rev-parse HEAD)"
if [[ -n "${BASECOAT_EXPECTED_SHA:-}" && "$SOURCE_COMMIT" != "$BASECOAT_EXPECTED_SHA" ]]; then
  echo "BaseCoat source provenance check failed: expected commit '$BASECOAT_EXPECTED_SHA' but fetched '$SOURCE_COMMIT'." >&2
  exit 1
fi

mkdir -p "$REPO_ROOT/$TARGET_DIR"

# Capture the PREVIOUS release's asset-manifest.json before it is
# overwritten below. If this repo has never run the #3415-fixed sync
# before (no .overlay-managed-files state yet), this lets that first sync
# still identify and prune shared-overlay files the OLD wholesale-wipe
# sync previously installed but this new release retires — otherwise they
# would linger in the overlay forever.
previous_asset_manifest_file=""
if [[ -f "$REPO_ROOT/$TARGET_DIR/asset-manifest.json" ]]; then
  previous_asset_manifest_file="$(mktemp)"
  cp "$REPO_ROOT/$TARGET_DIR/asset-manifest.json" "$previous_asset_manifest_file"
fi

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

# Copy runtime scripts and installed-payload validators.
rm -rf "$REPO_ROOT/$TARGET_DIR/scripts"
mkdir -p "$REPO_ROOT/$TARGET_DIR/scripts"
if [[ -d "$TMP_DIR/source/.github/base-coat/scripts" ]]; then
  cp -R "$TMP_DIR/source/.github/base-coat/scripts/." "$REPO_ROOT/$TARGET_DIR/scripts/"
fi
for validator in validate-basecoat.ps1 validate-basecoat.sh validate-skill-visibility.ps1 validate-asset-distribution.ps1 validate-workflow-action-pins.ps1 validate-workflow-action-pins.py workflow-ownership.ps1 retire-downstream-workflows.ps1; do
  if [[ -f "$TMP_DIR/source/scripts/$validator" ]]; then
    cp "$TMP_DIR/source/scripts/$validator" "$REPO_ROOT/$TARGET_DIR/scripts/$validator"
  fi
done

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}
cat > "$REPO_ROOT/$TARGET_DIR/.source-provenance.json" <<EOF
{
  "schemaVersion": 1,
  "commit": "$(json_escape "$SOURCE_COMMIT")",
  "requestedRef": "$(json_escape "$SOURCE_REF")",
  "source": "$(json_escape "$(redact_repo_url "$SOURCE_REPO")")",
  "mirror": "$(json_escape "$(redact_repo_url "$SOURCE_MIRROR")")"
}
EOF

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

# Copy Copilot-discoverable directories to their standard paths.
# Only copy flat agent/instruction/prompt/skill files — not taxonomy subdirs.
#
# These shared paths (.github/instructions, .github/prompts, .github/skills,
# .github/agents, .github/agents/references, .agents/skills) can also be
# written to by other overlays (e.g. basecoat-sheen, basecoat-adhesion), so
# BaseCoat must never wipe the destination directory wholesale — that would
# silently delete co-located files it does not own (#3415). Instead, copy
# files individually (never deleting anything first) and track every path
# BaseCoat writes in the overlay state file. After all copies, prune only the
# files BaseCoat itself previously placed that are no longer part of this
# sync — every other file, whether foreign or simply untracked, is left
# untouched.
mkdir -p "$REPO_ROOT/.github"

# resolve_real_path <path>: resolves symlinks/junctions on an existing path
# (via coreutils `realpath`) so a linked ancestor placed by a co-located
# overlay cannot silently redirect a write or delete outside the intended
# destination.
resolve_real_path() {
  realpath "$1"
}

# path_within_boundary <path> <boundary>: true only if the canonical
# (symlink-resolved) form of <path> is equal to or nested under the
# canonical form of <boundary>.
path_within_boundary() {
  local path="$1" boundary="$2" real_path real_boundary
  real_path="$(resolve_real_path "$path")" || return 1
  real_boundary="$(resolve_real_path "$boundary")" || return 1
  case "$real_path" in
    "$real_boundary") return 0 ;;
    "$real_boundary"/*) return 0 ;;
    *) return 1 ;;
  esac
}

overlay_state_file="$REPO_ROOT/$TARGET_DIR/.overlay-managed-files"
prev_overlay_file="$(mktemp)"
if [[ -f "$overlay_state_file" ]]; then
  sort -u "$overlay_state_file" -o "$prev_overlay_file"
elif [[ -f "$previous_asset_manifest_file" ]]; then
  # First sync after upgrading to the #3415 fix: there is no tracked
  # ownership history yet, but the OLD wholesale-wipe sync logic may have
  # installed files this new release retires. Reconstruct where each
  # previously-distributed asset would have landed and, if it still exists
  # on disk, treat it as BaseCoat-managed so it can be correctly identified
  # as stale below instead of lingering forever.
  seeded_overlay_file="$(mktemp)"
  grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' "$previous_asset_manifest_file" |
    sed -E 's/.*"path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' |
    while IFS= read -r asset_path; do
      case "$asset_path" in
        agents/references/*)
          echo ".github/agents/references/${asset_path#agents/references/}"
          ;;
        agents/*.agent.md)
          [[ "$asset_path" == */*/*.agent.md ]] && continue
          echo ".github/agents/${asset_path#agents/}"
          ;;
        instructions/*)
          echo ".github/instructions/${asset_path#instructions/}"
          ;;
        prompts/*)
          echo ".github/prompts/${asset_path#prompts/}"
          ;;
        skills/*)
          echo ".github/skills/${asset_path#skills/}"
          echo ".agents/skills/${asset_path#skills/}"
          ;;
      esac
    done > "$seeded_overlay_file"
  : > "$prev_overlay_file"
  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    [[ -f "$REPO_ROOT/$candidate" ]] && echo "$candidate" >> "$prev_overlay_file"
  done < "$seeded_overlay_file"
  rm -f "$seeded_overlay_file"
  sort -u "$prev_overlay_file" -o "$prev_overlay_file"
  seeded_count="$(wc -l < "$prev_overlay_file" | tr -d ' ')"
  if [[ "$seeded_count" -gt 0 ]]; then
    echo "Seeding overlay ownership from $seeded_count previously-distributed file(s) for first sync after #3415 fix."
  fi
else
  : > "$prev_overlay_file"
fi
[[ -n "$previous_asset_manifest_file" && -f "$previous_asset_manifest_file" ]] && rm -f "$previous_asset_manifest_file"
new_overlay_file="$(mktemp)"
: > "$new_overlay_file"

# copy_managed_overlay_tree <source_dir> <dest_dir>: copies every file from
# source into dest without deleting dest first, recording each written path
# (repo-relative) into $new_overlay_file.
copy_managed_overlay_tree() {
  local src="$1" dest="$2" rel dest_rel dest_dir dest_root_real
  [[ -d "$src" ]] || return 0
  mkdir -p "$dest"
  dest_root_real="$(resolve_real_path "$dest")"
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    dest_dir="$dest/$(dirname "$rel")"
    mkdir -p "$dest_dir"
    if ! path_within_boundary "$dest_dir" "$dest_root_real"; then
      echo "Refusing to write through a symlinked overlay path outside $dest: $dest/$rel" >&2
      continue
    fi
    if [[ -L "$dest/$rel" ]]; then
      echo "Refusing to overwrite a symlinked overlay destination file: $dest/$rel" >&2
      continue
    fi
    cp -f "$f" "$dest/$rel"
    dest_rel="${dest#"$REPO_ROOT"/}/$rel"
    echo "$dest_rel" >> "$new_overlay_file"
  done < <(find "$src" -type f -print0)
}

for copilot_dir in instructions prompts skills; do
  copy_managed_overlay_tree "$REPO_ROOT/$TARGET_DIR/$copilot_dir" "$REPO_ROOT/.github/$copilot_dir"
done

# Also copy skills to .agents/skills/ for cross-client interop (Agent Skills spec)
mkdir -p "$REPO_ROOT/.agents"
copy_managed_overlay_tree "$REPO_ROOT/$TARGET_DIR/skills" "$REPO_ROOT/.agents/skills"

# Agents: copy only *.agent.md files (skip taxonomy subdirs like models/, tasks/, types/)
if [[ -d "$REPO_ROOT/$TARGET_DIR/agents" ]]; then
  mkdir -p "$REPO_ROOT/.github/agents"
  agents_dest_real="$(resolve_real_path "$REPO_ROOT/.github/agents")"
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    if ! path_within_boundary "$REPO_ROOT/.github/agents" "$agents_dest_real"; then
      echo "Refusing to write through a symlinked overlay path outside $REPO_ROOT/.github/agents: $base" >&2
      continue
    fi
    if [[ -L "$REPO_ROOT/.github/agents/$base" ]]; then
      echo "Refusing to overwrite a symlinked overlay destination file: .github/agents/$base" >&2
      continue
    fi
    cp -f "$f" "$REPO_ROOT/.github/agents/$base"
    echo ".github/agents/$base" >> "$new_overlay_file"
  done < <(find "$REPO_ROOT/$TARGET_DIR/agents" -maxdepth 1 -name '*.agent.md' -print0)
fi

# Agent references: agent files may link to agents/references/<name>-detail.md
# for overflow content moved out to satisfy the token budget. Copy the whole
# subtree so those relative links resolve for installed agents.
copy_managed_overlay_tree "$REPO_ROOT/$TARGET_DIR/agents/references" "$REPO_ROOT/.github/agents/references"

# Prune only files BaseCoat previously placed in the shared overlay
# directories that are no longer part of the current sync. Anything not
# previously tracked (foreign files, or files never tracked) is left alone,
# regardless of whether it happens to sit in one of these dirs.
sort -u "$new_overlay_file" -o "$new_overlay_file"
comm -23 "$prev_overlay_file" "$new_overlay_file" > "${new_overlay_file}.stale" || true
repo_root_real="$(resolve_real_path "$REPO_ROOT")"
while IFS= read -r stale_rel; do
  [[ -z "$stale_rel" ]] && continue
  # Deletion candidates come from a state file (or, for the first sync, the
  # reconstructed previous manifest) that could in principle contain a
  # corrupted or maliciously crafted entry (e.g. '../victim' or a path under
  # .github/workflows). Reject anything that is not a relative path confined
  # to one of the exact managed overlay prefixes before it is even joined to
  # $REPO_ROOT, then re-verify containment against the canonical
  # (symlink-resolved) boundary right before deleting.
  case "$stale_rel" in
    /*|../*|*/../*|*/..|..)
      echo "Skipping stale overlay entry outside the managed overlay prefixes: $stale_rel" >&2
      continue
      ;;
  esac
  case "$stale_rel" in
    .github/instructions/*|.github/prompts/*|.github/skills/*|.github/agents/*|.agents/skills/*) ;;
    *)
      echo "Skipping stale overlay entry outside the managed overlay prefixes: $stale_rel" >&2
      continue
      ;;
  esac
  stale_full="$REPO_ROOT/$stale_rel"
  if [[ -f "$stale_full" ]]; then
    if ! path_within_boundary "$stale_full" "$repo_root_real"; then
      echo "Refusing to delete a stale overlay entry that resolves outside the repository: $stale_rel" >&2
      continue
    fi
    rm -f "$stale_full"
    echo "Removed stale BaseCoat-managed overlay file: $stale_rel"
    parent_dir="$(dirname "$stale_full")"
    while [[ "$parent_dir" == "$REPO_ROOT/.github/instructions"* || \
             "$parent_dir" == "$REPO_ROOT/.github/prompts"* || \
             "$parent_dir" == "$REPO_ROOT/.github/skills"* || \
             "$parent_dir" == "$REPO_ROOT/.github/agents"* || \
             "$parent_dir" == "$REPO_ROOT/.agents/skills"* ]]; do
      if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
        rmdir "$parent_dir"
        parent_dir="$(dirname "$parent_dir")"
      else
        break
      fi
    done
  fi
done < "${new_overlay_file}.stale"
rm -f "${new_overlay_file}.stale"

cp "$new_overlay_file" "$overlay_state_file"
rm -f "$prev_overlay_file" "$new_overlay_file"

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

if [[ "$SOURCE_REF" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  expected_version="${BASH_REMATCH[1]}"
  version_file="$REPO_ROOT/$TARGET_DIR/version.json"

  if [[ ! -f "$version_file" ]]; then
    echo "BaseCoat ref/version provenance check failed: '$SOURCE_REF' requires version.json but the file is missing." >&2
    exit 1
  fi

  synced_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$version_file" | head -n 1)"
  if [[ -z "$synced_version" ]]; then
    echo "BaseCoat ref/version provenance check failed: '$version_file' does not contain a version field." >&2
    exit 1
  fi

  if [[ "$synced_version" != "$expected_version" ]]; then
    echo "BaseCoat ref/version provenance check failed: requested '$SOURCE_REF' expects version '$expected_version' but synced payload reports '$synced_version'." >&2
    exit 1
  fi
fi

echo "Base Coat synced into $TARGET_DIR"
