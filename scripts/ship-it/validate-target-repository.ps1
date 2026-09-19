[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$TargetRepo,

  [switch]$AllowCrossRepository
)

$ErrorActionPreference = "Stop"

if ($TargetRepo -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
  throw "TargetRepo must be in owner/repo format."
}

function Normalize-Repository {
  param([Parameter(Mandatory)][string]$Repository)

  $normalized = $Repository.Trim().ToLowerInvariant()
  $normalized = $normalized -replace "^https?://(?:[^/@]+@)?github\.com/", ""
  $normalized = $normalized -replace "^git@github\.com:", ""
  $normalized = $normalized -replace "\.git$", ""
  return $normalized.TrimEnd("/")
}

$remoteUrl = (& git remote get-url origin 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteUrl)) {
  $hostRepo = $env:GITHUB_REPOSITORY
  if ([string]::IsNullOrWhiteSpace($hostRepo)) {
    throw "Cannot determine the current repository. Configure origin or GITHUB_REPOSITORY before dispatch."
  }
} else {
  $hostRepo = $remoteUrl.Trim()
}

$normalizedTarget = Normalize-Repository -Repository $TargetRepo
$normalizedHost = Normalize-Repository -Repository $hostRepo

if ($normalizedTarget -eq $normalizedHost) {
  [pscustomobject]@{
    target_repo = $TargetRepo
    current_repo = $hostRepo
    cross_repository = $false
    authorized = $true
  } | ConvertTo-Json -Compress
  exit 0
}

if (-not $AllowCrossRepository) {
  throw "Target repository '$TargetRepo' does not match current repository '$hostRepo'. Cross-repository dispatch requires explicit -AllowCrossRepository authorization."
}

[pscustomobject]@{
  target_repo = $TargetRepo
  current_repo = $hostRepo
  cross_repository = $true
  authorized = $true
} | ConvertTo-Json -Compress
