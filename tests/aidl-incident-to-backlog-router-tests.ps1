$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running AIDL incident-to-backlog router tests...'

$scriptPath = Join-Path $repoRoot 'scripts\aidl-incident-to-backlog-router.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$tempDir = Join-Path $repoRoot ("test-results\aidl-incident-router-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$caseIndex = 0
function Invoke-Router {
    param([string]$InputJson)

    $script:caseIndex++
    $inputPath = Join-Path $tempDir ("input-$script:caseIndex.json")
    $outputDir = Join-Path $tempDir ("output-$script:caseIndex")
    Set-Content -Path $inputPath -Value $InputJson -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath -InputPath $inputPath -OutputDir $outputDir 2>$null
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        throw "Case $script:caseIndex router run failed (exit $exit)."
    }
    $planPath = Join-Path $outputDir 'incident-routing-plan.json'
    if (-not (Test-Path $planPath)) {
        throw "Case $script:caseIndex did not produce a routing plan."
    }
    return (Get-Content $planPath -Raw | ConvertFrom-Json)
}

try {
    # --- Case 1: severity-to-priority mapping for all five severities on unrouted incidents. ---
    $map = @{ SEV1 = 'critical'; SEV2 = 'high'; SEV3 = 'medium'; SEV4 = 'low'; SEV5 = 'low' }
    foreach ($sev in $map.Keys) {
        $json = @"
[{ "incident_id": "INC-$sev", "severity": "$sev", "status": "open", "owner": "oncall-a", "affected_service": "svc-$sev", "customer_impact": "impact", "detected_at": "2026-01-05T09:00:00Z", "root_cause_summary": "rca" }]
"@
        $plan = Invoke-Router -InputJson $json
        $item = $plan.items[0]
        if ($item.action -ne 'create') { throw "Case 1 ($sev): unrouted incident must produce a create action." }
        if ($item.priority -ne $map[$sev]) { throw "Case 1 ($sev): expected priority $($map[$sev]), got $($item.priority)." }
        if (-not ($item.labels -contains "priority:$($map[$sev])")) { throw "Case 1 ($sev): priority label missing." }
        if (-not ($item.labels -contains 'incident')) { throw "Case 1 ($sev): incident label missing." }
        if ($item.title -ne "Remediate incident INC-$sev") { throw "Case 1 ($sev): unexpected title '$($item.title)'." }
        if ($item.eligible -ne $true) { throw "Case 1 ($sev): valid unrouted incident must be eligible." }
    }

    # --- Case 2: already-routed incident is skipped and its link is preserved. ---
    $routed = '[{ "incident_id": "INC-3001", "severity": "SEV1", "status": "closed", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z", "root_cause_summary": "rca", "verification_artifact_url": "https://github.com/IBuySpy-Shared/basecoat/commit/abc1234", "remediation_issue_url": "https://github.com/IBuySpy-Shared/basecoat/issues/42" }]'
    $plan = Invoke-Router -InputJson $routed
    if ($plan.summary.skip -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 2: routed incident must be skipped, not created.' }
    if ($plan.items[0].reason -ne 'already-routed') { throw 'Case 2: reason should be already-routed.' }
    if ($plan.items[0].remediation_issue_url -ne 'https://github.com/IBuySpy-Shared/basecoat/issues/42') { throw 'Case 2: existing remediation link must be preserved.' }

    # --- Case 3: placeholder remediation URL is treated as unrouted (create). ---
    $placeholder = '[{ "incident_id": "INC-3002", "severity": "SEV3", "status": "open", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z", "remediation_issue_url": "n/a" }]'
    $plan = Invoke-Router -InputJson $placeholder
    if ($plan.summary.create -ne 1) { throw 'Case 3: placeholder remediation URL must route (create).' }
    if ($plan.items[0].priority -ne 'medium') { throw 'Case 3: SEV3 must map to medium.' }

    # --- Case 4: invalid/missing severity is skipped as invalid. ---
    $invalid = '[{ "incident_id": "INC-3003", "severity": "SEV9", "status": "open", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z" }]'
    $plan = Invoke-Router -InputJson $invalid
    if ($plan.summary.invalid -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 4: invalid severity must be counted invalid and not created.' }
    if ($plan.items[0].reason -ne 'invalid-or-missing-severity') { throw 'Case 4: reason should flag invalid severity.' }

    # --- Case 5: owner and verification artifact are preserved in the create body. ---
    $withVerification = '[{ "incident_id": "INC-3004", "severity": "SEV2", "status": "open", "owner": "oncall-team-b", "affected_service": "billing", "customer_impact": "billing delayed", "detected_at": "2026-01-05T09:00:00Z", "root_cause_summary": "rca", "verification_artifact_url": "https://github.com/IBuySpy-Shared/basecoat/commit/abc1234" }]'
    $plan = Invoke-Router -InputJson $withVerification
    $body = $plan.items[0].body_markdown
    if ($body -notmatch 'oncall-team-b') { throw 'Case 5: owner (DRI) must be preserved in the body.' }
    if ($body -notmatch 'https://github\.com/IBuySpy-Shared/basecoat/commit/abc1234') { throw 'Case 5: verification artifact must be preserved in the body.' }
    if ($body -notmatch 'billing delayed') { throw 'Case 5: customer impact must be preserved in the body.' }

    # --- Case 6: missing incident_id is invalid (immutable routing identity), not routed. ---
    $missingId = '[{ "severity": "SEV4", "status": "open", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z" }]'
    $plan = Invoke-Router -InputJson $missingId
    if ($plan.summary.invalid -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 6: missing incident_id must be invalid, not created.' }
    if ($plan.items[0].reason -notmatch 'missing-incident-id') { throw 'Case 6: reason should flag missing-incident-id.' }
    if ($plan.items[0].eligible -ne $false) { throw 'Case 6: invalid record must not be eligible.' }

    # --- Case 7: shipped sample dataset produces no new issues (all already routed). ---
    $samplePath = Join-Path $repoRoot 'scripts\aidl-incident-routing-sample.json'
    if (-not (Test-Path $samplePath)) { throw 'Case 7: shipped sample dataset is missing.' }
    $sampleOut = Join-Path $tempDir 'output-sample'
    & pwsh -NoProfile -File $scriptPath -InputPath $samplePath -OutputDir $sampleOut 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Case 7: shipped sample router run failed.' }
    $samplePlan = Get-Content (Join-Path $sampleOut 'incident-routing-plan.json') -Raw | ConvertFrom-Json
    if ($samplePlan.summary.create -ne 0) { throw "Case 7: shipped sample must not route new issues, got $($samplePlan.summary.create)." }

    # --- Case 8: OutputDir outside the repository root is rejected. ---
    $guardInput = Join-Path $tempDir 'guard-input.json'
    Set-Content -Path $guardInput -Value $routed -Encoding UTF8
    $outsideDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-router-outside-" + [Guid]::NewGuid().ToString('N'))
    & pwsh -NoProfile -File $scriptPath -InputPath $guardInput -OutputDir $outsideDir 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 8: OutputDir outside the repo root must be rejected.' }

    # --- Case 9: duplicate incident_id -> first eligible, second invalid. ---
    $dup = '[{ "incident_id": "INC-DUP", "severity": "SEV2", "status": "open", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z", "root_cause_summary": "rca" }, { "incident_id": "INC-DUP", "severity": "SEV2", "status": "open", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z", "root_cause_summary": "rca" }]'
    $plan = Invoke-Router -InputJson $dup
    if ($plan.summary.create -ne 1 -or $plan.summary.invalid -ne 1) { throw 'Case 9: duplicate incident_id must yield one create and one invalid.' }
    $dupInvalid = @($plan.items | Where-Object { $_.reason -match 'duplicate-incident-id' })
    if ($dupInvalid.Count -ne 1) { throw 'Case 9: exactly one record must be flagged duplicate-incident-id.' }

    # --- Case 10: missing DRI/owner is invalid, not routed. ---
    $noOwner = '[{ "incident_id": "INC-NOOWNER", "severity": "SEV1", "status": "open", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z" }]'
    $plan = Invoke-Router -InputJson $noOwner
    if ($plan.summary.invalid -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 10: missing owner must be invalid, not created.' }
    if ($plan.items[0].reason -notmatch 'missing-owner') { throw 'Case 10: reason should flag missing-owner.' }

    # --- Case 11: a top-level JSON object (not an array) is rejected. ---
    $objInput = Join-Path $tempDir 'object-input.json'
    Set-Content -Path $objInput -Value '{ "incident_id": "INC-1", "severity": "SEV1" }' -Encoding UTF8
    $objOut = Join-Path $tempDir 'output-object'
    & pwsh -NoProfile -File $scriptPath -InputPath $objInput -OutputDir $objOut 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 11: a top-level JSON object must be rejected (array required).' }

    # --- Case 12: invalid detected_at timestamp is invalid, not routed. ---
    $badTs = '[{ "incident_id": "INC-BADTS", "severity": "SEV3", "status": "open", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "not-a-date" }]'
    $plan = Invoke-Router -InputJson $badTs
    if ($plan.summary.invalid -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 12: invalid detected_at must be invalid, not created.' }
    if ($plan.items[0].reason -notmatch 'invalid-or-missing-detected-at') { throw 'Case 12: reason should flag invalid detected_at.' }

    # --- Case 13: SEV1/SEV2 without root_cause_summary is invalid, not routed. ---
    $noRca = '[{ "incident_id": "INC-NORCA", "severity": "SEV1", "status": "open", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z" }]'
    $plan = Invoke-Router -InputJson $noRca
    if ($plan.summary.invalid -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 13: SEV1 without root cause must be invalid, not created.' }
    if ($plan.items[0].reason -notmatch 'missing-root-cause-for-high-severity') { throw 'Case 13: reason should flag missing root cause.' }

    # --- Case 14: unknown lifecycle status is invalid, not routed. ---
    $badStatus = '[{ "incident_id": "INC-BADST", "severity": "SEV3", "status": "exploded", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z" }]'
    $plan = Invoke-Router -InputJson $badStatus
    if ($plan.summary.invalid -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 14: unknown status must be invalid, not created.' }
    if ($plan.items[0].reason -notmatch 'invalid-or-missing-status') { throw 'Case 14: reason should flag invalid status.' }

    # --- Case 15: with a supplied area taxonomy, an out-of-taxonomy service is invalid. ---
    $areaFile = Join-Path $tempDir 'areas.json'
    Set-Content -Path $areaFile -Value '["payments-api","identity-service"]' -Encoding UTF8
    $areaInput = Join-Path $tempDir 'area-input.json'
    Set-Content -Path $areaInput -Value '[{ "incident_id": "INC-AREA", "severity": "SEV3", "status": "open", "owner": "o", "affected_service": "rogue-service", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z" }]' -Encoding UTF8
    $areaOut = Join-Path $tempDir 'output-area'
    & pwsh -NoProfile -File $scriptPath -InputPath $areaInput -OutputDir $areaOut -AreaTaxonomyPath $areaFile 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Case 15: router run with area taxonomy failed.' }
    $areaPlan = Get-Content (Join-Path $areaOut 'incident-routing-plan.json') -Raw | ConvertFrom-Json
    if ($areaPlan.summary.invalid -ne 1 -or $areaPlan.summary.create -ne 0) { throw 'Case 15: service outside the area taxonomy must be invalid.' }
    if ($areaPlan.items[0].reason -notmatch 'service-outside-area-taxonomy') { throw 'Case 15: reason should flag out-of-taxonomy service.' }

    # --- Case 16: closure (resolved/closed) without a valid verification artifact is invalid. ---
    $noVerif = '[{ "incident_id": "INC-NOVERIF", "severity": "SEV3", "status": "closed", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z" }]'
    $plan = Invoke-Router -InputJson $noVerif
    if ($plan.summary.invalid -ne 1 -or $plan.summary.create -ne 0) { throw 'Case 16: closure without verification artifact must be invalid.' }
    if ($plan.items[0].reason -notmatch 'closure-missing-verification-artifact') { throw 'Case 16: reason should flag missing closure verification.' }

    # --- Case 17: closure with a valid immutable verification artifact is eligible. ---
    $goodClosure = '[{ "incident_id": "INC-GOODCLOSE", "severity": "SEV3", "status": "resolved", "owner": "o", "affected_service": "s", "customer_impact": "i", "detected_at": "2026-01-05T09:00:00Z", "verification_artifact_url": "https://github.com/IBuySpy-Shared/basecoat/commit/abcdef1" }]'
    $plan = Invoke-Router -InputJson $goodClosure
    if ($plan.summary.create -ne 1) { throw 'Case 17: valid closure evidence with an unrouted incident must route.' }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'AIDL incident-to-backlog router tests passed' -ForegroundColor Green
exit 0
