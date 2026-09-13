#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${1:-$(pwd)}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
FAIL_ON_WARNING=0
warning_count=0
if [[ ${2:-} == "--fail-on-warning" ]]; then
  FAIL_ON_WARNING=1
fi
cd "$ROOT_DIR"

has_frontmatter_field() {
  local field="$1"
  local file="$2"
  awk -v field="$field" 'NR <= 20 && tolower($0) ~ "^" tolower(field) ":" { found = 1 } END { exit(found ? 0 : 1) }' "$file"
}

# Prints the raw scalar value of a top-level field from the YAML frontmatter
# block only (never the body), or nothing if absent. Scoping to the frontmatter
# block avoids false positives from fenced code samples elsewhere in the file.
frontmatter_field() {
  local field="$1" file="$2"
  awk -v field="$field" '
    NR == 1 && $0 != "---" { exit }
    NR == 1 { infm = 1; next }
    infm && $0 == "---" { exit }
    infm && tolower($0) ~ "^" tolower(field) ":" {
      line = $0
      sub("^[^:]*:[ \t]*", "", line)
      sub("[ \t]+#.*$", "", line)
      print line
      exit
    }
  ' "$file"
}

# Prints "1" when a top-level field key is present in the YAML frontmatter block
# (regardless of value), else nothing. Used to distinguish an absent field from
# a present-but-empty one, so `ships:` with no value is rejected rather than
# silently defaulted.
frontmatter_has_field() {
  local field="$1" file="$2"
  awk -v field="$field" '
    NR == 1 && $0 != "---" { exit }
    NR == 1 { infm = 1; next }
    infm && $0 == "---" { exit }
    infm && tolower($0) ~ "^" tolower(field) ":" { print "1"; exit }
  ' "$file"
}

# Normalizes a frontmatter scalar: strips surrounding quotes and surrounding
# whitespace only (never interior whitespace, so a malformed `t rue` stays
# malformed), then lowercases.
normalize_scalar() {
  printf '%s' "$1" \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^["'"'"']//; s/["'"'"']$//; s/^[[:space:]]+//; s/[[:space:]]+$//' \
    | tr '[:upper:]' '[:lower:]'
}

# Validates the #3374 asset distribution classification (ships/dogfood/status).
# Kept in sync with scripts/validate-asset-distribution.ps1.
check_asset_distribution() {
  local file="$1" ships dogfood status eff_ships eff_dogfood eff_status
  ships="$(normalize_scalar "$(frontmatter_field ships "$file")")"
  dogfood="$(normalize_scalar "$(frontmatter_field dogfood "$file")")"
  status="$(normalize_scalar "$(frontmatter_field status "$file")")"

  if [[ -z "$ships" && -n "$(frontmatter_has_field ships "$file")" ]]; then
    echo "Invalid ships '' in $file (expected true or false)" >&2
    exit 1
  fi
  if [[ -z "$dogfood" && -n "$(frontmatter_has_field dogfood "$file")" ]]; then
    echo "Invalid dogfood '' in $file (expected true or false)" >&2
    exit 1
  fi
  if [[ -z "$status" && -n "$(frontmatter_has_field status "$file")" ]]; then
    echo "Invalid status '' in $file (expected experimental, active, or deprecated)" >&2
    exit 1
  fi

  if [[ -n "$ships" && "$ships" != "true" && "$ships" != "false" ]]; then
    echo "Invalid ships '$ships' in $file (expected true or false)" >&2
    exit 1
  fi
  if [[ -n "$dogfood" && "$dogfood" != "true" && "$dogfood" != "false" ]]; then
    echo "Invalid dogfood '$dogfood' in $file (expected true or false)" >&2
    exit 1
  fi
  if [[ -n "$status" && "$status" != "experimental" && "$status" != "active" && "$status" != "deprecated" ]]; then
    echo "Invalid status '$status' in $file (expected experimental, active, or deprecated)" >&2
    exit 1
  fi

  eff_ships="${ships:-true}"
  eff_dogfood="${dogfood:-false}"
  eff_status="${status:-active}"
  if [[ "$eff_ships" == "false" && "$eff_dogfood" == "false" && "$eff_status" != "experimental" && "$eff_status" != "deprecated" ]]; then
    echo "Invalid distribution in $file: ships:false and dogfood:false requires status experimental or deprecated" >&2
    exit 1
  fi
}

required=(README.md CHANGELOG.md version.json asset-manifest.json instructions skills prompts agents)
if [[ ! -d workflows || -e .git ]]; then
  required+=(sync.sh sync.ps1)
fi
for item in "${required[@]}"; do
  if [[ ! -e "$item" ]]; then
    echo "Missing required path: $item" >&2
    exit 1
  fi
done

echo "Validating immutable workflow action pins..."
python3 "$SCRIPT_DIR/validate-workflow-action-pins.py" --root "$ROOT_DIR" --mode auto

