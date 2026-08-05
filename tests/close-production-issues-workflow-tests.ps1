$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

Write-Host 'Running production hygiene workflow tests...'

$workflowPath = Join-Path $repoRoot '.github\workflows\close-production-issues.yml'
if (-not (Test-Path $workflowPath)) {
    throw "Missing workflow file: $workflowPath"
}

$content = Get-Content $workflowPath -Raw

foreach ($inputName in @('issue_numbers', 'pr_numbers', 'branch_names')) {
    $inputPattern = "(?ms)^\s{6}${inputName}:\s*\r?\n.*?^\s{8}default:\s*`"`"\s*\r?\n\s{8}type:\s*string\s*$"
    if ($content -notmatch $inputPattern) {
        throw "Production hygiene workflow must define optional string input '$inputName' with an empty default"
    }
}

if ($content -notmatch '(?ms)^\s{6}dry_run:\s*\r?\n.*?^\s{8}default:\s*true\s*\r?\n\s{8}type:\s*boolean\s*$') {
    throw 'Production hygiene workflow must default dry_run to true'
}

foreach ($requiredText in @(
        'Protected branch deletion is forbidden',
        'Wildcard branch values are forbidden',
        'Use an exact branch name, not a refs/heads path',
        'No hygiene targets supplied',
        'PR #$pr is not recognized as Dependabot or mirror automation noise',
        'git/refs/heads/$encoded_branch'
    )) {
    if (-not $content.Contains($requiredText)) {
        throw "Production hygiene workflow is missing safety contract: $requiredText"
    }
}

if ($content -match 'for PR in 154 192|declare -A MIGRATIONS|seq 166 180|seq 181 190|seq 193 197') {
    throw 'Production hygiene workflow still contains unsafe hard-coded legacy cleanup targets'
}

$prCommentIndex = $content.IndexOf('issues/$pr/comments')
$prCloseIndex = $content.IndexOf('pulls/$pr" -f state=closed')
$issueCommentIndex = $content.IndexOf('issues/$issue/comments')
$issueCloseIndex = $content.IndexOf('issues/$issue" -f state=closed')
if ($prCommentIndex -lt 0 -or $prCloseIndex -le $prCommentIndex) {
    throw 'Production hygiene workflow must comment before closing a PR'
}
if ($issueCommentIndex -lt 0 -or $issueCloseIndex -le $issueCommentIndex) {
    throw 'Production hygiene workflow must comment before closing an issue'
}

$stepStart = $content.IndexOf('      - name: Validate and apply explicit hygiene plan')
$runMarker = '        run: |'
$runMarkerStart = $content.IndexOf($runMarker, $stepStart)
if ($stepStart -lt 0 -or $runMarkerStart -lt 0) {
    throw 'Unable to extract production hygiene workflow script'
}

$scriptBlock = $content.Substring($runMarkerStart + $runMarker.Length) -replace "^\r?\n", ''
$scriptLines = @(
    $scriptBlock -split "\r?\n" |
        ForEach-Object {
            if ($_.StartsWith('          ')) {
                $_.Substring(10)
            }
            else {
                $_
            }
        }
)

$scratchRoot = Join-Path $repoRoot ('test-results\production-hygiene-' + [Guid]::NewGuid().ToString('N'))
$fakeBin = Join-Path $scratchRoot 'bin'
$scriptPath = Join-Path $scratchRoot 'hygiene.sh'
$ghLog = Join-Path $scratchRoot 'gh.log'
$summaryPath = Join-Path $scratchRoot 'summary.md'
$oldPath = $env:PATH

try {
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    [System.IO.File]::WriteAllText(
        $scriptPath,
        (($scriptLines -join "`n") + "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )

    $fakeGh = @'
#!/usr/bin/env bash
set -euo pipefail
{
  printf '%s' "$1"
  shift
  printf '|%s' "$@"
  printf '\n'
} >> "$GH_LOG"

args="$*"
if [[ "$args" == *"--method POST"* || "$args" == *"--method PATCH"* || "$args" == *"--method DELETE"* ]]; then
  printf '{}\n'
elif [[ "$args" == *"pulls/228"* ]]; then
  printf '%s\n' '{"state":"open","user":{"login":"dependabot[bot]"},"head":{"ref":"dependabot/github_actions/actions/checkout-7.0.1"},"labels":[{"name":"dependencies"}]}'
elif [[ "$args" == *"issues/221"* ]]; then
  printf '%s\n' '{"state":"open","title":"Mirror issue"}'
elif [[ "$args" == *"git/ref/heads/automation%2Ftoken-inventory"* ]]; then
  printf '%s\n' '{"ref":"refs/heads/automation/token-inventory"}'
elif [[ "$args" == *"repos/ivegamsft/basecoat"* ]]; then
  printf '{}\n'
else
  echo "Unexpected gh invocation: $args" >&2
  exit 1
