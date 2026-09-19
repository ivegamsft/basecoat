[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$validator = Join-Path $repoRoot "scripts\ship-it\validate-target-repository.ps1"
$dispatch = Join-Path $repoRoot "scripts\ship-it\dispatch-intent.ps1"

if (-not (Test-Path $validator)) {
  throw "Missing target repository validator: $validator"
}

$sameRepo = & pwsh -NoProfile -File $validator -TargetRepo "IBuySpy-Shared/basecoat" | ConvertFrom-Json
if ($sameRepo.cross_repository) {
  throw "Same-repository validation incorrectly reported a cross-repository target."
}

$mismatchOutput = & pwsh -NoProfile -File $validator -TargetRepo "IBuySpy-Shared/basecoat-memory" 2>&1
if ($LASTEXITCODE -eq 0 -or ($mismatchOutput -join "`n") -notmatch "Cross-repository dispatch requires explicit") {
  throw "Mismatched repository should fail closed without explicit authorization."
}

$crossRepo = & pwsh -NoProfile -File $validator -TargetRepo "IBuySpy-Shared/basecoat-memory" -AllowCrossRepository | ConvertFrom-Json
if (-not $crossRepo.cross_repository -or -not $crossRepo.authorized) {
  throw "Explicit cross-repository authorization should be reported as authorized."
}

$dispatchContent = Get-Content -Raw -Path $dispatch
foreach ($requiredText in @(
  "validate-target-repository.ps1",
  "AllowCrossRepository",
  "target repository validator"
)) {
  if ($dispatchContent -notmatch [regex]::Escape($requiredText)) {
    throw "Dispatch script is missing repository-boundary contract text: $requiredText"
  }
}

Write-Host "Ship-it target repository tests passed."
