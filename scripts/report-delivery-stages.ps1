param(
    [Parameter(Mandatory)][string]$Repository,
    [Parameter(Mandatory)][string[]]$Start,
    [Parameter(Mandatory)][string[]]$End,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$FixturePath,
    [int]$MaxRequests = 2000,
    [double]$FanoutThreshold = 0.25,
    [double]$CancellationThreshold = 0.10
)

$ErrorActionPreference = 'Stop'
$Start = @($Start | ForEach-Object { $_ -split ',' })
$End = @($End | ForEach-Object { $_ -split ',' })
if ($Start.Count -ne 2 -or $End.Count -ne 2) {
    throw 'Provide two Start and End values, as arrays or quoted comma-separated UTC timestamps.'
}
$arguments = @((Join-Path $PSScriptRoot 'metrics\delivery_report.py'),
    '--repository', $Repository, '--start') + $Start + @('--end') + $End +
    @('--output', $OutputPath, '--max-requests', $MaxRequests,
      '--fanout-threshold', $FanoutThreshold, '--cancellation-threshold', $CancellationThreshold)
if ($FixturePath) { $arguments += @('--fixture', $FixturePath) }
& python @arguments
exit $LASTEXITCODE
