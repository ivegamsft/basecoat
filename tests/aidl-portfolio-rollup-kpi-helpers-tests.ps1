$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$helpersPath = Join-Path $repoRoot 'scripts\aidl-portfolio-rollup-kpi-helpers.ps1'

Write-Host 'Running AIDL portfolio rollup helper tests...'

if (-not (Test-Path $helpersPath)) {
    throw "Missing helper script: $helpersPath"
}

. $helpersPath

# Get-LabelNames returns an array (never a bare null) even for an unlabeled item.
$noLabels = Get-LabelNames -Item ([pscustomobject]@{ labels = @() })
if ($null -eq $noLabels) {
    throw 'Get-LabelNames should return an empty array, not null, for an unlabeled item.'
}
if (@($noLabels).Count -ne 0) {
    throw "Expected 0 labels for an unlabeled item, got $(@($noLabels).Count)."
}

$missingLabels = Get-LabelNames -Item ([pscustomobject]@{ })
if ($null -eq $missingLabels -or @($missingLabels).Count -ne 0) {
    throw 'Get-LabelNames should return an empty array when the labels property is absent.'
}

$labelled = Get-LabelNames -Item ([pscustomobject]@{ labels = @(
    [pscustomobject]@{ name = 'Sprint:41' },
    [pscustomobject]@{ name = 'blocked' },
    [pscustomobject]@{ name = '' },
    $null
) })
if (@($labelled).Count -ne 2) {
    throw "Expected 2 usable labels (blank/null skipped), got $(@($labelled).Count)."
}
if ($labelled -notcontains 'sprint:41' -or $labelled -notcontains 'blocked') {
    throw 'Get-LabelNames should lowercase and retain non-blank label names.'
}

# Test-AnyLabelMatch must tolerate the null/empty output of Get-LabelNames without throwing.
if (Test-AnyLabelMatch -Labels $null -Patterns @('^blocked$')) {
    throw 'Test-AnyLabelMatch should return false for null labels.'
}
if (Test-AnyLabelMatch -Labels @() -Patterns @('^blocked$')) {
    throw 'Test-AnyLabelMatch should return false for an empty label set.'
}
if (-not (Test-AnyLabelMatch -Labels @('blocked') -Patterns @('^blocked$'))) {
    throw 'Test-AnyLabelMatch should match a present label.'
}
if (-not (Test-AnyLabelMatch -Labels (Get-LabelNames -Item ([pscustomobject]@{ labels = @([pscustomobject]@{ name = 'sprint:41' }) })) -Patterns @('^sprint:\d+$'))) {
    throw 'Test-AnyLabelMatch should match a sprint label produced by Get-LabelNames.'
}
if (Test-AnyLabelMatch -Labels @('enhancement') -Patterns @('^blocked$', '^risk:high$')) {
    throw 'Test-AnyLabelMatch should return false when no pattern matches.'
}

# A regression guard for the reported failure: piping an unlabeled item through both helpers
# (as the live collection path does) must not throw a null-binding error.
$unlabeledItem = [pscustomobject]@{ labels = @() }
$result = Test-AnyLabelMatch -Labels (Get-LabelNames -Item $unlabeledItem) -Patterns @('^blocked$')
if ($result -ne $false) {
    throw 'Unlabeled item should not match, and must not throw a null-binding error.'
}

Write-Host 'AIDL portfolio rollup helper tests passed' -ForegroundColor Green
exit 0