# INVENTORY.md moved to docs/reference/ in v3.11.0 — accept either location (lowercase after Phase 3+4)
if [[ ! -e "INVENTORY.md" && ! -e "docs/reference/INVENTORY.md" && ! -e "docs/reference/inventory.md" ]]; then
  echo "Missing required path: INVENTORY.md" >&2
  exit 1
fi

while IFS= read -r file; do
  if [[ "$(sed -n '1p' "$file")" != "---" ]]; then
    echo "Missing frontmatter start in $file" >&2
    exit 1
  fi

  if ! has_frontmatter_field 'description' "$file"; then
    echo "Missing description in frontmatter for $file" >&2
    exit 1
  fi

  case "$(basename "$file")" in
    *.agent.md | SKILL.md | *.prompt.md) check_asset_distribution "$file" ;;
  esac

  if [[ "$(basename "$file")" == *.agent.md ]]; then
    if ! awk 'NR >= 2 && NR <= 60 && $0 == "---" { found = 1; exit } END { exit(found ? 0 : 1) }' "$file"; then
      echo "Missing YAML frontmatter closing '---' within first 60 lines in $file" >&2
      exit 1
    fi

    if ! grep -Eq '^## Inputs$' "$file"; then
      echo "Missing required section '## Inputs' in $file" >&2
      exit 1
    fi

    if ! grep -Eq '^## (Process|Workflow)$' "$file"; then
      echo "Missing required section '## Process' or '## Workflow' in $file" >&2
      exit 1
    fi

    if ! grep -Eiq '^##.*(output|report|results)' "$file"; then
      echo "Missing required output/report/results section in $file" >&2
      exit 1
    fi
  fi

  if [[ "$(basename "$file")" == "SKILL.md" ]]; then
    if ! has_frontmatter_field 'name' "$file"; then
      echo "Missing name in frontmatter for $file" >&2
      exit 1
    fi

    # Skills: visibility, when present, must be public|private. Agents use a
    # different routing-tier taxonomy (basic|specialized|advanced|internal),
    # so this enum check is scoped to SKILL.md only. Kept in sync with
    # scripts/validate-skill-visibility.ps1.
    visibility_line="$(awk 'NR==1 && /^---[[:space:]]*$/{inblock=1; next} inblock && /^---[[:space:]]*$/{exit} inblock{print}' "$file" | grep -E '^visibility:\s*' | head -n 1 || true)"
    if [[ -n "$visibility_line" ]]; then
      visibility_value="$(echo "$visibility_line" | sed -E 's/^visibility:\s*//; s/^["'"'"']?//; s/["'"'"']?$//' | tr -d '[:space:]')"
      if [[ "$visibility_value" != "public" && "$visibility_value" != "private" ]]; then
        echo "Invalid skill visibility '$visibility_value' in $file (expected 'public' or 'private')" >&2
        exit 1
      fi
    fi

    token_count=$(python3 - "$file" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
# words * 1.7 approximates cl100k_base tokens; kept in sync with scripts/audit-skills.ps1
print(round(len(re.findall(r'\S+', text)) * 1.7))
PY
)
    if (( token_count > 630 )); then
      warning_count=$((warning_count + 1))
      echo "WARNING: $file exceeds approx 630-token budget target (approx $token_count tokens)" >&2
    fi
  fi
done < <(find instructions prompts agents skills -type f \( -name '*.instructions.md' -o -name '*.prompt.md' -o -name '*.agent.md' -o -name 'SKILL.md' \) | sort)

# Optional per-asset version must be SemVer when present
while IFS= read -r file; do
  version_line="$(sed -n '1,40p' "$file" | grep -E '^version:\s*' | head -n 1 || true)"
  if [[ -n "$version_line" ]]; then
    version_value="$(echo "$version_line" | sed -E 's/^version:\s*//; s/^["'"'"']?//; s/["'"'"']?$//')"
    if [[ ! "$version_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "Invalid version '$version_value' in $file (expected SemVer X.Y.Z)" >&2
      exit 1
    fi
  fi
done < <(find instructions prompts agents skills -type f \( -name '*.instructions.md' -o -name '*.prompt.md' -o -name '*.agent.md' -o -name 'SKILL.md' \) | sort)

# Validate asset-manifest basic shape
python3 - <<'PY'
import json,sys
try:
    data=json.load(open("asset-manifest.json","r",encoding="utf-8"))
    for key in ("schemaVersion","libraryVersion","assets"):
        if key not in data:
            raise ValueError(f"missing key: {key}")
except Exception as e:
    print(f"asset-manifest.json invalid: {e}", file=sys.stderr)
    sys.exit(1)
PY

echo "Base Coat validation passed"

if [[ "$FAIL_ON_WARNING" == "1" && "$warning_count" -gt 0 ]]; then
  echo "Validation failed in fail-on-warning mode: $warning_count warning(s) found." >&2
  exit 1
fi
