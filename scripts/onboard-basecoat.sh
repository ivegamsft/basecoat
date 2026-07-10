#!/usr/bin/env bash
# onboard-basecoat.sh — One-command onboarding for basecoat memory contributions.
#
# Adds the basecoat-enabled topic and creates the three learning labels in a repo.
# After running, the repo is enlisted for the weekly passive sweep and can use
# all active push paths immediately.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/ivegamsft/basecoat/main/scripts/onboard-basecoat.sh) \
#     --repo YOUR_ORG/YOUR_REPO
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - Write access to the target repo
#
# Flags:
#   --repo    org/repo to enlist (required)
#   --dry-run Print what would be done without making changes

set -euo pipefail

REPO=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" ]]; then
  # Try to infer from git remote
  REPO=$(git remote get-url origin 2>/dev/null \
    | sed 's|.*github\.com[:/]\(.*\)\.git|\1|' \
    | sed 's|.*github\.com[:/]\(.*\)|\1|' || true)
  if [[ -z "$REPO" ]]; then
    echo "❌ --repo is required (e.g., --repo myorg/myrepo)" >&2
    exit 1
  fi
  echo "ℹ️  Inferred repo from git remote: $REPO"
fi

ORG="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

echo "🚀 Onboarding $REPO to basecoat memory contributions"
echo ""

# ── Step 1: Add basecoat-enabled topic ────────────────────────────────────────

echo "📌 Step 1/2: Adding 'basecoat-enabled' topic..."

if [[ "$DRY_RUN" == "true" ]]; then
  echo "   [dry-run] gh api repos/$REPO/topics --method PUT --field names[]=basecoat-enabled"
else
  # Get existing topics and append
  EXISTING=$(gh api "repos/$REPO/topics" --jq '.names[]' 2>/dev/null | tr '\n' ' ' || echo "")
  TOPICS_JSON="[]"
  if [[ -n "$EXISTING" ]]; then
    # Build JSON array of existing + new topic
    TOPICS_JSON=$(echo "$EXISTING basecoat-enabled" \
      | tr ' ' '\n' | sort -u | grep -v '^$' \
      | jq -R . | jq -s .)
  else
    TOPICS_JSON='["basecoat-enabled"]'
  fi

  gh api "repos/$REPO/topics" \
    --method PUT \
    --input <(jq -n --argjson names "$TOPICS_JSON" '{names: $names}') \
    --silent
  echo "   ✅ Topic added: basecoat-enabled"
fi

# ── Step 2: Create learning labels ────────────────────────────────────────────

echo "🏷️  Step 2/2: Creating learning labels..."

declare -A LABELS
LABELS["learning"]="0075ca:Candidate for basecoat shared memory"
LABELS["retrospective"]="e4e669:Sprint retrospective finding"
LABELS["decision"]="d93f0b:Architecture or process decision"

for name in "${!LABELS[@]}"; do
  IFS=':' read -r color desc <<< "${LABELS[$name]}"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "   [dry-run] gh label create $name --color $color --repo $REPO"
  else
    # Create or update (ignore already-exists error)
    if gh label create "$name" \
        --color "$color" \
        --description "$desc" \
        --repo "$REPO" 2>/dev/null; then
      echo "   ✅ Created label: $name"
    else
      # Label might already exist — update it
      gh label edit "$name" \
        --color "$color" \
        --description "$desc" \
        --repo "$REPO" 2>/dev/null && echo "   ↻  Updated label: $name" \
        || echo "   ℹ️  Label already exists: $name"
    fi
  fi
done

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "✅ $REPO is now enlisted in basecoat memory contributions."
echo ""
echo "Next steps:"
echo "  Passive:  Label any merged PR or closed issue 'learning', 'retrospective', or 'decision'"
echo "            → picked up automatically every Monday"
echo ""
echo "  Active:   Submit a learning immediately:"
echo "    Via issue form (no tooling):"
echo "    https://github.com/ivegamsft/basecoat/issues/new?template=memory-contribution.yml"
echo ""
echo "    Via callable workflow (add to your .github/workflows/):"
echo "    uses: IBuySpy-Shared/basecoat/.github/workflows/submit-learning-callable.yml@main"
echo ""
echo "    Via bash script:"
echo "    bash <(curl -fsSL https://raw.githubusercontent.com/ivegamsft/basecoat/main/scripts/submit-learning.sh) --help"
echo ""
echo "  Internal org members: see docs/memory/SETUP-INTERNAL.md"
echo "  External org members: see docs/memory/SETUP-EXTERNAL.md"
