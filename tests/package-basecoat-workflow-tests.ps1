[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$packagePath = Join-Path $repoRoot '.github\workflows\package-basecoat.yml'
$validatePath = Join-Path $repoRoot '.github\workflows\validate-basecoat.yml'
$chainPath = Join-Path $repoRoot '.github\workflows\post-merge-release-chain.yml'
$templatePath = Join-Path $repoRoot '.github\base-coat\workflows\post-merge-release-chain.yml'
$fixturePath = Join-Path $PSScriptRoot 'fixtures\release-packaging-targets.json'

$package = Get-Content $packagePath -Raw
$validate = Get-Content $validatePath -Raw
$chain = Get-Content $chainPath -Raw
$template = Get-Content $templatePath -Raw
$fixture = Get-Content $fixturePath -Raw | ConvertFrom-Json

if ($chain -ne $template) {
    throw 'Post-merge release chain workflow and distributed template must be identical.'
}
if ($fixture.ref_move.main_before -eq $fixture.ref_move.main_after) {
    throw 'Target-move fixture must model a moving main ref.'
}
if ($fixture.ref_move.merge_commit_sha -eq $fixture.ref_move.main_after) {
    throw 'Target-move fixture must distinguish the merged commit from later main.'
}
if ($fixture.ref_move.validation_tree_sha -ne $fixture.ref_move.merge_tree_sha -or
    $fixture.ref_move.package_tree_sha -ne $fixture.ref_move.merge_tree_sha -or
    $fixture.ref_move.main_after_tree_sha -eq $fixture.ref_move.merge_tree_sha) {
    throw 'Validation and packaging must preserve the original merge tree after main advances.'
}
if ($chain -notmatch 'const targetSha = String\(pr\.merge_commit_sha \|\| ''''\)\.toLowerCase\(\)' -or
    $chain -notmatch 'inputs:\s*\{\s*target_sha:\s*targetSha\s*\}') {
    throw 'Post-merge packaging must receive the immutable merge commit SHA, not the moving main ref.'
}
if ($chain -notmatch "dry_run:\s*'true'") {
    throw 'Post-merge release-gate evidence must remain explicitly dry-run.'
}
if ($chain -notmatch 'workflow_id:\s*''package-basecoat\.yml''[\s\S]*?event:\s*''workflow_dispatch''[\s\S]*?status,[\s\S]*?run\.display_title === expectedRunName') {
    throw 'Packaging coalescing must match only active or queued workflow-dispatch runs for the exact target.'
}
if ($chain -notmatch "for \(const status of \['queued', 'in_progress'\]\)") {
    throw 'Packaging coalescing must consider both queued and in-progress requests.'
}
if ($chain -notmatch 'github\.rest\.repos\.getCommit\([\s\S]*?ref:\s*''main''' -or
    $chain -notmatch 'run\.display_title === expectedRunName && run\.head_sha === controller\.sha') {
    throw 'Packaging coalescing must require the same controller commit, not just the target run name.'
}

if ($package -notmatch 'target_sha:[\s\S]*?required:\s*false' -or
    $package -notmatch 'run-name:\s*Package Base Coat \$\{\{\s*inputs\.target_sha \|\| github\.sha\s*\}\}' -or
    $package -notmatch 'group:\s*basecoat-package-\$\{\{\s*inputs\.target_sha \|\| github\.sha\s*\}\}' -or
    $package -notmatch 'cancel-in-progress:\s*false') {
    throw 'Package workflow must key non-cancelling concurrency by immutable target SHA.'
}
if ($package.Contains('github.event.inputs.target_sha') -or
    $package -notmatch 'TARGET_SHA:\s*\$\{\{\s*inputs\.target_sha \|\| github\.sha\s*\}\}') {
    throw 'Package target must use normalized inputs context with an event SHA fallback.'
}
foreach ($identity in @('sha', 'tree')) {
    $variable = '$actual_' + $identity
    $target = '$TARGET_' + $identity.ToUpperInvariant()
    $validated = '$VALIDATED_' + $identity.ToUpperInvariant()
    $condition = 'if [[ "' + $variable + '" != "' + $target + '" ]] || [[ "' + $variable + '" != "' + $validated + '" ]]; then'
    if (-not $package.Contains($condition)) {
        throw "Package $identity comparisons must preserve both exact-match checks as separate shell conditions."
    }
}
if ($package -notmatch 'resolve-target:[\s\S]*?target_sha:[\s\S]*?target_tree:' -or
    $package -notmatch 'TARGET_SHA.*\^\[0-9a-f\]\{40\}\$' -or
    $package -notmatch 'ref:\s*\$\{\{\s*steps\.requested\.outputs\.sha\s*\}\}') {
    throw 'Package workflow must reject non-full SHAs and resolve the requested commit/tree before validation.'
}
if ($package -notmatch 'target_sha:\s*\$\{\{\s*needs\.resolve-target\.outputs\.target_sha\s*\}\}' -or
    $package -notmatch 'needs:\s*\[resolve-target,\s*validate\]' -or
    $package -notmatch 'VALIDATED_TREE:\s*\$\{\{\s*needs\.validate\.outputs\.validated_tree\s*\}\}') {
    throw 'Package workflow must validate and package the same SHA/tree and fail on an identity mismatch.'
}
if ($validate -notmatch 'target_sha:[\s\S]*?type:\s*string' -or
    $validate -notmatch 'validated_tree:[\s\S]*?jobs\.validate-workflow-syntax\.outputs\.target_tree') {
    throw 'Reusable validation must accept and expose immutable source identity.'
}
$pinnedCheckouts = [regex]::Matches($validate, 'ref:\s*\$\{\{\s*inputs\.target_sha\s*\|\|\s*github\.sha\s*\}\}')
if ($pinnedCheckouts.Count -ne 4) {
    throw "Every validator checkout must use the target SHA; found $($pinnedCheckouts.Count) pinned checkouts instead of 4."
}
foreach ($jobName in @('validate-unix', 'validate-windows')) {
    $jobMatch = [regex]::Match($validate, "(?ms)^  ${jobName}:\s*\r?\n(.*?)(?=^  [a-z0-9_-]+:|\z)")
    if (-not $jobMatch.Success -or $jobMatch.Groups[1].Value -notmatch 'needs:\s*validate-workflow-syntax') {
        throw "$jobName must remain gated by validate-workflow-syntax so syntax failures skip costly work."
    }
}

$runNames = @{}
foreach ($request in $fixture.requests) {
    $requestKey = "basecoat-package-$($request.target_sha)"
    $runName = "Package Base Coat $($request.target_sha)"
    $runNames[$request.name] = [pscustomobject]@{ Key = $requestKey; Name = $runName }
}
if ($runNames['merge-a'].Key -ne $runNames['duplicate-a'].Key -or
    $runNames['merge-a'].Name -ne $runNames['duplicate-a'].Name) {
    throw 'Equivalent immutable requests must share a concurrency key and run identity.'
}
if ($runNames['merge-a'].Key -eq $runNames['merge-b'].Key -or
    $runNames['merge-a'].Name -eq $runNames['merge-b'].Name) {
    throw 'Distinct immutable targets must not share concurrency identity.'
}
if ($runNames['merge-a'].Name -ne "Package Base Coat $($fixture.ref_move.merge_commit_sha)" -or
    $fixture.ref_move.merge_commit_sha -ne $fixture.requests[0].target_sha) {
    throw 'A main-ref move must not change the target selected for an earlier merge.'
}

$activeStatuses = @('queued', 'in_progress')
foreach ($request in $fixture.requests) {
    $expectedName = $runNames[$request.name].Name
    $matchingActive = @($fixture.active_runs | Where-Object {
        $_.display_title -eq $expectedName -and $activeStatuses -contains $_.status -and
        $_.head_sha -eq $fixture.controller_sha
    })
    if ($matchingActive.Count -ne 1) {
        throw "Request $($request.name) must match only its own active immutable-target run."
    }
}
if (-not @($fixture.active_runs | Where-Object {
    $_.display_title -eq $runNames['merge-a'].Name -and $_.head_sha -ne $fixture.controller_sha
}).Count) {
    throw 'Fixture must include an obsolete controller for the same package target.'
}

Write-Host 'Package BaseCoat immutable-target workflow tests passed.'
