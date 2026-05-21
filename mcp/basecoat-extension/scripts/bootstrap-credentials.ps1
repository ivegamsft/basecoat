#Requires -Version 7.0
<#
.SYNOPSIS
Bootstrap GitHub App credentials for BaseCoat Copilot Extension (minimal interaction).

.DESCRIPTION
Creates GitHub App for BaseCoat Copilot Extension and stores credentials in repository secrets + Key Vault.

This is a credentials bootstrap script—infrastructure deployment is handled by CI/CD workflows and IaC.

Chicken-egg problem: The extension-deploy workflow needs GitHub App credentials before it can deploy.
This script bridges that gap by creating the app and configuring the secrets.

SMART DEFAULTS + APP CREATION: 
- If credentials are provided (env vars or params), stores them immediately
- If not provided, creates GitHub App automatically using gh CLI (requires org admin token)
- Extracts app credentials and stores in GitHub Secrets + Key Vault
- Minimal interaction: just run the script; it handles app creation

Prerequisites:
- GitHub CLI (gh) authenticated with org admin permissions
- Azure CLI (az) authenticated with Key Vault permissions (optional, for production)
- If providing existing credentials: set env vars or pass as params
- If auto-creating app: gh CLI must have org admin access

.PARAMETER AppId
GitHub App ID. If not provided, reads from $env:BASECOAT_EXTENSION_GITHUB_APP_ID
If still not provided, script will create app automatically (requires org admin token).

.PARAMETER OrgName
GitHub organization for app creation. Default: IBuySpy-Shared (extracted from $Repo)
Only needed if auto-creating app and providing -Repo in non-standard format.

.PARAMETER CreateApp
Force app creation even if credentials provided. Default: $false

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
Updated: Smart defaults for minimal interaction

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
    [string]$OrgName = "",

    [Parameter(Mandatory = $false)]
    [switch]$CreateApp = $false
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

function New-GitHubApp {
    param(
        [string]$OrgName,
        [string]$AppName = "BaseCoat Copilot Extension"
    )

    Write-Info "Attempting to create GitHub App: $AppName in org: $OrgName"
    Write-Info "(This requires you to have GitHub organization owner or app manager permissions)"
    
    try {
        # Use gh CLI to create app - this will work if user has org admin token
        Write-Info "Creating app via GitHub API..."
        
        $payload = @{
            name = $AppName
            description = "Copilot Extension for discovering and scaffolding BaseCoat assets (agents, skills, instructions, prompts)"
            homepage_url = "https://github.com/$OrgName/basecoat"
            webhook_events = @("push", "pull_request", "issues", "issue_comment")
            public = $false
        } | ConvertTo-Json

        $response = gh api "/orgs/$OrgName/apps" -X POST --input - <<< $payload 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error-Custom "Failed to create GitHub App. Response: $response"
            Write-Info "Ensure you:"
            Write-Info "  1. Have GitHub organization owner/manager permissions"
            Write-Info "  2. Have authenticated with 'gh auth login' using org admin account"
            Write-Info "  3. Run: gh auth status (to verify permissions)"
            exit 1
        }

        $app = $response | ConvertFrom-Json
        Write-Status "GitHub App created successfully!"
        Write-Status "App ID: $($app.id)"
        Write-Status "Client ID: $($app.client_id)"
        
        # Return the credentials
        return @{
            AppId = $app.id
            ClientId = $app.client_id
            ClientSecret = $app.client_secret
            WebhookSecret = $(openssl rand -hex 20)
        }
    } catch {
        Write-Error-Custom "GitHub App creation failed: $_"
        Write-Info "You can also create the app manually:"
        Write-Info "  1. Go to: https://github.com/organizations/$OrgName/settings/apps/new"
        Write-Info "  2. Fill in the form with required details"
        Write-Info "  3. Copy credentials and pass to bootstrap or set env vars"
        exit 1
    }
}

Write-Info "Bootstrapping GitHub App credentials"
Write-Info "Repository: $Repo"

# Auto-create app if no credentials provided and not explicitly disabled
if (-not $AppId -and (-not $ClientId -or -not $ClientSecret -or -not $WebhookSecret)) {
    Write-Info "No credentials provided; attempting to create GitHub App automatically..."
    
    $appCreds = New-GitHubApp -OrgName $OrgName
    $AppId = $appCreds.AppId
    $ClientId = $appCreds.ClientId
    $ClientSecret = $appCreds.ClientSecret
    $WebhookSecret = $appCreds.WebhookSecret
    
    Write-Status "GitHub App created and credentials extracted"
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
