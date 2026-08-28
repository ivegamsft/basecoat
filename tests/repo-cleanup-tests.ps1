#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

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

$skillPath = Join-Path $repoRoot 'skills\repo-cleanup\SKILL.md'
$contractPath = Join-Path $repoRoot 'skills\repo-cleanup\contract.md'
$evalPath = Join-Path $repoRoot 'skills\repo-cleanup\eval.yaml'

foreach ($path in @($skillPath, $contractPath, $evalPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing repo-cleanup asset: $path"
    }
}

$skill = Get-Content $skillPath -Raw
$contract = Get-Content $contractPath -Raw
Assert-Match $skill '(?m)^visibility:\s+public\r?$' 'repo-cleanup must be publicly visible'
Assert-Match $skill '(?m)^compatibility:\s+\[github-copilot-cli\]\r?$' 'repo-cleanup must be scoped to github-copilot-cli only (no copilot-coding-agent)'

# Exact-ref compare-and-swap lease (local and remote) — the core safety
# guarantee protecting against a branch/worktree change during the
# step-6 approval pause.
foreach ($guardrail in @(
        'refs/heads/<branch>',
        '--force-with-lease=refs/heads/<branch>:<expected-object-id>',
        'exact-ref compare-and-swap'
    )) {
    Assert-Match $skill ([regex]::Escape($guardrail)) "repo-cleanup skill missing exact-ref lease guardrail: $guardrail"
}

# Final PR/worktree refresh immediately before each deletion (not just
# once for the whole approved batch).
foreach ($guardrail in @(
        'Immediately before deleting each branch',
        'Re-check PR state and worktree mapping immediately before',
        'immediately before each `git worktree remove`'
    )) {
    Assert-Match $skill ([regex]::Escape($guardrail)) "repo-cleanup skill missing last-minute refresh guardrail: $guardrail"
}

# Dry-run report and approval gate covering both worktrees and branches.
foreach ($guardrail in @(
        'Dry-run report and approval gate',
        'Never skip the dry-run report and approval gate'
    )) {
    Assert-Match $skill ([regex]::Escape($guardrail)) "repo-cleanup skill missing dry-run approval gate guardrail: $guardrail"
}

# -D prohibition on local branch deletion.
foreach ($guardrail in @(
        'never `-D`',
        'Never force-delete a local branch (`-D`)'
    )) {
    Assert-Match $skill ([regex]::Escape($guardrail)) "repo-cleanup skill missing -D prohibition guardrail: $guardrail"
}

# Bounded gh pr list queries with an explicit truncation check.
foreach ($guardrail in @(
        '--limit 50',
        'treat a result count equal to the limit as truncated'
    )) {
    Assert-Match $skill ([regex]::Escape($guardrail)) "repo-cleanup skill missing bounded gh pr list guardrail: $guardrail"
}

# This skill must never delegate deletion/pruning to branch-hygiene-sweeper.
Assert-Match $skill ([regex]::Escape('does not delegate any part of its workflow')) 'repo-cleanup skill must state it does not delegate to @branch-hygiene-sweeper'

foreach ($guardrail in @(
        'release/freeze-protected',
        'closed superseded/discarded',
        'active agent use',
        'refresh failure',
        'Never perform destructive operations on `main`'
    )) {
    Assert-Match $contract ([regex]::Escape($guardrail)) "repo-cleanup contract missing moved safety invariant: $guardrail"
}

$eval = Get-Content $evalPath -Raw
foreach ($scenario in @('neg-4', 'neg-5')) {
    Assert-Match $eval ([regex]::Escape($scenario)) "repo-cleanup eval missing negative scenario: $scenario"
}

$routingFiles = @(
    'instructions\basecoat-10-core-intent-routing.instructions.md',
    'instructions\intent-routing.instructions.md',
    'docs\guides\intent-prefixes.md'
)
foreach ($relative in $routingFiles) {
    $path = Join-Path $repoRoot $relative
    $content = Get-Content $path -Raw
    Assert-Match $content 'repo-cleanup' "$relative missing repo-cleanup routing"

    # Table rows: any markdown table row that names the `repo-cleanup:` intent
    # prefix must not also list @branch-hygiene-sweeper as a route target on
    # that same row.
    $tableRowMatches = [regex]::Matches($content, '(?m)^\|.*repo-cleanup:.*\|\s*$')
    foreach ($rowMatch in $tableRowMatches) {
        if ($rowMatch.Value -match '@branch-hygiene-sweeper') {
            throw "$relative table row must not list @branch-hygiene-sweeper alongside the repo-cleanup: intent: $($rowMatch.Value)"
        }
    }

    # Prose paragraphs (exclude markdown table blocks, already checked above
    # on a per-row basis): any non-table paragraph that mentions
    # repo-cleanup: and also names @branch-hygiene-sweeper must explicitly
    # state that repo-cleanup does not delegate to it.
    $paragraphs = [regex]::Split($content, '\r?\n\r?\n') | Where-Object {
        ($_ -split '\r?\n' | Where-Object { $_.TrimStart().StartsWith('|') }).Count -eq 0
    }
    foreach ($paragraph in $paragraphs) {
        $normalized = $paragraph -replace '\s+', ' '
        if ($normalized -match 'repo-cleanup:' -and $normalized -match '@branch-hygiene-sweeper' -and
            $normalized -notmatch 'rather than delegating to `@branch-hygiene-sweeper`') {
            throw "$relative paragraph mentions repo-cleanup: and @branch-hygiene-sweeper without stating repo-cleanup does not delegate to it: $paragraph"
        }
    }
}

Write-Host 'PASS repo-cleanup skill guardrails, eval negatives, and routing are present and consistent'
