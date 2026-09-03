[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$manifestPath = Join-Path $repoRoot '.github\base-coat\workflows\workflow-ownership-manifest.json'
$installerPath = Join-Path $repoRoot 'scripts\configure-downstream-workflows.ps1'
$retirementPath = Join-Path $repoRoot 'scripts\retire-downstream-workflows.ps1'
$scratch = Join-Path $repoRoot 'test-results\workflow-ownership-tests'
$sourceDir = Join-Path $scratch 'source'
$destinationDir = Join-Path $scratch 'destination'
$syncSourceDir = Join-Path $scratch 'sync-source'
$syncConsumerDir = Join-Path $scratch 'sync-consumer'
$syncScriptPath = Join-Path $repoRoot 'sync.ps1'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

foreach ($path in @($manifestPath, $installerPath, $retirementPath, $syncScriptPath)) {
    Assert-True -Condition (Test-Path -LiteralPath $path -PathType Leaf) `
        -Message "Missing workflow ownership asset: $path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True -Condition ($manifest.schemaVersion -eq 1) `
    -Message 'Workflow ownership manifest must use schema version 1.'
Assert-True -Condition ($manifest.defaultOwnership -eq 'repo-owned') `
    -Message 'Unmarked workflows must default to repo-owned.'
Assert-True -Condition (@($manifest.workflows).Count -gt 0) `
    -Message 'Workflow ownership manifest must mark factory-owned workflows.'
Assert-True -Condition (@($manifest.workflows | Where-Object { $_.ownership -ne 'factory-owned' }).Count -eq 0) `
    -Message 'Workflow ownership manifest may only explicitly mark factory-owned workflows.'

foreach ($requiredFactoryWorkflow in @(
        'basecoat-secret-scan.yml',
        'ship-it-intent-dispatch.yml',
        'basecoat-internal-database-ci-cd.yml'
    )) {
    Assert-True -Condition (@($manifest.workflows | Where-Object { $_.file -eq $requiredFactoryWorkflow }).Count -eq 1) `
        -Message "Workflow ownership manifest must mark $requiredFactoryWorkflow as factory-owned."
}

try {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $sourceDir, $destinationDir -Force | Out-Null

    New-Item -ItemType Directory -Force -Path @(
        (Join-Path $syncSourceDir '.github\base-coat\workflows'),
        (Join-Path $syncSourceDir 'scripts'),
        (Join-Path $syncSourceDir 'agents'),
        (Join-Path $syncSourceDir 'instructions'),
        (Join-Path $syncSourceDir 'prompts'),
        (Join-Path $syncSourceDir 'skills'),
        (Join-Path $syncSourceDir 'templates'),
        (Join-Path $syncSourceDir 'docs\reference'),
        (Join-Path $syncSourceDir 'docs\guides'),
        $syncConsumerDir
    ) | Out-Null
    '# Sync source' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'README.md') -Encoding utf8NoBOM
    '# Changelog' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'CHANGELOG.md') -Encoding utf8NoBOM
    '{"version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'version.json') -Encoding utf8NoBOM
    '{"schemaVersion":"1","assets":[]}' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'asset-manifest.json') -Encoding utf8NoBOM
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $syncSourceDir '.github\base-coat\workflows\workflow-ownership-manifest.json')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\workflow-ownership.ps1') -Destination (Join-Path $syncSourceDir 'scripts\workflow-ownership.ps1')
    Copy-Item -LiteralPath $retirementPath -Destination (Join-Path $syncSourceDir 'scripts\retire-downstream-workflows.ps1')
    git -C $syncSourceDir init -q -b main
    git -C $syncSourceDir config user.name 'basecoat-test'
    git -C $syncSourceDir config user.email 'basecoat-test@example.com'
    git -C $syncSourceDir add -A
    git -C $syncSourceDir commit -qm 'seed ownership distribution fixture'
    git -C $syncConsumerDir init -q -b main
    git -C $syncConsumerDir config user.name 'basecoat-test'
    git -C $syncConsumerDir config user.email 'basecoat-test@example.com'
    '# Consumer' | Set-Content -LiteralPath (Join-Path $syncConsumerDir 'README.md') -Encoding utf8NoBOM
    git -C $syncConsumerDir add README.md
    git -C $syncConsumerDir commit -qm 'seed consumer'

    Push-Location $syncConsumerDir
    try {
        $env:BASECOAT_REPO = "file://$syncSourceDir"
        $env:BASECOAT_REF = 'main'
        & pwsh -NoProfile -File $syncScriptPath | Out-Null
        Assert-True -Condition ($LASTEXITCODE -eq 0) `
            -Message 'Sync must distribute the workflow ownership guard assets.'
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO, Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        Pop-Location
    }

    foreach ($distributedPath in @(
            '.github\base-coat\workflows\workflow-ownership-manifest.json',
            '.github\base-coat\scripts\workflow-ownership.ps1',
            '.github\base-coat\scripts\retire-downstream-workflows.ps1'
        )) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $syncConsumerDir $distributedPath) -PathType Leaf) `
            -Message "Sync must distribute workflow ownership asset: $distributedPath"
    }

    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $sourceDir 'workflow-ownership-manifest.json')
    @'
name: "BaseCoat - Secret Scanning (warn only)"
on:
  workflow_dispatch:
jobs:
  scan:
    runs-on: ubuntu-latest
'@ | Set-Content -LiteralPath (Join-Path $sourceDir 'secret-scan.yml') -Encoding utf8NoBOM

    'repo-owned ci workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'ci.yml') -Encoding utf8NoBOM
    'locally maintained workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'basecoat-custom-ci.yml') -Encoding utf8NoBOM
    'legacy factory workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'bc-secret-scan.yml') -Encoding utf8NoBOM
    'factory workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'basecoat-secret-scan.yml') -Encoding utf8NoBOM

    $rejectedOutput = & pwsh -NoProfile -File $retirementPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -Workflow ci.yml 2>&1 | Out-String
    Assert-True -Condition ($LASTEXITCODE -ne 0) `
        -Message 'Retirement guard must reject a repo-owned workflow.'
    Assert-True -Condition ($rejectedOutput -match 'Refusing to remove repository-owned workflow') `
        -Message 'Retirement guard must explain that unmarked workflows are repository-owned.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $destinationDir 'ci.yml')) `
        -Message 'Retirement guard must leave a repo-owned workflow in place.'

    & pwsh -NoProfile -File $retirementPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -Workflow basecoat-secret-scan.yml `
        -DryRun | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Dry-run retirement of a factory-owned workflow must succeed.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $destinationDir 'basecoat-secret-scan.yml')) `
        -Message 'Dry-run retirement must not remove the factory-owned workflow.'

    & pwsh -NoProfile -File $installerPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -InstallClass reusable | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Installer must complete when its ownership manifest is present.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $destinationDir 'bc-secret-scan.yml'))) `
        -Message 'Installer must retire a legacy workflow marked factory-owned.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $destinationDir 'basecoat-custom-ci.yml')) `
        -Message 'Installer must preserve an unmarked workflow even with a BaseCoat-like prefix.'

    & pwsh -NoProfile -File $retirementPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -Workflow basecoat-secret-scan.yml | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Retirement of a factory-owned workflow must succeed.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $destinationDir 'basecoat-secret-scan.yml'))) `
        -Message 'Retirement command must remove the approved factory-owned workflow.'

    Write-Host 'Workflow ownership tests passed.'
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
