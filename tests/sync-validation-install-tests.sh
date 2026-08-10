#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_ROOT="$REPO_ROOT/test-results/sync-validation-bash-$$"
CONSUMER_ROOT="$FIXTURE_ROOT/consumer"
TEST_BRANCH="sync-validation-$RANDOM-$$"

cleanup() {
  git -C "$REPO_ROOT" branch -D "$TEST_BRANCH" >/dev/null 2>&1 || true
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

mkdir -p "$CONSUMER_ROOT" "$FIXTURE_ROOT/tmp"
git -C "$CONSUMER_ROOT" init >/dev/null
git -C "$CONSUMER_ROOT" config user.name basecoat-test
git -C "$CONSUMER_ROOT" config user.email basecoat-test@example.com
printf '# Consumer\n' > "$CONSUMER_ROOT/README.md"
git -C "$CONSUMER_ROOT" add README.md
git -C "$CONSUMER_ROOT" commit -m 'initial commit' >/dev/null

git -C "$REPO_ROOT" branch "$TEST_BRANCH" HEAD
pushd "$CONSUMER_ROOT" >/dev/null
BASECOAT_REPO="file://$REPO_ROOT" \
BASECOAT_REF="$TEST_BRANCH" \
TMPDIR="$FIXTURE_ROOT/tmp" \
  bash "$REPO_ROOT/sync.sh"
popd >/dev/null

INSTALL_PATH="$CONSUMER_ROOT/.github/base-coat"
for validator in \
  validate-basecoat.ps1 \
  validate-basecoat.sh \
  validate-workflow-action-pins.ps1 \
  validate-workflow-action-pins.py; do
  if [[ ! -f "$INSTALL_PATH/scripts/$validator" ]]; then
    echo "Bash sync did not install validator: scripts/$validator" >&2
    exit 1
  fi
done

bash "$INSTALL_PATH/scripts/validate-basecoat.sh" "$INSTALL_PATH"

invalid_workflow="$INSTALL_PATH/workflows/sync-test-unpinned.yml"
cat > "$invalid_workflow" <<'EOF'
jobs:
  validate:
    steps:
      - uses: actions/checkout@v4
EOF
if bash "$INSTALL_PATH/scripts/validate-basecoat.sh" "$INSTALL_PATH"; then
  echo "Bash sync-installed validator accepted an unpinned workflow action." >&2
  exit 1
fi

echo "Bash sync validation install tests passed"
