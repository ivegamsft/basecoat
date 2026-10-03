[CmdletBinding()]
param(
    [switch]$Check
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$installer = Join-Path $PSScriptRoot 'dogfood-install.ps1'
& pwsh -NoProfile -File $installer -RootDir $repoRoot -Check:$Check
exit $LASTEXITCODE
