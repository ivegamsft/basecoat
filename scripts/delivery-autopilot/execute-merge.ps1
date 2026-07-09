[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidatePattern("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")]
  [string]$Repo,

  [Parameter(Mandatory)]
  [int]$PullRequestNumber,

  [ValidateSet("merge", "squash", "rebase")]
  [string]$Method = "squash",

  [switch]$DeleteBranch,
  [switch]$DryRun,
  [string]$OutputPath = "test-results\delivery-autopilot\merge-result.json"
)

$ErrorActionPreference = "Stop"

function Write-JsonOutput {
  param([object]$Data, [string]$Path)
  $fullPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
  $directory = Split-Path -Path $fullPath -Parent
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $Data | ConvertTo-Json -Depth 10 | Set-Content -Path $fullPath -Encoding utf8
}

$commandArgs = @("pr", "merge", "$PullRequestNumber", "--repo", $Repo, "--$Method")
if ($DeleteBranch) {
  $commandArgs += "--delete-branch"
}

if ($DryRun) {
  $result = [ordered]@{
    mode = "dry-run"
    generated_at = "dry-run-static"
    repo = $Repo
    pr_number = $PullRequestNumber
    method = $Method
    delete_branch = [bool]$DeleteBranch
    action = "would-merge"
    command = "gh " + ($commandArgs -join " ")
  }
  Write-JsonOutput -Data $result -Path $OutputPath
  $result | ConvertTo-Json -Depth 10 | Write-Output
  exit 0
}

$output = & gh @commandArgs 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Merge command failed: $output"
}

$result = [ordered]@{
  mode = "live"
  generated_at = (Get-Date).ToUniversalTime().ToString("o")
  repo = $Repo
  pr_number = $PullRequestNumber
  method = $Method
  delete_branch = [bool]$DeleteBranch
  action = "merged"
  command = "gh " + ($commandArgs -join " ")
  output = ($output -join "`n")
}

Write-JsonOutput -Data $result -Path $OutputPath
$result | ConvertTo-Json -Depth 10 | Write-Output
