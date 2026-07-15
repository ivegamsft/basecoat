$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running AIDL memory hygiene sweep tests...'

$scriptPath = Join-Path $repoRoot 'scripts\aidl-memory-hygiene-sweep.ps1'
if (-not (Test-Path $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$tempDir = Join-Path $repoRoot ("test-results\aidl-memory-hygiene-tests-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$caseIndex = 0
function Invoke-Sweep {
    param([string]$InputJson, [string]$AsOf = '2026-03-01T00:00:00Z', [int]$ReviewAfterDays = 30)

    $script:caseIndex++
    $inputPath = Join-Path $tempDir ("input-$script:caseIndex.json")
    $outputDir = Join-Path $tempDir ("output-$script:caseIndex")
    Set-Content -Path $inputPath -Value $InputJson -Encoding UTF8

    & pwsh -NoProfile -File $scriptPath -InputPath $inputPath -OutputDir $outputDir -AsOf $AsOf -ReviewAfterDays $ReviewAfterDays 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Case $script:caseIndex sweep failed (exit $LASTEXITCODE)." }
    return @{
        Report = (Get-Content (Join-Path $outputDir 'memory-hygiene-report.json') -Raw | ConvertFrom-Json)
        OutputDir = $outputDir
    }
}

function Get-Flagged {
    param([object]$Report, [string]$Id)
    return @($Report.flagged | Where-Object { $_.id -eq $Id })[0]
}

try {
    # --- Case 1: a hold past its re-review date with no newer evidence is rejected as stale. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m1", "subject": "logging", "fact": "use winston", "status": "hold", "decided_at": "2026-01-01T00:00:00Z" }]'
    $f = Get-Flagged -Report $r.Report -Id 'm1'
    if ($null -eq $f -or $f.primary_action -ne 'reject-stale') { throw 'Case 1: an expired hold must be flagged reject-stale.' }

    # --- Case 2: a hold within the re-review window is not stale. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m2", "subject": "logging", "fact": "use winston", "status": "hold", "decided_at": "2026-02-20T00:00:00Z" }]'
    if ($r.Report.summary.reject_stale -ne 0) { throw 'Case 2: a hold within the window must not be stale.' }

    # --- Case 3: a hold past the window but with newer evidence is not stale. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m3", "subject": "logging", "fact": "use winston", "status": "hold", "decided_at": "2026-01-01T00:00:00Z", "evidence_recorded_at": "2026-02-25T00:00:00Z" }]'
    if ($r.Report.summary.reject_stale -ne 0) { throw 'Case 3: newer evidence must clear the stale flag.' }

    # --- Case 4: a dead repository file citation is flagged. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m4", "subject": "auth", "fact": "use jwt", "status": "promote", "citations": ["scripts/definitely-missing-file.ps1:5"] }]'
    $f = Get-Flagged -Report $r.Report -Id 'm4'
    if ($null -eq $f -or ($f.actions -notcontains 'dead-citation')) { throw 'Case 4: a dead file citation must be flagged.' }

    # --- Case 5: a resolvable repository file citation is not flagged. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m5", "subject": "auth", "fact": "use jwt", "status": "promote", "citations": ["scripts/aidl-memory-hygiene-sweep.ps1:1"] }]'
    if ($r.Report.summary.dead_citation -ne 0 -or $r.Report.flagged_count -ne 0) { throw 'Case 5: a resolvable file citation must not be flagged.' }

    # --- Case 6: a URL citation is not treated as a dead file reference (online verification). ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m6", "subject": "auth", "fact": "use jwt", "status": "promote", "citations": ["https://github.com/IBuySpy-Shared/basecoat/pull/1"] }]'
    if ($r.Report.flagged_count -ne 0) { throw 'Case 6: a URL citation must not be flagged as a dead file reference.' }

    # --- Case 7: a dead-citation entry with no replacement/rationale needs a replacement or rationale. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m7", "subject": "auth", "fact": "use jwt", "status": "promote", "citations": ["scripts/missing.ps1:1"] }]'
    $f = Get-Flagged -Report $r.Report -Id 'm7'
    if ($f.actions -notcontains 'needs-replacement-or-rationale') { throw 'Case 7: removal without a replacement/rationale must be flagged.' }

    # --- Case 8: a superseded entry with a replacement is deprecated with replacement. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m8", "subject": "cache", "fact": "use redis", "status": "promote", "superseded": true, "replaced_by": "m-cache-2" }]'
    $f = Get-Flagged -Report $r.Report -Id 'm8'
    if ($null -eq $f -or $f.primary_action -ne 'deprecate-with-replacement') { throw 'Case 8: a superseded entry with a replacement must be deprecate-with-replacement.' }

    # --- Case 9: a dead-citation entry with a no-replacement rationale is removed with rationale. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m9", "subject": "auth", "fact": "use jwt", "status": "promote", "citations": ["scripts/missing.ps1:1"], "no_replacement_rationale": "pattern obsolete" }]'
    $f = Get-Flagged -Report $r.Report -Id 'm9'
    if ($f.actions -contains 'needs-replacement-or-rationale') { throw 'Case 9: a recorded no-replacement rationale must clear the needs-rationale flag.' }
    if ($f.actions -notcontains 'remove-with-rationale') { throw 'Case 9: a recorded no-replacement rationale must record a remove-with-rationale action.' }

    # --- Case 10: duplicates are consolidated, retaining the most recent evidence. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "dup-a", "subject": "naming", "fact": "camel case", "status": "promote", "evidence_recorded_at": "2026-01-05T00:00:00Z" }, { "id": "dup-b", "subject": "naming", "fact": "camel case", "status": "promote", "evidence_recorded_at": "2026-02-05T00:00:00Z" }]'
    $fa = Get-Flagged -Report $r.Report -Id 'dup-a'
    $fb = Get-Flagged -Report $r.Report -Id 'dup-b'
    if ($null -eq $fa -or $fa.primary_action -ne 'consolidate-duplicate') { throw 'Case 10: the older duplicate must be flagged for consolidation.' }
    if ($null -ne $fb) { throw 'Case 10: the newest-evidence duplicate must be retained (not flagged).' }

    # --- Case 11: duplicate tie-break on equal evidence uses the lexicographically greatest id. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "aaa", "subject": "naming", "fact": "camel case", "status": "promote", "evidence_recorded_at": "2026-01-05T00:00:00Z" }, { "id": "zzz", "subject": "naming", "fact": "camel case", "status": "promote", "evidence_recorded_at": "2026-01-05T00:00:00Z" }]'
    if ($null -ne (Get-Flagged -Report $r.Report -Id 'zzz')) { throw 'Case 11: the greatest id must be retained on an evidence tie.' }
    if ($null -eq (Get-Flagged -Report $r.Report -Id 'aaa')) { throw 'Case 11: the lesser id must be flagged for consolidation on an evidence tie.' }

    # --- Case 12: a missing id is flagged as an invalid entry. ---
    $r = Invoke-Sweep -InputJson '[{ "subject": "x", "fact": "y", "status": "promote" }]'
    if ($r.Report.summary.invalid_entry -ne 1) { throw 'Case 12: a memory entry without an id must be flagged invalid.' }

    # --- Case 13: an all-clean store recommends no actions and writes the markdown companion. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "clean", "subject": "auth", "fact": "use jwt", "status": "promote", "citations": ["scripts/aidl-memory-hygiene-sweep.ps1:1"] }]'
    if ($r.Report.flagged_count -ne 0) { throw 'Case 13: a clean store must have no flagged entries.' }
    $mdPath = Join-Path $r.OutputDir 'memory-hygiene-report.md'
    if (-not (Test-Path $mdPath)) { throw 'Case 13: the markdown companion must be written.' }
    if ((Get-Content $mdPath -Raw) -notmatch 'AIDL Memory Hygiene Sweep') { throw 'Case 13: the markdown must contain the report heading.' }

    # --- Case 14: identical inputs with a fixed -AsOf produce byte-identical reports. ---
    $input14 = '[{ "id": "m14", "subject": "logging", "fact": "use winston", "status": "hold", "decided_at": "2026-01-01T00:00:00Z" }]'
    $p1 = Join-Path $tempDir 'det1.json'; Set-Content -Path $p1 -Value $input14 -Encoding UTF8
    $o1 = Join-Path $tempDir 'det-out-1'; $o2 = Join-Path $tempDir 'det-out-2'
    & pwsh -NoProfile -File $scriptPath -InputPath $p1 -OutputDir $o1 -AsOf '2026-03-01T00:00:00Z' 2>$null
    & pwsh -NoProfile -File $scriptPath -InputPath $p1 -OutputDir $o2 -AsOf '2026-03-01T00:00:00Z' 2>$null
    if ((Get-Content (Join-Path $o1 'memory-hygiene-report.json') -Raw) -ne (Get-Content (Join-Path $o2 'memory-hygiene-report.json') -Raw)) { throw 'Case 14: a fixed -AsOf must yield byte-identical reports.' }

    # --- Case 15: a top-level JSON object (not an array) is rejected. ---
    $objPath = Join-Path $tempDir 'object.json'
    Set-Content -Path $objPath -Value '{ "id": "m" }' -Encoding UTF8
    & pwsh -NoProfile -File $scriptPath -InputPath $objPath -OutputDir (Join-Path $tempDir 'obj-out') -AsOf '2026-03-01T00:00:00Z' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 15: a top-level JSON object must be rejected (array required).' }

    # --- Case 16: an invalid -AsOf value is rejected. ---
    $badAsOfInput = Join-Path $tempDir 'badasof.json'
    Set-Content -Path $badAsOfInput -Value '[{ "id": "m", "subject": "s", "fact": "f", "status": "promote" }]' -Encoding UTF8
    & pwsh -NoProfile -File $scriptPath -InputPath $badAsOfInput -OutputDir (Join-Path $tempDir 'badasof-out') -AsOf 'not-a-date' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 16: a malformed -AsOf must be rejected.' }

    # --- Case 17: OutputDir outside the repository root is rejected. ---
    $guardInput = Join-Path $tempDir 'guard.json'
    Set-Content -Path $guardInput -Value '[{ "id": "m", "subject": "s", "fact": "f", "status": "promote" }]' -Encoding UTF8
    $outsideDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aidl-hygiene-outside-" + [Guid]::NewGuid().ToString('N'))
    & pwsh -NoProfile -File $scriptPath -InputPath $guardInput -OutputDir $outsideDir -AsOf '2026-03-01T00:00:00Z' 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 17: OutputDir outside the repo root must be rejected.' }

    # --- Case 18: a non-positive ReviewAfterDays is rejected. ---
    $rdInput = Join-Path $tempDir 'reviewdays.json'
    Set-Content -Path $rdInput -Value '[{ "id": "m", "subject": "s", "fact": "f", "status": "promote" }]' -Encoding UTF8
    & pwsh -NoProfile -File $scriptPath -InputPath $rdInput -OutputDir (Join-Path $tempDir 'rd-out') -AsOf '2026-03-01T00:00:00Z' -ReviewAfterDays 0 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'Case 18: ReviewAfterDays of 0 must be rejected.' }

    # --- Case 19: a citation escaping the repository (../) or a directory is not resolved. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m19a", "subject": "a", "fact": "b", "status": "promote", "citations": ["../outside.ps1:1"] }, { "id": "m19b", "subject": "c", "fact": "d", "status": "promote", "citations": ["scripts/:1"] }]'
    if ($null -eq (Get-Flagged -Report $r.Report -Id 'm19a')) { throw 'Case 19: a ../ citation escaping the repo must be treated as dead.' }
    if ($null -eq (Get-Flagged -Report $r.Report -Id 'm19b')) { throw 'Case 19: a directory citation must not resolve as a live file.' }

    # --- Case 20: URL citations are reported as pending online verification, not silently dropped. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m20", "subject": "a", "fact": "b", "status": "promote", "citations": ["https://github.com/IBuySpy-Shared/basecoat/pull/1"] }]'
    if ($r.Report.url_citations_pending_online_check -ne 1) { throw 'Case 20: URL citations must be counted as pending online verification.' }
    if (@($r.Report.online_check_entries | Where-Object { $_.id -eq 'm20' }).Count -ne 1) { throw 'Case 20: URL citations must be surfaced per entry.' }

    # --- Case 21: a hold with a missing decided_at is flagged (not silently ok). ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m21", "subject": "a", "fact": "b", "status": "hold" }]'
    $f = Get-Flagged -Report $r.Report -Id 'm21'
    if ($null -eq $f -or ($f.actions -notcontains 'reject-stale')) { throw 'Case 21: a hold without a valid decided_at must be flagged.' }

    # --- Case 22: every action is counted (not only the primary). ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m22", "subject": "a", "fact": "b", "status": "promote", "citations": ["scripts/missing.ps1:1"] }]'
    if ($r.Report.summary.dead_citation -ne 1 -or $r.Report.summary.needs_replacement_or_rationale -ne 1) { throw 'Case 22: both dead-citation and needs-replacement-or-rationale must be counted.' }

    # --- Case 23: duplicate ids are rejected as invalid (not consolidated). ---
    $r = Invoke-Sweep -InputJson '[{ "id": "same", "subject": "n", "fact": "camel", "status": "promote", "evidence_recorded_at": "2026-01-05T00:00:00Z" }, { "id": "same", "subject": "n", "fact": "camel", "status": "promote", "evidence_recorded_at": "2026-02-05T00:00:00Z" }]'
    if ($r.Report.summary.invalid_entry -ne 2) { throw 'Case 23: duplicate ids must be flagged invalid (both entries).' }
    if ($r.Report.summary.consolidate_duplicate -ne 0) { throw 'Case 23: duplicate ids must not be consolidated by content.' }

    # --- Case 24: future-dated evidence (after -AsOf) does not clear a stale hold. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m24", "subject": "a", "fact": "b", "status": "hold", "decided_at": "2026-01-01T00:00:00Z", "evidence_recorded_at": "2026-12-01T00:00:00Z" }]'
    if ($r.Report.summary.reject_stale -ne 1) { throw 'Case 24: evidence dated after -AsOf must not clear a stale hold.' }

    # --- Case 25: prose "owner/repo" citations are not treated as dead repository files. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m25", "subject": "a", "fact": "b", "status": "promote", "citations": ["IBuySpy-Shared/basecoat PRs #312, #340"] }]'
    if ($r.Report.summary.dead_citation -ne 0 -or $r.Report.flagged_count -ne 0) { throw 'Case 25: an owner/repo prose citation must not be flagged as a dead file.' }

    # --- Case 26: a backtick-wrapped URL is classified as a URL (pending online check), not a file. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m26", "subject": "a", "fact": "b", "status": "promote", "citations": ["`https://example.com/x`"] }]'
    if ($r.Report.url_citations_pending_online_check -ne 1) { throw 'Case 26: a quoted/backticked URL must be classified as a URL.' }
    if ($r.Report.summary.dead_citation -ne 0) { throw 'Case 26: a quoted URL must not be flagged as a dead file.' }

    # --- Case 27: the injective duplicate key does not collide across delimiter placement. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "k1", "subject": "a|b", "fact": "c", "status": "promote" }, { "id": "k2", "subject": "a", "fact": "b|c", "status": "promote" }]'
    if ($r.Report.summary.consolidate_duplicate -ne 0) { throw 'Case 27: entries differing only by delimiter placement must not be treated as duplicates.' }

    # --- Case 28: promotion-pipeline field aliases are recognized (candidate_id, decision, audited_at_utc). ---
    $r = Invoke-Sweep -InputJson '[{ "candidate_id": "cand-1", "subject": "a", "fact": "b", "decision": "hold", "audited_at_utc": "2026-01-01T00:00:00Z" }]'
    $f = Get-Flagged -Report $r.Report -Id 'cand-1'
    if ($null -eq $f -or ($f.actions -notcontains 'reject-stale')) { throw 'Case 28: an aliased hold (decision/audited_at_utc/candidate_id) must age and be flagged reject-stale.' }

    # --- Case 29: an entry missing required fields (subject/fact/status) is flagged invalid. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m29", "subject": "a" }]'
    if ($r.Report.summary.invalid_entry -ne 1 -or $r.Report.summary.ok -ne 0) { throw 'Case 29: an entry missing fact/status must be flagged invalid, not ok.' }
    $f = Get-Flagged -Report $r.Report -Id 'm29'
    if ($f.actions -notcontains 'invalid-entry') { throw 'Case 29: the invalid-entry action must be recorded.' }

    # --- Case 30: an unsupported status value is flagged invalid. ---
    $r = Invoke-Sweep -InputJson '[{ "id": "m30", "subject": "a", "fact": "b", "status": "holdd" }]'
    if ($r.Report.summary.invalid_entry -ne 1 -or $r.Report.summary.ok -ne 0) { throw 'Case 30: an unsupported status must be flagged invalid.' }
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

Write-Host 'AIDL memory hygiene sweep tests passed' -ForegroundColor Green
exit 0
