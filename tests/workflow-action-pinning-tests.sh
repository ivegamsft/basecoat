#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_ROOT="$REPO_ROOT/test-results/workflow-action-pinning-bash-$$"
CHECKOUT_SHA="9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0"

cleanup() {
  rm -rf "$FIXTURE_ROOT"
}
trap cleanup EXIT

mkdir -p \
  "$FIXTURE_ROOT/instructions" \
  "$FIXTURE_ROOT/skills" \
  "$FIXTURE_ROOT/prompts" \
  "$FIXTURE_ROOT/agents" \
  "$FIXTURE_ROOT/scripts" \
  "$FIXTURE_ROOT/workflows"

cat > "$FIXTURE_ROOT/README.md" <<'EOF'
# Installed fixture
EOF
cat > "$FIXTURE_ROOT/CHANGELOG.md" <<'EOF'
# Changes
EOF
cat > "$FIXTURE_ROOT/INVENTORY.md" <<'EOF'
# Inventory
EOF
cat > "$FIXTURE_ROOT/version.json" <<'EOF'
{"version":"1.0.0"}
EOF
cat > "$FIXTURE_ROOT/asset-manifest.json" <<'EOF'
{"schemaVersion":"1","libraryVersion":"1.0.0","assets":[{"path":"workflows/valid.yml"}]}
EOF
cat > "$FIXTURE_ROOT/sync.sh" <<'EOF'
#!/usr/bin/env bash
EOF
cat > "$FIXTURE_ROOT/sync.ps1" <<'EOF'
$true
EOF
cat > "$FIXTURE_ROOT/workflows/valid.yml" <<EOF
jobs:
  validate:
    steps:
      - uses: actions/checkout@$CHECKOUT_SHA
        with: { uses: nested-input }
      - run: |
          echo "uses: actions/checkout@v4"
EOF

cp \
  "$REPO_ROOT/scripts/validate-basecoat.sh" \
  "$REPO_ROOT/scripts/validate-workflow-action-pins.py" \
  "$FIXTURE_ROOT/scripts/"

bash "$FIXTURE_ROOT/scripts/validate-basecoat.sh" "$FIXTURE_ROOT"

cat > "$FIXTURE_ROOT/workflows/invalid.yml" <<'EOF'
jobs:
  validate:
    steps:
      - uses: actions/checkout@v4
EOF
if bash "$FIXTURE_ROOT/scripts/validate-basecoat.sh" "$FIXTURE_ROOT"; then
  echo "Installed Bash validation did not reject an unpinned workflow action." >&2
  exit 1
fi

echo "Bash workflow action pinning tests passed"
