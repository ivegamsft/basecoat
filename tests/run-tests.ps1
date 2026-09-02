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

Write-Host 'Running reusable-workflow contract tests...'
& python (Join-Path $PSScriptRoot 'reusable-workflow-contract-tests.py')
if ($LASTEXITCODE -ne 0) {
    Write-FailureLog 'reusable-workflow-contract-tests'
    exit 1
}

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

Write-Host 'Running Bash sync parity tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'sync-sh-parity-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Bash sync parity tests failed' -ForegroundColor Red
    Write-FailureLog 'sync-sh-parity-tests'
    exit 1
}

Write-Host 'Running adoption scanner tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'adoption-scanner-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Adoption scanner tests failed' -ForegroundColor Red
    Write-FailureLog 'adoption-scanner-tests'
    exit 1
}

Write-Host 'Running adoption metrics parser tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'adoption-metrics-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Adoption metrics parser tests failed' -ForegroundColor Red
    Write-FailureLog 'adoption-metrics-tests'
    exit 1
}

Write-Host 'Running consumer updater tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'consumer-updater-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Consumer updater tests failed' -ForegroundColor Red
    Write-FailureLog 'consumer-updater-tests'
    exit 1
}

Write-Host 'Running model inventory tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'model-inventory-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Model inventory tests failed' -ForegroundColor Red
    Write-FailureLog 'model-inventory-tests'
    exit 1
}

Write-Host 'Running model capability tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'model-capability-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Model capability tests failed' -ForegroundColor Red
    Write-FailureLog 'model-capability-tests'
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

Write-Host 'Running coverage threshold ratchet tests...'
& node --test (Join-Path $PSScriptRoot 'coverage-threshold-ratchet.test.js')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Coverage threshold ratchet tests failed' -ForegroundColor Red
    Write-FailureLog 'coverage-threshold-ratchet'
    exit 1
}

Write-Host 'Running npm lock integrity tests...'
& node --test (Join-Path $PSScriptRoot 'npm-lock-integrity.test.mjs')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'npm lock integrity tests failed' -ForegroundColor Red
    Write-FailureLog 'npm-lock-integrity'
    exit 1
}

Write-Host 'Running terraform plan destroy guardrail tests...'
& node --test (Join-Path $PSScriptRoot 'terraform-plan-destroy-guardrail.test.js')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Terraform plan destroy guardrail tests failed' -ForegroundColor Red
    Write-FailureLog 'terraform-plan-destroy-guardrail'
    exit 1
}

Write-Host 'Running workflow action pinning tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-action-pinning-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Workflow action pinning tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-action-pinning-tests'
    exit 1
}

Write-Host 'Running automation stuck-state watchdog tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'automation-stuck-state-watchdog-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Automation stuck-state watchdog tests failed' -ForegroundColor Red
    Write-FailureLog 'automation-stuck-state-watchdog-tests'
    exit 1
}

Write-Host 'Running issue-triage lock refresh tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'issue-triage-lock-refresh-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Issue-triage lock refresh tests failed' -ForegroundColor Red
    Write-FailureLog 'issue-triage-lock-refresh-tests'
    exit 1
}

Write-Host 'Running issue-triage workflow contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-issue-triage-contract.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Issue-triage workflow contract tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-issue-triage-contract'
    exit 1
}

Write-Host 'Running code-review-agent workflow contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-code-review-agent-contract.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Code-review-agent workflow contract tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-code-review-agent-contract'
    exit 1
}

Write-Host 'Running Copilot authentication workflow contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-copilot-auth-contract.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Copilot authentication workflow contract tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-copilot-auth-contract'
    exit 1
}

Write-Host 'Running actionlint compatibility contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-actionlint-compat-contract.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Actionlint compatibility contract tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-actionlint-compat-contract'
    exit 1
}

