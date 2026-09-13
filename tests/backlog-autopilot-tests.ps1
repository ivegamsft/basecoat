[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

$agentPath      = Join-Path $repoRoot "agents\basecoat-60-workflow-backlog-autopilot.agent.md"
$agentEvalPath  = Join-Path $repoRoot "agents\basecoat-60-workflow-backlog-autopilot.agent.eval.yaml"
$configPath     = Join-Path $repoRoot "scripts\backlog-autopilot\autopilot.config.json"
$waveScript     = Join-Path $repoRoot "scripts\backlog-autopilot\build-waves.ps1"
$paceScript     = Join-Path $repoRoot "scripts\backlog-autopilot\pace-gate.ps1"
$mergeScript    = Join-Path $repoRoot "scripts\backlog-autopilot\merge-gate.ps1"
$designDoc      = Join-Path $repoRoot "docs\design\backlog-autopilot-intent.md"
$guideDoc       = Join-Path $repoRoot "docs\guides\backlog-autopilot-integration.md"
$canonRouting   = Join-Path $repoRoot "instructions\basecoat-10-core-intent-routing.instructions.md"
$aliasRouting   = Join-Path $repoRoot "instructions\intent-routing.instructions.md"

$failures = 0
function Assert($condition, $message) {
    if (-not $condition) {
        Write-Host "  FAIL: $message" -ForegroundColor Red
        $script:failures++
    } else {
        Write-Host "  ok: $message" -ForegroundColor DarkGray
    }
}

Write-Host "backlog-autopilot: asset existence"
foreach ($p in @($agentPath, $agentEvalPath, $configPath, $waveScript, $paceScript, $mergeScript, $designDoc, $guideDoc)) {
    Assert (Test-Path $p) "exists: $p"
}

Write-Host "backlog-autopilot: routing registration"
$canonicalText = Get-Content $canonRouting -Raw
Assert ($canonicalText -match '\|\s*`autopilot:`') "autopilot: prefix row in $(Split-Path $canonRouting -Leaf)"
Assert ($canonicalText -match 'Backlog Autopilot Routing') "autopilot routing section in $(Split-Path $canonRouting -Leaf)"
$aliasText = Get-Content $aliasRouting -Raw
Assert ($aliasText -match 'canonicalInstruction:\s*"basecoat-10-core-intent-routing\.instructions\.md"') "intent-routing compatibility alias identifies canonical routing"
Assert ($aliasText -match 'See `basecoat-10-core-intent-routing\.instructions\.md`') "intent-routing compatibility alias points to canonical routing"

Write-Host "backlog-autopilot: merge-queue posture"
$config = Get-Content $configPath -Raw | ConvertFrom-Json
Assert ($config.merge.merge_queue_posture -eq "required") "merge_queue_posture required"
Assert ($config.selection.order -eq "oldest-first") "selection order oldest-first"

$temp = Join-Path $repoRoot "test-results\backlog-autopilot-test"
if (Test-Path $temp) { Remove-Item -Path $temp -Recurse -Force }
New-Item -ItemType Directory -Path $temp -Force | Out-Null

Write-Host "backlog-autopilot: wave builder ordering + dependencies"
# Issue 30 is oldest; 10 depends on 30; 20 has an excluded label and must be
# dropped; 50 depends on the open-but-excluded #20 and must therefore stay blocked.
$issuesFixture = @(
    [pscustomobject]@{ number = 10; createdAt = "2026-07-20T00:00:00Z"; title = "dependent"; body = "Depends on #30"; labels = @() },
    [pscustomobject]@{ number = 20; createdAt = "2026-07-19T00:00:00Z"; title = "blocked one"; body = "no deps"; labels = @([pscustomobject]@{ name = "blocked" }) },
    [pscustomobject]@{ number = 30; createdAt = "2026-07-18T00:00:00Z"; title = "oldest root"; body = "no deps"; labels = @() },
    [pscustomobject]@{ number = 40; createdAt = "2026-07-21T00:00:00Z"; title = "independent"; body = "no deps"; labels = @() },
    [pscustomobject]@{ number = 50; createdAt = "2026-07-22T00:00:00Z"; title = "waits on excluded"; body = "Depends on #20"; labels = @() }
)
$issuesPath = Join-Path $temp "issues.json"
$issuesFixture | ConvertTo-Json -Depth 6 | Set-Content -Path $issuesPath -Encoding utf8
$wavesPath = Join-Path $temp "waves.json"

& $waveScript -Repo "test/repo" -WaveSize 5 -InputPath $issuesPath -OutputPath $wavesPath | Out-Null
Assert ($LASTEXITCODE -eq 0) "build-waves.ps1 exits 0"

$waves = Get-Content $wavesPath -Raw | ConvertFrom-Json
$allWaved = @($waves.waves | ForEach-Object { $_.issues } | ForEach-Object { $_ })
Assert (-not ($allWaved -contains 20)) "excluded-label issue #20 dropped"
Assert ($waves.waves[0].issues -contains 30) "oldest root #30 lands in wave 1"
Assert ($waves.waves[0].issues -contains 40) "independent #40 lands in wave 1"
Assert (-not ($waves.waves[0].issues -contains 10)) "dependent #10 not in wave 1"

$dependentWave = ($waves.waves | Where-Object { $_.issues -contains 10 } | Select-Object -First 1).wave
Assert ($dependentWave -gt 1) "dependent #10 lands in a later wave (wave $dependentWave)"

# #50 depends on the open-but-excluded #20; since #20 never becomes actionable,
# #50 must stay blocked rather than being treated as ready.
Assert ($waves.blocked -contains 50) "dependent on open non-actionable issue (#50) stays blocked"
Assert (-not ($allWaved -contains 50)) "blocked dependent #50 never waved"

Write-Host "backlog-autopilot: epic sub-issue and parent-ref ordering"
# Epic #100 has native sub-issues 110/120/130; 130 carries an excluded label so
# it is never actionable, which must keep the epic blocked. Epic #200 has one
# actionable child (210) and must land in a LATER wave. Epic #300 has no native
# sub-issue array; its child #310 declares "Parent: #300", which must still
# order the epic after the child.
$epicFixture = @(
    [pscustomobject]@{ number = 100; createdAt = "2026-07-10T00:00:00Z"; title = "epic native"; body = "Epic umbrella"; labels = @(); subIssues = @(110, 120, 130) },
    [pscustomobject]@{ number = 110; createdAt = "2026-07-11T00:00:00Z"; title = "child a"; body = "Parent: test/repo#100"; labels = @() },
    [pscustomobject]@{ number = 120; createdAt = "2026-07-12T00:00:00Z"; title = "child b"; body = "Parent: #100"; labels = @() },
    [pscustomobject]@{ number = 130; createdAt = "2026-07-13T00:00:00Z"; title = "child needs-info"; body = "Parent: #100"; labels = @([pscustomobject]@{ name = "needs-info" }) },
    [pscustomobject]@{ number = 200; createdAt = "2026-07-14T00:00:00Z"; title = "epic all-actionable"; body = "umbrella"; labels = @(); subIssues = @(210) },
    [pscustomobject]@{ number = 210; createdAt = "2026-07-15T00:00:00Z"; title = "child of 200"; body = "no deps"; labels = @() },
    [pscustomobject]@{ number = 300; createdAt = "2026-07-16T00:00:00Z"; title = "epic parent-ref only"; body = "umbrella no native"; labels = @() },
    [pscustomobject]@{ number = 310; createdAt = "2026-07-17T00:00:00Z"; title = "child parent-ref"; body = "Parent: #300"; labels = @() },
    # Finding-3 isolation: epic #400 has NO native subIssues array, and its only
    # child #410 is excluded (needs-info) so it is absent from $ordered. The sole
    # signal linking them is #410's "Parent: #400" body reference, which must be
    # parsed from the full issue set. If it were parsed only from $ordered the
    # excluded child would vanish and #400 would wrongly schedule.
    [pscustomobject]@{ number = 400; createdAt = "2026-07-18T00:00:00Z"; title = "epic excluded-child parent-ref"; body = "umbrella no native"; labels = @() },
    [pscustomobject]@{ number = 410; createdAt = "2026-07-19T00:00:00Z"; title = "excluded child parent-ref only"; body = "Parent: #400"; labels = @([pscustomobject]@{ name = "needs-info" }) }
)
$epicPath = Join-Path $temp "epic.json"
$epicFixture | ConvertTo-Json -Depth 6 | Set-Content -Path $epicPath -Encoding utf8
$epicWavesPath = Join-Path $temp "epic-waves.json"
& $waveScript -Repo "test/repo" -WaveSize 5 -InputPath $epicPath -OutputPath $epicWavesPath | Out-Null
Assert ($LASTEXITCODE -eq 0) "build-waves.ps1 exits 0 (epic fixture)"
$epicWaves = Get-Content $epicWavesPath -Raw | ConvertFrom-Json
function Get-WaveOf($waves, $n) {
    $w = ($waves.waves | Where-Object { $_.issues -contains $n } | Select-Object -First 1)
    if ($w) { return $w.wave } else { return 0 }
}
$epicAllWaved = @($epicWaves.waves | ForEach-Object { $_.issues } | ForEach-Object { $_ })
# Native sub-issue children order the parent after them.
Assert ((Get-WaveOf $epicWaves 210) -eq 1) "native child #210 lands in wave 1"
Assert ((Get-WaveOf $epicWaves 200) -gt (Get-WaveOf $epicWaves 210)) "epic #200 lands after its native child #210"
# Parent-ref child (no native subIssues array) still orders the epic after it.
Assert ((Get-WaveOf $epicWaves 310) -eq 1) "parent-ref child #310 lands in wave 1"
Assert ((Get-WaveOf $epicWaves 300) -gt (Get-WaveOf $epicWaves 310)) "epic #300 lands after its parent-ref child #310"
# An epic with an open-but-excluded (needs-info) child can never complete.
Assert ($epicWaves.blocked -contains 100) "epic #100 with needs-info child stays blocked"
Assert (-not ($epicAllWaved -contains 100)) "blocked epic #100 never waved"
Assert (-not ($epicAllWaved -contains 130)) "excluded child #130 dropped"
# Finding-3 isolation: parent linked ONLY via an excluded child's Parent: ref.
Assert ($epicWaves.blocked -contains 400) "epic #400 blocked by excluded parent-ref-only child #410"
Assert (-not ($epicAllWaved -contains 400)) "blocked epic #400 never waved"
Assert (-not ($epicAllWaved -contains 410)) "excluded parent-ref-only child #410 dropped"
# Negative regression: without sub-issue/parent mapping the epic would wrongly
# co-schedule with its children; assert it does NOT share a wave with them.
Assert (-not ($epicWaves.waves | Where-Object { ($_.issues -contains 200) -and ($_.issues -contains 210) })) "epic #200 never shares a wave with its child #210"

Write-Host "backlog-autopilot: dependency-cycle detection"
$cycleFixture = @(
    [pscustomobject]@{ number = 1; createdAt = "2026-07-18T00:00:00Z"; title = "a"; body = "Depends on #2"; labels = @() },
    [pscustomobject]@{ number = 2; createdAt = "2026-07-18T00:00:00Z"; title = "b"; body = "Depends on #1"; labels = @() }
)
$cyclePath = Join-Path $temp "cycle.json"
$cycleFixture | ConvertTo-Json -Depth 6 | Set-Content -Path $cyclePath -Encoding utf8
$cycleOut = & $waveScript -Repo "test/repo" -InputPath $cyclePath | ConvertFrom-Json
Assert (($cycleOut.blocked -contains 1) -and ($cycleOut.blocked -contains 2)) "dependency cycle reported as blocked"

Write-Host "backlog-autopilot: pace gate interval"
$intervalReady = & $paceScript -Mode interval -LastMergeUtc "2020-01-01T00:00:00Z" | ConvertFrom-Json
Assert ($intervalReady.ready -eq $true -and $intervalReady.wait_seconds -eq 0) "stale last-merge => ready, wait 0"
$intervalWait = & $paceScript -Mode interval -LastMergeUtc "2026-07-27T10:00:00Z" -NowUtc "2026-07-27T10:00:10Z" | ConvertFrom-Json
Assert ($intervalWait.ready -eq $false -and $intervalWait.wait_seconds -gt 0) "recent last-merge => wait > 0"

Write-Host "backlog-autopilot: pace gate backoff"
$b2 = & $paceScript -Mode backoff -Attempt 2 -StatusCode 429 | ConvertFrom-Json
Assert ($b2.should_retry -eq $true -and $b2.wait_seconds -eq 20) "attempt 2 on 429 => 5*2^2 = 20s"
$bNo = & $paceScript -Mode backoff -Attempt 1 -StatusCode 200 | ConvertFrom-Json
Assert ($bNo.should_retry -eq $false -and $bNo.wait_seconds -eq 0) "non-retryable status => no wait"
$bCap = & $paceScript -Mode backoff -Attempt 20 -StatusCode 429 | ConvertFrom-Json
Assert ($bCap.wait_seconds -le 300) "backoff capped at max_seconds"

Write-Host "backlog-autopilot: pace gate api-burst"
$burstReady = & $paceScript -Mode apiburst -LastBurstUtc "2020-01-01T00:00:00Z" | ConvertFrom-Json
Assert ($burstReady.mode -eq "apiburst" -and $burstReady.ready -eq $true -and $burstReady.wait_seconds -eq 0) "stale last-burst => ready, wait 0"
$burstWait = & $paceScript -Mode apiburst -LastBurstUtc "2026-07-27T10:00:00Z" -NowUtc "2026-07-27T10:00:00Z" | ConvertFrom-Json
Assert ($burstWait.ready -eq $false -and $burstWait.wait_seconds -gt 0) "just-fired burst => wait > 0"

Write-Host "backlog-autopilot: merge gate posture enforcement"
# Required posture WITH a native merge queue: serialized single-in-flight native landing.
$mgNativeIdle = & $mergeScript -InFlightCount 0 -HasNativeMergeQueue | ConvertFrom-Json
Assert ($mgNativeIdle.posture -eq "required" -and $mgNativeIdle.landing -eq "native-merge-queue") "required + native => native landing"
Assert ($mgNativeIdle.can_arm -eq $true -and $mgNativeIdle.max_in_flight -eq 1) "native, none in flight => may arm, serialized to 1"
$mgNativeBusy = & $mergeScript -InFlightCount 1 -HasNativeMergeQueue | ConvertFrom-Json
Assert ($mgNativeBusy.can_arm -eq $false) "native, one in flight => hold (serialized)"
# Required posture WITHOUT a native queue: repo policy blocks auto-merge => escalate, never fall back.
$mgBlocked = & $mergeScript -InFlightCount 0 | ConvertFrom-Json
Assert ($mgBlocked.policy_block -eq $true -and $mgBlocked.can_arm -eq $false) "required without native queue => policy block, not armable"
Assert ($mgBlocked.landing -eq "blocked-native-queue-required") "required without native queue => blocked landing, no auto-merge fallback"
Assert ($mgBlocked.require_green_checks -eq $true) "green-checks requirement surfaced"
# The in-flight count is mandatory and validated: a negative (or omitted) count
# must be rejected so the one-in-flight guardrail cannot be silently defeated.
& pwsh -NoProfile -File $mergeScript -InFlightCount -1 *> $null
Assert ($LASTEXITCODE -ne 0) "negative in-flight count rejected (validated, non-permissive)"

Write-Host "backlog-autopilot: global sub-issue endpoint failure detection (#3358)"
# Every online sub-issue lookup failing (transient/auth) must fail loud rather
# than silently sentinel-blocking every issue and still exiting 0. The
# `subIssuesStatus` fixture hook models the online outcome deterministically.
$allErr = @(
    [pscustomobject]@{ number = 10; createdAt = "2026-07-01T00:00:00Z"; title = "a"; body = ""; labels = @(); subIssuesStatus = "error" },
    [pscustomobject]@{ number = 20; createdAt = "2026-07-02T00:00:00Z"; title = "b"; body = ""; labels = @(); subIssuesStatus = "error" }
)
$allErrPath = Join-Path $temp "all-error.json"
$allErr | ConvertTo-Json -Depth 6 | Set-Content -Path $allErrPath -Encoding utf8
$allErrOut = Join-Path $temp "all-error-waves.json"
& pwsh -NoProfile -File $waveScript -Repo "test/repo" -InputPath $allErrPath -OutputPath $allErrOut 2>$null | Out-Null
Assert ($LASTEXITCODE -eq 3) "every sub-issue lookup failing exits non-zero (3), not a silent empty wave"
Assert (-not (Test-Path $allErrOut)) "no wave plan written when the endpoint globally fails"

# Not-all-failed (one transient error, one 404-unsupported) is a per-epic
# condition, not a global outage: exit 0, the errored epic fails closed
# (blocked), the unsupported one still schedules from body references.
$mixed = @(
    [pscustomobject]@{ number = 10; createdAt = "2026-07-01T00:00:00Z"; title = "a"; body = ""; labels = @(); subIssuesStatus = "error" },
    [pscustomobject]@{ number = 20; createdAt = "2026-07-02T00:00:00Z"; title = "b"; body = ""; labels = @(); subIssuesStatus = "unsupported" }
)
$mixedPath = Join-Path $temp "mixed.json"
$mixed | ConvertTo-Json -Depth 6 | Set-Content -Path $mixedPath -Encoding utf8
$mixedOut = Join-Path $temp "mixed-waves.json"
& $waveScript -Repo "test/repo" -InputPath $mixedPath -OutputPath $mixedOut 2>$null | Out-Null
Assert ($LASTEXITCODE -eq 0) "partial sub-issue failure does not trip the global gate (exit 0)"
$mixedWaves = Get-Content $mixedOut -Raw | ConvertFrom-Json
$mixedWaved = @($mixedWaves.waves | ForEach-Object { $_.issues } | ForEach-Object { $_ })
Assert ($mixedWaves.blocked -contains 10) "errored epic #10 fails closed (blocked)"
Assert ($mixedWaved -contains 20) "unsupported epic #20 is scheduled (no sentinel block)"

# Every lookup returning 404 (endpoint unsupported) degrades gracefully: no
# sentinel-blocking, waves still built from body/Parent references, exit 0.
$allUnsup = @(
    [pscustomobject]@{ number = 10; createdAt = "2026-07-01T00:00:00Z"; title = "a"; body = ""; labels = @(); subIssuesStatus = "unsupported" },
    [pscustomobject]@{ number = 20; createdAt = "2026-07-02T00:00:00Z"; title = "b"; body = ""; labels = @(); subIssuesStatus = "unsupported" }
)
$allUnsupPath = Join-Path $temp "all-unsupported.json"
$allUnsup | ConvertTo-Json -Depth 6 | Set-Content -Path $allUnsupPath -Encoding utf8
$allUnsupOut = Join-Path $temp "all-unsupported-waves.json"
& $waveScript -Repo "test/repo" -InputPath $allUnsupPath -OutputPath $allUnsupOut 2>$null | Out-Null
Assert ($LASTEXITCODE -eq 0) "globally unsupported endpoint degrades gracefully (exit 0)"
$unsupWaves = Get-Content $allUnsupOut -Raw | ConvertFrom-Json
$unsupWaved = @($unsupWaves.waves | ForEach-Object { $_.issues } | ForEach-Object { $_ })
Assert (($unsupWaved -contains 10) -and ($unsupWaved -contains 20)) "unsupported endpoint still schedules independent issues"
Assert ($unsupWaves.blocked.Count -eq 0) "no issue sentinel-blocked when the endpoint is merely unsupported"

Remove-Item -Path $temp -Recurse -Force

if ($failures -gt 0) {
    Write-Host "backlog-autopilot tests: $failures failure(s)" -ForegroundColor Red
    exit 1
}
Write-Host "backlog-autopilot tests: all passed" -ForegroundColor Green
exit 0
