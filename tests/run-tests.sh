#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

assert_path_exists() {
  local path="$1"
  local message="$2"
  if [[ ! -e "$path" ]]; then
    echo "$message" >&2
    exit 1
  fi
}

echo "Running validate-basecoat.sh..."
bash scripts/validate-basecoat.sh

echo "Running installed workflow action pinning tests..."
bash tests/workflow-action-pinning-tests.sh

echo "Running Bash sync validation install tests..."
bash tests/sync-validation-install-tests.sh

echo "Running package-basecoat.sh..."
bash scripts/package-basecoat.sh

version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' version.json | head -n 1)"
assert_path_exists "dist/base-coat-$version.zip" "Packaging test failed: zip artifact missing"
assert_path_exists "dist/base-coat-$version.tar.gz" "Packaging test failed: tar.gz artifact missing"
assert_path_exists "dist/SHA256SUMS.txt" "Packaging test failed: SHA256SUMS.txt missing"

if ! grep -q "base-coat-$version.zip" dist/SHA256SUMS.txt || ! grep -q "base-coat-$version.tar.gz" dist/SHA256SUMS.txt; then
  echo "Packaging test failed: checksum file missing expected artifact names" >&2
  exit 1
fi

echo "Running install-git-hooks.sh..."
bash scripts/install-git-hooks.sh
hooks_path="$(git config --get core.hooksPath)"
if [[ "$hooks_path" != ".githooks" ]]; then
  echo "Hook installation test failed. Expected '.githooks', got '$hooks_path'." >&2
  exit 1
fi

echo "Running commit message scanner negative test..."
cleanup() {
  if [[ -n "${temp_repo:-}" ]]; then
    rm -rf "$temp_repo"
  fi
}
trap cleanup EXIT
temp_repo="$(mktemp -d)"

pushd "$temp_repo" >/dev/null
git init >/dev/null
git config user.name basecoat-test
git config user.email basecoat-test@example.com
echo "hello" > test.txt
git add test.txt
git commit -m "safe commit message" >/dev/null
echo "updated" > test.txt
git add test.txt
git commit -m "-----BEGIN PRIVATE KEY-----" >/dev/null

if bash "$REPO_ROOT/scripts/scan-commit-messages.sh" HEAD~1..HEAD >/dev/null 2>&1; then
  echo "Commit message scanner test failed: expected failure for sensitive commit message" >&2
  exit 1
fi
popd >/dev/null

echo "All bash tests passed"