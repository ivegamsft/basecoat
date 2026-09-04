#!/usr/bin/env bash
set -euo pipefail

# Base Coat Adoption Dashboard — Bootstrap Script
# Configures GitHub secrets and enables Pages for metrics collection.
# No secrets are stored in code — they are set via gh CLI at setup time.
#
# Usage:
#   ./scripts/bootstrap-dashboard.sh              — Interactive setup
#   ./scripts/bootstrap-dashboard.sh --add        — Add repos to existing config
#   ./scripts/bootstrap-dashboard.sh --remove     — Remove repos from config
#   ./scripts/bootstrap-dashboard.sh --list       — Show current repos

REPO="ivegamsft/basecoat"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE_FILE="$SCRIPT_DIR/.dashboard-repos-cache.json"

get_current_repos() {
    if [[ -f "$CACHE_FILE" ]]; then
        jq -r '.[]' "$CACHE_FILE" 2>/dev/null || true
    fi
}

save_repos() {
    local repos_json="$1"
    echo "$repos_json" > "$CACHE_FILE"
    echo "$repos_json" | gh secret set DASHBOARD_REPOS --repo "$REPO"
}

# Check prerequisites
command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI required. Install from https://cli.github.com"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required. Install from https://stedolan.github.io/jq/"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: Not authenticated. Run 'gh auth login' first."; exit 1; }

