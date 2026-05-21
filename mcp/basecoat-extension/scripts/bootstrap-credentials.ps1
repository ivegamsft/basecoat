#Requires -Version 7.0
<#
.SYNOPSIS
Bootstrap GitHub App credentials for BaseCoat Copilot Extension (minimal interaction).

.DESCRIPTION
Stores GitHub App credentials in GitHub repository secrets and Azure Key Vault.

This is a credentials bootstrap script—infrastructure deployment is handled by CI/CD workflows and IaC.

Chicken-egg problem: The extension-deploy workflow needs GitHub App credentials before it can deploy.
This script bridges that gap by storing the secrets securely.

SMART DEFAULTS:
- If credentials are provided (env vars or params), stores them immediately
- If not provided, shows clear instructions for manual GitHub App creation
- Minimal interaction: set env vars, then run script
- Note: GitHub App creation is manual (security measure) — not automated

Prerequisites:
- GitHub App registered in IBuySpy-Shared org (manual step via github.com/organizations/{org}/settings/apps/new)
- GitHub CLI (gh) authenticated and authorized to configure repository secrets
- Azure CLI (az) authenticated with Key Vault permissions (optional, for production)

.PARAMETER AppId
GitHub App ID. If not provided, reads from $env:BASECOAT_EXTENSION_GITHUB_APP_ID
If not provided, script will prompt you to create app manually via GitHub UI.

.PARAMETER OrgName
GitHub organization for app creation guidance. Default: IBuySpy-Shared (extracted from $Repo)
Only used if credentials are missing (to show correct creation link).

.PARAMETER ClientId
GitHub OAuth Client ID. If not provided, reads from $env:BASECOAT_EXTENSION_GITHUB_CLIENT_ID

.PARAMETER ClientSecret
GitHub OAuth Client Secret. If not provided, reads from $env:BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET

.PARAMETER WebhookSecret
GitHub webhook signature secret. If not provided, reads from $env:BASECOAT_EXTENSION_WEBHOOK_SECRET

.PARAMETER PrivateKeyPath
Path to GitHub App private key PEM file. Default: ./private-key.pem
If not provided, reads from $env:BASECOAT_EXTENSION_PRIVATE_KEY_PATH

.PARAMETER Repo
GitHub repository in format 'owner/repo'. Default: IBuySpy-Shared/basecoat
If not provided, reads from $env:BASECOAT_EXTENSION_REPO

.PARAMETER KeyVaultName
Azure Key Vault name for production (optional). If provided, secrets are also stored in vault.
If not provided, reads from $env:BASECOAT_EXTENSION_KEY_VAULT_NAME

.EXAMPLE
# Minimal interaction: no creds provided, auto-create app
PS> .\bootstrap-credentials.ps1
# Script creates BaseCoat Copilot Extension app, stores creds automatically

.EXAMPLE
# Minimal interaction: set creds, no app creation
PS> $env:BASECOAT_EXTENSION_GITHUB_APP_ID = "123456"
PS> $env:BASECOAT_EXTENSION_GITHUB_CLIENT_ID = "Iv1.a1b2c3d4..."
PS> $env:BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET = "ghp_xxxxxxxx"
PS> $env:BASECOAT_EXTENSION_WEBHOOK_SECRET = "whsec_xxxxxxxx"
PS> $env:BASECOAT_EXTENSION_PRIVATE_KEY_PATH = "./private-key.pem"
PS> .\bootstrap-credentials.ps1

