#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Contract tests for issue #3859: automation PRs must dispatch the PR size labeler.

.DESCRIPTION
    Events caused by GITHUB_TOKEN never start pull_request_target workflows, so a
    PR created or edited by a workflow with github.token never reaches
    pr-size-labeler.yml. Every workflow that runs `gh pr create` or
    `pulls.create` must dispatch the labeler after its last PR create or edit,
    hold `actions: write`, and warn when GH_AW_GITHUB_TOKEN falls back to
    github.token. A workflow whose PR is written with a non-GITHUB_TOKEN
    credential may opt out with a `pr-triage-dispatch: exempt (<reason>)` marker.
#>

param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$helperRelPath = '.github/base-coat/scripts/dispatch-pr-triage.sh'
$helperPath = Join-Path $repoRoot $helperRelPath

Write-Host 'Running automation PR triage dispatch contract tests...'

$failures = [System.Collections.Generic.List[string]]::new()

function Get-PrTriageViolations {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Content
    )

    $violations = @()
    $writePattern = 'gh pr create|gh pr edit|pulls\.create\(|pulls\.update\('
    if ($Content -notmatch 'gh pr create|pulls\.create\b') {
        return $violations
    }
    if ($Content -match 'pr-triage-dispatch:\s*exempt\s*\(\S[^)]*\)') {
        return $violations
    }

    $dispatchPattern = 'dispatch-pr-triage\.sh|createWorkflowDispatch'
    $dispatchMatches = [regex]::Matches($Content, $dispatchPattern)
    if ($dispatchMatches.Count -eq 0) {
        $violations += "${Name}: creates a PR but never dispatches the PR size labeler"
        return $violations
    }
    if ($Content -notmatch 'dispatch-pr-triage\.sh' -and $Content -notmatch 'pr-size-labeler\.yml') {
        $violations += "${Name}: createWorkflowDispatch does not target pr-size-labeler.yml"
    }

    $writeMatches = [regex]::Matches($Content, $writePattern)
    $lastWrite = $writeMatches[$writeMatches.Count - 1].Index
    $lastDispatch = $dispatchMatches[$dispatchMatches.Count - 1].Index
    if ($lastDispatch -lt $lastWrite) {
        $violations += "${Name}: the labeler dispatch must follow the last PR create or edit"
    }

    if ($Content -notmatch '(?m)^permissions:\s*\r?\n(?:[ ]+\S.*\r?\n)*?[ ]+actions:\s*write') {
        $violations += "${Name}: workflow permissions must grant actions: write for the labeler dispatch"
    }

    if ($Content -match 'dispatch-pr-triage\.sh') {
        foreach ($envName in 'AUTOMATION_TOKEN_CONFIGURED', 'DISPATCH_GH_TOKEN') {
            if ($Content -notmatch "$envName\s*:") {
                $violations += "${Name}: the dispatch step must set $envName for the helper"
            }
        }
    } elseif ($Content -match 'GH_AW_GITHUB_TOKEN' -and $Content -notmatch 'core\.warning\(`GH_AW_GITHUB_TOKEN is not configured') {
        $violations += "${Name}: must warn when GH_AW_GITHUB_TOKEN falls back to github.token"
    }

    return $violations
}

# The detector must flag an undispatched PR creator and accept a dispatched one.
$fixtureMissing = "permissions:`n  contents: write`njobs:`n  x:`n    steps:`n      - run: gh pr create --base main`n"
if ((Get-PrTriageViolations -Name 'fixture-missing' -Content $fixtureMissing).Count -eq 0) {
    $failures.Add('detector did not flag a workflow that creates a PR without dispatching the labeler')
}
$fixtureOrder = "permissions:`n  actions: write`njobs:`n  x:`n    env:`n      AUTOMATION_TOKEN_CONFIGURED: x`n      DISPATCH_GH_TOKEN: x`n    steps:`n      - run: |`n          bash $helperRelPath 1`n          gh pr create --base main`n"
if ((Get-PrTriageViolations -Name 'fixture-order' -Content $fixtureOrder).Count -eq 0) {
    $failures.Add('detector did not flag a labeler dispatch that precedes the PR create')
}
$fixtureGood = "permissions:`n  actions: write`n  contents: write`njobs:`n  x:`n    env:`n      AUTOMATION_TOKEN_CONFIGURED: x`n      DISPATCH_GH_TOKEN: x`n    steps:`n      - run: |`n          gh pr create --base main`n          bash $helperRelPath 1`n"
$goodViolations = @(Get-PrTriageViolations -Name 'fixture-good' -Content $fixtureGood)
if ($goodViolations.Count -ne 0) {
    $failures.Add("detector rejected a compliant workflow: $($goodViolations -join '; ')")
}