Write-Host 'Running version-check callable contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'version-check-callable-contract.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Version-check callable contract tests failed' -ForegroundColor Red
    Write-FailureLog 'version-check-callable-contract'
    exit 1
}

Write-Host 'Running post-merge release chain workflow tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'post-merge-release-chain-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Post-merge release chain workflow tests failed' -ForegroundColor Red
    Write-FailureLog 'post-merge-release-chain-tests'
    exit 1
}

Write-Host 'Running delivery-autopilot tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'delivery-autopilot-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Delivery-autopilot tests failed' -ForegroundColor Red
    Write-FailureLog 'delivery-autopilot-tests'
    exit 1
}

Write-Host 'Running backlog-autopilot tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'backlog-autopilot-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Backlog-autopilot tests failed' -ForegroundColor Red
    Write-FailureLog 'backlog-autopilot-tests'
    exit 1
}

Write-Host 'Running PR auto-merge executor workflow tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'pr-auto-merge-executor-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'PR auto-merge executor workflow tests failed' -ForegroundColor Red
    Write-FailureLog 'pr-auto-merge-executor-tests'
    exit 1
}

Write-Host 'Running solo-dev profile guidance tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'solo-dev-profile-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Solo-dev profile guidance tests failed' -ForegroundColor Red
    Write-FailureLog 'solo-dev-profile-tests'
    exit 1
}

Write-Host 'Running bootstrap secret-requirement contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'bootstrap-secret-requirements-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Bootstrap secret-requirement contract tests failed' -ForegroundColor Red
    Write-FailureLog 'bootstrap-secret-requirements-tests'
    exit 1
}

Write-Host 'Running issue-approve routing workflow tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-issue-approve-routing-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Issue-approve routing workflow tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-issue-approve-routing-tests'
    exit 1
}

Write-Host 'Running auto-approve cloud-agent workflows tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'auto-approve-cloud-agent-workflows-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Auto-approve cloud-agent workflows tests failed' -ForegroundColor Red
    Write-FailureLog 'auto-approve-cloud-agent-workflows-tests'
    exit 1
}

Write-Host 'Running merge eligibility human-review reconcile tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'merge-eligibility-human-review-reconcile-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Merge eligibility human-review reconcile tests failed' -ForegroundColor Red
    Write-FailureLog 'merge-eligibility-human-review-reconcile-tests'
    exit 1
}

Write-Host 'Running post-onboarding drift loop tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'post-onboarding-drift-loop-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Post-onboarding drift loop tests failed' -ForegroundColor Red
    Write-FailureLog 'post-onboarding-drift-loop-tests'
    exit 1
}

Write-Host 'Running downstream reviewer-routing audit tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'downstream-reviewer-routing-audit-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Downstream reviewer-routing audit tests failed' -ForegroundColor Red
    Write-FailureLog 'downstream-reviewer-routing-audit-tests'
    exit 1
}

Write-Host 'Running docs link checker tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'docs-link-checker-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Docs link checker tests failed' -ForegroundColor Red
    Write-FailureLog 'docs-link-checker-tests'
    exit 1
}

Write-Host 'Running issue-to-spec synthesis tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'issue-to-spec-synthesis-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Issue-to-spec synthesis tests failed' -ForegroundColor Red
    Write-FailureLog 'issue-to-spec-synthesis-tests'
    exit 1
}

Write-Host 'Running human approval boundaries policy tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'human-approval-boundaries-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Human approval boundaries policy tests failed' -ForegroundColor Red
    Write-FailureLog 'human-approval-boundaries-tests'
    exit 1
}

Write-Host 'Running ship-it intent dispatch tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ship-it-dispatch-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Ship-it intent dispatch tests failed' -ForegroundColor Red
    Write-FailureLog 'ship-it-dispatch-tests'
    exit 1
}

Write-Host 'Running skill workflow dependency tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'skill-workflow-dependency-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Skill workflow dependency tests failed' -ForegroundColor Red
    Write-FailureLog 'skill-workflow-dependency-tests'
    exit 1
}