.EXAMPLE
# With command-line parameters (existing app)
PS> .\bootstrap-credentials.ps1 `
  -AppId "123456" `
  -ClientId "Iv1.a1b2c3d4..." `
  -ClientSecret "ghp_xxxxxxxx" `
  -WebhookSecret "whsec_xxxxxxxx" `
  -PrivateKeyPath "./private-key.pem"

.NOTES
Author: Platform Engineer / Deployment Task
Generated: Sprint 31
Updated: Bootstrap with auto-create GitHub App capability
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$AppId = $env:BASECOAT_EXTENSION_GITHUB_APP_ID,

    [Parameter(Mandatory = $false)]
    [string]$ClientId = $env:BASECOAT_EXTENSION_GITHUB_CLIENT_ID,

    [Parameter(Mandatory = $false)]
    [string]$ClientSecret = $env:BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET,

    [Parameter(Mandatory = $false)]
    [string]$WebhookSecret = $env:BASECOAT_EXTENSION_WEBHOOK_SECRET,

    [Parameter(Mandatory = $false)]
    [string]$PrivateKeyPath = $env:BASECOAT_EXTENSION_PRIVATE_KEY_PATH,

    [Parameter(Mandatory = $false)]
    [string]$Repo = $env:BASECOAT_EXTENSION_REPO ?? "IBuySpy-Shared/basecoat",

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = $env:BASECOAT_EXTENSION_KEY_VAULT_NAME ?? "",

    [Parameter(Mandatory = $false)]
    [string]$OrgName = ""
)

$ErrorActionPreference = "Stop"

# Smart defaults for private key path
if (-not $PrivateKeyPath) {
    $PrivateKeyPath = "./private-key.pem"
}

# Extract org name from repo if not provided
if (-not $OrgName) {
    $OrgName = $Repo.Split('/')[0]
}

function Write-Status {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Show-AppCreationGuide {
    param([string]$OrgName)
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  GitHub App Creation Required (Manual Step)                   ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Info "GitHub doesn't allow programmatic app creation (security measure)."
    Write-Info "You must create the app manually via GitHub UI:"
    
    Write-Host ""
    Write-Host "  1. Visit: https://github.com/organizations/$OrgName/settings/apps/new" -ForegroundColor Cyan
    Write-Host "  2. Fill in these details:" -ForegroundColor Cyan
    Write-Host "     - App name: BaseCoat Copilot Extension" -ForegroundColor Cyan
    Write-Host "     - Description: Copilot Extension for managing BaseCoat assets" -ForegroundColor Cyan
    Write-Host "     - Homepage URL: https://github.com/$OrgName/basecoat" -ForegroundColor Cyan
    Write-Host "     - Webhook URL: https://basecoat.example.com/api/github/webhook" -ForegroundColor Cyan
    Write-Host "     - Webhook events: issues, pull_request, push" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. After creation, copy these credentials:" -ForegroundColor Cyan
    Write-Host "     - App ID" -ForegroundColor Cyan
    Write-Host "     - Client ID" -ForegroundColor Cyan
    Write-Host "     - Client Secret" -ForegroundColor Cyan
    Write-Host "     - Webhook Secret" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  4. Download private key (PEM format)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  5. Run bootstrap with credentials:" -ForegroundColor Cyan
    Write-Host "     `$env:BASECOAT_EXTENSION_GITHUB_APP_ID = 'YOUR_APP_ID'" -ForegroundColor Green
    Write-Host "     `$env:BASECOAT_EXTENSION_GITHUB_CLIENT_ID = 'YOUR_CLIENT_ID'" -ForegroundColor Green
    Write-Host "     `$env:BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET = 'YOUR_CLIENT_SECRET'" -ForegroundColor Green
    Write-Host "     `$env:BASECOAT_EXTENSION_WEBHOOK_SECRET = 'YOUR_WEBHOOK_SECRET'" -ForegroundColor Green
    Write-Host "     `$env:BASECOAT_EXTENSION_PRIVATE_KEY_PATH = './private-key.pem'" -ForegroundColor Green
    Write-Host "     .\bootstrap-credentials.ps1" -ForegroundColor Green
    Write-Host ""
}

Write-Info "Bootstrapping GitHub App credentials"
Write-Info "Repository: $Repo"

# Auto-create app if no credentials provided and not explicitly disabled
if (-not $AppId -and (-not $ClientId -or -not $ClientSecret -or -not $WebhookSecret)) {
    Write-Host ""
    Write-Error-Custom "Missing GitHub App credentials"
    Show-AppCreationGuide -OrgName $OrgName
    exit 1
}

# Validate that credentials are provided (either via params or env vars)
$missingCredentials = @()
if (-not $AppId) { $missingCredentials += "AppId (set env var BASECOAT_EXTENSION_GITHUB_APP_ID or pass -AppId)" }
if (-not $ClientId) { $missingCredentials += "ClientId (set env var BASECOAT_EXTENSION_GITHUB_CLIENT_ID or pass -ClientId)" }
if (-not $ClientSecret) { $missingCredentials += "ClientSecret (set env var BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET or pass -ClientSecret)" }
if (-not $WebhookSecret) { $missingCredentials += "WebhookSecret (set env var BASECOAT_EXTENSION_WEBHOOK_SECRET or pass -WebhookSecret)" }

