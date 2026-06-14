param(
    [bool]$GuidanceAuditFailOnError = $true
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$testResultsDir = Join-Path $repoRoot 'test-results'

function Write-FailureLog {
    param([string]$TestName, [string]$Detail = '')
    if (-not (Test-Path $testResultsDir)) {
        New-Item -ItemType Directory -Path $testResultsDir -Force | Out-Null
    }
    $logPath = Join-Path $testResultsDir 'failure.log'
    $timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    $entry = "[$timestamp] FAILED: $TestName"
    if ($Detail) { $entry += "`n  Detail: $Detail" }
    Add-Content -Path $logPath -Value $entry
    Write-Host "  [Screenshot capture: no browser test — see $logPath]" -ForegroundColor Yellow
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [string]$Actual,
        [string]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected', got '$Actual'."
    }
}

Write-Host 'Running validate-basecoat.ps1...'
./scripts/validate-basecoat.ps1

Write-Host 'Checking eval.yaml presence for all skills...'
$skillsDir = Join-Path $repoRoot 'skills'
$missingEval = @()
Get-ChildItem $skillsDir -Directory | ForEach-Object {
    $evalPath = Join-Path $_.FullName 'eval.yaml'
    if (-not (Test-Path $evalPath)) {
        $missingEval += $_.Name
    }
}
if ($missingEval.Count -gt 0) {
    $missing = $missingEval -join ', '
    Write-Host "  eval.yaml CI gate FAILED: $($missingEval.Count) skill(s) missing eval.yaml: $missing" -ForegroundColor Red
    Write-FailureLog 'eval-yaml-gate' "Missing eval.yaml in: $missing"
    exit 1
}
Write-Host "  eval.yaml CI gate passed: all $((Get-ChildItem $skillsDir -Directory).Count) skills have eval.yaml" -ForegroundColor Green

Write-Host 'Running organized guidance audits...'
$guidanceAuditArgs = @(
    '-NoProfile',
    '-File',
    (Join-Path $repoRoot 'scripts' 'run-guidance-audits.ps1')
)
if ($GuidanceAuditFailOnError) {
    $guidanceAuditArgs += '-FailOnError'
}
& pwsh @guidanceAuditArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Guidance audit run failed' -ForegroundColor Red
    Write-FailureLog 'run-guidance-audits'
    exit 1
}

Write-Host 'Running package-basecoat.ps1...'
./scripts/package-basecoat.ps1

$version = (Get-Content version.json -Raw | ConvertFrom-Json).version
Assert-PathExists -Path "dist/base-coat-$version.zip" -Message 'Packaging test failed: zip artifact missing'
Assert-PathExists -Path "dist/base-coat-$version.tar.gz" -Message 'Packaging test failed: tar.gz artifact missing'
Assert-PathExists -Path 'dist/SHA256SUMS.txt' -Message 'Packaging test failed: SHA256SUMS.txt missing'

$checksums = Get-Content 'dist/SHA256SUMS.txt' -Raw
if ($checksums -notmatch "base-coat-$version.zip" -or $checksums -notmatch "base-coat-$version.tar.gz") {
    throw 'Packaging test failed: checksum file missing expected artifact names'
}

Write-Host 'Running install-git-hooks.ps1...'
./scripts/install-git-hooks.ps1
$hooksPath = (git config --get core.hooksPath)
Assert-Equal -Actual $hooksPath -Expected '.githooks' -Message 'Hook installation test failed'

Write-Host 'Running commit message scanner negative test...'
$tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-test-" + [System.Guid]::NewGuid().ToString())

try {
    New-Item -ItemType Directory -Path $tempRepo | Out-Null
    Push-Location $tempRepo
    git init | Out-Null
    git config user.name 'basecoat-test'
    git config user.email 'basecoat-test@example.com'
    Set-Content -Path 'test.txt' -Value 'hello'
    git add test.txt
    git commit -m 'safe commit message' | Out-Null
    Set-Content -Path 'test.txt' -Value 'updated'
    git add test.txt
    git commit -m '-----BEGIN PRIVATE KEY-----' | Out-Null

    $scanScript = Join-Path $repoRoot 'scripts/scan-commit-messages.sh'
    $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashCommand) {
        throw 'Commit message scanner execution test requires bash, but bash is not available in this environment.'
    }

    $output = & $bashCommand.Source $scanScript 'HEAD~1..HEAD' 2>&1
    $scanExitCode = $LASTEXITCODE
    if ($scanExitCode -eq 0) {
        throw 'Commit message scanner test failed: expected failure for sensitive commit message'
    }
}
finally {
    Pop-Location
    if (Test-Path $tempRepo) {
        Remove-Item -Path $tempRepo -Recurse -Force
    }
}

