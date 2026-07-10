#Requires -Version 5.0
<#
.SYNOPSIS
Validate PRODUCTION_REPO_TOKEN readiness for BaseCoat publish-to-production workflow.

.DESCRIPTION
This script validates that PRODUCTION_REPO_TOKEN (or a new token candidate) has the
required permissions to push to ivegamsft/basecoat. It's designed to help ensure the
token is correctly configured before it's set as a repository secret.

.PARAMETER Token
Optional. The token value to validate. If not provided, checks the PRODUCTION_REPO_TOKEN
environment variable. If neither is set, displays the manual validation steps.

.EXAMPLE
# Validate current secret from environment
$env:PRODUCTION_REPO_TOKEN = "ghp_..."
.\scripts\validate-production-token.ps1

.EXAMPLE
# Validate a new token before setting it as a secret
.\scripts\validate-production-token.ps1 -Token "ghp_YourNewTokenHere"

.EXAMPLE
# Display usage information
.\scripts\validate-production-token.ps1

.NOTES
Required Permissions for the token:
  ✓ Contents: Read and write (push commits, create releases)
  ✓ Administration: Read and write (manage branch protection)
  ✓ Workflows: Read and write (update GitHub Actions workflows)
  ✓ Scoped to: ivegamsft/basecoat repository only

Token Creation (requires ivegamsft account):
  1. Sign in to github.com as ivegamsft
  2. Settings → Developer settings → Personal access tokens → Fine-grained tokens
  3. Generate new token → Set resource owner to ivegamsft
  4. Repository: ivegamsft/basecoat
  5. Permissions: Contents (RW), Administration (RW), Workflows (RW)
  6. Expiration: 90 days (recommended)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Token = $env:PRODUCTION_REPO_TOKEN
)

$ErrorActionPreference = 'Stop'

