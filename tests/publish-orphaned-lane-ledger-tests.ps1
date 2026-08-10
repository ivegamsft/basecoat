#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$publisherPath = Join-Path $repoRoot '.github\base-coat\scripts\publish-orphaned-lane-ledger.ps1'
$testRoot = Join-Path $repoRoot ('test-results\lane-ledger-mutations-' + [Guid]::NewGuid().ToString('N'))
$fakeBin = Join-Path $testRoot 'bin'
$originalPath = $env:PATH
$originalListJson = $env:FAKE_GH_LIST_JSON
$originalFailTarget = $env:FAKE_GH_FAIL_TARGET
$originalLogPath = $env:FAKE_GH_LOG_PATH

function New-Ledger {
    param(
        [string]$Path,
        [switch]$WithOrphan
    )

    $lanes = if ($WithOrphan) {
        @(
            [pscustomobject]@{
                lane = 'feat/retained'
                source = 'remote'
                state = 'stale-unmerged'
                terminalState = 'PARKED'
                action = 'retained'
                prNumber = $null
                owner = 'owner'
                ageDays = 45
                nextAction = 'Recover retained WIP.'
            }
        )
    }
    else {
        @()
    }

    [pscustomobject]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        lanes = $lanes
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding utf8
}

function Invoke-FailureCase {
    param(
        [string]$Name,
        [switch]$WithOrphan,
        [object[]]$ExistingIssues,
        [string]$FailTarget,
        [string]$ExpectedContext,
        [string]$ForbiddenSuccess
    )

    $caseRoot = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $ledgerPath = Join-Path $caseRoot 'ledger.json'
    $bodyPath = Join-Path $caseRoot 'issue.md'
    $logPath = Join-Path $caseRoot 'gh.log'
    New-Ledger -Path $ledgerPath -WithOrphan:$WithOrphan
    $env:FAKE_GH_LIST_JSON = @($ExistingIssues) | ConvertTo-Json -Depth 5 -Compress
    $env:FAKE_GH_FAIL_TARGET = $FailTarget
    $env:FAKE_GH_LOG_PATH = $logPath

    $output = & pwsh -NoProfile -File $publisherPath -LedgerPath $ledgerPath -BodyPath $bodyPath 2>&1
    $exitCode = $LASTEXITCODE
    $outputText = $output -join "`n"
    if ($exitCode -eq 0) {
        throw "$Name must fail when gh mutation '$FailTarget' fails"
    }
    if ($outputText -notmatch [regex]::Escape($ExpectedContext)) {
        throw "$Name did not report actionable mutation context. Output: $outputText"
    }
    if ($ForbiddenSuccess -and $outputText -match [regex]::Escape($ForbiddenSuccess)) {
        throw "$Name printed success after a failed mutation"
    }
    if (-not (Test-Path $logPath) -or (Get-Content $logPath -Raw) -notmatch [regex]::Escape($FailTarget)) {
        throw "$Name did not execute the expected failing mutation"
    }
}

try {
    New-Item -ItemType Directory -Path $testRoot, $fakeBin -Force | Out-Null
    @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
$operation = if ($Arguments.Count -ge 2) { $Arguments[1] } else { '' }
$target = if ($operation -eq 'create') { 'create' } elseif ($Arguments.Count -ge 3) { "$operation`:$($Arguments[2])" } else { $operation }
if ($env:FAKE_GH_LOG_PATH) {
    Add-Content -Path $env:FAKE_GH_LOG_PATH -Value $target
}
if ($operation -eq 'list') {
    [Console]::Out.WriteLine($env:FAKE_GH_LIST_JSON)
    exit 0
}
if ($target -eq $env:FAKE_GH_FAIL_TARGET) {
    [Console]::Error.WriteLine("simulated gh failure for $target")
    exit 42
}
[Console]::Out.WriteLine('https://example.test/success')
'@ | Set-Content -Path (Join-Path $fakeBin 'fake-gh.ps1')
    Set-Content -Path (Join-Path $fakeBin 'gh.cmd') -Value '@pwsh -NoProfile -File "%~dp0fake-gh.ps1" %*'
    @'
#!/usr/bin/env bash
exec pwsh -NoProfile -File "$(dirname "$0")/fake-gh.ps1" "$@"
'@ | Set-Content -Path (Join-Path $fakeBin 'gh') -NoNewline
    if (-not $IsWindows) {
        chmod +x (Join-Path $fakeBin 'gh')
    }
    $env:PATH = "$fakeBin$([IO.Path]::PathSeparator)$originalPath"

    $markerBody = '<!-- basecoat-orphaned-lane-ledger -->'
    Invoke-FailureCase `
        -Name 'zero-orphan-close' `
        -ExistingIssues @([pscustomobject]@{ number = 10; title = 'Orphaned lane ledger'; body = $markerBody }) `
        -FailTarget 'close:10' `
        -ExpectedContext 'Failed to close resolved orphaned-lane issue #10' `
        -ForbiddenSuccess 'No retained orphaned lanes require an issue.'

    Invoke-FailureCase `
        -Name 'existing-issue-edit' `
        -WithOrphan `
        -ExistingIssues @([pscustomobject]@{ number = 20; title = 'Orphaned lane ledger'; body = $markerBody }) `
        -FailTarget 'edit:20' `
        -ExpectedContext 'Failed to update orphaned-lane issue #20' `
        -ForbiddenSuccess 'Updated orphaned-lane issue #20.'

    Invoke-FailureCase `
        -Name 'duplicate-close' `
        -WithOrphan `
        -ExistingIssues @(
            [pscustomobject]@{ number = 30; title = 'Orphaned lane ledger'; body = $markerBody }
            [pscustomobject]@{ number = 31; title = 'Orphaned lane ledger duplicate'; body = $markerBody }
        ) `
        -FailTarget 'close:31' `
        -ExpectedContext 'Failed to close duplicate orphaned-lane issue #31'

    Invoke-FailureCase `
        -Name 'new-issue-create' `
        -WithOrphan `
        -ExistingIssues @() `
        -FailTarget 'create' `
        -ExpectedContext "Failed to create orphaned-lane issue 'Orphaned lane ledger'"
}
finally {
    $env:PATH = $originalPath
    $env:FAKE_GH_LIST_JSON = $originalListJson
    $env:FAKE_GH_FAIL_TARGET = $originalFailTarget
    $env:FAKE_GH_LOG_PATH = $originalLogPath
    if (Test-Path $testRoot) {
        Remove-Item $testRoot -Recurse -Force
    }
}

Write-Host 'publish-orphaned-lane-ledger tests passed' -ForegroundColor Green
