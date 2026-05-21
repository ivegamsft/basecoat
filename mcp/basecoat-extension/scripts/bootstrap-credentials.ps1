#Requires -Version 7.0
<#
.SYNOPSIS
Bootstrap GitHub App credentials for BaseCoat Copilot Extension.

.DESCRIPTION
Stores GitHub App credentials in GitHub repository secrets (for CI/CD) and Azure Key Vault (for production).
This is a credentials-only bootstrap script—infrastructure deployment is handled by CI/CD workflows and IaC.

Chicken-egg problem: The extension-deploy workflow needs GitHub App credentials before it can deploy.
This script bridges that gap by configuring the secrets.

Prerequisites:
- GitHub CLI (gh) authenticated and authorized to configure repository secrets
- Azure CLI (az) authenticated with Key Vault permissions (for production)
- GitHub App registered in IBuySpy-Shared org (#1073)
- GitHub App credentials from org-admin

.PARAMETER AppId
GitHub App ID

.PARAMETER ClientId
GitHub OAuth Client ID

.PARAMETER ClientSecret
GitHub OAuth Client Secret

.PARAMETER WebhookSecret
GitHub webhook signature secret

.PARAMETER PrivateKeyPath
Path to GitHub App private key PEM file

.PARAMETER Repo
GitHub repository in format 'owner/repo'. Default: IBuySpy-Shared/basecoat

.PARAMETER KeyVaultName
Azure Key Vault name for production (optional). If provided, secrets are also stored in vault.

.EXAMPLE
PS> .\bootstrap-credentials.ps1 `
  -AppId "123456" `
  -ClientId "Iv1.a1b2c3d4..." `
  -ClientSecret "ghp_xxxxxxxx" `
  -WebhookSecret "whsec_xxxxxxxx" `
  -PrivateKeyPath "./private-key.pem"

.NOTES
Author: Platform Engineer / Deployment Task
Generated: Sprint 31
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$WebhookSecret,

    [Parameter(Mandatory = $true)]
    [string]$PrivateKeyPath,

    [Parameter(Mandatory = $false)]
    [string]$Repo = "IBuySpy-Shared/basecoat",

    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = ""
)

$ErrorActionPreference = "Stop"

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

Write-Info "Bootstrapping GitHub App credentials"
Write-Info "Repository: $Repo"

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
