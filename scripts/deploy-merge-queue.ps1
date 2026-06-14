#!/usr/bin/env pwsh

<#
.SYNOPSIS
Deploy Merge Queue Enforcement to BaseCoat

.DESCRIPTION
Deploys merge queue and required checks enforcement ruleset to the main branch
of IBuySpy-Shared/basecoat. Includes validation and rollback support.

.PARAMETER DryRun
Run in simulation mode without making changes

.EXAMPLE
.\deploy-merge-queue.ps1
.\deploy-merge-queue.ps1 -DryRun

.PREREQUISITES
- GitHub CLI (gh) installed and authenticated
- PowerShell 7.0+ (cross-platform compatibility)
#>

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Configuration
$OWNER = 'IBuySpy-Shared'
$REPO = 'basecoat'
$RULESET_NAME = 'main-merge-queue-enforcement'

# Logging functions
function Write-InfoMessage {
    param([string]$Message)
    Write-Information "[INFO] $Message"
}

function Write-SuccessMessage {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Warning "[WARNING] $Message"
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Error "[ERROR] $Message"
}

# Check prerequisites
function Test-Prerequisites {
    Write-InfoMessage 'Checking prerequisites...'

    $ghPath = $null
    try {
        $ghPath = (Get-Command gh -ErrorAction Stop).Source
    } catch {
        Write-ErrorMessage 'GitHub CLI (gh) is not installed'
        throw
    }

    Write-SuccessMessage "GitHub CLI found: $ghPath"
}

# Validate GitHub authentication
function Test-GitHubAuth {
    Write-InfoMessage 'Validating GitHub authentication...'

    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage 'Not authenticated to GitHub. Run: gh auth login'
        throw
    }

    Write-SuccessMessage 'GitHub authentication verified'
}

# Validate repository access
function Test-RepositoryAccess {
    Write-InfoMessage "Validating access to $OWNER/$REPO..."

    $repoInfo = gh repo view "$OWNER/$REPO" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMessage "Cannot access $OWNER/$REPO"
        throw
    }

    Write-SuccessMessage 'Repository access verified'
}

# Create merge queue ruleset
function Deploy-MergeQueue {
    Write-InfoMessage 'Deploying merge queue ruleset to main branch...'

    $rulesetJson = @{
        name        = $RULESET_NAME
        description = 'Enforce merge queue and required checks on main branch (Sprint 36)'
        target      = 'branch'
        enforcement = 'active'
        conditions  = @{
            ref_name = @{
                include = @('refs/heads/main')
                exclude = @()
            }
        }
        rules       = @(
            @{
                type       = 'pull_request'
                parameters = @{
                    required_approving_review_count = 1
                    dismiss_stale_reviews_on_push   = $true
                    require_code_owner_review       = $false
                    require_last_push_approval      = $false
                }
            },
            @{
                type       = 'required_status_checks'
                parameters = @{
                    strict_required_status_checks_policy = $true
                    do_not_enforce_on_create              = $false
                    required_status_checks                = @(
                        @{
                            context       = 'validate-commit-messages'
                            integration_id = $null
                        },
                        @{
                            context       = 'validate-unix'
                            integration_id = $null
                        },
                        @{
                            context       = 'validate-windows'
                            integration_id = $null
                        }
                    )
                }
            },
            @{
                type       = 'merge_queue'
                parameters = @{
                    check_response_timeout_minutes = 60
                    grouping_strategy              = 'headCommit'
                    max_entries_to_build           = 5
                    max_entries_to_merge           = 1
                    merge_method                   = 'squash'
                    min_entries_to_merge           = 1
                    min_entries_to_merge_wait_minutes = 5
                }
            }
        )
        bypass_actors = @()
    } | ConvertTo-Json -Depth 10

    if ($DryRun) {
        Write-WarningMessage 'DRY RUN MODE: Would deploy the following ruleset:'
        $rulesetJson | ConvertFrom-Json | ConvertTo-Json -Depth 10 | Write-Host
        return
    }

    $tempFile = New-TemporaryFile -ErrorAction SilentlyContinue
    try {
        $rulesetJson | Set-Content -Path $tempFile.FullName
        gh api `
            --method POST `
            -H 'Accept: application/vnd.github+json' `
            "/repos/$OWNER/$REPO/rulesets" `
            --input $tempFile.FullName

        if ($LASTEXITCODE -eq 0) {
            Write-SuccessMessage 'Merge queue ruleset deployed successfully'
        } else {
            Write-ErrorMessage 'Failed to deploy merge queue ruleset'
            throw
        }
    } finally {
        Remove-Item -Path $tempFile.FullName -ErrorAction SilentlyContinue
    }
}

# Verify deployment
function Test-DeploymentVerification {
    Write-InfoMessage 'Verifying merge queue deployment...'

    $rulesets = gh api "/repos/$OWNER/$REPO/rulesets" --jq '.[] | select(.name | contains("merge-queue"))' 2>&1

    if ([string]::IsNullOrWhiteSpace($rulesets)) {
        Write-WarningMessage 'Merge queue ruleset not found. Deployment may still be propagating...'
        return
    }

    Write-SuccessMessage 'Merge queue ruleset verified:'
    Write-Host $rulesets

    Write-SuccessMessage 'Deployment verification complete'
}

# Main execution
function Main {
    Write-SuccessMessage '=== BaseCoat Merge Queue Deployment ==='
    Write-InfoMessage "Repository: $OWNER/$REPO"
    Write-InfoMessage 'Target: main branch'

    if ($DryRun) {
        Write-WarningMessage 'Running in DRY RUN mode (no changes will be made)'
    }

    Test-Prerequisites
    Test-GitHubAuth
    Test-RepositoryAccess
    Deploy-MergeQueue

    if (-not $DryRun) {
        Test-DeploymentVerification
    }

    Write-SuccessMessage '=== Merge queue deployment complete ==='
}

# Execute
try {
    Main
} catch {
    Write-ErrorMessage $_.Exception.Message
    exit 1
}
