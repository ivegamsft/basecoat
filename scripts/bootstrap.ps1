<#
.SYNOPSIS
    Bootstrap and preflight-check a BaseCoat environment.

.DESCRIPTION
    Idempotent four-phase setup for new BaseCoat adopters:
      Phase 1 — Repo setup      (fork detection, GitHub settings, gh aw extension)
      Phase 2 — Memory layer    (SQLite init, gitignore guard, optional shared memory sync)
      Phase 3 — Secrets check   (profile-driven required secret/variable matrix with precise remediation, plus interactive bootstrap for missing values)
      Phase 4 — Validation      (validate-basecoat.ps1 + run-tests.ps1)
    
    Generates audit log to .memory/bootstrap-audit.json with all checks, warnings, and errors.
    Optionally creates GitHub issues for critical failures (-CreateIssues flag).

.PARAMETER Silent
    Suppress interactive prompts. Suitable for CI use. Audit log is still generated.

.PARAMETER SkipTests
    Skip Phase 4 test suite run (useful when bootstrapping in environments without all
    test dependencies installed).

.PARAMETER CreateIssues
    Automatically create GitHub issues for critical errors found during validation.
    Only works in interactive mode (-Silent disables issue creation).

.PARAMETER SharedMemoryRepo
    Override the shared org memory repo (e.g., 'MyOrg/basecoat-memory').
    Defaults to BASECOAT_SHARED_MEMORY_REPO environment variable if set.

.PARAMETER OnboardingProfile
    Optional profile selector for secret and variable requirements:
    solo-dev, team-dev, or regulated-team.
    Defaults to BASECOAT_ONBOARDING_PROFILE, then onboarding contract, then team-dev.

.PARAMETER OnboardingContractPath
    Optional path to onboarding profile contract JSON file. Used to resolve
    profile when -OnboardingProfile is not provided.
    Defaults to BASECOAT_ONBOARDING_CONTRACT_PATH, then .github/basecoat-onboarding-profile.json.

.PARAMETER ValidateProfileOnly
    Resolve and validate the onboarding profile contract, print the selected
    profile as JSON, and exit before running bootstrap phases.

.EXAMPLE
    pwsh scripts/bootstrap.ps1

.EXAMPLE
    pwsh scripts/bootstrap.ps1 -Silent -SkipTests

.EXAMPLE
    pwsh scripts/bootstrap.ps1 -CreateIssues

.EXAMPLE
    pwsh scripts/bootstrap.ps1 -SharedMemoryRepo "MyOrg/basecoat-memory"

.EXAMPLE
    pwsh scripts/bootstrap.ps1 -OnboardingProfile regulated-team -Silent
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$SkipTests,
    [switch]$CreateIssues,
    [string]$SharedMemoryRepo = $env:BASECOAT_SHARED_MEMORY_REPO,
    [ValidateSet('solo-dev', 'team-dev', 'regulated-team')]
    [string]$OnboardingProfile,
    [string]$OnboardingContractPath = $(if ($env:BASECOAT_ONBOARDING_CONTRACT_PATH) { $env:BASECOAT_ONBOARDING_CONTRACT_PATH } else { '.github\basecoat-onboarding-profile.json' }),
    [switch]$ValidateProfileOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:DefaultGitHubOidcIssuer = 'https://token.actions.githubusercontent.com'
$script:DefaultGitHubOidcAudience = 'api://AzureADTokenExchange'

# ── helpers ──────────────────────────────────────────────────────────────────

$script:errors   = [System.Collections.Generic.List[string]]::new()
$script:warnings = [System.Collections.Generic.List[string]]::new()
$script:checks   = [System.Collections.Generic.List[hashtable]]::new()

function Write-Header([string]$text) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-Check([string]$label, [bool]$ok, [string]$detail = "") {
    $icon   = if ($ok) { "✅" } else { "❌" }
    $color  = if ($ok) { "Green" } else { "Red" }
    $suffix = if ($detail) { "  ($detail)" } else { "" }
    Write-Host "  $icon  $label$suffix" -ForegroundColor $color
    $script:checks.Add(@{ label = $label; ok = $ok; detail = $detail })
}

function Write-Warn([string]$msg) {
    Write-Host "  ⚠️   $msg" -ForegroundColor Yellow
    $script:warnings.Add($msg)
}

function Write-Fail([string]$msg) {
    Write-Host "  ❌  $msg" -ForegroundColor Red
    $script:errors.Add($msg)
}

function Confirm-Step([string]$prompt) {
    if ($Silent) { return $true }
    $ans = Read-Host "$prompt [Y/n]"
    return ($ans -eq '' -or $ans -match '^[Yy]')
}

