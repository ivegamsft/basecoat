#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"
cd "$ROOT_DIR"

VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' version.json | head -n 1)"
if [[ -z "$VERSION" ]]; then
  echo "Unable to determine version from version.json" >&2
  exit 1
fi

DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/stage/base-coat"
ARCHIVE_BASE="base-coat-$VERSION"

rm -rf "$DIST_DIR"
mkdir -p "$STAGE_DIR"

for item in README.md CHANGELOG.md INVENTORY.md version.json asset-manifest.json sync.sh sync.ps1 instructions skills prompts agents scripts templates .githooks docs examples .github; do
  if [[ -e "$item" ]]; then
    cp -R "$item" "$STAGE_DIR/$item"
  fi
done

distributed_workflows="$STAGE_DIR/.github/base-coat/workflows"
if [[ ! -d "$distributed_workflows" ]]; then
  echo "Package validation failed: missing distributed workflows '$distributed_workflows'" >&2
  exit 1
fi
cp -R "$distributed_workflows" "$STAGE_DIR/workflows"

validation_scripts=(
  scripts/validate-basecoat.ps1
  scripts/validate-basecoat.sh
  scripts/validate-workflow-action-pins.ps1
  scripts/validate-workflow-action-pins.py
  scripts/validate-reusable-workflow-contracts.py
)
for relative_path in "${validation_scripts[@]}"; do
  if [[ ! -f "$STAGE_DIR/$relative_path" ]]; then
    echo "Package validation failed: missing workflow pin validator '$relative_path'" >&2
    exit 1
  fi
done
python3 - "$STAGE_DIR/asset-manifest.json" "${validation_scripts[@]}" <<'PY'
import json
import sys

manifest_path, *required_paths = sys.argv[1:]
with open(manifest_path, encoding="utf-8") as handle:
    manifest_paths = {asset["path"] for asset in json.load(handle)["assets"]}
missing = [path for path in required_paths if path not in manifest_paths]
if missing:
    raise SystemExit(
        "Package validation failed: asset-manifest.json is missing " + ", ".join(missing)
    )
PY

packaged_callers=()
while IFS= read -r packaged_caller; do
  packaged_callers+=("$packaged_caller")
done < <(
  grep -rlE '/\.github/workflows/check-basecoat-version-callable\.yml@' \
    "$STAGE_DIR/.github/workflow-templates" --include='*.yml' --include='*.yaml'
)
if [[ ${#packaged_callers[@]} -eq 0 ]]; then
  echo "Package validation failed: no packaged BaseCoat version workflow callers found" >&2
  exit 1
fi
python3 "$STAGE_DIR/scripts/validate-reusable-workflow-contracts.py" \
  "$STAGE_DIR/.github/workflows/check-basecoat-version-callable.yml" \
  "${packaged_callers[@]}"

if command -v zip >/dev/null 2>&1; then
  (cd "$DIST_DIR/stage" && zip -qr "../$ARCHIVE_BASE.zip" base-coat)
else
  (cd "$DIST_DIR/stage" && python3 -m zipfile -c "../$ARCHIVE_BASE.zip" base-coat)
fi
tar -C "$DIST_DIR/stage" -czf "$DIST_DIR/$ARCHIVE_BASE.tar.gz" base-coat

(cd "$DIST_DIR" && sha256sum "$ARCHIVE_BASE.zip" "$ARCHIVE_BASE.tar.gz" > SHA256SUMS.txt)

echo "Packaged artifacts into $DIST_DIR"
