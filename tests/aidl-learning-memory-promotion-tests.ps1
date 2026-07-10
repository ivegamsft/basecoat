$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running AIDL learning-to-memory promotion pipeline tests...'

$scriptPath = Join-Path $repoRoot 'scripts\aidl-learning-memory-promotion.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$tempDir = Join-Path $repoRoot ("test-results\\aidl-learning-memory-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $inputPath = Join-Path $tempDir 'input.json'
    $outputDir = Join-Path $tempDir 'output'

    @'
[
  {
    "id": "incident-retry-guard",
    "sourceType": "incident",
    "category": "runbook",
    "title": "Retry storm due to missing circuit-breaker policy",
    "pattern": "Repeated retry storms occurred when downstream dependencies timed out without a breaker.",
    "resolution": "Apply bounded retries and circuit-breaker defaults in shared service templates.",
    "outcome": "Incident count dropped after mitigation rollout.",
    "evidence": [
      "https://github.com/ivegamsft/basecoat/issues/1701",
      "https://github.com/ivegamsft/basecoat/pull/1705"
    ],
    "recurrence": 4,
    "impact": 5,
    "affectedTeams": 3
  },
  {
    "id": "one-off-typo",
    "sourceType": "review",
    "category": "instruction",
    "title": "Single typo in release notes template",
    "pattern": "A one-time typo in release notes caused a lint warning.",
    "resolution": "Fix the typo directly in the template.",
    "outcome": "No recurrence observed.",
    "evidence": [
      "https://github.com/ivegamsft/basecoat/pull/1709"
    ],
    "recurrence": 1,
    "impact": 2,
    "affectedTeams": 1
  },
  {
    "id": "token-leak-note",
    "sourceType": "sprint",
    "category": "memory",
    "title": "Postmortem included temporary token",
    "pattern": "Temporary token EXAMPLE_TOKEN was pasted during triage.",
    "resolution": "Redact sensitive values and rotate credentials before publishing artifacts.",
    "outcome": "Artifact was sanitized before archival.",
    "evidence": [
      "https://github.com/ivegamsft/basecoat/issues/1712"
    ],
    "recurrence": 3,
    "impact": 4,
    "affectedTeams": 2
  },
  {
    "id": "qa-checklist-ordering",
    "sourceType": "review",
    "category": "skill",
    "title": "Review queues improve with standardized QA checklist order",
    "pattern": "Review latency decreases when QA checklist ordering is consistent across teams.",
    "resolution": "Publish and adopt one shared checklist sequence for review workflows.",
    "outcome": "Review cycle time trend improved but needs another sprint to confirm durability.",
    "evidence": [
      "https://github.com/ivegamsft/basecoat/issues/1715",
      "https://github.com/ivegamsft/basecoat/issues/1717"
    ],
    "recurrence": 2,
    "impact": 3,
    "affectedTeams": 2
  },
  {
    "id": "missing-evidence-candidate",
    "sourceType": "governance",
    "category": "policy",
    "title": "Waiver reviews need deterministic owner handoff",
    "pattern": "Waiver reviews regress when ownership handoff is undocumented.",
    "resolution": "Require owner handoff metadata before waiver approval.",
    "outcome": "Approval quality improved after adding handoff metadata.",
    "recurrence": 3,
    "impact": 4,
    "affectedTeams": 2
  }
]
'@ | Set-Content -Path $inputPath -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath `
        -InputPath $inputPath `
        -OutputDir $outputDir `
        -MinimumRecurrence 2 `
        -MinimumImpact 3 `
        -PromoteScoreThreshold 70 `
        -HoldScoreThreshold 45

    if ($LASTEXITCODE -ne 0) {
        throw 'Pipeline execution failed'
    }

    $summaryPath = Join-Path $outputDir 'candidate-summary.json'
    $packetPath = Join-Path $outputDir 'promotion-packets.json'
    $auditPath = Join-Path $outputDir 'promotion-audit-ledger.json'
    $adoptionPath = Join-Path $outputDir 'adoption-impact-tracking.json'
    $reportPath = Join-Path $outputDir 'promotion-report.md'

    foreach ($required in @($summaryPath, $packetPath, $auditPath, $adoptionPath, $reportPath)) {
        if (-not (Test-Path $required)) {
            throw "Missing pipeline output artifact: $required"
        }
    }

    $summary = Get-Content -Path $summaryPath -Raw | ConvertFrom-Json -Depth 100
    if ($summary.input_count -ne 5) {
        throw "Expected input_count=5, got $($summary.input_count)"
    }
    if ($summary.promote_count -ne 1) {
        throw "Expected promote_count=1, got $($summary.promote_count)"
    }
    if ($summary.hold_count -ne 1) {
        throw "Expected hold_count=1, got $($summary.hold_count)"
    }
    if ($summary.reject_count -ne 3) {
        throw "Expected reject_count=3, got $($summary.reject_count)"
    }

    $packets = @(Get-Content -Path $packetPath -Raw | ConvertFrom-Json -Depth 100)
    if ($packets.Count -ne 2) {
        throw "Expected two reviewable packets (promote + hold), got $($packets.Count)"
    }
    $hasRunbookRoute = @($packets | Where-Object { $_.route.target_path -eq 'docs/operations/' }).Count -eq 1
    if (-not $hasRunbookRoute) {
        throw 'Expected promoted incident candidate to route to docs/operations/'
    }
    $allSubjectsValid = @($packets | Where-Object { $_.subject -match '^[a-z][a-z-]+:[a-z][a-z0-9-]+$' }).Count -eq $packets.Count
    if (-not $allSubjectsValid) {
        throw 'Expected all packet subjects to satisfy domain:key memory contract'
    }

    $audit = @(Get-Content -Path $auditPath -Raw | ConvertFrom-Json -Depth 100)
    $sensitiveRejected = @($audit | Where-Object { $_.candidate_id -eq 'token-leak-note' -and $_.decision -eq 'reject' }).Count -eq 1
    if (-not $sensitiveRejected) {
        throw 'Expected sensitive candidate to be rejected in audit ledger'
    }
    $missingEvidenceRejected = @($audit | Where-Object { $_.candidate_id -eq 'missing-evidence-candidate' -and $_.decision -eq 'reject' }).Count -eq 1
    if (-not $missingEvidenceRejected) {
        throw 'Expected missing-evidence candidate to be rejected in audit ledger'
    }

    $adoption = @(Get-Content -Path $adoptionPath -Raw | ConvertFrom-Json -Depth 100)
    if ($adoption.Count -ne 1) {
        throw "Expected one adoption plan entry for promoted candidate, got $($adoption.Count)"
    }
    if ($adoption[0].metric -ne 'repeat_incident_rate') {
        throw "Expected incident adoption metric repeat_incident_rate, got $($adoption[0].metric)"
    }

    $report = Get-Content -Path $reportPath -Raw
    if ($report -notmatch '## Approval workflow') {
        throw 'Promotion report missing approval workflow section'
    }
    if ($report -notmatch '## Safeguard controls') {
        throw 'Promotion report missing safeguard controls section'
    }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'AIDL learning-to-memory promotion pipeline tests passed' -ForegroundColor Green
exit 0