function Test-CommandExists([string]$cmd) {
    return $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Read-SecretValue([string]$prompt) {
    $secure = Read-Host $prompt -AsSecureString
    if (-not $secure -or $secure.Length -eq 0) { return '' }

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Set-GitHubSecretValue(
    [string]$repoSlug,
    [string]$secretName,
    [string]$secretValue,
    [string]$environmentName = 'staging'
) {
    if ([string]::IsNullOrWhiteSpace($secretValue)) { return $false }

    $secretValue | gh secret set $secretName -R $repoSlug --env $environmentName 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Set-GitHubRepoSecretValue(
    [string]$repoSlug,
    [string]$secretName,
    [string]$secretValue
) {
    if ([string]::IsNullOrWhiteSpace($secretValue)) { return $false }

    $secretValue | gh secret set $secretName -R $repoSlug 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-AzureAccountContext {
    if (-not (Test-CommandExists 'az')) { return $null }

    try {
        $account = az account show 2>$null | ConvertFrom-Json -ErrorAction Stop
        if (-not $account) { return $null }
        return $account
    } catch {
        return $null
    }
}

function Set-GitHubVariableValue(
    [string]$repoSlug,
    [string]$variableName,
    [string]$variableValue
) {
    if ([string]::IsNullOrWhiteSpace($variableValue)) { return $false }

    $variableValue | gh variable set $variableName -R $repoSlug 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-GitHubOidcIssuer([string]$repoSlug) {
    $issuer = $env:BASECOAT_GITHUB_OIDC_ISSUER
    if (-not [string]::IsNullOrWhiteSpace($issuer)) {
        return $issuer.Trim()
    }

    try {
        $issuerConfigRaw = gh api "repos/$repoSlug/actions/oidc/customization/issuer" 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($issuerConfigRaw)) {
            $issuerConfig = $issuerConfigRaw | ConvertFrom-Json -ErrorAction Stop

            if ($issuerConfig.issuer) {
                return $issuerConfig.issuer
            }

            if ($issuerConfig.include_enterprise_slug -and $issuerConfig.enterprise_slug) {
                return "$($script:DefaultGitHubOidcIssuer)/$($issuerConfig.enterprise_slug)"
            }
        }
    } catch {
        # Fall back to default issuer when API is unavailable.
    }

    return $script:DefaultGitHubOidcIssuer
}

function Get-GitHubOidcAudience {
    if (-not [string]::IsNullOrWhiteSpace($env:BASECOAT_GITHUB_OIDC_AUDIENCE)) {
        return $env:BASECOAT_GITHUB_OIDC_AUDIENCE.Trim()
    }

    return $script:DefaultGitHubOidcAudience
}

function Get-OnboardingProfileSelection(
    [string]$requestedProfile,
    [string]$contractPath,
    [switch]$strictContract
) {
    $profileFromContract = $null
    $contract = $null
    if (-not [string]::IsNullOrWhiteSpace($contractPath)) {
        $resolvedContractPath = if ([System.IO.Path]::IsPathRooted($contractPath)) {
            $contractPath
        } else {
            Join-Path (Get-Location) $contractPath
        }

        if (Test-Path $resolvedContractPath) {
            try {
                $contractRaw = Get-Content -Path $resolvedContractPath -Raw
                if ([string]::IsNullOrWhiteSpace($contractRaw)) {
                    if ($strictContract) {
                        throw 'Contract file is empty.'
                    }
                } else {
                    $contract = $contractRaw | ConvertFrom-Json -ErrorAction Stop
                    $profileProperty = $contract.PSObject.Properties['profile']
                    if (-not $profileProperty -or [string]::IsNullOrWhiteSpace([string]$profileProperty.Value)) {
                        if ($strictContract) {
                            throw "Required field 'profile' is missing or empty."
                        }
                    } else {
                        $profileFromContract = $profileProperty.Value.ToString().Trim()
                    }
                }
            } catch {
                if ($strictContract) {
                    throw "Invalid onboarding contract at '$resolvedContractPath': $($_.Exception.Message)"
                }
                Write-Warn "Could not parse onboarding contract at '$resolvedContractPath': $($_.Exception.Message)"
            }
        }
    }

    $candidateProfile = @(
        $requestedProfile,
        $env:BASECOAT_ONBOARDING_PROFILE,
        $profileFromContract,
        'team-dev'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1

    $profiles = @{
        'solo-dev' = [ordered]@{
            profile = 'solo-dev'
            branch_policy = 'minimal'
            workflow_pack = 'solo'
            template_pack = 'solo'
            telemetry_mode = 'local'
            secrets_mode = 'local'
            hook_pack = 'none'
        }
        'team-dev' = [ordered]@{
            profile = 'team-dev'
            branch_policy = 'shared'
            workflow_pack = 'team'
            template_pack = 'team'
            telemetry_mode = 'shared'
            secrets_mode = 'workflow-secrets'
            hook_pack = 'standard'
        }
        'regulated-team' = [ordered]@{
            profile = 'regulated-team'
            branch_policy = 'locked-down'
            workflow_pack = 'regulated'
            template_pack = 'regulated'
            telemetry_mode = 'org-managed'
            secrets_mode = 'org-managed'
            hook_pack = 'guardrails'
        }
    }

    if (-not $profiles.ContainsKey($candidateProfile)) {
        throw "Unsupported onboarding profile '$candidateProfile'. Allowed values: solo-dev, team-dev, regulated-team."
    }

    if ($contract) {
        $migrationFromProperty = $contract.PSObject.Properties['migration_from']
        $migrationFrom = if ($migrationFromProperty -and $migrationFromProperty.Value) {
            $migrationFromProperty.Value.ToString().Trim()
        } else {
            $null
        }
        $allowDowngradeProperty = $contract.PSObject.Properties['allow_profile_downgrade']
        $allowProfileDowngrade = $false

        if ($allowDowngradeProperty) {
            if ($allowDowngradeProperty.Value -isnot [bool]) {
                throw "Onboarding contract field 'allow_profile_downgrade' must be a boolean."
            }
            $allowProfileDowngrade = [bool]$allowDowngradeProperty.Value
        }

        if (-not [string]::IsNullOrWhiteSpace($migrationFrom)) {
            if (-not $profiles.ContainsKey($migrationFrom)) {
                throw "Unsupported migration_from profile '$migrationFrom'. Allowed values: solo-dev, team-dev, regulated-team."
            }

            $profileRank = @{
                'solo-dev' = 1
                'team-dev' = 2
                'regulated-team' = 3
            }
            if (
                $profileRank[$candidateProfile] -lt $profileRank[$migrationFrom] -and
                -not $allowProfileDowngrade
            ) {
                throw "Profile downgrade from '$migrationFrom' to '$candidateProfile' is blocked. Set allow_profile_downgrade to true only with explicit approval."
            }
        }
    }

    return [pscustomobject]$profiles[$candidateProfile]
}

function Get-OnboardingSecretVariableRequirements(
    [pscustomobject]$profileSelection,
    [bool]$hasPublishWorkflow,
    [bool]$hasPortalDeployWorkflow
) {
    $requirements = [System.Collections.Generic.List[object]]::new()

    if ($profileSelection.secrets_mode -eq 'org-managed') {
        $requirements.Add([pscustomobject]@{
            Name = 'GH_AW_GITHUB_MCP_SERVER_TOKEN'
            Kind = 'secret'
            Remediation = "Set with 'gh secret set GH_AW_GITHUB_MCP_SERVER_TOKEN -R <repo>' scoped to Issues/PR read-write and Contents read."
            Rotation = 'Rotate every 30 days (set PAT expiration <=30 days).'
        })
    }

    if ($hasPublishWorkflow) {
        $requirements.Add([pscustomobject]@{
            Name = 'PRODUCTION_REPO_TOKEN'
            Kind = 'secret'
            Remediation = "Set with 'gh secret set PRODUCTION_REPO_TOKEN --repo <repo>' after creating PAT on ivegamsft/basecoat with Contents/Admin/Workflows read-write."
            Rotation = 'Rotate before PAT expiration; keep expiration <=30 days where possible.'
        })
    }

    if ($hasPortalDeployWorkflow -and $profileSelection.profile -ne 'solo-dev') {
        $requirements.Add([pscustomobject]@{
            Name = 'AZURE_CLIENT_ID'
            Kind = 'variable'
            Pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
            Remediation = "Set with 'gh variable set AZURE_CLIENT_ID -R <repo>' using a valid Entra application (GUID) client ID."
            Rotation = ''
        })
        $requirements.Add([pscustomobject]@{
            Name = 'AZURE_TENANT_ID'
            Kind = 'variable'
            Pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
            Remediation = "Set with 'gh variable set AZURE_TENANT_ID -R <repo>' using your Entra tenant GUID."
            Rotation = ''
        })
        $requirements.Add([pscustomobject]@{
            Name = 'AZURE_SUBSCRIPTION_ID'
            Kind = 'variable'
            Pattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
            Remediation = "Set with 'gh variable set AZURE_SUBSCRIPTION_ID -R <repo>' using your target Azure subscription GUID."
            Rotation = ''
        })
        $requirements.Add([pscustomobject]@{
            Name = 'GHCR_PULL_TOKEN'
            Kind = 'secret'
            Remediation = "Set with 'gh secret set GHCR_PULL_TOKEN -R <repo>' using a PAT with read:packages."
            Rotation = 'Rotate every 30 days (set PAT expiration <=30 days).'
        })
    }

    return $requirements
}

function Test-OnboardingSecretVariableRequirements(
    [string]$repoSlug,
    [array]$requirements,
    [bool]$interactiveMode
) {
    $secretNames = @()
    $repoVarLookup = @{}

    try {
        $secretNames = @(
            gh secret list -R $repoSlug --json name --jq '.[].name' 2>$null |
                Where-Object { $_ }
        )
    } catch {
        Write-Warn "Could not inspect repository secrets (needs repo admin access)."
    }

    try {
        $repoVariablesRaw = gh variable list -R $repoSlug --json name,value 2>$null | ConvertFrom-Json -ErrorAction Stop
        foreach ($variable in @($repoVariablesRaw)) {
            if ($variable.name) {
                $repoVarLookup[$variable.name] = [string]$variable.value
            }
        }
    } catch {
        Write-Warn "Could not inspect repository variables (needs repo admin access)."
    }

    Write-Host "  Required configuration matrix:" -ForegroundColor Cyan
    foreach ($requirement in $requirements) {
        Write-Host "    - $($requirement.Kind): $($requirement.Name)" -ForegroundColor DarkGray
    }

    foreach ($requirement in $requirements) {
        if ($requirement.Kind -eq 'secret') {
            $hasSecret = $secretNames -contains $requirement.Name
            if ($hasSecret) {
                Write-Check "$($requirement.Name) repo secret present" $true "required"
                continue
            }

            Write-Fail "$($requirement.Name) missing. $($requirement.Remediation.Replace('<repo>', $repoSlug))"
            if ($interactiveMode -and (Confirm-Step "  Configure missing secret '$($requirement.Name)' now?")) {
                $secretValue = Read-SecretValue "  Enter value for $($requirement.Name)"
                if (Set-GitHubRepoSecretValue -repoSlug $repoSlug -secretName $requirement.Name -secretValue $secretValue) {
                    Write-Check "$($requirement.Name) configured" $true "repo secret"
                } else {
                    Write-Fail "Could not configure $($requirement.Name). $($requirement.Remediation.Replace('<repo>', $repoSlug))"
                }
            }
            continue
        }

        if (-not $repoVarLookup.ContainsKey($requirement.Name)) {
            Write-Fail "$($requirement.Name) missing. $($requirement.Remediation.Replace('<repo>', $repoSlug))"
            if ($interactiveMode -and (Confirm-Step "  Configure missing variable '$($requirement.Name)' now?")) {
                $inputValue = Read-Host "  Enter value for $($requirement.Name)"
                if (Set-GitHubVariableValue -repoSlug $repoSlug -variableName $requirement.Name -variableValue $inputValue) {
                    Write-Check "$($requirement.Name) configured" $true "repo variable"
                    $repoVarLookup[$requirement.Name] = $inputValue
                } else {
                    Write-Fail "Could not configure $($requirement.Name). $($requirement.Remediation.Replace('<repo>', $repoSlug))"
                }
            }
            continue
        }

        $currentValue = [string]$repoVarLookup[$requirement.Name]
        if (-not [string]::IsNullOrWhiteSpace($requirement.Pattern) -and ($currentValue -notmatch $requirement.Pattern)) {
            Write-Fail "$($requirement.Name) has invalid format ('$currentValue'). $($requirement.Remediation.Replace('<repo>', $repoSlug))"
            continue
        }

        Write-Check "$($requirement.Name) available for workflows" $true "repo variable"
    }

    $rotationEntries = @(
        $requirements |
            Where-Object { $_.Kind -eq 'secret' -and -not [string]::IsNullOrWhiteSpace($_.Rotation) } |
            ForEach-Object { "$($_.Name): $($_.Rotation)" }
    )
    if ($rotationEntries.Count -gt 0) {
        Write-Host "  Rotation/expiration guidance:" -ForegroundColor DarkGray
        foreach ($entry in $rotationEntries) {
            Write-Host "    • $entry" -ForegroundColor DarkGray
        }
    }
}

function Ensure-PortalOidcBootstrap(
    [string]$repoSlug,
    [string]$environmentName = 'staging'
) {
    $azureContext = Get-AzureAccountContext
    if (-not $azureContext) {
        Write-Fail "Azure CLI is not logged in — cannot provision portal OIDC bootstrap"
        return $false
    }

    $tenantId = $azureContext.tenantId
    $subscriptionId = $azureContext.id
    $displayName = 'basecoat-portal-staging-deploy'
    $scope = "/subscriptions/$subscriptionId"
    $subject = "repo:$repoSlug:environment:$environmentName"
    $issuer = Get-GitHubOidcIssuer -repoSlug $repoSlug
    $audience = Get-GitHubOidcAudience

    try {
        $appId = az ad app list --display-name $displayName --query "[0].appId" -o tsv 2>$null
        if (-not $appId) {
            $appId = az ad app create --display-name $displayName --query appId -o tsv 2>$null
            if (-not $appId) {
                Write-Fail "Failed to create Entra application for portal OIDC bootstrap"
                return $false
            }
            Write-Check "Portal Entra application created" $true $displayName
        } else {
            Write-Check "Portal Entra application exists" $true $displayName
        }

        $spId = az ad sp list --filter "appId eq '$appId'" --query "[0].id" -o tsv 2>$null
        if ($spId) {
            Write-Check "Portal service principal exists" $true $appId
        } else {
            Write-Warn "Portal service principal not found; continuing with app registration only"
        }

        $credentialName = "$environmentName-github-actions"
        $federatedCredential = @{
            name       = $credentialName
            issuer     = $issuer
            subject    = $subject
            audiences  = @($audience)
        } | ConvertTo-Json -Compress

        $credentialExists = $false
        $existingCredentialByName = $null
        try {
            $existingCredentials = az ad app federated-credential list --id $appId 2>$null | ConvertFrom-Json
            $existingCredentialByName = @($existingCredentials | Where-Object {
                $_.name -eq $credentialName
            } | Select-Object -First 1)

            $credentialExists = @($existingCredentials | Where-Object {
                $_.subject -eq $subject -and $_.issuer -eq $issuer -and $_.audiences -contains $audience
            }).Count -gt 0
        } catch {
            $credentialExists = $false
        }

        if (-not $credentialExists) {
            if ($existingCredentialByName) {
                $existingCredentialId = if ($existingCredentialByName.id) { $existingCredentialByName.id } else { $credentialName }
                az ad app federated-credential delete --id $appId --federated-credential-id $existingCredentialId 2>$null | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Fail "Failed to update federated credential '$credentialName' for portal OIDC bootstrap"
                    return $false
                }
                Write-Check "Portal federated credential replaced" $true $credentialName
            }

            $credentialFile = Join-Path $env:TEMP "basecoat-portal-oidc-$environmentName.json"
            $federatedCredential | Out-File -FilePath $credentialFile -Encoding utf8 -Force
            $null = az ad app federated-credential create --id $appId --parameters $credentialFile 2>$null
            Remove-Item -Path $credentialFile -Force -ErrorAction SilentlyContinue
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "Failed to create federated credential for portal OIDC bootstrap"
                return $false
            }
            Write-Check "Portal federated credential created" $true "$environmentName ($issuer)"
        } else {
            Write-Check "Portal federated credential exists" $true "$environmentName ($issuer)"
        }

        $rbacExists = az role assignment list --assignee $appId --scope $scope --query "[?roleDefinitionName=='Contributor'] | [0].id" -o tsv 2>$null
        if (-not $rbacExists) {
            az role assignment create --assignee $appId --role "Contributor" --scope $scope 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "Failed to assign Contributor on $scope to portal app"
                return $false
            }
            Write-Check "Portal Contributor role assigned" $true $scope
        } else {
            Write-Check "Portal Contributor role exists" $true $scope
        }

        # User Access Administrator allows IaC to create role assignments (e.g. AcrPull for managed identity)
        $uaaExists = az role assignment list --assignee $appId --scope $scope --query "[?roleDefinitionName=='User Access Administrator'] | [0].id" -o tsv 2>$null
        if (-not $uaaExists) {
            az role assignment create --assignee $appId --role "User Access Administrator" --scope $scope 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "Failed to assign User Access Administrator on $scope to portal app"
                return $false
            }
            Write-Check "Portal User Access Administrator role assigned" $true $scope
        } else {
            Write-Check "Portal User Access Administrator role exists" $true $scope
        }

        if (Set-GitHubVariableValue -repoSlug $repoSlug -variableName 'AZURE_CLIENT_ID' -variableValue $appId) {
            Write-Check "AZURE_CLIENT_ID configured" $true "repo variable"
        } else {
            Write-Fail "Could not set AZURE_CLIENT_ID"
            return $false
        }

        if (Set-GitHubVariableValue -repoSlug $repoSlug -variableName 'AZURE_TENANT_ID' -variableValue $tenantId) {
            Write-Check "AZURE_TENANT_ID configured" $true "repo variable"
        } else {
            Write-Fail "Could not set AZURE_TENANT_ID"
            return $false
        }

        if (Set-GitHubVariableValue -repoSlug $repoSlug -variableName 'AZURE_SUBSCRIPTION_ID' -variableValue $subscriptionId) {
            Write-Check "AZURE_SUBSCRIPTION_ID configured" $true "repo variable"
        } else {
            Write-Fail "Could not set AZURE_SUBSCRIPTION_ID"
            return $false
        }

        Write-Host "  ℹ️   Portal deploy now uses OIDC via azure/login@v2 and repo variables." -ForegroundColor DarkGray
        return $true
    } catch {
        Write-Fail "Could not provision portal OIDC bootstrap: $_"
        return $false
    }
}

function Test-OpenIssueWithTitle {
    param(
        [string]$repoSlug,
        [string]$title
    )

    try {
        $issues = gh issue list -R $repoSlug --state open --limit 100 --json number,title 2>$null | ConvertFrom-Json
        return [bool](@($issues | Where-Object { $_.title -eq $title } | Select-Object -First 1))
    } catch {
        return $false
    }
}

function Write-AuditLog([string]$repoRoot, [hashtable]$auditData) {
    $memoryDir = Join-Path $repoRoot '.memory'
    if (-not (Test-Path $memoryDir)) {
        New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    }

    $auditFile = Join-Path $memoryDir 'bootstrap-audit.json'
    $auditData | ConvertTo-Json -Depth 10 | Out-File -FilePath $auditFile -Encoding UTF8 -Force
    return $auditFile
}

function Create-GitHubIssue(
    [string]$repoSlug,
    [string]$title,
    [string]$body,
    [string[]]$labels = @()
) {
    try {
        $cmd = @('gh', 'issue', 'create', '-R', $repoSlug, '--title', $title, '--body', $body)
        foreach ($label in $labels) {
            $cmd += @('--label', $label)
        }
        & $cmd 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

# ── repo root detection ───────────────────────────────────────────────────────

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Not inside a git repository. Run this script from within your BaseCoat repo."
    exit 1
}
Set-Location $repoRoot

# Resolve the profile without running setup phases when used by CI or contract tests.
if ($ValidateProfileOnly) {
    try {
        Get-OnboardingProfileSelection `
            -requestedProfile $OnboardingProfile `
            -contractPath $OnboardingContractPath `
            -strictContract |
            ConvertTo-Json -Compress
        exit 0
    } catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}

Write-Host ""
Write-Host "  BaseCoat Bootstrap" -ForegroundColor White
Write-Host "  Profile: bootstrap + readiness checks" -ForegroundColor DarkGray
Write-Host "  Repo: $repoRoot" -ForegroundColor DarkGray
Write-Host "  Mode: $(if ($Silent) { 'Silent' } else { 'Interactive' })" -ForegroundColor DarkGray

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1 — Repo setup
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Phase 1 — Repo Setup"

# Detect fork vs origin
$remoteUrl = git remote get-url origin 2>$null
$isFork    = $false
if ($remoteUrl -match 'IBuySpy-Shared/basecoat') {
    Write-Check "Remote is upstream BaseCoat (not a fork)" $true "consider forking for org-specific customizations"
} else {
    $isFork = $true
    Write-Check "Repo is a fork/clone of BaseCoat" $true $remoteUrl
}

# gh CLI
if (Test-CommandExists 'gh') {
    $ghVersion = (gh --version 2>$null | Select-Object -First 1)
    Write-Check "GitHub CLI (gh) available" $true $ghVersion
} else {
    Write-Fail "GitHub CLI (gh) not found — install from https://cli.github.com"
}

# gh auth
$authStatus = gh auth status 2>&1 | Out-String
if ($authStatus -match 'Logged in') {
    Write-Check "gh auth: logged in" $true
} else {
    Write-Warn "gh auth: not logged in — run 'gh auth login'"
}

# gh aw extension
$awVersion = gh extension list 2>$null | Select-String 'gh-aw'
if ($awVersion) {
    Write-Check "gh aw extension installed" $true ($awVersion.ToString().Trim())
} else {
    Write-Warn "gh aw extension not installed — agentic workflows won't compile"
    if (Confirm-Step "  Install gh aw now?") {
        gh extension install github/gh-aw
        Write-Check "gh aw extension installed" $true "just installed"
    }
}

# GitHub Actions enabled (best-effort check via API)
try {
    $actionsStatus = gh api "repos/{owner}/{repo}/actions/permissions" --jq '.enabled' 2>$null
    if ($actionsStatus -eq 'true') {
        Write-Check "GitHub Actions enabled" $true
    } else {
        Write-Warn "GitHub Actions may be disabled — check Settings → Actions → General"
    }
} catch {
    Write-Warn "Could not verify Actions status (may need repo write access)"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 — Memory layer
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Phase 2 — Memory Layer"

# .gitignore guard
$gitignorePath = Join-Path $repoRoot '.gitignore'
$requiredPatterns = @('*.db', '*.sqlite', '.memory/', '.copilot/session-state/')
$gitignoreContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath -Raw } else { '' }

$missingPatterns = @($requiredPatterns | Where-Object { $gitignoreContent -notmatch [regex]::Escape($_) })
if ($missingPatterns.Count -eq 0) {
    Write-Check ".gitignore protects memory stores" $true
} else {
    Write-Warn ".gitignore missing patterns: $($missingPatterns -join ', ')"
    if (Confirm-Step "  Add missing .gitignore patterns now?") {
        $additions = "`n# BaseCoat memory stores — org-private, never commit`n"
        $additions += $missingPatterns -join "`n"
        $additions += "`n"
        Add-Content -Path $gitignorePath -Value $additions
        Write-Check ".gitignore updated" $true
    }
}

# .memory/ directory
$memoryDir = Join-Path $repoRoot '.memory'
if (-not (Test-Path $memoryDir)) {
    New-Item -ItemType Directory -Path $memoryDir | Out-Null
    New-Item -ItemType File -Path (Join-Path $memoryDir '.gitkeep') | Out-Null
    Write-Check ".memory/ directory created" $true
} else {
    Write-Check ".memory/ directory exists" $true
}

# Shared memory sync (optional)
if ($SharedMemoryRepo) {
    Write-Host "  Shared memory repo: $SharedMemoryRepo" -ForegroundColor DarkGray
    $syncScript = Join-Path $repoRoot 'scripts' 'sync-shared-memory.ps1'
    if (Test-Path $syncScript) {
        if (Confirm-Step "  Sync shared org memory now?") {
            try {
                & $syncScript -SharedMemoryRepo $SharedMemoryRepo
                Write-Check "Shared memory synced" $true $SharedMemoryRepo
            } catch {
                Write-Warn "Shared memory sync failed: $_"
            }
        }
    } else {
        Write-Warn "sync-shared-memory.ps1 not found — skipping shared memory sync"
    }
} else {
    Write-Host "  Shared memory: not configured (set BASECOAT_SHARED_MEMORY_REPO to enable)" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 3 — Secrets / config checklist
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Phase 3 — Secrets & Config"

# Resolve repo + onboarding profile once for all checks.
try {
    $repoSlug = (gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null).Trim()
    if (-not $repoSlug) {
        throw "Unable to resolve repository slug"
    }
} catch {
    Write-Fail "Could not resolve repository slug from gh CLI: $($_.Exception.Message)"
    $repoSlug = $null
}

$profileSelection = $null
try {
    $profileSelection = Get-OnboardingProfileSelection -requestedProfile $OnboardingProfile -contractPath $OnboardingContractPath
    Write-Check "Onboarding profile selected" $true "$($profileSelection.profile) (workflow_pack=$($profileSelection.workflow_pack), secrets_mode=$($profileSelection.secrets_mode))"
} catch {
    Write-Fail $_.Exception.Message
}

$publishWorkflow = Join-Path $repoRoot '.github\workflows\publish-to-production.yml'
$portalDeployWorkflow = Join-Path $repoRoot '.github\workflows\portal-deploy.yml'
$script:portalDeployReady = $false
if ((Test-Path $portalDeployWorkflow) -and $profileSelection -and $profileSelection.profile -ne 'solo-dev' -and $repoSlug) {
    try {
        $requiredPortalVars = @(
            'AZURE_CLIENT_ID',
            'AZURE_TENANT_ID',
            'AZURE_SUBSCRIPTION_ID'
        )
        $repoVarNames = @(
            gh variable list -R $repoSlug --json name --jq '.[].name' 2>$null |
                Where-Object { $_ }
        )
        $missingPortalVars = @(
            $requiredPortalVars | Where-Object {
                $repoVarNames -notcontains $_
            }
        )

        if ($missingPortalVars.Count -gt 0) {
            Write-Warn "Portal deploy variables missing for profile '$($profileSelection.profile)': $($missingPortalVars -join ', ')"

            if ($missingPortalVars.Count -gt 0 -and -not $Silent) {
                $portalOidcReady = Ensure-PortalOidcBootstrap -repoSlug $repoSlug -environmentName 'staging'
                if (-not $portalOidcReady) {
                    Write-Fail "Portal OIDC bootstrap could not be completed"
                }
            }
        }

        $repoVarNames = @(
            gh variable list -R $repoSlug --json name --jq '.[].name' 2>$null |
                Where-Object { $_ }
        )

        $script:portalDeployReady = @(
            $requiredPortalVars | Where-Object {
                $repoVarNames -contains $_
            }
        ).Count -eq $requiredPortalVars.Count

        Write-Host "  ℹ️   Portal deploy uses GITHUB_TOKEN for GHCR pulls (no separate PAT needed)." -ForegroundColor DarkGray
        Write-Host "  ℹ️   Portal deploy uses azure/login@v2 with federated credentials and repo variables." -ForegroundColor DarkGray
        Write-Host "  ℹ️   PORTAL_POSTGRES_ADMIN_PASSWORD is optional (Bicep can generate the PostgreSQL admin password)" -ForegroundColor DarkGray
    } catch {
        Write-Warn "Could not verify portal deployment secrets: $_"
    }
}

if ($repoSlug -and $profileSelection) {
    $requirements = Get-OnboardingSecretVariableRequirements `
        -profileSelection $profileSelection `
        -hasPublishWorkflow (Test-Path $publishWorkflow) `
        -hasPortalDeployWorkflow (Test-Path $portalDeployWorkflow)
    Test-OnboardingSecretVariableRequirements `
        -repoSlug $repoSlug `
        -requirements $requirements `
        -interactiveMode (-not $Silent)
}

# BASECOAT_SHARED_MEMORY_REPO env var
if ($SharedMemoryRepo) {
    Write-Check "BASECOAT_SHARED_MEMORY_REPO configured" $true $SharedMemoryRepo
} else {
    Write-Host "  ℹ️   BASECOAT_SHARED_MEMORY_REPO not set (optional — needed for shared org memory)" -ForegroundColor DarkGray
}

# version.json readable
$versionFile = Join-Path $repoRoot 'version.json'
if (Test-Path $versionFile) {
    $version = (Get-Content $versionFile | ConvertFrom-Json).version
    Write-Check "version.json readable" $true "v$version"
} else {
    Write-Fail "version.json not found"
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 4 — Validation
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Phase 4 — Validation"

$validateScript = Join-Path $repoRoot 'scripts' 'validate-basecoat.ps1'
$testScript     = Join-Path $repoRoot 'tests'   'run-tests.ps1'

if (Test-Path $validateScript) {
    try {
        & $validateScript
        Write-Check "validate-basecoat.ps1 passed" $true
    } catch {
        Write-Fail "validate-basecoat.ps1 failed: $_"
    }
} else {
    Write-Warn "scripts/validate-basecoat.ps1 not found — skipping"
}

if (-not $SkipTests) {
    if (Test-Path $testScript) {
        try {
            & $testScript
            Write-Check "run-tests.ps1 passed" $true
        } catch {
            Write-Fail "run-tests.ps1 failed: $_"
        }
    } else {
        Write-Warn "tests/run-tests.ps1 not found — skipping"
    }
} else {
    Write-Host "  ⏭️   Tests skipped (-SkipTests)" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
# Phase 5 — Optional app bootstrap
# ─────────────────────────────────────────────────────────────────────────────

if ((Test-Path $portalDeployWorkflow) -and -not $Silent) {
    Write-Header "Phase 5 — Optional Portal Deploy"
    if ($script:portalDeployReady) {
        if (Confirm-Step "  Trigger portal-deploy.yml now?") {
            gh workflow run portal-deploy.yml -R $repoSlug 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Check "portal-deploy.yml triggered" $true
            } else {
                Write-Warn "Could not trigger portal-deploy.yml (exit code $LASTEXITCODE)."
            }
        } else {
            Write-Host "  Skipped workflow trigger." -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  Portal deploy trigger skipped because required secrets are not ready." -ForegroundColor DarkGray
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Bootstrap Summary"

$passed = @($script:checks | Where-Object { $_.ok }).Count
$failed = @($script:checks | Where-Object { -not $_.ok }).Count

Write-Host "  Checks passed : $passed" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Checks failed : $failed" -ForegroundColor Red
}
if ($script:warnings.Count -gt 0) {
    Write-Host "  Warnings      : $($script:warnings.Count)" -ForegroundColor Yellow
}

# Build audit report
$auditReport = @{
    timestamp      = Get-Date -AsUTC -Format 'o'
    repo           = $repoSlug
    mode           = if ($Silent) { 'Silent' } else { 'Interactive' }
    passed         = $passed
    failed         = $failed
    warnings       = $script:warnings.Count
    errors         = $script:errors.Count
    checks         = @($script:checks | ForEach-Object { @{ label = $_.label; ok = $_.ok; detail = $_.detail } })
    warnings_list  = @($script:warnings)
    errors_list    = @($script:errors)
}

# Write audit log
$auditFile = Write-AuditLog -repoRoot $repoRoot -auditData $auditReport
Write-Host ""
Write-Host "  📋 Audit log written: $($auditFile | Resolve-Path -Relative)" -ForegroundColor DarkGray

# Optionally create issues for critical errors
if ($CreateIssues -and -not $Silent) {
    Write-Host ""
    Write-Host "  Creating GitHub issues for bootstrap findings..." -ForegroundColor DarkGray
    
    try {
        if ($script:errors.Count -gt 0) {
            $errorTitle = "🔴 Bootstrap validation errors"
            if (-not (Test-OpenIssueWithTitle -repoSlug $repoSlug -title $errorTitle)) {
                $errorBody = @"
Bootstrap validation found critical errors:

$(($script:errors | ForEach-Object { "- $_" }) -join "`n")

Run pwsh scripts/bootstrap.ps1 to review full details.
Audit log: .memory/bootstrap-audit.json
"@
                if (Create-GitHubIssue -repoSlug $repoSlug -title $errorTitle -body $errorBody -labels @('github-actions', 'priority:high', 'maintenance')) {
                    Write-Host "  ✅ Issue created for critical errors" -ForegroundColor Green
                }
            }
        }

        if ($script:warnings.Count -gt 0) {
            $warningTitle = "🟡 Bootstrap validation warnings"
            if (-not (Test-OpenIssueWithTitle -repoSlug $repoSlug -title $warningTitle)) {
                $warningBody = @"
Bootstrap validation found warnings:

$(($script:warnings | ForEach-Object { "- $_" }) -join "`n")

Run pwsh scripts/bootstrap.ps1 to review full details.
Audit log: .memory/bootstrap-audit.json
"@
                if (Create-GitHubIssue -repoSlug $repoSlug -title $warningTitle -body $warningBody -labels @('maintenance', 'documentation')) {
                    Write-Host "  ✅ Issue created for warnings" -ForegroundColor Green
                }
            }
        }
    } catch {
        Write-Host "  ⚠️   Could not create issue: $_" -ForegroundColor Yellow
    }
}

if ($script:errors.Count -eq 0 -and $failed -eq 0) {
    Write-Host ""
    Write-Host "  🎉  BaseCoat bootstrap complete!" -ForegroundColor Green
    Write-Host "  → Open VS Code and start using agents from the agents/ directory." -ForegroundColor DarkGray
    Write-Host "  → See docs/INDEX.md for the full documentation index." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Host "  ⚠️   Bootstrap completed with issues. Resolve the items above before use." -ForegroundColor Yellow
    if ($script:errors.Count -gt 0) {
        Write-Host ""
        Write-Host "  Errors to fix:" -ForegroundColor Red
        $script:errors | ForEach-Object { Write-Host "    • $_" -ForegroundColor Red }
    }
    Write-Host ""
    exit 1
}