Write-Host 'Running ship-it build-break detector tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ship-it-build-break-detector-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Ship-it build-break detector tests failed' -ForegroundColor Red
    Write-FailureLog 'ship-it-build-break-detector-tests'
    exit 1
}

Write-Host 'Running ship-it release gate enforcer tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'ship-it-release-gate-enforcer-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Ship-it release gate enforcer tests failed' -ForegroundColor Red
    Write-FailureLog 'ship-it-release-gate-enforcer-tests'
    exit 1
}

Write-Host 'Running workflow enhancements (#1389) tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-enhancements-1389-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Workflow enhancements (#1389) tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-enhancements-1389-tests'
    exit 1
}

Write-Host 'Running reviewer autoassign collaborator eligibility tests (#1575)...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'reviewer-autoassign-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Reviewer autoassign tests failed' -ForegroundColor Red
    Write-FailureLog 'reviewer-autoassign-tests'
    exit 1
}

Write-Host 'Running routing guardrail tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'routing-guardrail-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Routing guardrail tests failed' -ForegroundColor Red
    Write-FailureLog 'routing-guardrail-tests'
    exit 1
}

Write-Host 'Running pr-lifecycle routing coverage tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'pr-lifecycle-routing-coverage-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'pr-lifecycle routing coverage tests failed' -ForegroundColor Red
    Write-FailureLog 'pr-lifecycle-routing-coverage-tests'
    exit 1
}

Write-Host 'Running lane closeout tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'lane-closeout-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Lane closeout tests failed' -ForegroundColor Red
    Write-FailureLog 'lane-closeout-tests'
    exit 1
}

Write-Host 'Running repo-cleanup contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'repo-cleanup-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Repo-cleanup contract tests failed' -ForegroundColor Red
    Write-FailureLog 'repo-cleanup-tests'
    exit 1
}

Write-Host 'Running cleanup branch automation tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'cleanup-branches-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Cleanup branch automation tests failed' -ForegroundColor Red
    Write-FailureLog 'cleanup-branches-tests'
    exit 1
}

Write-Host 'Running orphaned-lane publisher tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'publish-orphaned-lane-ledger-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Orphaned-lane publisher tests failed' -ForegroundColor Red
    Write-FailureLog 'publish-orphaned-lane-ledger-tests'
    exit 1
}

Write-Host 'Running issue triage script tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'issue-triage-script-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Issue triage script tests failed' -ForegroundColor Red
    Write-FailureLog 'issue-triage-script-tests'
    exit 1
}

Write-Host 'Running triage-field-sync contract tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'workflow-triage-field-sync-contract.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Triage-field-sync contract tests failed' -ForegroundColor Red
    Write-FailureLog 'workflow-triage-field-sync-contract'
    exit 1
}

Write-Host 'Running hook pack contract tests...'
& pwsh -NoProfile -File (Join-Path $repoRoot 'scripts' 'validate-hook-packs.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Hook pack contract tests failed' -ForegroundColor Red
    Write-FailureLog 'validate-hook-packs'
    exit 1
}

Write-Host 'Running generate registry tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'generate-registry-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Generate registry tests failed' -ForegroundColor Red
    Write-FailureLog 'generate-registry-tests'
    exit 1
}

Write-Host 'Running prompt library tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'prompt-library-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Prompt library tests failed' -ForegroundColor Red
    Write-FailureLog 'prompt-library-tests'
    exit 1
}

Write-Host 'Running data workload tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'data-workload-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Data workload tests failed' -ForegroundColor Red
    Write-FailureLog 'data-workload-tests'
    exit 1
}

Write-Host 'Running AIDL portfolio project bootstrap tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-portfolio-project-bootstrap-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL portfolio project bootstrap tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-portfolio-project-bootstrap-tests'
    exit 1
}

