$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$workflowPath = Join-Path $repoRoot '.github' 'workflows' 'validate-basecoat.yml'
$handFixturePath = Join-Path $PSScriptRoot 'fixtures' 'actionlint' 'hand-authored-queue.yml'
$generatedFixturePath = Join-Path $PSScriptRoot 'fixtures' 'actionlint' 'generated-gh-aw.lock.yml'
$errors = @()

foreach ($path in @($workflowPath, $handFixturePath, $generatedFixturePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        $errors += "Required actionlint contract file is missing: $path"
    }
}

if ($errors.Count -eq 0) {
    $workflow = Get-Content -LiteralPath $workflowPath -Raw
    $handFixture = Get-Content -LiteralPath $handFixturePath -Raw
    $generatedFixture = Get-Content -LiteralPath $generatedFixturePath -Raw

    foreach ($requiredText in @(
        'hand_authored_args=',
        'generated_lock_args=',
        'Lint hand-authored workflows',
        'Lint generated gh-aw locks',
        'Hand-authored queue regression is rejected',
        'Generated gh-aw compatibility regression passes'
    )) {
        if (-not $workflow.Contains($requiredText)) {
            $errors += "validate-basecoat.yml is missing actionlint split contract text: $requiredText"
        }
    }

    $handLintSection = [regex]::Match(
        $workflow,
        '(?ms)- name: Lint hand-authored workflows.*?(?=\n\s*- name: Lint generated gh-aw locks)'
    ).Value
    foreach ($pattern in @(
        'unknown permission scope \"copilot-requests\"',
        'unexpected key \"queue\" for \"concurrency\" section'
    )) {
        if ($handLintSection.Contains($pattern)) {
            $errors += "Hand-authored actionlint invocation must not ignore: $pattern"
        }
    }

    foreach ($fixture in @($handFixture, $generatedFixture)) {
        if (-not $fixture.Contains('queue: max')) {
            $errors += 'Both actionlint regression fixtures must exercise concurrency.queue'
        }
    }
    if (-not $generatedFixture.Contains('copilot-requests: write')) {
        $errors += 'Generated actionlint fixture must exercise copilot-requests permission compatibility'
    }
}

Write-Host 'Running actionlint compatibility contract checks...'

if ($errors.Count -gt 0) {
    Write-Host 'Actionlint compatibility contract FAILED.' -ForegroundColor Red
    foreach ($errorMessage in $errors) {
        Write-Host "  - $errorMessage" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'Actionlint compatibility contract passed.' -ForegroundColor Green
exit 0