if ($missingCredentials.Count -gt 0) {
    Write-Error-Custom "Missing required credentials:"
    $missingCredentials | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Info "To bootstrap with smart defaults, set these environment variables:"
    Write-Host "  `$env:BASECOAT_EXTENSION_GITHUB_APP_ID = '...'"
    Write-Host "  `$env:BASECOAT_EXTENSION_GITHUB_CLIENT_ID = '...'"
    Write-Host "  `$env:BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET = '...'"
    Write-Host "  `$env:BASECOAT_EXTENSION_WEBHOOK_SECRET = '...'"
    Write-Host "  `$env:BASECOAT_EXTENSION_PRIVATE_KEY_PATH = './private-key.pem' (optional; defaults to ./private-key.pem)"
    Write-Host ""
    exit 1
}

# Validate prerequisites
if (-not (Test-Path $PrivateKeyPath)) {
    Write-Error-Custom "Private key file not found: $PrivateKeyPath"
    exit 1
}

$PrivateKey = Get-Content $PrivateKeyPath -Raw

# Store in GitHub repository secrets (for CI/CD workflow)
Write-Info "Storing credentials in GitHub repository secrets..."
try {
    gh secret set BASECOAT_EXTENSION_GITHUB_APP_ID --body "$AppId" --repo "$Repo"
    Write-Status "Secret set: BASECOAT_EXTENSION_GITHUB_APP_ID"
    
    gh secret set BASECOAT_EXTENSION_GITHUB_CLIENT_ID --body "$ClientId" --repo "$Repo"
    Write-Status "Secret set: BASECOAT_EXTENSION_GITHUB_CLIENT_ID"
    
    gh secret set BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET --body "$ClientSecret" --repo "$Repo"
    Write-Status "Secret set: BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET"
    
    gh secret set BASECOAT_EXTENSION_WEBHOOK_SECRET --body "$WebhookSecret" --repo "$Repo"
    Write-Status "Secret set: BASECOAT_EXTENSION_WEBHOOK_SECRET"
    
    gh secret set BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY --body "$PrivateKey" --repo "$Repo"
    Write-Status "Secret set: BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY"
} catch {
    Write-Error-Custom "Failed to set GitHub secrets: $_"
    exit 1
}

# Store in Azure Key Vault for production (optional)
if ($KeyVaultName) {
    Write-Info "Storing credentials in Azure Key Vault: $KeyVaultName"
    try {
        az keyvault secret set --vault-name "$KeyVaultName" --name "basecoat-app-id" --value "$AppId" > $null
        Write-Status "Secret stored: basecoat-app-id"
        
        az keyvault secret set --vault-name "$KeyVaultName" --name "basecoat-client-id" --value "$ClientId" > $null
        Write-Status "Secret stored: basecoat-client-id"
        
        az keyvault secret set --vault-name "$KeyVaultName" --name "basecoat-client-secret" --value "$ClientSecret" > $null
        Write-Status "Secret stored: basecoat-client-secret"
        
        az keyvault secret set --vault-name "$KeyVaultName" --name "basecoat-webhook-secret" --value "$WebhookSecret" > $null
        Write-Status "Secret stored: basecoat-webhook-secret"
        
        az keyvault secret set --vault-name "$KeyVaultName" --name "basecoat-private-key" --value "$PrivateKey" > $null
        Write-Status "Secret stored: basecoat-private-key"
    } catch {
        Write-Error-Custom "Failed to store secrets in Key Vault: $_"
        exit 1
    }
}

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         Credentials Bootstrap Complete                         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "What's next:" -ForegroundColor Cyan
Write-Host "  1. Trigger extension-deploy workflow: gh workflow run extension-deploy.yml"
Write-Host "  2. Workflow builds image and deploys via Bicep IaC"
Write-Host "  3. Monitor deployment: gh run list --workflow=extension-deploy.yml"
Write-Host "  4. QA validates @basecoat appears in Copilot Chat"
Write-Host ""

exit 0
