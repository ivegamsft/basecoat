<#
.SYNOPSIS
    Bootstrap COPILOT_GITHUB_TOKEN at repository scope for agentic workflows.

.DESCRIPTION
    Sets the COPILOT_GITHUB_TOKEN GitHub Actions repository secret using gh CLI.
    Token is accepted as SecureString input or prompt and is never echoed.

.PARAMETER Repo
    Repository slug (owner/name). Defaults to the current origin remote repo.

.PARAMETER Token
    PAT value as SecureString. If omitted, prompts interactively unless -Silent.

.PARAMETER AlsoSetGhAwGithubToken
    Also sets GH_AW_GITHUB_TOKEN to the same PAT. Prefer a separate least-privilege
    token for GH_AW_GITHUB_TOKEN unless you intentionally want reuse.

.PARAMETER Silent
    Non-interactive mode. Requires -Token.

.PARAMETER SkipPermissionValidation
    Skip live Copilot API permission validation before setting secrets.

.EXAMPLE
    pwsh scripts/bootstrap-copilot-github-token.ps1

.EXAMPLE
    $t = Read-Host "PAT" -AsSecureString
    pwsh scripts/bootstrap-copilot-github-token.ps1 -Repo "ivegamsft/basecoat" -Token $t
#>

[CmdletBinding()]
param(
    [string]$Repo,
    [securestring]$Token,
    [switch]$AlsoSetGhAwGithubToken,
    [switch]$Silent,
    [switch]$SkipPermissionValidation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Ok([string]$m) { Write-Host "✅ $m" -ForegroundColor Green }
function Write-Warn([string]$m) { Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Fail([string]$m) { Write-Host "❌ $m" -ForegroundColor Red }

function Get-HttpStatusCodeFromException([System.Exception]$Exception) {
    if ($Exception -and $Exception.PSObject.Properties.Match('Response').Count -gt 0 -and $Exception.Response) {
        return [int]$Exception.Response.StatusCode
    }
    return $null
}

function Test-CopilotTokenPermission([string]$PlainToken) {
    $headers = @{
        Authorization = "Bearer $PlainToken"
        Accept        = 'application/json'
    }

    try {
        # /models is a lightweight Copilot API auth check for token + Copilot access.
        $null = Invoke-RestMethod -Method Get -Uri 'https://api.githubcopilot.com/models' -Headers $headers -TimeoutSec 20
        return @{
            Ok      = $true
            Message = "Copilot API validation succeeded (token accepted)."
            Code    = 200
        }
    } catch {
        $statusCode = Get-HttpStatusCodeFromException $_.Exception
        if ($statusCode -eq 401 -or $statusCode -eq 403) {
            return @{
                Ok      = $false
                Message = "Copilot API rejected the token (HTTP $statusCode). Ensure fine-grained PAT with Account permission 'Copilot Requests: Read' and active Copilot access."
                Code    = $statusCode
            }
        }
        return @{
            Ok      = $false
            Message = "Copilot API validation failed before setting secrets: $($_.Exception.Message)"
            Code    = $statusCode
        }
    }
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required."
}

$authStatus = gh auth status 2>&1 | Out-String
if ($authStatus -notmatch 'Logged in') {
    throw "gh is not authenticated. Run 'gh auth login' first."
}

if (-not $Repo) {
    $remoteUrl = git config --get remote.origin.url 2>$null
    if (-not $remoteUrl) {
        throw "Could not infer repository from origin remote. Pass -Repo owner/name."
    }
    $Repo = ($remoteUrl -replace '.*github\.com[:/]' -replace '\.git$')
}

if (-not $Token) {
    if ($Silent) {
        throw "-Silent requires -Token."
    }
    $Token = Read-Host "Enter PAT for COPILOT_GITHUB_TOKEN" -AsSecureString
}

$tokenPtr = [IntPtr]::Zero
try {
    $tokenPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
    $tokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPtr)

    if ([string]::IsNullOrWhiteSpace($tokenPlain)) {
        throw "Token cannot be empty."
    }

    if (-not $SkipPermissionValidation) {
        $validation = Test-CopilotTokenPermission -PlainToken $tokenPlain
        if (-not $validation.Ok) {
            throw $validation.Message
        }
        Write-Ok $validation.Message
    } else {
        Write-Warn "Skipped live Copilot API permission validation."
    }

    $tokenPlain | gh secret set COPILOT_GITHUB_TOKEN --repo $Repo
    if ($LASTEXITCODE -ne 0) {
        throw "Failed setting COPILOT_GITHUB_TOKEN on $Repo."
    }
    Write-Ok "Set COPILOT_GITHUB_TOKEN on $Repo"

    if ($AlsoSetGhAwGithubToken) {
        $tokenPlain | gh secret set GH_AW_GITHUB_TOKEN --repo $Repo
        if ($LASTEXITCODE -ne 0) {
            throw "Failed setting GH_AW_GITHUB_TOKEN on $Repo."
        }
        Write-Warn "Set GH_AW_GITHUB_TOKEN using the same PAT (reuse mode)."
    } else {
        Write-Host "ℹ️  Recommended: use a separate PAT for GH_AW_GITHUB_TOKEN (least privilege)." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Next: run 'gh secret list --repo $Repo' to confirm secrets are present." -ForegroundColor DarkGray
}
finally {
    if ($tokenPtr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPtr)
    }
}
