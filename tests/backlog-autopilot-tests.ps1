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

Remove-Item -Path $temp -Recurse -Force

if ($failures -gt 0) {
    Write-Host "backlog-autopilot tests: $failures failure(s)" -ForegroundColor Red
    exit 1
}
Write-Host "backlog-autopilot tests: all passed" -ForegroundColor Green
exit 0
