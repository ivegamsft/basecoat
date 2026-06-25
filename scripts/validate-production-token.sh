#!/usr/bin/env bash
#
# Validate PRODUCTION_REPO_TOKEN readiness for BaseCoat publish-to-production workflow.
#
# Usage:
#   ./scripts/validate-production-token.sh                    # Check current secret
#   ./scripts/validate-production-token.sh <token_value>      # Validate a new token before setting
#
# This script helps ensure the token has the required permissions before it's set as a secret.

set -euo pipefail

TOKEN="${1:-${PRODUCTION_REPO_TOKEN:-}}"

if [[ -z "${TOKEN}" ]]; then
    cat <<'EOF'
Usage: validate-production-token.sh [TOKEN]

This script validates that PRODUCTION_REPO_TOKEN (or a new token candidate) has the
required permissions to push to ivegamsft/basecoat.

Options:
  TOKEN (optional)    Token to validate. If not provided, checks PRODUCTION_REPO_TOKEN env var.
                      If neither is set, displays the manual validation steps.

Environment variable:
  PRODUCTION_REPO_TOKEN    If set, the script will validate this token.

Examples:
  # Validate current secret from environment
  PRODUCTION_REPO_TOKEN="ghp_..." bash scripts/validate-production-token.sh

  # Validate a new token before setting it as a secret
  bash scripts/validate-production-token.sh "ghp_YourNewTokenHere"

Required Permissions:
  ✓ Contents: Read and write (push commits, create releases)
  ✓ Administration: Read and write (manage branch protection)
  ✓ Workflows: Read and write (update GitHub Actions workflows)
  ✓ Scoped to: ivegamsft/basecoat repository only

Token Creation Steps (requires ivegamsft account):
  1. Sign in to github.com as ivegamsft
  2. Settings → Developer settings → Personal access tokens → Fine-grained tokens
  3. Generate new token → Set resource owner to ivegamsft
  4. Repository: ivegamsft/basecoat
  5. Permissions: Contents (RW), Administration (RW), Workflows (RW)
  6. Expiration: 90 days (recommended)
  7. Generate and copy the token value
  8. Set secret: gh secret set PRODUCTION_REPO_TOKEN --repo IBuySpy-Shared/basecoat
  9. Paste token when prompted

Quick verification after generating token:
  curl -s -H "Authorization: token <new-token>" \
    https://api.github.com/repos/ivegamsft/basecoat | \
    jq '.permissions'
  
  Output should include: "push": true OR "admin": true

EOF
    exit 0
fi

echo "Validating PRODUCTION_REPO_TOKEN..."
echo ""

# Validate token authentication
HTTP_CODE=$(curl -s -o repo.json -w "%{http_code}" \
  -H "Authorization: token ${TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/ivegamsft/basecoat" 2>/dev/null || echo "000")

case "${HTTP_CODE}" in
  401)
    echo "❌ FAILED: Token authentication failed (HTTP 401)"
    echo "   The token may be expired, revoked, or invalid."
    echo ""
    echo "   Remediation:"
    echo "   - Generate a new fine-grained PAT as ivegamsft account owner"
    echo "   - Ensure token has not expired"
    echo "   - Verify token scopes include Contents, Administration, and Workflows RW"
    exit 1
    ;;
  403)
    echo "❌ FAILED: Token forbidden (HTTP 403)"
    echo "   The token lacks access to ivegamsft/basecoat."
    echo ""
    echo "   Likely causes:"
    echo "   - Token was created by IBuySpy-Shared org member (must be created by ivegamsft)"
    echo "   - Token resource owner is not ivegamsft"
    echo "   - Token does not include ivegamsft/basecoat in repository access"
    echo ""
    echo "   Remediation:"
    echo "   - Delete the current token"
    echo "   - Sign in as ivegamsft account owner"
    echo "   - Create new fine-grained PAT with ivegamsft as resource owner"
    exit 1
    ;;
  404)
    echo "❌ FAILED: Repository not found (HTTP 404)"
    echo "   The token cannot read ivegamsft/basecoat."
    echo ""
    echo "   This may indicate:"
    echo "   - Token resource owner is not ivegamsft"
    echo "   - Repository access is not configured"
    echo ""
    echo "   Remediation:"
    echo "   - Verify token was created by ivegamsft account owner"
    echo "   - Ensure 'Repository access' includes ivegamsft/basecoat"
    exit 1
    ;;
  200)
    echo "✅ API authentication succeeded (HTTP 200)"
    ;;
  *)
    echo "❌ FAILED: Unexpected HTTP response (HTTP ${HTTP_CODE})"
    echo "   Check GitHub status at https://www.githubstatus.com/"
    exit 1
    ;;
esac

# Parse permissions
PERMISSIONS=$(python3 - <<'PYEOF' 2>/dev/null || echo '{}')
import json
try:
    with open("repo.json", encoding="utf-8") as f:
        d = json.load(f)
    perms = d.get("permissions", {})
    print(json.dumps({
        "push": perms.get("push", False),
        "pull": perms.get("pull", False),
        "admin": perms.get("admin", False)
    }))
except:
    print('{}')
PYEOF
)

PUSH_ACCESS=$(echo "$PERMISSIONS" | python3 -c "import sys, json; d=json.load(sys.stdin); print('true' if d.get('push') or d.get('admin') else 'false')" 2>/dev/null || echo "false")

echo "Current permissions:"
echo "$PERMISSIONS" | python3 -m json.tool 2>/dev/null || echo "$PERMISSIONS"
echo ""

if [[ "${PUSH_ACCESS}" == "true" ]]; then
    echo "✅ SUCCESS: Token has push access!"
    echo ""
    echo "The PRODUCTION_REPO_TOKEN is ready to use. You can now:"
    echo "  1. Set it as a secret: gh secret set PRODUCTION_REPO_TOKEN --repo IBuySpy-Shared/basecoat"
    echo "  2. Re-run the publish workflow: gh workflow run publish-to-production.yml --repo IBuySpy-Shared/basecoat"
    echo ""
    rm -f repo.json
    exit 0
else
    echo "❌ FAILED: Token lacks push/admin access"
    echo ""
    echo "Required permissions (at least one must be true):"
    echo "  - push: true   (Contents: Read and write)"
    echo "  - admin: true  (Administration: Read and write)"
    echo ""
    echo "Steps to fix:"
    echo "  1. Sign in to github.com as ivegamsft"
    echo "  2. Go to Settings → Developer settings → Personal access tokens → Fine-grained tokens"
    echo "  3. Create new token or edit existing one:"
    echo "     - Resource owner: ivegamsft (MUST be ivegamsft, not IBuySpy-Shared)"
    echo "     - Repository: ivegamsft/basecoat"
    echo "     - Permissions:"
    echo "       ✓ Contents: Read and write"
    echo "       ✓ Administration: Read and write"
    echo "       ✓ Workflows: Read and write"
    echo "  4. Save and copy the token"
    echo "  5. Run this script again with the new token to validate"
    echo ""
    rm -f repo.json
    exit 1
fi
