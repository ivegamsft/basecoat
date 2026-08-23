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

  if ! sed -n '1,20p' "$file" | grep -qi '^description:'; then
    echo "Missing description in frontmatter for $file" >&2
    exit 1
  fi

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
    if ! sed -n '1,20p' "$file" | grep -qi '^name:'; then
      echo "Missing name in frontmatter for $file" >&2
      exit 1
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
