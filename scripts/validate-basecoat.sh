#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
FAIL_ON_WARNING=0
if [[ ${2:-} == "--fail-on-warning" ]]; then
  FAIL_ON_WARNING=1
fi
cd "$ROOT_DIR"

required=(README.md CHANGELOG.md version.json asset-manifest.json sync.sh sync.ps1 instructions skills prompts agents)
for item in "${required[@]}"; do
  if [[ ! -e "$item" ]]; then
    echo "Missing required path: $item" >&2
    exit 1
  fi
done

# INVENTORY.md moved to docs/reference/ in v3.11.0 — accept either location
if [[ ! -e "INVENTORY.md" && ! -e "docs/reference/INVENTORY.md" ]]; then
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

  if [[ "$(basename "$file")" == "SKILL.md" ]]; then
    if ! sed -n '1,20p' "$file" | grep -qi '^name:'; then
      echo "Missing name in frontmatter for $file" >&2
      exit 1
    fi

    token_count=$(python3 - "$file" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
print(round(len(re.findall(r'\S+', text)) * 1.35))
PY
)
    if (( token_count > 500 )); then
      warning_count=$((warning_count + 1))
      echo "WARNING: $file exceeds approx 500-token budget target (approx $token_count tokens)" >&2
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
