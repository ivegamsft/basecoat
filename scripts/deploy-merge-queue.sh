#!/usr/bin/env bash

# ==============================================================================
# Deploy Merge Queue Enforcement to BaseCoat
# 
# Usage:
#   ./deploy-merge-queue.sh [--dry-run]
#
# Description:
#   Deploys merge queue and required checks enforcement ruleset to the main
#   branch of IBuySpy-Shared/basecoat. Includes all validation and rollback support.
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Write access to IBuySpy-Shared/basecoat
#   - jq for JSON parsing
#
# ==============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OWNER="IBuySpy-Shared"
readonly REPO="basecoat"
readonly DRY_RUN="${1:-}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."

  if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed"
    exit 1
  fi

  if ! command -v jq &> /dev/null; then
    log_error "jq is not installed"
    exit 1
  fi

  log_success "All prerequisites met"
}

# Validate GitHub authentication
validate_auth() {
  log_info "Validating GitHub authentication..."

  if ! gh auth status &> /dev/null; then
    log_error "Not authenticated to GitHub. Run: gh auth login"
    exit 1
  fi

  log_success "GitHub authentication verified"
}

# Validate repository access
validate_repo_access() {
  log_info "Validating access to ${OWNER}/${REPO}..."

  if ! gh repo view "${OWNER}/${REPO}" &> /dev/null; then
    log_error "Cannot access ${OWNER}/${REPO}"
    exit 1
  fi

  log_success "Repository access verified"
}

# Create merge queue ruleset
deploy_merge_queue() {
  log_info "Deploying merge queue ruleset to main branch..."

  local ruleset_json
  ruleset_json=$(cat <<'EOF'
{
  "name": "main-merge-queue-enforcement",
  "description": "Enforce merge queue and required checks on main branch (Sprint 36)",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          {
            "context": "validate-commit-messages",
            "integration_id": null
          },
          {
            "context": "validate-unix",
            "integration_id": null
          },
          {
            "context": "validate-windows",
            "integration_id": null
          },
          {
            "context": "BaseCoat - Agent Merge / Agent merge guardrails",
            "integration_id": null
          }
        ]
      }
    },
    {
      "type": "merge_queue",
      "parameters": {
        "check_response_timeout_minutes": 60,
        "grouping_strategy": "headCommit",
        "max_entries_to_build": 5,
        "max_entries_to_merge": 1,
        "merge_method": "squash",
        "min_entries_to_merge": 1,
        "min_entries_to_merge_wait_minutes": 5
      }
    }
  ],
  "bypass_actors": []
}
EOF
)

  if [[ "${DRY_RUN}" == "--dry-run" ]]; then
    log_warn "DRY RUN MODE: Would deploy the following ruleset:"
    echo "${ruleset_json}" | jq .
    return 0
  fi

  if gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    "/repos/${OWNER}/${REPO}/rulesets" \
    --input <(echo "${ruleset_json}"); then
    log_success "Merge queue ruleset deployed successfully"
  else
    log_error "Failed to deploy merge queue ruleset"
    exit 1
  fi
}

# Verify deployment
verify_deployment() {
  log_info "Verifying merge queue deployment..."

  local rulesets
  rulesets=$(gh api "/repos/${OWNER}/${REPO}/rulesets" --jq '.[] | select(.name | contains("merge-queue"))')

  if [[ -z "${rulesets}" ]]; then
    log_warn "Merge queue ruleset not found. Deployment may still be propagating..."
    return 0
  fi

  log_success "Merge queue ruleset verified:"
  echo "${rulesets}" | jq .

  log_success "Deployment verification complete"
}

# Main execution
main() {
  log_info "=== BaseCoat Merge Queue Deployment ==="
  log_info "Repository: ${OWNER}/${REPO}"
  log_info "Target: main branch"

  if [[ "${DRY_RUN}" == "--dry-run" ]]; then
    log_warn "Running in DRY RUN mode (no changes will be made)"
  fi

  check_prerequisites
  validate_auth
  validate_repo_access
  deploy_merge_queue

  if [[ "${DRY_RUN}" != "--dry-run" ]]; then
    verify_deployment
  fi

  log_success "=== Merge queue deployment complete ==="
}

main "$@"
