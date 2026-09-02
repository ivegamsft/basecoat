$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$runtimePath = Join-Path $repoRoot '.github\workflows\merge-eligibility-human-review-reconcile.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\merge-eligibility-human-review-reconcile.yml'
$executorPath = Join-Path $repoRoot '.github\workflows\pr-auto-merge-executor.yml'

foreach ($path in @($runtimePath, $templatePath, $executorPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing workflow file: $path"
    }
}

function Assert-Match {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Message
    )

    if ($Content -notmatch $Pattern) {
        throw $Message
    }
}

$runtime = Get-Content $runtimePath -Raw
$template = Get-Content $templatePath -Raw
$executor = Get-Content $executorPath -Raw

$reviewTrigger = [regex]::Match(
    $executor,
    '(?ms)^\s{2}pull_request_review:\s*\r?\n(?<block>.*?)(?=^\s{2}[a-z_]+:\s*$|^permissions:\s*$)'
)
if (-not $reviewTrigger.Success) {
    throw 'Privileged executor may keep dismissal-only pull_request_review; it must not omit the block without this unprivileged listener.'
}
if ($reviewTrigger.Groups['block'].Value -match '(?m)(?:\[\s*submitted\s*\]|^\s*-\s*submitted\s*$|^\s*-\s*edited\s*$)') {
    throw 'Privileged executor must not restore submitted or edited pull_request_review triggers.'
}

foreach ($entry in @(
        @{ Name = '.github/workflows/merge-eligibility-human-review-reconcile.yml'; Content = $runtime; WorkflowId = 'pr-auto-merge-executor.yml' },
        @{ Name = '.github/base-coat/workflows/merge-eligibility-human-review-reconcile.yml'; Content = $template; WorkflowId = 'basecoat-pr-auto-merge-executor.yml' }
    )) {
    $name = $entry.Name
    $content = $entry.Content

    if ($content -match '(?m)(?:\[\s*submitted\s*\]|^\s*-\s*submitted\s*$|^\s*-\s*edited\s*$)') {
        throw "$name must not subscribe to submitted or edited pull_request_review events; Copilot reviewer triggers become action_required before job filters run."
    }
    Assert-Match $content '(?ms)pull_request_review:\s*\r?\n\s*types:\s*\r?\n\s*-\s*dismissed' "$name may listen to human review dismissal only."
    Assert-Match $content '(?m)^\s*schedule:\s*$' "$name must poll current-head human approvals on a schedule for team-dev."
    Assert-Match $content "github\.event\.review\.user\.type != 'Bot'" "$name must ignore Copilot/bot reviewers so those runs no-op if later approved."
    Assert-Match $content "github\.actor != 'copilot-pull-request-reviewer\[bot\]'" "$name must skip the Copilot reviewer app actor."
    Assert-Match $content "github\.actor != 'Copilot'" "$name must skip the Copilot actor login observed on action_required review runs."
    Assert-Match $content 'hasCurrentHeadHumanApproval' "$name must dispatch scheduled reconciliation only for current-head human approvals."
    Assert-Match $content 'ref:\s*\$\{\{\s*github\.event\.repository\.default_branch\s*\}\}' "$name must load governance only from the trusted default branch."
    Assert-Match $content 'main\.reconcile_merge_eligibility // false' "$name must honor the reconciliation policy pack flag."
    Assert-Match $content 'github\.rest\.pulls\.get' "$name must revalidate the live pull request before dispatch."
    Assert-Match $content 'pullRequest\.state !== ''open''' "$name must refuse dispatch when the PR is no longer open."
    Assert-Match $content 'eventHead !== liveHead' "$name must prefer the live PR head over a stale review event SHA."
    Assert-Match $content ([regex]::Escape("workflow_id: '$($entry.WorkflowId)'")) "$name must dispatch the installed executor by filename."
    Assert-Match $content "ref: defaultBranch" "$name must dispatch the executor from the trusted default branch."
}

if ($runtime -match '(?m)^\s*contents:\s*write\s*$' -or $template -match '(?m)^\s*contents:\s*write\s*$') {
    throw 'Human-review reconcile workflows must not request contents: write.'
}

$policyPath = Join-Path $repoRoot '.github\governance\policy-packs.json'
$distributedPolicyPath = Join-Path $repoRoot '.github\base-coat\governance\policy-packs.json'
foreach ($path in @($policyPath, $distributedPolicyPath)) {
    $policy = Get-Content -Path $path -Raw | ConvertFrom-Json
    if ($policy.profiles.'solo-dev'.main.reconcile_merge_eligibility -ne $false) {
        throw "$path must disable human-review merge eligibility reconciliation for solo-dev."
    }
    if ($policy.profiles.'team-dev'.main.reconcile_merge_eligibility -ne $true -or
        $policy.profiles.'regulated-team'.main.reconcile_merge_eligibility -ne $true) {
        throw "$path must keep human-review merge eligibility reconciliation for team and regulated profiles."
    }
}

Write-Host 'Merge eligibility human-review reconcile tests passed.'