echo "╔══════════════════════════════════════════════════════╗"
echo "║  Base Coat Adoption Dashboard — Bootstrap Setup      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Handle --list
if [[ "${1:-}" == "--list" ]]; then
    mapfile -t current < <(get_current_repos)
    if [[ ${#current[@]} -eq 0 ]]; then
        echo "  No repos configured. Run without flags to set up."
    else
        echo "  Currently monitoring ${#current[@]} repos:"
        for r in "${current[@]}"; do echo "    • $r"; done
    fi
    exit 0
fi

# Handle --add
if [[ "${1:-}" == "--add" ]]; then
    mapfile -t current < <(get_current_repos)
    echo "  Currently monitoring: ${current[*]:-none}"
    echo "  How many repos to add?"
    read -rp "  count> " count
    for ((i=1; i<=count; i++)); do
        read -rp "  repo $i of $count (org/repo)> " r
        if [[ -n "$r" ]]; then
            # Check for duplicates
            if printf '%s\n' "${current[@]}" | grep -qx "$r"; then
                echo "    Already tracked: $r"
            else
                current+=("$r")
                echo "    Added: $r"
            fi
        fi
    done
    repos_json=$(printf '%s\n' "${current[@]}" | jq -R . | jq -s .)
    save_repos "$repos_json"
    echo "  ✓ Updated. Now monitoring ${#current[@]} repos."
    exit 0
fi

# Handle --remove
if [[ "${1:-}" == "--remove" ]]; then
    mapfile -t current < <(get_current_repos)
    if [[ ${#current[@]} -eq 0 ]]; then
        echo "  No repos configured."
        exit 0
    fi
    echo "  Currently monitoring:"
    for i in "${!current[@]}"; do
        echo "    [$((i+1))] ${current[$i]}"
    done
    echo ""
    read -rp "  Enter numbers to remove (comma-separated, or 'q' to cancel): " input
    [[ "$input" == "q" ]] && exit 0

    IFS=',' read -ra indices <<< "$input"
    remaining=()
    for i in "${!current[@]}"; do
        skip=false
        for idx in "${indices[@]}"; do
            if [[ $((idx - 1)) -eq $i ]]; then skip=true; break; fi
        done
        if [[ "$skip" == "false" ]]; then
            remaining+=("${current[$i]}")
        else
            echo "    Removed: ${current[$i]}"
        fi
    done

    repos_json=$(printf '%s\n' "${remaining[@]}" | jq -R . | jq -s .)
    save_repos "$repos_json"
    echo "  ✓ Now monitoring ${#remaining[@]} repos."
    exit 0
fi

# Full setup mode
echo "This script will:"
echo "  1. Configure GitHub secrets for metrics collection"
echo "  2. Set the list of dogfooding repos to monitor"
echo "  3. Enable GitHub Pages on the gh-pages branch"
echo ""

# Step 1: Collect dogfooding repo names
echo "── Step 1: Dogfooding Repositories ──"
mapfile -t existing < <(get_current_repos)
REPOS=()

if [[ ${#existing[@]} -gt 0 ]]; then
    echo "  Existing config found: ${existing[*]}"
    read -rp "  Keep existing and add more? (Y/n): " keep
    if [[ "${keep,,}" != "n" ]]; then
        REPOS=("${existing[@]}")
    fi
fi

echo "  How many repos to add?"
read -rp "  count> " count
for ((i=1; i<=count; i++)); do
    read -rp "  repo $i of $count (org/repo)> " r
    [[ -n "$r" ]] && REPOS+=("$r")
done

if [[ ${#REPOS[@]} -eq 0 ]]; then
    echo "ERROR: At least one repo required."
    exit 1
fi

REPOS_JSON=$(printf '%s\n' "${REPOS[@]}" | jq -R . | jq -s .)
echo "  Configured ${#REPOS[@]} repos: ${REPOS[*]}"
echo ""

# Step 2: Copilot Metrics API token
echo "── Step 2: GitHub Token for Copilot Metrics API ──"
echo "The Copilot usage API requires a token with org:read scope."
echo "Options:"
echo "  a) Use existing GITHUB_TOKEN (works if workflow has org read access)"
echo "  b) Provide a Personal Access Token (classic) with admin:org scope"
echo ""
read -rp "  Use a separate PAT? (y/N): " use_pat

if [[ "${use_pat,,}" == "y" ]]; then
    echo "  Enter a PAT with admin:org scope (input hidden):"
    read -rs pat
    echo ""
    if [[ -z "$pat" ]]; then
        echo "ERROR: PAT cannot be empty."
        exit 1
    fi
    echo "$pat" | gh secret set COPILOT_METRICS_TOKEN --repo "$REPO"
    echo "  ✓ Secret COPILOT_METRICS_TOKEN configured"
else
    echo "  ✓ Will use default GITHUB_TOKEN (ensure workflow has org read permission)"
fi
echo ""

# Step 3: Store repo list as secret (not in code)
echo "── Step 3: Storing Configuration ──"
save_repos "$REPOS_JSON"
echo "  ✓ Secret DASHBOARD_REPOS configured with ${#REPOS[@]} repos"
echo ""

# Step 4: Organization name
ORG=$(echo "$REPO" | cut -d'/' -f1)
gh secret set DASHBOARD_ORG --repo "$REPO" --body "$ORG"
echo "  ✓ Secret DASHBOARD_ORG configured as '$ORG'"
echo ""

# Step 5: Enable GitHub Pages
echo "── Step 4: GitHub Pages ──"
echo "  Checking if gh-pages branch exists..."
if gh api "repos/$REPO/branches/gh-pages" >/dev/null 2>&1; then
    echo "  ✓ gh-pages branch already exists"
else
    echo "  Creating gh-pages branch with initial content..."
    gh api --method POST "repos/$REPO/git/refs" \
        -f ref="refs/heads/gh-pages" \
        -f sha="$(gh api "repos/$REPO/git/ref/heads/main" --jq '.object.sha')" >/dev/null
    echo "  ✓ gh-pages branch created"
fi

# Enable Pages via API
gh api --method POST "repos/$REPO/pages" \
    -f "source[branch]=gh-pages" \
    -f "source[path]=/" 2>/dev/null || true
echo "  ✓ GitHub Pages enabled on gh-pages branch"
echo ""

# Step 6: Verify
echo "── Setup Complete ──"
echo ""
echo "  Secrets configured:"
echo "    • DASHBOARD_REPOS  — list of repos to monitor"
echo "    • DASHBOARD_ORG    — organization name"
if [[ "${use_pat,,}" == "y" ]]; then
    echo "    • COPILOT_METRICS_TOKEN — PAT for Copilot API"
fi
echo ""
echo "  Next steps:"
echo "    1. Push the adoption-metrics workflow to main"
echo "    2. Trigger manually: gh workflow run adoption-metrics.yml"
echo "    3. View dashboard at: https://${ORG,,}.github.io/basecoat/"
echo ""
echo "  To reconfigure later, re-run this script."
echo "  To add/remove repos: gh secret set DASHBOARD_REPOS --repo $REPO"
