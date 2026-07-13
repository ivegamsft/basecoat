$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running AIDL incident routing verification tests...'

$scriptPath = Join-Path $repoRoot 'scripts\aidl-incident-routing-verification.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$tempDir = Join-Path $repoRoot ("test-results\aidl-incident-routing-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$caseIndex = 0
function Invoke-Audit {
    param(
        [string]$InputJson
    )

    $script:caseIndex++
    $inputPath = Join-Path $tempDir ("input-$script:caseIndex.json")
    $outputDir = Join-Path $tempDir ("output-$script:caseIndex")
    Set-Content -Path $inputPath -Value $InputJson -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath -InputPath $inputPath -OutputDir $outputDir 2>$null
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        throw "Case $script:caseIndex script run failed (exit $exit)."
    }

    $jsonPath = Join-Path $outputDir 'incident-routing-verification.json'
    $mdPath = Join-Path $outputDir 'incident-routing-verification.md'
    foreach ($required in @($jsonPath, $mdPath)) {
        if (-not (Test-Path $required)) {
            throw "Case $script:caseIndex missing expected artifact: $required"
        }
    }
    return [pscustomobject]@{
        Json = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json -Depth 100
        Markdown = Get-Content -Path $mdPath -Raw
    }
}

try {
    # --- Case 1: fully valid closed SEV1 incident -> overall pass, all metrics pass. ---
    $valid = @'
[
  {
    "incident_id": "INC-1001",
    "severity": "SEV1",
    "status": "closed",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T13:00:00Z",
    "owner": "oncall-a",
    "affected_service": "payments-api",
    "customer_impact": "checkout unavailable",
    "root_cause_summary": "connection pool exhaustion",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/1",
    "remediation_priority": "critical",
    "verification_artifact_url": "https://github.com/IBuySpy-Shared/basecoat/actions/runs/10",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $valid
    if ($r.Json.status -ne 'pass') { throw "Case 1: expected overall pass, got $($r.Json.status)" }
    if ($r.Json.metrics.routed_incidents_with_remediation_link.status -ne 'pass') { throw 'Case 1: linkage should pass.' }
    if ($r.Json.metrics.verified_closures_high_critical.status -ne 'pass') { throw 'Case 1: verification should pass.' }
    if ($r.Json.metrics.median_incident_to_remediation_creation_latency_business_days.status -ne 'pass') { throw 'Case 1: latency should pass.' }
    if ($r.Json.incidents[0].status -ne 'pass') { throw 'Case 1: incident should pass.' }
    if ($r.Json.incidents[0].priority_status -ne 'pass') { throw 'Case 1: aligned priority should pass.' }
    if ($r.Json.incidents[0].affected_service -ne 'payments-api') { throw 'Case 1: affected_service should be retained in the finding.' }
    if ($r.Json.incidents[0].recommended_priority -ne 'critical') { throw 'Case 1: recommended_priority for SEV1 should be critical.' }
    if ($r.Markdown -notmatch 'Service/Area') { throw 'Case 1: markdown findings table should include a Service/Area column.' }
    if ($r.Json.incidents[0].remediation_reference -ne 'https://github.com/IBuySpy-Shared/basecoat/issues/1') { throw 'Case 1: remediation reference should be retained in the finding.' }
    if ($r.Json.incidents[0].verification_reference -ne 'https://github.com/IBuySpy-Shared/basecoat/actions/runs/10') { throw 'Case 1: verification reference should be retained in the finding.' }

    # --- Case 2: placeholder remediation link ("n/a") is not a valid GitHub issue/PR. ---
    $placeholder = @'
[
  {
    "incident_id": "INC-2001",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "oncall-a",
    "affected_service": "search",
    "customer_impact": "degraded",
    "root_cause_summary": "",
    "remediation_issue_url": "n/a",
    "verification_artifact_url": "",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $placeholder
    if ($r.Json.incidents[0].remediation_linked -ne $false) { throw 'Case 2: "n/a" must not count as a remediation link.' }
    if ($r.Json.metrics.routed_incidents_with_remediation_link.status -ne 'fail') { throw 'Case 2: linkage should fail.' }
    if ($r.Json.status -ne 'fail') { throw 'Case 2: overall should fail.' }

    # --- Case 3: duplicate incident_id -> the duplicate record fails. ---
    $dup = @'
[
  {
    "incident_id": "INC-DUP",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/2",
    "repeat_without_prior_verification": false
  },
  {
    "incident_id": "INC-DUP",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/3",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $dup
    $dupRows = @($r.Json.incidents | Where-Object { $_.id_valid -eq $false })
    if ($dupRows.Count -ne 1) { throw "Case 3: expected exactly one duplicate-id fail, got $($dupRows.Count)." }
    if ($r.Json.status -ne 'fail') { throw 'Case 3: overall should fail on duplicate id.' }

    # --- Case 4: missing incident_id -> deterministic placeholder, incident fails. ---
    $missingId = @'
[
  {
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/4",
    "repeat_without_prior_verification": false
  }
]
'@
    $r1 = Invoke-Audit -InputJson $missingId
    $r2 = Invoke-Audit -InputJson $missingId
    if ($r1.Json.incidents[0].incident_id -ne 'MISSING-ID-1') { throw "Case 4: expected deterministic MISSING-ID-1, got $($r1.Json.incidents[0].incident_id)." }
    if ($r1.Json.incidents[0].incident_id -ne $r2.Json.incidents[0].incident_id) { throw 'Case 4: missing-id placeholder must be deterministic across runs.' }
    if ($r1.Json.incidents[0].status -ne 'fail') { throw 'Case 4: missing id should fail the incident.' }

    # --- Case 5: unknown severity must not silently pass. ---
    $unknownSev = @'
[
  {
    "incident_id": "INC-5001",
    "severity": "P0",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/5",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $unknownSev
    if ($r.Json.incidents[0].severity_valid -ne $false) { throw 'Case 5: P0 should be flagged as unknown severity.' }
    if ($r.Json.incidents[0].status -ne 'fail') { throw 'Case 5: unknown severity should fail the incident.' }

    # --- Case 6: reversed timestamps -> incident fails and latency fails closed (no valid sample). ---
    $reversed = @'
[
  {
    "incident_id": "INC-6001",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T12:00:00Z",
    "remediation_created_at": "2026-01-05T09:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/6",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $reversed
    if ($r.Json.incidents[0].timestamp_chronological -ne $false) { throw 'Case 6: reversed timestamps should be flagged.' }
    if ($r.Json.metrics.median_incident_to_remediation_creation_latency_business_days.status -ne 'fail') { throw 'Case 6: latency should fail closed when a remediation is expected but no valid sample exists.' }
    if ($r.Json.status -ne 'fail') { throw 'Case 6: overall should fail on reversed timestamps.' }

    # --- Case 7: closed SEV3 without a verification artifact must fail (verification required for every closure). ---
    $closedNoVerify = @'
[
  {
    "incident_id": "INC-7001",
    "severity": "SEV3",
    "status": "closed",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/7",
    "verification_artifact_url": "unknown",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $closedNoVerify
    if ($r.Json.incidents[0].verification_status -ne 'fail') { throw 'Case 7: closed incident with placeholder verification must fail verification.' }
    if ($r.Json.status -ne 'fail') { throw 'Case 7: overall should fail.' }

    # --- Case 8: markdown injection via pipe/newline in incident_id must be escaped. ---
    $injection = @'
[
  {
    "incident_id": "INC-8001 | evil | row",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/8",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $injection
    if ($r.Markdown -notmatch 'INC-8001 \\\| evil \\\| row') { throw 'Case 8: pipe characters in incident_id must be escaped in the markdown table.' }
    $findingsSection = ($r.Markdown -split '## Incident Findings')[1]
    $dataRows = @(($findingsSection -split "`n") | Where-Object { $_ -match '^\| INC-8001' })
    if ($dataRows.Count -ne 1) { throw "Case 8: expected exactly one rendered data row for the injected incident, got $($dataRows.Count)." }

    # --- Case 9: Friday-to-Monday remediation is one business day (not 72 hours). ---
    $businessDay = @'
[
  {
    "incident_id": "INC-9001",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-02T00:00:00Z",
    "remediation_created_at": "2026-01-05T00:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/9",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $businessDay
    if ([math]::Abs([double]$r.Json.incidents[0].latency_business_days - 1.0) -gt 0.01) { throw "Case 9: Friday-to-Monday should be 1.0 business day, got $($r.Json.incidents[0].latency_business_days)." }
    if ($r.Json.metrics.median_incident_to_remediation_creation_latency_business_days.status -ne 'pass') { throw 'Case 9: 1.0 business day should pass (not > 1).' }

    # --- Case 10: string-serialized boolean "false" must not score as a repeat. ---
    $stringBool = @'
[
  {
    "incident_id": "INC-1002",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/12",
    "repeat_without_prior_verification": "false"
  }
]
'@
    $r = Invoke-Audit -InputJson $stringBool
    if ($r.Json.incidents[0].repeat_without_prior_verification -ne $false) { throw 'Case 10: string "false" must parse as boolean false.' }
    if ($r.Json.metrics.repeat_incidents_without_prior_verification.value -ne 0) { throw 'Case 10: repeat count should be 0.' }

    # --- Case 11: markdown sections present. ---
    if ($r.Markdown -notmatch '## Metric Scorecard') { throw 'Case 11: markdown missing Metric Scorecard.' }
    if ($r.Markdown -notmatch '## Incident Findings') { throw 'Case 11: markdown missing Incident Findings.' }
    if ($r.Markdown -notmatch 'Threshold Contract') { throw 'Case 11: markdown missing Threshold Contract.' }

    # --- Case 12: an unrecognized status (typo) must not be treated as open and bypass controls. ---
    $badStatus = @'
[
  {
    "incident_id": "INC-1201",
    "severity": "SEV3",
    "status": "clsoed",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/13",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $badStatus
    if ($r.Json.incidents[0].status_valid -ne $false) { throw 'Case 12: typo status should be flagged invalid.' }
    if ($r.Json.incidents[0].status -ne 'fail') { throw 'Case 12: invalid status should fail the incident.' }

    # --- Case 13: a partial latency sample (one linked incident missing its timestamp) must fail closed. ---
    $partial = @'
[
  {
    "incident_id": "INC-1301",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/14",
    "repeat_without_prior_verification": false
  },
  {
    "incident_id": "INC-1302",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/15",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $partial
    $latencyMetric = $r.Json.metrics.median_incident_to_remediation_creation_latency_business_days
    if ($latencyMetric.expected_incidents -ne 2 -or $latencyMetric.sampled_incidents -ne 1) { throw "Case 13: expected 2 expected / 1 sampled, got $($latencyMetric.expected_incidents)/$($latencyMetric.sampled_incidents)." }
    if ($latencyMetric.status -ne 'fail') { throw 'Case 13: latency must fail closed when a sample is missing.' }

    # --- Case 14: business hours must split at midnight (Friday 23:30 -> Saturday 00:30 = 0.5 hours). ---
    $boundary = @'
[
  {
    "incident_id": "INC-1401",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-02T23:30:00Z",
    "remediation_created_at": "2026-01-03T00:30:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/16",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $boundary
    $boundaryLatency = [double]$r.Json.incidents[0].latency_business_days
    if ([math]::Abs($boundaryLatency - ([math]::Round(0.5 / 24.0, 3))) -gt 0.001) { throw "Case 14: Friday 23:30 to Saturday 00:30 should be 0.5 business hours ($([math]::Round(0.5/24.0,3)) days), got $boundaryLatency." }

    # --- Case 15: a malformed repeat flag must fail closed, not silently become false. ---
    $badBool = @'
[
  {
    "incident_id": "INC-1501",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/17",
    "repeat_without_prior_verification": "maybe"
  }
]
'@
    $r = Invoke-Audit -InputJson $badBool
    if ($r.Json.incidents[0].repeat_flag_valid -ne $false) { throw 'Case 15: malformed repeat flag should be flagged invalid.' }
    if ($r.Json.incidents[0].status -ne 'fail') { throw 'Case 15: malformed repeat flag should fail the incident.' }

    # --- Case 16: a lone carriage return in a cell must be collapsed (no injected row). ---
    $crInject = @'
[
  {
    "incident_id": "INC-1601\rInjected-Row",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/18",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $crInject
    $findingsSection = ($r.Markdown -split '## Incident Findings')[1]
    $injRows = @(($findingsSection -split "`r`n|`n|`r") | Where-Object { $_ -match '^\| INC-1601' })
    if ($injRows.Count -ne 1) { throw "Case 16: a lone CR must not inject an extra row; got $($injRows.Count) rows." }
    if ($injRows[0] -notmatch 'INC-1601 Injected-Row') { throw 'Case 16: the CR should be collapsed to a space within a single cell.' }

    # --- Case 17: remediation priority must align with incident severity. ---
    $misPriority = @'
[
  {
    "incident_id": "INC-1701",
    "severity": "SEV1",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "root_cause_summary": "rc",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/19",
    "remediation_priority": "low",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $misPriority
    if ($r.Json.incidents[0].priority_status -ne 'fail') { throw 'Case 17: a SEV1 incident with low remediation priority must fail priority alignment.' }
    if ($r.Json.incidents[0].status -ne 'fail') { throw 'Case 17: misaligned priority should fail the incident.' }

    # --- Case 17b: a routed incident with no remediation priority must fail (mandatory mapping). ---
    $missingPriority = @'
[
  {
    "incident_id": "INC-1702",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/20",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $missingPriority
    if ($r.Json.incidents[0].priority_status -ne 'fail') { throw 'Case 17b: a linked incident without a priority must fail priority alignment.' }
    if ($r.Json.incidents[0].status -ne 'fail') { throw 'Case 17b: missing priority should fail the incident.' }

    # --- Case 17c: exact severity-to-priority mapping (SEV2 -> high; SEV1 priority is not high). ---
    $exactWrong = @'
[
  {
    "incident_id": "INC-1703",
    "severity": "SEV2",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "root_cause_summary": "rc",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/21",
    "remediation_priority": "critical",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $exactWrong
    if ($r.Json.incidents[0].priority_status -ne 'fail') { throw 'Case 17c: SEV2 with priority critical must fail (expected high).' }
    $exactRight = @'
[
  {
    "incident_id": "INC-1704",
    "severity": "SEV2",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "root_cause_summary": "rc",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/22",
    "remediation_priority": "priority:high",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $exactRight
    if ($r.Json.incidents[0].priority_status -ne 'pass') { throw 'Case 17c: SEV2 with priority:high must pass.' }

    # --- Case 18: an OutputDir under a junction that resolves outside the repo must be rejected. ---
    if ($IsWindows) {
        $externalTarget = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-ext-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $externalTarget -Force | Out-Null
        $junctionPath = Join-Path $tempDir 'linked-out'
        $junctionCreated = $false
        try {
            New-Item -ItemType Junction -Path $junctionPath -Target $externalTarget -ErrorAction Stop | Out-Null
            $junctionCreated = $true
        } catch {
            $junctionCreated = $false
        }
        if ($junctionCreated) {
            $guardInput2 = Join-Path $tempDir 'guard-input-2.json'
            Set-Content -Path $guardInput2 -Value $valid -Encoding UTF8
            & pwsh -NoProfile -File $scriptPath -InputPath $guardInput2 -OutputDir (Join-Path $junctionPath 'out') 2>$null
            if ($LASTEXITCODE -eq 0) { throw 'Case 18: OutputDir under a junction resolving outside the repo must be rejected.' }
            Remove-Item -Path $junctionPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Item -Path $externalTarget -Recurse -Force -ErrorAction SilentlyContinue
    }

    # --- Case 18b: refuse to write through a pre-existing symlinked destination report file. ---
    $symOutputDir = Join-Path $tempDir 'sym-output'
    New-Item -ItemType Directory -Path $symOutputDir -Force | Out-Null
    $externalFile = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-extfile-" + [Guid]::NewGuid().ToString('N') + ".json")
    Set-Content -Path $externalFile -Value '{}' -Encoding UTF8
    $linkPath = Join-Path $symOutputDir 'incident-routing-verification.json'
    $symlinkCreated = $false
    try {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $externalFile -ErrorAction Stop | Out-Null
        $symlinkCreated = $true
    } catch {
        $symlinkCreated = $false
    }
    if ($symlinkCreated) {
        $symInput = Join-Path $tempDir 'sym-input.json'
        Set-Content -Path $symInput -Value $valid -Encoding UTF8
        & pwsh -NoProfile -File $scriptPath -InputPath $symInput -OutputDir $symOutputDir 2>$null
        if ($LASTEXITCODE -eq 0) { throw 'Case 18b: writing through a symlinked destination report file must be rejected.' }
        $externalContents = Get-Content -LiteralPath $externalFile -Raw
        if ($externalContents.Trim() -ne '{}') { throw 'Case 18b: the external symlink target must not be overwritten.' }
        Remove-Item -Path $linkPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $externalFile -Force -ErrorAction SilentlyContinue

    # --- Case 18c: a dangling symlink destination (missing target) must also be rejected. ---
    $danglingDir = Join-Path $tempDir 'dangling-output'
    New-Item -ItemType Directory -Path $danglingDir -Force | Out-Null
    $danglingTarget = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-missing-" + [Guid]::NewGuid().ToString('N') + ".json")
    $danglingLink = Join-Path $danglingDir 'incident-routing-verification.json'
    $danglingCreated = $false
    try {
        New-Item -ItemType SymbolicLink -Path $danglingLink -Target $danglingTarget -ErrorAction Stop | Out-Null
        $danglingCreated = $true
    } catch {
        $danglingCreated = $false
    }
    if ($danglingCreated) {
        $danglingInput = Join-Path $tempDir 'dangling-input.json'
        Set-Content -Path $danglingInput -Value $valid -Encoding UTF8
        & pwsh -NoProfile -File $scriptPath -InputPath $danglingInput -OutputDir $danglingDir 2>$null
        if ($LASTEXITCODE -eq 0) { throw 'Case 18c: a dangling symlink destination must be rejected.' }
        if (Test-Path -LiteralPath $danglingTarget) { throw 'Case 18c: the dangling symlink target must not be created.' }
        Remove-Item -Path $danglingLink -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $danglingTarget -Force -ErrorAction SilentlyContinue

    # --- Case 18d: a backslash immediately before a pipe must not un-escape the pipe. ---
    $bsInject = @'
[
  {
    "incident_id": "INC-BS\\| injected",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "s",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/23",
    "remediation_priority": "medium",
    "repeat_without_prior_verification": false
  }
]
'@
    $r = Invoke-Audit -InputJson $bsInject
    if ($r.Json.incidents[0].incident_id -ne 'INC-BS\| injected') { throw 'Case 18d: incident_id should round-trip the literal backslash-pipe.' }
    $bsFindings = ($r.Markdown -split '## Incident Findings')[1]
    $bsRows = @(($bsFindings -split "`r`n|`n|`r") | Where-Object { $_ -match '^\| INC-BS' })
    if ($bsRows.Count -ne 1) { throw "Case 18d: a backslash-pipe must not inject a row; got $($bsRows.Count)." }
    if ($bsRows[0] -notmatch 'INC-BS\\\\\\\| injected') { throw 'Case 18d: the backslash must be escaped before the pipe so both render literally in one cell.' }

    # --- Case 18e: optional area taxonomy validation (-AreaTaxonomyPath). ---
    $taxonomyPath = Join-Path $tempDir 'areas.json'
    Set-Content -Path $taxonomyPath -Value '["payments-api","auth-api"]' -Encoding UTF8
    $taxInput = Join-Path $tempDir 'tax-input.json'
    $taxOut = Join-Path $tempDir 'tax-output'
    @'
[
  {
    "incident_id": "INC-AREA-OK",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "payments-api",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/24",
    "remediation_priority": "medium",
    "repeat_without_prior_verification": false
  },
  {
    "incident_id": "INC-AREA-BAD",
    "severity": "SEV3",
    "status": "open",
    "detected_at": "2026-01-05T09:00:00Z",
    "remediation_created_at": "2026-01-05T10:00:00Z",
    "owner": "o",
    "affected_service": "not-a-real-area",
    "customer_impact": "c",
    "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/25",
    "remediation_priority": "medium",
    "repeat_without_prior_verification": false
  }
]
'@ | Set-Content -Path $taxInput -Encoding UTF8
    & pwsh -NoProfile -File $scriptPath -InputPath $taxInput -OutputDir $taxOut -AreaTaxonomyPath $taxonomyPath 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Case 18e: taxonomy-validated run failed.' }
    $taxResult = Get-Content -Path (Join-Path $taxOut 'incident-routing-verification.json') -Raw | ConvertFrom-Json -Depth 100
    $okRow = @($taxResult.incidents) | Where-Object { $_.incident_id -eq 'INC-AREA-OK' } | Select-Object -First 1
    $badRow = @($taxResult.incidents) | Where-Object { $_.incident_id -eq 'INC-AREA-BAD' } | Select-Object -First 1
    if ($okRow.area_valid -ne $true) { throw 'Case 18e: a known area must be valid.' }
    if ($badRow.area_valid -ne $false) { throw 'Case 18e: an unknown area must be invalid.' }
    if ($badRow.status -ne 'fail') { throw 'Case 18e: an unknown area must fail the incident.' }

    # --- Case 18f: the linkage warn band is reachable (95-99% linkage -> overall warn, not fail). ---
    $many = @()
    for ($i = 1; $i -le 20; $i++) {
        $many += [ordered]@{
            incident_id = "INC-M$i"
            severity = "SEV3"
            status = "open"
            detected_at = "2026-01-05T09:00:00Z"
            remediation_created_at = "2026-01-05T10:00:00Z"
            owner = "o"
            affected_service = "s"
            customer_impact = "c"
            remediation_issue_url = "https://github.com/IBuySpy-Shared/basecoat/issues/$(100 + $i)"
            remediation_priority = "medium"
            repeat_without_prior_verification = $false
        }
    }
    $many += [ordered]@{
        incident_id = "INC-UNLINKED"
        severity = "SEV3"
        status = "open"
        detected_at = "2026-01-05T09:00:00Z"
        owner = "o"
        affected_service = "s"
        customer_impact = "c"
        repeat_without_prior_verification = $false
    }
    $r = Invoke-Audit -InputJson (ConvertTo-Json -InputObject $many -Depth 6)
    if ($r.Json.metrics.routed_incidents_with_remediation_link.status -ne 'warn') { throw "Case 18f: 20/21 linkage should be a warn, got $($r.Json.metrics.routed_incidents_with_remediation_link.status)." }
    $unlinkedRow = @($r.Json.incidents) | Where-Object { $_.incident_id -eq 'INC-UNLINKED' } | Select-Object -First 1
    if ($unlinkedRow.status -ne 'warn') { throw 'Case 18f: an unlinked record should be a warn, not a fail.' }
    if ($r.Json.status -ne 'warn') { throw "Case 18f: overall should be warn (linkage warn band reachable), got $($r.Json.status)." }

    # --- Case 18g: a top-level JSON object (not an array) must be rejected. ---
    $objInput = Join-Path $tempDir 'object-input.json'
    Set-Content -Path $objInput -Value '{"incident_id":"INC-1","severity":"SEV1","status":"open"}' -Encoding UTF8
    & pwsh -NoProfile -File $scriptPath -InputPath $objInput -OutputDir (Join-Path $tempDir 'obj-out') 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 18g: a top-level JSON object must be rejected (array required).' }

    # --- Case 19: OutputDir containment guard (outside root + prefix-bypass sibling). ---
    $guardInput = Join-Path $tempDir 'guard-input.json'
    Set-Content -Path $guardInput -Value $valid -Encoding UTF8
    $outsideDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-outside-" + [Guid]::NewGuid().ToString('N'))
    & pwsh -NoProfile -File $scriptPath -InputPath $guardInput -OutputDir $outsideDir 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 19: OutputDir outside the repo root must be rejected.' }
    $repoRootTrimmed = $repoRoot.Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $prefixBypassDir = $repoRootTrimmed + "-outside" + [System.IO.Path]::DirectorySeparatorChar + "out"
    & pwsh -NoProfile -File $scriptPath -InputPath $guardInput -OutputDir $prefixBypassDir 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 19: sibling OutputDir sharing the repo-root prefix must be rejected.' }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'AIDL incident routing verification tests passed' -ForegroundColor Green
exit 0
