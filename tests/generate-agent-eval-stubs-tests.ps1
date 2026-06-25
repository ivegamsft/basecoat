#!/usr/bin/env pwsh
<#
.SYNOPSIS
Tests for scripts/generate-agent-eval-stubs.ps1.

.DESCRIPTION
Verifies that:
- The script generates the correct filename: <full-stem>.agent.eval.yaml
  (matches what the agent-merge CI guardrail checks for)
- The generated YAML content uses the full stem for name/skill fields
- The generated YAML uses the internal frontmatter name for description/scenarios
- DryRun mode does not write files
- Force mode regenerates existing stubs
- Skipping works when the eval file already exists

.EXAMPLE
.\generate-agent-eval-stubs-tests.ps1
#>

$ErrorActionPreference = 'Stop'

$repoRoot   = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'scripts/generate-agent-eval-stubs.ps1'
$tempDir    = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-agent-eval-test-" + [System.Guid]::NewGuid().ToString())

$script:passed = 0
$script:failed = 0

function Test-Assert {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host "✓ $Name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "✗ $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "  └─ $Detail" -ForegroundColor Yellow }
        $script:failed++
    }
}

Write-Host 'Running generate-agent-eval-stubs tests...' -ForegroundColor Blue
Write-Host ''

# ── Script exists ──────────────────────────────────────────────────────────────
Test-Assert 'generate-agent-eval-stubs.ps1 exists' (Test-Path $scriptPath) "Expected: $scriptPath"

if (-not (Test-Path $scriptPath)) {
    Write-Host "`nCannot continue: script file missing." -ForegroundColor Red
    exit 1
}

# ── Setup temp agent directory ─────────────────────────────────────────────────
try {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tempDir 'agents') | Out-Null

    # Create a test agent .md file mimicking the repository naming convention
    $testAgentContent = @"
---
name: test-widget
description: "Test widget agent. USE FOR: widget operations, widget management. DO NOT USE FOR: non-widget tasks."
visibility: basic
---

# Test Widget Agent

Test agent body.
"@

    $testAgentFile = Join-Path $tempDir 'agents/basecoat-99-test-test-widget.agent.md'
    Set-Content -Path $testAgentFile -Value $testAgentContent -Encoding UTF8

    # ── DryRun does not create file ────────────────────────────────────────────────
    $dryRunOutput = & pwsh -NoProfile -File $scriptPath -AgentsDir (Join-Path $tempDir 'agents') -DryRun 2>&1
    $expectedEvalPath = Join-Path $tempDir 'agents/basecoat-99-test-test-widget.agent.eval.yaml'

    Test-Assert 'DryRun mode does not write eval file' `
        (-not (Test-Path $expectedEvalPath)) `
        "File should not exist after -DryRun: $expectedEvalPath"

    Test-Assert 'DryRun output contains correct eval filename' `
        ([bool]($dryRunOutput -join '' | Select-String 'basecoat-99-test-test-widget.agent.eval.yaml')) `
        "DryRun should show the target .agent.eval.yaml filename"

    # ── Normal run creates file with correct name ──────────────────────────────────
    & pwsh -NoProfile -File $scriptPath -AgentsDir (Join-Path $tempDir 'agents') 2>&1 | Out-Null

    Test-Assert 'Generated eval file has correct <full-stem>.agent.eval.yaml name' `
        (Test-Path $expectedEvalPath) `
        "Expected file: $expectedEvalPath — script must NOT generate <short-name>.eval.yaml"

    # ── Verify file content ────────────────────────────────────────────────────────
    if (Test-Path $expectedEvalPath) {
        $evalContent = Get-Content $expectedEvalPath -Raw

        Test-Assert 'Generated YAML name field uses full filename stem' `
            ($evalContent -match "name: 'basecoat-99-test-test-widget-routing'") `
            "name: field must use full stem, not short name"

        Test-Assert 'Generated YAML skill field uses full filename path' `
            ($evalContent -match "skill: 'agents/basecoat-99-test-test-widget\.agent\.md'") `
            "skill: field must reference the full agent filename"

        Test-Assert 'Generated YAML description uses internal agent name' `
            ($evalContent -match "test-widget agent") `
            "description/scenarios must reference the frontmatter internal name"

        Test-Assert 'Generated YAML contains pos-1 scenario' `
            ($evalContent -match "id: 'pos-1'") `
            "Must contain at least pos-1 activation scenario"

        Test-Assert 'Generated YAML contains neg-1 scenario' `
            ($evalContent -match "id: 'neg-1'") `
            "Must contain at least neg-1 non-activation scenario"

        Test-Assert 'Generated YAML pos scenario has expect_activation: true' `
            ($evalContent -match 'expect_activation: true') `
            "Positive scenarios must have expect_activation: true"

        Test-Assert 'Generated YAML neg scenario has expect_activation: false' `
            ($evalContent -match 'expect_activation: false') `
            "Negative scenarios must have expect_activation: false"
    }

    # ── Skip when eval already exists ─────────────────────────────────────────────
    $secondRunOutput = & pwsh -NoProfile -File $scriptPath -AgentsDir (Join-Path $tempDir 'agents') 2>&1
    Test-Assert 'Second run without -Force skips existing eval file' `
        (($secondRunOutput -join '') -match 'skipped 1') `
        "Should report skipped:1 when eval companion already exists"

    # ── Force regenerates existing stubs ──────────────────────────────────────────
    $forceOutput = & pwsh -NoProfile -File $scriptPath -AgentsDir (Join-Path $tempDir 'agents') -Force 2>&1
    Test-Assert 'Force mode regenerates existing eval stub' `
        (($forceOutput -join '') -match 'Generated 1') `
        "Should report Generated:1 when -Force is used even if file exists"

    # ── Guardrail check: no .agent.eval.yaml missing after run ────────────────────
    $agentFiles  = Get-ChildItem (Join-Path $tempDir 'agents') -Filter '*.agent.md'
    $missingEval = $agentFiles | Where-Object {
        $stem     = $_.BaseName -replace '\.agent$', ''
        $evalPath = Join-Path $_.DirectoryName "$stem.agent.eval.yaml"
        -not (Test-Path $evalPath)
    }
    Test-Assert 'No .agent.eval.yaml missing after generate run (guardrail simulation)' `
        ($missingEval.Count -eq 0) `
        ("Still missing: " + ($missingEval.Name -join ', '))
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ''
$total = $script:passed + $script:failed
Write-Host "Results: $($script:passed) passed, $($script:failed) failed" `
    -ForegroundColor $(if ($script:failed -eq 0) { 'Green' } else { 'Red' })

if ($script:failed -gt 0) {
    exit 1
}
