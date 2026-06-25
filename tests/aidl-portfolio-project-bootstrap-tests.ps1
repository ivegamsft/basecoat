$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running AIDL portfolio project bootstrap tests...'

$scriptPath = Join-Path $repoRoot 'scripts\aidl-portfolio-project-bootstrap.ps1'
$manifestPath = Join-Path $repoRoot 'docs\specs\aidl-portfolio\project-bootstrap-manifest.json'
$schemaPath = Join-Path $repoRoot 'docs\specs\aidl-portfolio\project-bootstrap-manifest.schema.json'
$guidePath = Join-Path $repoRoot 'docs\guides\aidl-portfolio-project-bootstrap.md'

foreach ($requiredPath in @($scriptPath, $manifestPath, $schemaPath, $guidePath)) {
    if (-not (Test-Path $requiredPath)) {
        throw "Missing required artifact: $requiredPath"
    }
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-bootstrap-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $statePath = Join-Path $tempDir 'project-state.json'
    $dryRunJson = Join-Path $tempDir 'dry-run-report.json'
    $dryRunMd = Join-Path $tempDir 'dry-run-report.md'
    $validateJson = Join-Path $tempDir 'validate-report.json'
    $validateMd = Join-Path $tempDir 'validate-report.md'
    $validateAdvisoryJson = Join-Path $tempDir 'validate-advisory-report.json'
    $validateAdvisoryMd = Join-Path $tempDir 'validate-advisory-report.md'
    $applyJson = Join-Path $tempDir 'apply-report.json'
    $applyMd = Join-Path $tempDir 'apply-report.md'
    $secondApplyJson = Join-Path $tempDir 'apply2-report.json'
    $secondApplyMd = Join-Path $tempDir 'apply2-report.md'
    $alignedStatePath = Join-Path $tempDir 'aligned-state.json'
    $validateAlignedJson = Join-Path $tempDir 'validate-aligned-report.json'
    $validateAlignedMd = Join-Path $tempDir 'validate-aligned-report.md'

    @'
{
  "fields": [
    {
      "name": "Status",
      "type": "single_select",
      "options": ["Backlog", "Ready", "In Progress", "Done"]
    },
    {
      "name": "Type",
      "type": "single_select",
      "options": ["Feature", "Bug"]
    }
  ],
  "views": [
    {
      "name": "Backlog",
      "layout": "TABLE",
      "groupBy": "Status"
    }
  ],
  "rules": [
    {
      "id": "rule-label-to-risk-sync",
      "name": "Legacy risk sync"
    }
  ]
}
'@ | Set-Content -Path $statePath -Encoding UTF8

    Write-Host '  Running validate mode (drift expected)...'
    & pwsh -NoProfile -File $scriptPath `
        -ManifestPath $manifestPath `
        -Mode validate `
        -CurrentStatePath $statePath `
        -JsonReportPath $validateJson `
        -MarkdownReportPath $validateMd

    if ($LASTEXITCODE -eq 0) {
        throw 'Validate mode should fail when drift exists'
    }

    $validateReport = Get-Content $validateJson -Raw | ConvertFrom-Json -Depth 100
    if ($validateReport.conformanceMode -ne 'enforce') {
        throw "Validate report conformanceMode expected 'enforce', got '$($validateReport.conformanceMode)'"
    }
    if ($validateReport.summary.remediationIssues -lt 1) {
        throw 'Validate report expected remediation issue payloads'
    }
    $hasCritical = @($validateReport.findings | Where-Object { $_.severity -eq 'critical' }).Count -ge 1
    if (-not $hasCritical) {
        throw 'Validate report expected at least one critical severity drift finding'
    }

    Write-Host '  Running validate mode (advisory)...'
    & pwsh -NoProfile -File $scriptPath `
        -ManifestPath $manifestPath `
        -Mode validate `
        -ConformanceMode advisory `
        -CurrentStatePath $statePath `
        -JsonReportPath $validateAdvisoryJson `
        -MarkdownReportPath $validateAdvisoryMd

    if ($LASTEXITCODE -ne 0) {
        throw 'Validate advisory mode should not fail when drift exists'
    }
    $validateAdvisoryReport = Get-Content $validateAdvisoryJson -Raw | ConvertFrom-Json -Depth 100
    if ($validateAdvisoryReport.conformanceMode -ne 'advisory') {
        throw "Validate advisory report conformanceMode expected 'advisory', got '$($validateAdvisoryReport.conformanceMode)'"
    }

    Write-Host '  Running dry-run mode...'
    & pwsh -NoProfile -File $scriptPath `
        -ManifestPath $manifestPath `
        -Mode dry-run `
        -CurrentStatePath $statePath `
        -JsonReportPath $dryRunJson `
        -MarkdownReportPath $dryRunMd

    if ($LASTEXITCODE -ne 0) {
        throw 'Dry-run execution failed'
    }

    if (-not (Test-Path $dryRunJson) -or -not (Test-Path $dryRunMd)) {
        throw 'Dry-run did not emit both json and markdown reports'
    }

    $dryRunReport = Get-Content $dryRunJson -Raw | ConvertFrom-Json -Depth 100
    if ($dryRunReport.summary.plannedCreates -lt 1) {
        throw 'Dry-run expected at least one planned create action'
    }
    if ($dryRunReport.findings.Count -lt 1) {
        throw 'Dry-run expected at least one mismatch finding for existing partial state'
    }
    $hasRuleNameMismatch = @($dryRunReport.findings | Where-Object { $_.id -eq 'RULE_NAME_MISMATCH' }).Count -eq 1
    if (-not $hasRuleNameMismatch) {
        throw 'Dry-run expected rule mismatch finding when rule name drifts from manifest'
    }

    Write-Host '  Running first apply mode...'
    & pwsh -NoProfile -File $scriptPath `
        -ManifestPath $manifestPath `
        -Mode apply `
        -CurrentStatePath $statePath `
        -JsonReportPath $applyJson `
        -MarkdownReportPath $applyMd

    if ($LASTEXITCODE -ne 0) {
        throw 'First apply execution failed'
    }

    $applyReport = Get-Content $applyJson -Raw | ConvertFrom-Json -Depth 100
    if ($applyReport.summary.appliedCreates -lt 1) {
        throw 'First apply expected to apply at least one additive create'
    }

    $updatedState = Get-Content $statePath -Raw | ConvertFrom-Json -Depth 100
    $hasRoadmapView = @($updatedState.views | Where-Object { $_.name -eq 'Roadmap' }).Count -eq 1
    if (-not $hasRoadmapView) {
        throw 'Apply mode did not persist expected missing view into state snapshot'
    }

    Write-Host '  Running second apply mode for idempotency...'
    & pwsh -NoProfile -File $scriptPath `
        -ManifestPath $manifestPath `
        -Mode apply `
        -CurrentStatePath $statePath `
        -JsonReportPath $secondApplyJson `
        -MarkdownReportPath $secondApplyMd

    if ($LASTEXITCODE -ne 0) {
        throw 'Second apply execution failed'
    }

    $secondApplyReport = Get-Content $secondApplyJson -Raw | ConvertFrom-Json -Depth 100
    if ($secondApplyReport.summary.plannedCreates -ne 0) {
        throw "Second apply should be idempotent (plannedCreates expected 0, got $($secondApplyReport.summary.plannedCreates))"
    }
    if ($secondApplyReport.summary.appliedCreates -ne 0) {
        throw "Second apply should be idempotent (appliedCreates expected 0, got $($secondApplyReport.summary.appliedCreates))"
    }

    Write-Host '  Running validate mode against aligned state...'
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 100
    [pscustomobject]@{
        fields = @($manifest.fields)
        views = @($manifest.views)
        rules = @($manifest.rules)
    } | ConvertTo-Json -Depth 100 | Set-Content -Path $alignedStatePath -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -ManifestPath $manifestPath `
        -Mode validate `
        -CurrentStatePath $alignedStatePath `
        -JsonReportPath $validateAlignedJson `
        -MarkdownReportPath $validateAlignedMd

    if ($LASTEXITCODE -ne 0) {
        throw 'Validate mode should pass when state is fully aligned with manifest'
    }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'AIDL portfolio project bootstrap tests passed' -ForegroundColor Green
exit 0
