#Requires -Version 7.0
<#
.SYNOPSIS
Bootstrap Azure Container Apps environment variables for BaseCoat Copilot Extension.

.DESCRIPTION
Configures BASECOAT_EXTENSION_* secrets and environment variables in ACA after GitHub App registration.
This script is intended for platform engineers during Sprint 32 deployment.

Prerequisites:
- Azure CLI (az) installed and authenticated
- GitHub App registered in IBuySpy-Shared org (issue #1073)
- GitHub App credentials available (APP_ID, CLIENT_ID, CLIENT_SECRET, WEBHOOK_SECRET, PRIVATE_KEY)

.PARAMETER ResourceGroup
Azure resource group containing the extension Container App.
Example: rg-basecoat-prod

.PARAMETER ContainerAppName
Container App name. Defaults to 'bcext-app' for prod, 'bcext-app-{env}' for staging/dev.

.PARAMETER Environment
Deployment environment: prod, staging, or dev. Default: prod

.PARAMETER AppId
GitHub App ID (from GitHub App settings)

.PARAMETER ClientId
GitHub OAuth Client ID (from GitHub App settings)

.PARAMETER ClientSecret
GitHub OAuth Client Secret (from organization vault)

.PARAMETER WebhookSecret
GitHub webhook signature secret (from organization vault)

.PARAMETER PrivateKeyPath
Path to GitHub App private key PEM file (from organization vault)

.PARAMETER AllowedOrg
GitHub organization for membership checks. Default: IBuySpy-Shared

.PARAMETER AcaBaseUrl
Base URL for the ACA deployment (e.g., https://bcext-app.eastus.azurecontainerapps.io)
If not provided, will be retrieved from ACA configuration.

.EXAMPLE
PS> .\bootstrap-aca.ps1 `
  -ResourceGroup "rg-basecoat-prod" `
  -AppId "123456" `
  -ClientId "Iv1.a1b2c3d4..." `
  -ClientSecret "ghp_xxxxxxxx" `
  -WebhookSecret "whsec_xxxxxxxx" `
  -PrivateKeyPath "./private-key.pem" `
  -AllowedOrg "IBuySpy-Shared"

.NOTES
Author: Platform Engineer / Deployment Task
Generated: Sprint 31
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$ContainerAppName = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("prod", "staging", "dev")]
    [string]$Environment = "prod",

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
    [string]$AllowedOrg = "IBuySpy-Shared",

    [Parameter(Mandatory = $false)]
    [string]$AcaBaseUrl = ""
)

$ErrorActionPreference = "Stop"

# Helper functions
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

# Determine Container App name if not provided
if (-not $ContainerAppName) {
    if ($Environment -eq "prod") {
        $ContainerAppName = "bcext-app"
    } else {
        $ContainerAppName = "bcext-app-$Environment"
    }
}

Write-Info "Starting ACA bootstrap for $ContainerAppName in $Environment"

# Validate prerequisites
Write-Info "Validating prerequisites..."

# Check Azure CLI
try {
    $null = az --version 2>$null
} catch {
    Write-Error-Custom "Azure CLI not found. Install from https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check private key file
if (-not (Test-Path $PrivateKeyPath)) {
    Write-Error-Custom "Private key file not found: $PrivateKeyPath"
    exit 1
}

# Read private key
try {
    $PrivateKey = Get-Content $PrivateKeyPath -Raw
    $PrivateKey = $PrivateKey -replace "`r`n", "\n"
} catch {
    Write-Error-Custom "Failed to read private key: $_"
    exit 1
}

Write-Status "Prerequisites validated"

# Retrieve ACA base URL if not provided
if (-not $AcaBaseUrl) {
    Write-Info "Retrieving ACA FQDN..."
    try {
        $AcaBaseUrl = az containerapp show `
            --resource-group $ResourceGroup `
            --name $ContainerAppName `
            --query "properties.configuration.ingress.fqdn" -o tsv 2>$null
        
        if (-not $AcaBaseUrl -or $AcaBaseUrl -eq "null") {
            Write-Error-Custom "Could not retrieve FQDN for $ContainerAppName"
            exit 1
        }
        $AcaBaseUrl = "https://$AcaBaseUrl"
    } catch {
        Write-Error-Custom "Failed to retrieve ACA configuration: $_"
        exit 1
    }
}

Write-Status "ACA Base URL: $AcaBaseUrl"

