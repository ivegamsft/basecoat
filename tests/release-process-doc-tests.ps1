$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$docPath = Join-Path $repoRoot 'docs\operations\release-process.md'

if (-not (Test-Path $docPath)) {
    throw "Release process doc not found: $docPath"
}

$content = Get-Content -Path $docPath -Raw
$requiredPatterns = @(
    '--repo IBuySpy-Shared/basecoat',
    'publish-to-production.yml',
    'should never be targeted directly'
)

foreach ($pattern in $requiredPatterns) {
    if ($content -notmatch [regex]::Escape($pattern)) {
        throw "Release process doc contract failed: missing '$pattern'"
    }
}

if ($content -match '--repo\s+ivegamsft/basecoat') {
    throw "Release process doc contract failed: manual release command targets production mirror repo"
}

Write-Host 'Release process doc tests passed'
