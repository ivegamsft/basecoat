#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASECOAT_REPO="${1:-IBuySpy-Shared/basecoat}"
BASECOAT_VERSION="${2:-v$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO_ROOT/version.json" | head -n 1)}"
ARTIFACT_SOURCE="${3:-release}"
KEEP_REPO="${KEEP_REPO:-0}"
TEMP_REPO="$REPO_ROOT/test-results/basecoat-consumer-bash-$$"
DOWNLOAD_DIR="$TEMP_REPO/.basecoat-download"
INSTALL_PATH="$TEMP_REPO/.github/base-coat"

if [[ "$ARTIFACT_SOURCE" != "release" && "$ARTIFACT_SOURCE" != "current" ]]; then
  echo "Artifact source must be 'release' or 'current'." >&2
  exit 1
fi

rm -rf "$TEMP_REPO"
mkdir -p "$TEMP_REPO"

cleanup() {
  if [[ "$KEEP_REPO" != "1" ]]; then
    rm -rf "$TEMP_REPO"
  fi
}
trap cleanup EXIT

for command in git gh tar sha256sum python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command is required" >&2
    exit 1
  fi
done

assert_path_exists() {
  local path="$1"
  local message="$2"
  if [[ ! -e "$path" ]]; then
    echo "$message" >&2
    exit 1
  fi
}

verify_release_digest() {
  local asset_name="$1"
  local archive="$2"
  local expected_digest
  expected_digest="$(
    gh release view "$BASECOAT_VERSION" \
      --repo "$BASECOAT_REPO" \
      --json assets \
      --jq ".assets[] | select(.name == \"$asset_name\") | .digest"
  )"
  if [[ ! "$expected_digest" =~ ^sha256:([a-fA-F0-9]{64})$ ]]; then
    echo "Release asset is missing an immutable SHA-256 digest: $asset_name" >&2
    exit 1
  fi
  local actual_digest
  actual_digest="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "${actual_digest,,}" != "${BASH_REMATCH[1],,}" ]]; then
    echo "Release asset digest mismatch: $asset_name" >&2
    exit 1
  fi
}

mkdir -p "$TEMP_REPO/.github/workflows" "$DOWNLOAD_DIR" "$INSTALL_PATH"
git init "$TEMP_REPO" >/dev/null

pushd "$TEMP_REPO" >/dev/null
git config user.name basecoat-consumer-test
git config user.email basecoat-consumer-test@example.com

cat > .github/base-coat.lock.json <<EOF
{
  "baseCoatRepo": "$BASECOAT_REPO",
  "version": "$BASECOAT_VERSION",
  "installPath": ".github/base-coat",
  "checksumRequired": true
}
EOF

if [[ "$ARTIFACT_SOURCE" == "release" ]]; then
  package_version="${BASECOAT_VERSION#v}"
  asset_name="base-coat-$package_version.tar.gz"
  zip_asset_name="base-coat-$package_version.zip"
  source_asset_name="basecoat-$BASECOAT_VERSION.zip"
  GH_PAGER=cat gh release download "$BASECOAT_VERSION" \
    --repo "$BASECOAT_REPO" \
    --pattern "$asset_name" \
    --pattern "$zip_asset_name" \
    --pattern "$source_asset_name" \
    --pattern "SHA256SUMS.txt" \
    --dir "$DOWNLOAD_DIR"
  archive="$DOWNLOAD_DIR/$asset_name"
  assert_path_exists "$archive" "Release archive not downloaded: $asset_name"
  pushd "$DOWNLOAD_DIR" >/dev/null
  sha256sum -c SHA256SUMS.txt
  popd >/dev/null
  verify_release_digest "$asset_name" "$archive"
  tar -xzf "$archive" -C "$TEMP_REPO"
  rm -rf "$INSTALL_PATH"
  mv "$TEMP_REPO/base-coat" "$INSTALL_PATH"

  source_archive="$DOWNLOAD_DIR/$source_asset_name"
  assert_path_exists "$source_archive" "Release source archive not downloaded: $source_asset_name"
  verify_release_digest "$source_asset_name" "$source_archive"
  source_extract="$TEMP_REPO/.basecoat-release-source"
  mkdir -p "$source_extract"
  python3 -m zipfile -e "$source_archive" "$source_extract"
  for source_path in \
    "$source_extract/templates/intake/PULL_REQUEST_TEMPLATE.md" \
    "$source_extract/templates/intake/issue.md"; do
    assert_path_exists "$source_path" "Released source baseline missing: $source_path"
  done
else
  bash "$REPO_ROOT/scripts/package-basecoat.sh" "$REPO_ROOT"
  package_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO_ROOT/version.json" | head -n 1)"
  dist_dir="$REPO_ROOT/dist"
  pushd "$dist_dir" >/dev/null
  sha256sum -c SHA256SUMS.txt
  popd >/dev/null
  rm -rf "$INSTALL_PATH"
  tar -xzf "$dist_dir/base-coat-$package_version.tar.gz" -C "$TEMP_REPO"
  mv "$TEMP_REPO/base-coat" "$INSTALL_PATH"
fi

for path in \
  "$INSTALL_PATH/instructions" \
  "$INSTALL_PATH/skills" \
  "$INSTALL_PATH/prompts" \
  "$INSTALL_PATH/agents" \
  "$INSTALL_PATH/version.json"; do
  assert_path_exists "$path" "Installed baseline missing: $path"
done

if [[ "$ARTIFACT_SOURCE" == "current" ]]; then
  for path in \
    "$INSTALL_PATH/workflows" \
    "$INSTALL_PATH/templates/intake/PULL_REQUEST_TEMPLATE.md" \
    "$INSTALL_PATH/templates/intake/issue.md" \
    "$INSTALL_PATH/scripts/validate-basecoat.ps1" \
    "$INSTALL_PATH/scripts/validate-basecoat.sh" \
    "$INSTALL_PATH/scripts/validate-workflow-action-pins.ps1" \
    "$INSTALL_PATH/scripts/validate-workflow-action-pins.py"; do
    assert_path_exists "$path" "Installed validation component missing: $path"
  done
else
  assert_path_exists \
    "$INSTALL_PATH/.github/base-coat/workflows" \
    "Released package missing its distributed workflows"
fi

bash "$INSTALL_PATH/scripts/validate-basecoat.sh" "$INSTALL_PATH"

if [[ "$ARTIFACT_SOURCE" == "current" ]]; then
  invalid_workflow="$INSTALL_PATH/workflows/consumer-smoke-unpinned.yml"
  cat > "$invalid_workflow" <<'EOF'
jobs:
  validate:
    steps:
      - uses: actions/checkout@v4
EOF
  if bash "$INSTALL_PATH/scripts/validate-basecoat.sh" "$INSTALL_PATH"; then
    echo "Installed payload validation did not reject an unpinned consumer workflow action." >&2
    exit 1
  fi
  rm -f "$invalid_workflow"
fi

echo "$ARTIFACT_SOURCE consumer smoke test passed in $TEMP_REPO"
popd >/dev/null