# Prepare environment variables
$envVars = @(
    @{ name = "BASECOAT_EXTENSION_GITHUB_APP_ID"; value = $AppId }
    @{ name = "BASECOAT_EXTENSION_GITHUB_CLIENT_ID"; value = $ClientId }
    @{ name = "BASECOAT_EXTENSION_GITHUB_CLIENT_SECRET"; value = $ClientSecret; secret = $true }
    @{ name = "BASECOAT_EXTENSION_WEBHOOK_SECRET"; value = $WebhookSecret; secret = $true }
    @{ name = "BASECOAT_EXTENSION_GITHUB_PRIVATE_KEY"; value = $PrivateKey; secret = $true }
    @{ name = "BASECOAT_EXTENSION_ALLOWED_ORG"; value = $AllowedOrg }
    @{ name = "BASECOAT_EXTENSION_OAUTH_CALLBACK_URL"; value = "$AcaBaseUrl/api/github/oauth/callback" }
    @{ name = "BASECOAT_EXTENSION_OAUTH_STATE_TTL_MS"; value = "600000" }
    @{ name = "BASECOAT_EXTENSION_SESSION_TTL_MS"; value = "86400000" }
    @{ name = "BASECOAT_EXTENSION_SESSION_ROTATION_INTERVAL_MS"; value = "14400000" }
)

# Build az containerapp update command with all env vars
Write-Info "Setting environment variables on $ContainerAppName..."

$secretsJson = @()
$envJson = @()

foreach ($envVar in $envVars) {
    if ($envVar.secret) {
        $secretsJson += @{
            name  = $envVar.name
            value = $envVar.value
        }
    } else {
        $envJson += @{
            name      = $envVar.name
            value     = $envVar.value
            secretRef = ""
        }
    }
}

# Convert secrets to JSON format for az containerapp update
$secretsArg = ""
if ($secretsJson.Count -gt 0) {
    $secretsArg = $secretsJson | ConvertTo-Json -Compress
    $secretsArg = $secretsArg -replace '"', '\"'
}

# Build container update args
$updateArgs = @(
    "containerapp"
    "update"
    "--resource-group"
    $ResourceGroup
    "--name"
    $ContainerAppName
)

# Add environment variables (non-secrets)
foreach ($envVar in $envJson) {
    if ($envVar.name -and $envVar.value) {
        $updateArgs += "--set-env-vars"
        $updateArgs += "$($envVar.name)=$($envVar.value)"
    }
}

# Update Container App with environment variables
try {
    & az @updateArgs 2>&1 | Where-Object { $_ }
} catch {
    Write-Error-Custom "Failed to update environment variables: $_"
    exit 1
}

Write-Status "Environment variables updated"

# Set secrets if any
if ($secretsJson.Count -gt 0) {
    Write-Info "Setting secrets..."
    foreach ($secret in $secretsJson) {
        try {
            # Escape value for shell
            $escapedValue = $secret.value -replace '"', '\"' -replace '$', '`$'
            
            & az containerapp secret set `
                --resource-group $ResourceGroup `
                --name $ContainerAppName `
                --secrets "$($secret.name)=$escapedValue" 2>&1 | Where-Object { $_ }
            
            Write-Status "Secret set: $($secret.name)"
        } catch {
            Write-Error-Custom "Failed to set secret $($secret.name): $_"
            exit 1
        }
    }
}

# Validate deployment
Write-Info "Validating deployment..."

try {
    $status = az containerapp show `
        --resource-group $ResourceGroup `
        --name $ContainerAppName `
        --query "properties.runningStatus" -o tsv
    
    if ($status -ne "Running") {
        Write-Error-Custom "Container App is not running (status: $status). Restart may be required."
        exit 1
    }
    
    Write-Status "Container App is running"
} catch {
    Write-Error-Custom "Failed to validate Container App status: $_"
    exit 1
}

# Health check
Write-Info "Running health check..."
try {
    $healthUrl = "$AcaBaseUrl/health"
    $response = Invoke-WebRequest -Uri $healthUrl -SkipHttpErrorCheck -TimeoutSec 30
    
    if ($response.StatusCode -eq 200) {
        Write-Status "Health check passed"
    } else {
        Write-Error-Custom "Health check failed (HTTP $($response.StatusCode)). Container App may need to restart."
        exit 1
    }
} catch {
    Write-Error-Custom "Health check failed: $_"
    Write-Info "Container App may still be starting. Check logs in Application Insights."
    exit 1
}

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         ACA Bootstrap Complete                                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor Cyan
Write-Host "  Resource Group:           $ResourceGroup"
Write-Host "  Container App:            $ContainerAppName"
Write-Host "  Environment:              $Environment"
Write-Host "  Base URL:                 $AcaBaseUrl"
Write-Host "  GitHub App ID:            $AppId"
Write-Host "  OAuth Client ID:          $ClientId"
Write-Host "  Allowed Organization:     $AllowedOrg"
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify environment variables in ACA portal"
Write-Host "  2. Confirm secrets are set (in ACA portal or vault)"
Write-Host "  3. Monitor Application Insights for telemetry"
Write-Host "  4. Test OAuth flow: GET $AcaBaseUrl/api/github/oauth/request"
Write-Host "  5. Validate @basecoat appears in Copilot Chat"
Write-Host ""

exit 0