Write-Host 'Running AIDL portfolio rollup and KPI publisher tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-portfolio-rollup-kpi-publisher-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL portfolio rollup and KPI publisher tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-portfolio-rollup-kpi-publisher-tests'
    exit 1
}

Write-Host 'Running AIDL portfolio rollup helper tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-portfolio-rollup-kpi-helpers-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL portfolio rollup helper tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-portfolio-rollup-kpi-helpers-tests'
    exit 1
}

Write-Host 'Running AIDL portfolio rollup scorecard tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-portfolio-rollup-scorecard-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL portfolio rollup scorecard tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-portfolio-rollup-scorecard-tests'
    exit 1
}

Write-Host 'Running project rules drift audit tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'project-rules-drift-audit-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Project rules drift audit tests failed' -ForegroundColor Red
    Write-FailureLog 'project-rules-drift-audit-tests'
    exit 1
}

Write-Host 'Running Keep/Fix/Throttle weekly scorecard tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'keep-fix-throttle-weekly-scorecard-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Keep/Fix/Throttle weekly scorecard tests failed' -ForegroundColor Red
    Write-FailureLog 'keep-fix-throttle-weekly-scorecard-tests'
    exit 1
}

Write-Host 'Running Keep/Fix/Throttle helper tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'keep-fix-throttle-helpers-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Keep/Fix/Throttle helper tests failed' -ForegroundColor Red
    Write-FailureLog 'keep-fix-throttle-helpers-tests'
    exit 1
}
 
Write-Host 'Running AIDL learning-to-memory promotion pipeline tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-learning-memory-promotion-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL learning-to-memory promotion pipeline tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-learning-memory-promotion-tests'
    exit 1
}

Write-Host 'Running AIDL memory hygiene sweep tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-memory-hygiene-sweep-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL memory hygiene sweep tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-memory-hygiene-sweep-tests'
    exit 1
}

Write-Host 'Running chronicle-to-story export tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'chronicle-to-story-export-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'chronicle-to-story export tests failed' -ForegroundColor Red
    Write-FailureLog 'chronicle-to-story-export-tests'
    exit 1
}

Write-Host 'Running AIDL incident routing verification tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-incident-routing-verification-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL incident routing verification tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-incident-routing-verification-tests'
    exit 1
}

Write-Host 'Running AIDL incident-to-backlog router tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'aidl-incident-to-backlog-router-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'AIDL incident-to-backlog router tests failed' -ForegroundColor Red
    Write-FailureLog 'aidl-incident-to-backlog-router-tests'
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

Write-Host 'Running agent-merge eval policy tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'agent-merge-eval-policy-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Agent-merge eval policy tests failed' -ForegroundColor Red
    Write-FailureLog 'agent-merge-eval-policy-tests'
    exit 1
}

Write-Host 'Running generate agent eval stubs tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'generate-agent-eval-stubs-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Generate agent eval stubs tests failed' -ForegroundColor Red
    Write-FailureLog 'generate-agent-eval-stubs-tests'
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

Write-Host 'Running token-cost-compare tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'token-cost-compare-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Token-cost-compare tests failed' -ForegroundColor Red
    Write-FailureLog 'token-cost-compare-tests'
    exit 1
}

Write-Host 'Running generate registry tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'generate-registry-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Generate registry tests failed' -ForegroundColor Red
    Write-FailureLog 'generate-registry-tests'
    exit 1
}

Write-Host 'Running publish-to-production dispatch tag tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'publish-to-production-dispatch-tag-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Publish-to-production dispatch tag tests failed' -ForegroundColor Red
    Write-FailureLog 'publish-to-production-dispatch-tag-tests'
    exit 1
}

Write-Host 'Running production hygiene workflow tests...'
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'close-production-issues-workflow-tests.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Production hygiene workflow tests failed' -ForegroundColor Red
    Write-FailureLog 'close-production-issues-workflow-tests'
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
