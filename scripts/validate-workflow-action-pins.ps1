[CmdletBinding()]
param(
    [string]$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [ValidateSet('Auto', 'Source', 'Installed')]
    [string]$Mode = 'Auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $RootDir).Path
$scannerPath = Join-Path $PSScriptRoot 'validate-workflow-action-pins.py'
if (-not (Test-Path $scannerPath -PathType Leaf)) {
    throw "Workflow action pin scanner is missing: $scannerPath"
}

function Find-Python3 {
    foreach ($commandName in @('python3', 'python')) {
        $candidate = Get-Command $commandName -ErrorAction SilentlyContinue
        if (-not $candidate) {
            continue
        }
        & $candidate.Source -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' *> $null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }
    return $null
}

$pythonCommand = Find-Python3
if (-not $pythonCommand) {
    throw 'Workflow action pin validation requires Python 3 (python or python3).'
}

& $pythonCommand.Source $scannerPath --root $resolvedRoot --mode $Mode.ToLowerInvariant()
if ($LASTEXITCODE -ne 0) {
    throw "Workflow action pin validation failed with exit code $LASTEXITCODE."
}
