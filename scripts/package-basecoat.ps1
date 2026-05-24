$ErrorActionPreference = 'Stop'

$rootDir = if ($args.Count -gt 0) { $args[0] } else { (Get-Location).Path }
Set-Location $rootDir

$version = (Get-Content version.json -Raw | ConvertFrom-Json).version
if (-not $version) {
    throw 'Unable to determine version from version.json'
}

$distDir = Join-Path $rootDir 'dist'
$stageDir = Join-Path $distDir 'stage\base-coat'
$archiveBase = "base-coat-$version"

if (Test-Path $distDir) {
    Remove-Item -Path $distDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

# mkdocs.yml is excluded — it's a docs-site build config, not consumer guidance
foreach ($item in @('README.md', 'CHANGELOG.md', 'INVENTORY.md', 'version.json', 'asset-manifest.json', 'sync.sh', 'sync.ps1', 'instructions', 'skills', 'prompts', 'agents', 'scripts', '.githooks', 'docs', 'examples', '.github')) {
    if (Test-Path $item) {
        Copy-Item -Path $item -Destination (Join-Path $stageDir $item) -Recurse -Force
    }
}

# Exclude eval metadata from packaged install payloads
foreach ($evalRoot in @(
    (Join-Path $stageDir 'skills'),
    (Join-Path $stageDir 'agents')
)) {
    if (Test-Path $evalRoot) {
        Get-ChildItem -Path $evalRoot -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -eq 'eval.yaml' -or $_.Name -like '*.agent.eval.yaml'
        } | ForEach-Object {
            Remove-Item -Path $_.FullName -Force
        }
    }
}

# Verify no eval metadata leaked into staged payloads
$evalLeaks = @()
foreach ($evalRoot in @((Join-Path $stageDir 'skills'), (Join-Path $stageDir 'agents'))) {
    if (Test-Path $evalRoot) {
        $evalLeaks += Get-ChildItem -Path $evalRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'eval.yaml' -or $_.Name -like '*.agent.eval.yaml' }
    }
}
if ($evalLeaks.Count -gt 0) {
    $evalLeaks | ForEach-Object { Write-Error "Eval metadata leaked into stage: $($_.FullName)" }
    throw "Package validation failed: eval metadata found in staged artifacts"
}
Write-Host "✅ No eval metadata found in staged install artifacts"

$zipPath = Join-Path $distDir "$archiveBase.zip"
Compress-Archive -Path (Join-Path $distDir 'stage\base-coat\*') -DestinationPath $zipPath

$tarPath = Join-Path $distDir "$archiveBase.tar.gz"
tar -czf $tarPath -C (Join-Path $distDir 'stage') 'base-coat'

$zipChecksum = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$tarChecksum = (Get-FileHash $tarPath -Algorithm SHA256).Hash.ToLowerInvariant()

$checksumLines = @(
    "$zipChecksum  $(Split-Path $zipPath -Leaf)",
    "$tarChecksum  $(Split-Path $tarPath -Leaf)"
)
Set-Content -Path (Join-Path $distDir 'SHA256SUMS.txt') -Value $checksumLines

Write-Host "Packaged artifacts into $distDir"
