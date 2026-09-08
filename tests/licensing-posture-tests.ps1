#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract tests for third-party content licensing posture.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$instructionPath = Join-Path $repoRoot 'instructions\basecoat-10-core-licensing-posture.instructions.md'

Write-Host 'Running licensing posture contract tests...'

$failures = @()
if (-not (Test-Path $instructionPath)) {
    $failures += 'missing licensing-posture instruction'
} else {
    $instruction = Get-Content $instructionPath -Raw
    foreach ($requiredText in @(
        'basecoat-owned',
        'public-reference',
        'open-source-compatible',
        'vendor-guidance',
        'restricted-standard',
        'unknown',
        'Paraphrase first',
        'cite-only',
        'THIRD-PARTY-NOTICES',
        'Reviewer Decision Record',
        'source_class:',
        'notice_required:',
        'copied restricted text',
        'missing attribution',
        'not legal advice'
    )) {
        if ($instruction -notmatch [regex]::Escape($requiredText)) {
            $failures += "licensing instruction missing '$requiredText'"
        }
    }
}

$reviewCases = @(
    @{
        Name = 'citation-only-restricted-standard'
        SourceClass = 'restricted-standard'
        Usage = 'cite-only'
        Attribution = $true
        NoticeRequired = $false
        NoticePresent = $false
        Expected = 'allow'
    },
    @{
        Name = 'copied-restricted-standard'
        SourceClass = 'restricted-standard'
        Usage = 'short-quote'
        Attribution = $true
        NoticeRequired = $false
        NoticePresent = $false
        Expected = 'block'
    },
    @{
        Name = 'vendor-paraphrase-with-citation'
        SourceClass = 'vendor-guidance'
        Usage = 'paraphrase'
        Attribution = $true
        NoticeRequired = $false
        NoticePresent = $false
        Expected = 'allow'
    },
    @{
        Name = 'vendor-paraphrase-without-citation'
        SourceClass = 'vendor-guidance'
        Usage = 'paraphrase'
        Attribution = $false
        NoticeRequired = $false
        NoticePresent = $false
        Expected = 'block'
    },
    @{
        Name = 'compatible-copy-with-notice'
        SourceClass = 'open-source-compatible'
        Usage = 'vendored-copy'
        Attribution = $true
        NoticeRequired = $true
        NoticePresent = $true
        Expected = 'allow'
    },
    @{
        Name = 'copied-content-without-notice'
        SourceClass = 'open-source-compatible'
        Usage = 'vendored-copy'
        Attribution = $true
        NoticeRequired = $true
        NoticePresent = $false
        Expected = 'block'
    }
)

function Get-ReviewDecision {
    param([hashtable]$Case)

    if ($Case.SourceClass -eq 'unknown') { return 'block' }
    if ($Case.SourceClass -eq 'restricted-standard' -and $Case.Usage -ne 'cite-only') { return 'block' }
    if ($Case.SourceClass -ne 'basecoat-owned' -and $Case.Usage -ne 'cite-only' -and -not $Case.Attribution) { return 'block' }
    if ($Case.NoticeRequired -and -not $Case.NoticePresent) { return 'block' }
    return 'allow'
}

foreach ($case in $reviewCases) {
    $actual = Get-ReviewDecision $case
    if ($actual -ne $case.Expected) {
        $failures += "$($case.Name) expected $($case.Expected), got $actual"
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Licensing posture contract FAILED.' -ForegroundColor Red
    foreach ($failure in $failures) {
        Write-Host "  - $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Licensing posture contract passed.' -ForegroundColor Green