fi
'@
    $fakeGhPath = Join-Path $fakeBin 'gh'
    [System.IO.File]::WriteAllText(
        $fakeGhPath,
        ($fakeGh -replace "`r`n", "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    if (-not $IsWindows) {
        & chmod +x $fakeGhPath
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to make the fake GitHub CLI executable'
        }
    }

    $gitCommand = Get-Command git -ErrorAction Stop
    $gitRoot = Split-Path (Split-Path $gitCommand.Source -Parent) -Parent
    $bashPath = Join-Path $gitRoot 'bin\bash.exe'
    if (-not (Test-Path $bashPath)) {
        $bashPath = (Get-Command bash -ErrorAction Stop).Source
    }

    $env:PATH = "$fakeBin$([System.IO.Path]::PathSeparator)$oldPath"
    $env:GH_LOG = $ghLog
    $env:GH_TOKEN = 'test-token'
    $env:PROD_REPO = 'ivegamsft/basecoat'
    $env:GITHUB_STEP_SUMMARY = $summaryPath

    function Invoke-HygieneScript {
        param(
            [string]$Issues = '',
            [string]$PullRequests = '',
            [string]$Branches = '',
            [string]$DryRun = 'true'
        )

        Set-Content -Path $ghLog -Value '' -NoNewline
        Set-Content -Path $summaryPath -Value '' -NoNewline
        $env:ISSUE_NUMBERS = $Issues
        $env:PR_NUMBERS = $PullRequests
        $env:BRANCH_NAMES = $Branches
        $env:DRY_RUN = $DryRun
        $output = @(& $bashPath $scriptPath 2>&1)
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = $output
            GhLog = @(Get-Content $ghLog -ErrorAction SilentlyContinue)
        }
    }

    $invalidNumber = Invoke-HygieneScript -Issues '221,abc'
    if ($invalidNumber.ExitCode -eq 0 -or ($invalidNumber.Output -join "`n") -notmatch 'Invalid issue number') {
        throw 'Production hygiene workflow accepted a malformed issue number'
    }

    foreach ($unsafeBranch in @('main', 'gh-pages', 'feature/*', 'feature,,other')) {
        $result = Invoke-HygieneScript -Branches $unsafeBranch
        if ($result.ExitCode -eq 0) {
            throw "Production hygiene workflow accepted unsafe branch input: $unsafeBranch"
        }
    }

    $dryRun = Invoke-HygieneScript `
        -Issues '221' `
        -PullRequests '228' `
        -Branches 'automation/token-inventory' `
        -DryRun 'true'
    if ($dryRun.ExitCode -ne 0) {
        throw "Production hygiene dry run failed: $($dryRun.Output -join "`n")"
    }
    if (($dryRun.GhLog -join "`n") -match '--method\|(POST|PATCH|DELETE)') {
        throw 'Production hygiene dry run attempted a mutating GitHub API request'
    }
    if (($dryRun.Output -join "`n") -notmatch '\[DRY RUN\].*PR #228' -or
        ($dryRun.Output -join "`n") -notmatch '\[DRY RUN\].*issue #221' -or
        ($dryRun.Output -join "`n") -notmatch "\[DRY RUN\].*automation/token-inventory") {
        throw 'Production hygiene dry run did not report every explicit target'
    }

    $liveRun = Invoke-HygieneScript `
        -Issues '221' `
        -PullRequests '228' `
        -Branches 'automation/token-inventory' `
        -DryRun 'false'
    if ($liveRun.ExitCode -ne 0) {
        throw "Production hygiene live-mode fixture failed: $($liveRun.Output -join "`n")"
    }

    $log = $liveRun.GhLog -join "`n"
    $prComment = $log.IndexOf('api|--method|POST|repos/ivegamsft/basecoat/issues/228/comments')
    $prClose = $log.IndexOf('api|--method|PATCH|repos/ivegamsft/basecoat/pulls/228')
    $issueComment = $log.IndexOf('api|--method|POST|repos/ivegamsft/basecoat/issues/221/comments')
    $issueClose = $log.IndexOf('api|--method|PATCH|repos/ivegamsft/basecoat/issues/221')
    if ($prComment -lt 0 -or $prClose -le $prComment) {
        throw 'Production hygiene live mode did not comment before closing PR #228'
    }
    if ($issueComment -lt 0 -or $issueClose -le $issueComment) {
        throw 'Production hygiene live mode did not comment before closing issue #221'
    }
    if ($log -notmatch 'api\|--method\|DELETE\|repos/ivegamsft/basecoat/git/refs/heads/automation%2Ftoken-inventory') {
        throw 'Production hygiene live mode did not delete only the exact encoded branch ref'
    }
}
finally {
    $env:PATH = $oldPath
    foreach ($name in @(
            'GH_LOG',
            'GH_TOKEN',
            'PROD_REPO',
            'GITHUB_STEP_SUMMARY',
            'ISSUE_NUMBERS',
            'PR_NUMBERS',
            'BRANCH_NAMES',
            'DRY_RUN'
        )) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    Remove-Item -Path $scratchRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Production hygiene workflow tests passed' -ForegroundColor Green
exit 0
