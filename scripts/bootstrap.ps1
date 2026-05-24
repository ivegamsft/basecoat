<#
.SYNOPSIS
    Bootstrap and preflight-check a BaseCoat environment.

.DESCRIPTION
    Idempotent four-phase setup for new BaseCoat adopters:
      Phase 1 — Repo setup      (fork detection, GitHub settings, gh aw extension)
      Phase 2 — Memory layer    (SQLite init, gitignore guard, optional shared memory sync)
      Phase 3 — Secrets check   (validate secrets and, in interactive mode, optionally configure missing portal deploy secrets)
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

.EXAMPLE
    pwsh scripts/bootstrap.ps1

.EXAMPLE
    pwsh scripts/bootstrap.ps1 -Silent -SkipTests

.EXAMPLE
    pwsh scripts/bootstrap.ps1 -CreateIssues

.EXAMPLE
    pwsh scripts/bootstrap.ps1 -SharedMemoryRepo "MyOrg/basecoat-memory"
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$SkipTests,
    [switch]$CreateIssues,
    [string]$SharedMemoryRepo = $env:BASECOAT_SHARED_MEMORY_REPO
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    $subject = "repo:IBuySpy-Shared/basecoat:environment:$environmentName"

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

        $federatedCredential = @{
            name       = "$environmentName-github-actions"
            issuer     = "https://token.actions.githubusercontent.com"
            subject    = $subject
            audiences  = @("api://AzureADTokenExchange")
        } | ConvertTo-Json -Compress

        $credentialExists = $false
        try {
            $existingCredentials = az ad app federated-credential list --id $appId 2>$null | ConvertFrom-Json
            $credentialExists = @($existingCredentials | Where-Object {
                $_.subject -eq $subject -and $_.issuer -eq 'https://token.actions.githubusercontent.com'
            }).Count -gt 0
        } catch {
            $credentialExists = $false
        }

        if (-not $credentialExists) {
            $credentialFile = Join-Path $env:TEMP "basecoat-portal-oidc-$environmentName.json"
            $federatedCredential | Out-File -FilePath $credentialFile -Encoding utf8 -Force
            $null = az ad app federated-credential create --id $appId --parameters $credentialFile 2>$null
            Remove-Item -Path $credentialFile -Force -ErrorAction SilentlyContinue
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "Failed to create federated credential for portal OIDC bootstrap"
                return $false
            }
            Write-Check "Portal federated credential created" $true $environmentName
        } else {
            Write-Check "Portal federated credential exists" $true $environmentName
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

# COPILOT_GITHUB_TOKEN
try {
    $repoSlug = (gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null).Trim()
    if (-not $repoSlug) {
        throw "Unable to resolve repository slug"
    }
    
    $secrets = gh secret list -R $repoSlug 2>$null | Out-String
    if ($secrets -match 'COPILOT_GITHUB_TOKEN') {
        Write-Check "COPILOT_GITHUB_TOKEN repo secret present" $true "required for agentic workflows"
    } else {
        Write-Warn "COPILOT_GITHUB_TOKEN not set — agentic workflows won't run"
        Write-Host "  → Create a fine-grained PAT with 'Copilot Requests: Read'" -ForegroundColor DarkGray
        Write-Host "    https://github.com/settings/personal-access-tokens/new" -ForegroundColor DarkGray
        Write-Host "    Then: gh secret set COPILOT_GITHUB_TOKEN" -ForegroundColor DarkGray
    }
} catch {
    Write-Warn "Could not check repo secrets (needs repo admin access)"
}

# Portal deployment secrets (if portal deploy workflow is present)
$portalDeployWorkflow = Join-Path $repoRoot '.github\workflows\portal-deploy.yml'
$script:portalDeployReady = $false
if (Test-Path $portalDeployWorkflow) {
    try {
        $repoSlug = (gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>$null).Trim()
        if (-not $repoSlug) {
            throw "Unable to resolve repository slug"
        }

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
            Write-Warn "Missing portal deploy variables: $($missingPortalVars -join ', ')"

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
        $repoSecretNames = @(
            gh secret list -R $repoSlug --json name --jq '.[].name' 2>$null |
                Where-Object { $_ }
        )

        foreach ($variableName in $requiredPortalVars) {
            if ($repoVarNames -contains $variableName) {
                Write-Check "$variableName available for portal deploy" $true
            } else {
                Write-Fail "$variableName missing for portal deploy (set as repo variable)"
            }
        }

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

Run \`pwsh scripts/bootstrap.ps1\` to review full details.
Audit log: \`.memory/bootstrap-audit.json\`
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

Run \`pwsh scripts/bootstrap.ps1\` to review full details.
Audit log: \`.memory/bootstrap-audit.json\`
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