Write-Host 'Running sync process tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'sync-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Sync process tests failed' -ForegroundColor Red
    Write-FailureLog 'sync-tests'
    exit 1
}

Write-Host 'Running adoption scanner tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'adoption-scanner-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Adoption scanner tests failed' -ForegroundColor Red
    Write-FailureLog 'adoption-scanner-tests'
    exit 1
}

Write-Host 'Running A/B experiment harness tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ab-experiment-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'A/B experiment harness tests failed' -ForegroundColor Red
    Write-FailureLog 'ab-experiment-tests'
    exit 1
}

Write-Host 'Running workflow guardrails tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-guardrails-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Workflow guardrails tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-guardrails-tests'
    exit 1
}

Write-Host 'Running workflow enhancements (#1389) tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-enhancements-1389-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Workflow enhancements (#1389) tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-enhancements-1389-tests'
    exit 1
}

Write-Host 'Running routing guardrail tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'routing-guardrail-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Routing guardrail tests failed' -ForegroundColor Red
    Write-FailureLog 'routing-guardrail-tests'
    exit 1
}

Write-Host 'Running cleanup branch automation tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'cleanup-branches-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Cleanup branch automation tests failed' -ForegroundColor Red
    Write-FailureLog 'cleanup-branches-tests'
    exit 1
}

Write-Host 'Running issue triage script tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'issue-triage-script-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Issue triage script tests failed' -ForegroundColor Red
    Write-FailureLog 'issue-triage-script-tests'
    exit 1
}

Write-Host 'Running data workload tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'data-workload-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Data workload tests failed' -ForegroundColor Red
    Write-FailureLog 'data-workload-tests'
    exit 1
}

Write-Host 'Running MCP tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'mcp-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'MCP tests failed' -ForegroundColor Red
    Write-FailureLog 'mcp-tests'
    exit 1
}

Write-Host 'Running asset quality gate tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'quality-gate-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Asset quality gate tests failed' -ForegroundColor Red
    Write-FailureLog 'quality-gate-tests'
    exit 1
}

Write-Host 'Running behavioral evaluation smoke tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'behavioral-eval-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Behavioral evaluation smoke tests failed' -ForegroundColor Red
    Write-FailureLog 'behavioral-eval-tests'
    exit 1
}

Write-Host 'Running harness eval gate workflow tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'harness-change-eval-gate-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Harness eval gate workflow tests failed' -ForegroundColor Red
    Write-FailureLog 'harness-change-eval-gate-tests'
    exit 1
}

Write-Host 'Running orchestrator harness conformance tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'orchestrator-harness-conformance-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Orchestrator harness conformance tests failed' -ForegroundColor Red
    Write-FailureLog 'orchestrator-harness-conformance-tests'
    exit 1
}

Write-Host 'Running VS Code harness benchmark suite tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'vscode-harness-benchmark-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'VS Code harness benchmark suite tests failed' -ForegroundColor Red
    Write-FailureLog 'vscode-harness-benchmark-tests'
    exit 1
}

Write-Host 'Running generate eval stubs tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'generate-eval-stubs-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Generate eval stubs tests failed' -ForegroundColor Red
    Write-FailureLog 'generate-eval-stubs-tests'
    exit 1
}

Write-Host 'Running generate registry tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'generate-registry-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Generate registry tests failed' -ForegroundColor Red
    Write-FailureLog 'generate-registry-tests'
    exit 1
}

Write-Host 'Running extension intent routing eval tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'extension-intent-routing-eval-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Extension intent routing eval tests failed' -ForegroundColor Red
    Write-FailureLog 'extension-intent-routing-eval-tests'
    exit 1
}

Write-Host 'Running show-context tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'show-context-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Show-context tests failed' -ForegroundColor Red
    Write-FailureLog 'show-context-tests'
    exit 1
}

Write-Host 'Running token-status tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'token-status-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Token-status tests failed' -ForegroundColor Red
    Write-FailureLog 'token-status-tests'
    exit 1
}

Write-Host 'Running coherence check (non-blocking)...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot '..' 'scripts' 'check-coherence.ps1')
# Non-blocking: coherence issues are warnings, not failures

Write-Host "`nRunning .gitignore coverage check..." -ForegroundColor Cyan
& pwsh -File "$PSScriptRoot/../scripts/check-gitignore-coverage.ps1"
# Advisory only — do not use -Strict here

Write-Host 'All PowerShell tests passed'
exit 0