$workflowDirs = @('.github/workflows', '.github/base-coat/workflows') |
    ForEach-Object { Join-Path $repoRoot $_ } |
    Where-Object { Test-Path $_ }
$creators = 0
foreach ($file in Get-ChildItem -Path $workflowDirs -Filter *.yml -File) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'gh pr create|pulls\.create\b') { $creators++ }
    $relative = [System.IO.Path]::GetRelativePath($repoRoot, $file.FullName) -replace '\\', '/'
    foreach ($violation in (Get-PrTriageViolations -Name $relative -Content $content)) {
        $failures.Add($violation)
    }
}
if ($creators -eq 0) {
    $failures.Add('no PR-creating workflows were found; the scan is not reading workflow files')
}

if (-not (Test-Path $helperPath)) {
    $failures.Add("missing helper: $helperRelPath")
} else {
    $helper = Get-Content $helperPath -Raw
    if ($helper -notmatch 'gh workflow run "\$workflow"[^\n]*-f "pr_number=\$\{pr_number\}"') {
        $failures.Add('helper must run gh workflow run <labeler> -f pr_number=<n>')
    }
    foreach ($labeler in 'pr-size-labeler.yml', 'basecoat-pr-size-labeler.yml') {
        if ($helper -notmatch [regex]::Escape($labeler)) {
            $failures.Add("helper must try the $labeler labeler name")
        }
    }
    if ($helper -notmatch '::warning::GH_AW_GITHUB_TOKEN is not configured') {
        $failures.Add('helper must emit a ::warning:: when falling back to github.token')
    }
    if ($helper -notmatch 'DISPATCH_GH_TOKEN') {
        $failures.Add('helper must dispatch with DISPATCH_GH_TOKEN (github.token with actions: write)')
    }

    $bashPath = if ($IsWindows) {
        $gitRoot = Split-Path (Split-Path (Get-Command git -ErrorAction Stop).Source -Parent) -Parent
        Join-Path $gitRoot 'bin\bash.exe'
    } else { (Get-Command bash -ErrorAction Stop).Source }
    $stub = @'
gh() {
  if [[ "$1" == "api" ]]; then
    if [[ "$scenario" == "lookup-error" ]]; then
      echo "workflow inventory denied" >&2
      return 23
    fi
    case "$scenario" in
      consumer) echo ".github/workflows/basecoat-pr-size-labeler.yml" ;;
      missing) ;;
      *) echo ".github/workflows/pr-size-labeler.yml" ;;
    esac
  elif [[ "$1 $2" == "workflow run" ]]; then
    if [[ "$scenario" == "dispatch-error" ]]; then
      echo "workflow dispatch denied" >&2
      return 24
    fi
    echo "dispatch:$3"
  else
    echo "unexpected gh invocation: $*" >&2
    return 25
  fi
}
export -f gh
export GITHUB_REPOSITORY=owner/repo AUTOMATION_TOKEN_CONFIGURED=true
scenario="$1"
export scenario
bash .github/base-coat/scripts/dispatch-pr-triage.sh 42
'@
    Push-Location $repoRoot
    try {
        foreach ($case in @(
            @{ Name = 'canonical'; Code = 0; Output = 'dispatch:pr-size-labeler.yml' },
            @{ Name = 'consumer'; Code = 0; Output = 'dispatch:basecoat-pr-size-labeler.yml' },
            @{ Name = 'missing'; Code = 0; Output = '::warning::No PR size labeler workflow is installed' },
            @{ Name = 'lookup-error'; Code = 23; Output = 'workflow inventory denied' },
            @{ Name = 'dispatch-error'; Code = 24; Output = 'workflow dispatch denied' }
        )) {
            $output = & $bashPath -c $stub fixture $case.Name 2>&1 | Out-String
            if ($LASTEXITCODE -ne $case.Code -or -not $output.Contains($case.Output) -or
                ($case.Code -ne 0 -and $output.Contains('Dispatched '))) {
                $failures.Add("helper scenario '$($case.Name)' did not preserve lookup/dispatch outcome: $output")
            }
        }
    } finally { Pop-Location }
}

if ($failures.Count -gt 0) {
    Write-Host 'Automation PR triage dispatch contract tests failed:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Automation PR triage dispatch contract tests passed ($creators PR-creating workflows checked)." -ForegroundColor Green
exit 0