function Show-Usage {
    Write-Host @"
Usage: .\scripts\validate-production-token.ps1 [[-Token] <token_value>]

This script validates that PRODUCTION_REPO_TOKEN (or a new token candidate) has the
required permissions to push to ivegamsft/basecoat.

Parameters:
  -Token (optional)    Token to validate. If not provided, checks PRODUCTION_REPO_TOKEN env var.

Examples:
  # Validate current secret from environment
  `$env:PRODUCTION_REPO_TOKEN = "ghp_..."
  .\scripts\validate-production-token.ps1

  # Validate a new token before setting it as a secret
  .\scripts\validate-production-token.ps1 -Token "ghp_YourNewTokenHere"

Required Permissions:
  ✓ Contents: Read and write (push commits, create releases)
  ✓ Administration: Read and write (manage branch protection)
  ✓ Workflows: Read and write (update GitHub Actions workflows)
  ✓ Scoped to: ivegamsft/basecoat repository only

Token Creation Steps (requires ivegamsft account):
  1. Sign in to github.com as ivegamsft
  2. Settings → Developer settings → Personal access tokens → Fine-grained tokens
  3. Click 'Generate new token'
  4. Set Token name: 'BaseCoat PRODUCTION_REPO_TOKEN'
  5. Set Resource owner: ivegamsft
  6. Set Repository: ivegamsft/basecoat
  7. Set Permissions:
     - Contents: Read and write
     - Administration: Read and write
     - Workflows: Read and write
  8. Set Expiration: 90 days (recommended)
  9. Click 'Generate token' and copy the token value
  10. Run: gh secret set PRODUCTION_REPO_TOKEN --repo IBuySpy-Shared/basecoat
      Then paste the token value when prompted

Quick verification after generating token:
  `$headers = @{
      'Authorization' = 'token <new-token>'
      'Accept' = 'application/vnd.github+json'
  }
  Invoke-RestMethod 'https://api.github.com/repos/ivegamsft/basecoat' -Headers `$headers | 
      Select-Object -ExpandProperty permissions

  (Output should include: push: true OR admin: true)

"@
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    Show-Usage
}

Write-Host "Validating PRODUCTION_REPO_TOKEN..."
Write-Host ""

# Validate token authentication
$headers = @{
    'Authorization' = "token $Token"
    'Accept'        = 'application/vnd.github+json'
}

try {
    $response = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/ivegamsft/basecoat" `
        -Headers $headers `
        -ErrorAction Stop
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    
    switch ($statusCode) {
        401 {
            Write-Host "❌ FAILED: Token authentication failed (HTTP 401)" -ForegroundColor Red
            Write-Host "   The token may be expired, revoked, or invalid." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   Remediation:" -ForegroundColor Yellow
            Write-Host "   - Generate a new fine-grained PAT as ivegamsft account owner" -ForegroundColor Yellow
            Write-Host "   - Ensure token has not expired" -ForegroundColor Yellow
            Write-Host "   - Verify token scopes include Contents, Administration, and Workflows RW" -ForegroundColor Yellow
            exit 1
        }
        403 {
            Write-Host "❌ FAILED: Token forbidden (HTTP 403)" -ForegroundColor Red
            Write-Host "   The token lacks access to ivegamsft/basecoat." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   Likely causes:" -ForegroundColor Yellow
            Write-Host "   - Token was created by IBuySpy-Shared org member (must be created by ivegamsft)" -ForegroundColor Yellow
            Write-Host "   - Token resource owner is not ivegamsft" -ForegroundColor Yellow
            Write-Host "   - Token does not include ivegamsft/basecoat in repository access" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   Remediation:" -ForegroundColor Yellow
            Write-Host "   - Delete the current token" -ForegroundColor Yellow
            Write-Host "   - Sign in as ivegamsft account owner" -ForegroundColor Yellow
            Write-Host "   - Create new fine-grained PAT with ivegamsft as resource owner" -ForegroundColor Yellow
            exit 1
        }
        404 {
            Write-Host "❌ FAILED: Repository not found (HTTP 404)" -ForegroundColor Red
            Write-Host "   The token cannot read ivegamsft/basecoat." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   This may indicate:" -ForegroundColor Yellow
            Write-Host "   - Token resource owner is not ivegamsft" -ForegroundColor Yellow
            Write-Host "   - Repository access is not configured" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   Remediation:" -ForegroundColor Yellow
            Write-Host "   - Verify token was created by ivegamsft account owner" -ForegroundColor Yellow
            Write-Host "   - Ensure 'Repository access' includes ivegamsft/basecoat" -ForegroundColor Yellow
            exit 1
        }
        default {
            Write-Host "❌ FAILED: Unexpected HTTP response (HTTP $statusCode)" -ForegroundColor Red
            Write-Host "   Check GitHub status at https://www.githubstatus.com/" -ForegroundColor Yellow
            exit 1
        }
    }
}

Write-Host "✅ API authentication succeeded (HTTP 200)" -ForegroundColor Green

# Check permissions
$permissions = $response.permissions
$hasPushAccess = $permissions.push -or $permissions.admin

Write-Host "Current permissions:" -ForegroundColor Cyan
Write-Host "  push:  $($permissions.push)" -ForegroundColor White
Write-Host "  pull:  $($permissions.pull)" -ForegroundColor White
Write-Host "  admin: $($permissions.admin)" -ForegroundColor White
Write-Host ""

if ($hasPushAccess) {
    Write-Host "✅ SUCCESS: Token has push access!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The PRODUCTION_REPO_TOKEN is ready to use. You can now:" -ForegroundColor Green
    Write-Host "  1. Set it as a secret: gh secret set PRODUCTION_REPO_TOKEN --repo IBuySpy-Shared/basecoat" -ForegroundColor White
    Write-Host "  2. Re-run the publish workflow: gh workflow run publish-to-production.yml --repo IBuySpy-Shared/basecoat" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "❌ FAILED: Token lacks push/admin access" -ForegroundColor Red
    Write-Host ""
    Write-Host "Required permissions (at least one must be true):" -ForegroundColor Yellow
    Write-Host "  - push: true   (Contents: Read and write)" -ForegroundColor Yellow
    Write-Host "  - admin: true  (Administration: Read and write)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Steps to fix:" -ForegroundColor Yellow
    Write-Host "  1. Sign in to github.com as ivegamsft" -ForegroundColor Yellow
    Write-Host "  2. Go to Settings → Developer settings → Personal access tokens → Fine-grained tokens" -ForegroundColor Yellow
    Write-Host "  3. Create new token or edit existing one:" -ForegroundColor Yellow
    Write-Host "     - Resource owner: ivegamsft (MUST be ivegamsft, not IBuySpy-Shared)" -ForegroundColor Yellow
    Write-Host "     - Repository: ivegamsft/basecoat" -ForegroundColor Yellow
    Write-Host "     - Permissions:" -ForegroundColor Yellow
    Write-Host "       ✓ Contents: Read and write" -ForegroundColor Yellow
    Write-Host "       ✓ Administration: Read and write" -ForegroundColor Yellow
    Write-Host "       ✓ Workflows: Read and write" -ForegroundColor Yellow
    Write-Host "  4. Save and copy the token" -ForegroundColor Yellow
    Write-Host "  5. Run this script again with the new token to validate" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
