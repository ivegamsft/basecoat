[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$manifestPath = Join-Path $repoRoot '.github\base-coat\workflows\workflow-ownership-manifest.json'
$installerPath = Join-Path $repoRoot 'scripts\configure-downstream-workflows.ps1'
$retirementPath = Join-Path $repoRoot 'scripts\retire-downstream-workflows.ps1'
$scratch = Join-Path $repoRoot 'test-results\workflow-ownership-tests'
$sourceDir = Join-Path $scratch 'source'
$destinationDir = Join-Path $scratch 'destination'
$syncSourceDir = Join-Path $scratch 'sync-source'
$syncConsumerDir = Join-Path $scratch 'sync-consumer'
$syncScriptPath = Join-Path $repoRoot 'sync.ps1'

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

foreach ($path in @($manifestPath, $installerPath, $retirementPath, $syncScriptPath)) {
    Assert-True -Condition (Test-Path -LiteralPath $path -PathType Leaf) `
        -Message "Missing workflow ownership asset: $path"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True -Condition ($manifest.schemaVersion -eq 1) `
    -Message 'Workflow ownership manifest must use schema version 1.'
Assert-True -Condition ($manifest.defaultOwnership -eq 'repo-owned') `
    -Message 'Unmarked workflows must default to repo-owned.'
Assert-True -Condition (@($manifest.workflows).Count -gt 0) `
    -Message 'Workflow ownership manifest must mark factory-owned workflows.'
Assert-True -Condition (@($manifest.workflows | Where-Object { $_.ownership -ne 'factory-owned' }).Count -eq 0) `
    -Message 'Workflow ownership manifest may only explicitly mark factory-owned workflows.'

foreach ($requiredFactoryWorkflow in @(
        'basecoat-secret-scan.yml',
        'agent-assignment-worker.yml',
        'ship-it-intent-dispatch.yml',
        'basecoat-internal-database-ci-cd.yml'
    )) {
    Assert-True -Condition (@($manifest.workflows | Where-Object { $_.file -eq $requiredFactoryWorkflow }).Count -eq 1) `
        -Message "Workflow ownership manifest must mark $requiredFactoryWorkflow as factory-owned."
}

try {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $sourceDir, $destinationDir -Force | Out-Null

    New-Item -ItemType Directory -Force -Path @(
        (Join-Path $syncSourceDir '.github\base-coat\workflows'),
        (Join-Path $syncSourceDir 'scripts'),
        (Join-Path $syncSourceDir 'agents'),
        (Join-Path $syncSourceDir 'instructions'),
        (Join-Path $syncSourceDir 'prompts'),
        (Join-Path $syncSourceDir 'skills'),
        (Join-Path $syncSourceDir 'templates'),
        (Join-Path $syncSourceDir 'docs\reference'),
        (Join-Path $syncSourceDir 'docs\guides'),
        $syncConsumerDir
    ) | Out-Null
    '# Sync source' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'README.md') -Encoding utf8NoBOM
    '# Changelog' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'CHANGELOG.md') -Encoding utf8NoBOM
    '{"version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'version.json') -Encoding utf8NoBOM
    '{"schemaVersion":"1","assets":[]}' | Set-Content -LiteralPath (Join-Path $syncSourceDir 'asset-manifest.json') -Encoding utf8NoBOM
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $syncSourceDir '.github\base-coat\workflows\workflow-ownership-manifest.json')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts\workflow-ownership.ps1') -Destination (Join-Path $syncSourceDir 'scripts\workflow-ownership.ps1')
    Copy-Item -LiteralPath $retirementPath -Destination (Join-Path $syncSourceDir 'scripts\retire-downstream-workflows.ps1')
    git -C $syncSourceDir init -q -b main
    git -C $syncSourceDir config user.name 'basecoat-test'
    git -C $syncSourceDir config user.email 'basecoat-test@example.com'
    git -C $syncSourceDir add -A
    git -C $syncSourceDir commit -qm 'seed ownership distribution fixture'
    git -C $syncConsumerDir init -q -b main
    git -C $syncConsumerDir config user.name 'basecoat-test'
    git -C $syncConsumerDir config user.email 'basecoat-test@example.com'
    '# Consumer' | Set-Content -LiteralPath (Join-Path $syncConsumerDir 'README.md') -Encoding utf8NoBOM
    git -C $syncConsumerDir add README.md
    git -C $syncConsumerDir commit -qm 'seed consumer'

    Push-Location $syncConsumerDir
    try {
        $env:BASECOAT_REPO = "file://$syncSourceDir"
        $env:BASECOAT_REF = 'main'
        & pwsh -NoProfile -File $syncScriptPath | Out-Null
        Assert-True -Condition ($LASTEXITCODE -eq 0) `
            -Message 'Sync must distribute the workflow ownership guard assets.'
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO, Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        Pop-Location
    }

    foreach ($distributedPath in @(
            '.github\base-coat\workflows\workflow-ownership-manifest.json',
            '.github\base-coat\scripts\workflow-ownership.ps1',
            '.github\base-coat\scripts\retire-downstream-workflows.ps1'
        )) {
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $syncConsumerDir $distributedPath) -PathType Leaf) `
            -Message "Sync must distribute workflow ownership asset: $distributedPath"
    }

    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $sourceDir 'workflow-ownership-manifest.json')
    @'
name: "BaseCoat - Secret Scanning (warn only)"
on:
  workflow_dispatch:
jobs:
  scan:
    runs-on: ubuntu-latest
'@ | Set-Content -LiteralPath (Join-Path $sourceDir 'secret-scan.yml') -Encoding utf8NoBOM

    'repo-owned ci workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'ci.yml') -Encoding utf8NoBOM
    'locally maintained workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'basecoat-custom-ci.yml') -Encoding utf8NoBOM
    'legacy factory workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'bc-secret-scan.yml') -Encoding utf8NoBOM
    'factory workflow' | Set-Content -LiteralPath (Join-Path $destinationDir 'basecoat-secret-scan.yml') -Encoding utf8NoBOM

    $rejectedOutput = & pwsh -NoProfile -File $retirementPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -Workflow ci.yml 2>&1 | Out-String
    Assert-True -Condition ($LASTEXITCODE -ne 0) `
        -Message 'Retirement guard must reject a repo-owned workflow.'
    Assert-True -Condition ($rejectedOutput -match 'Refusing to remove repository-owned workflow') `
        -Message 'Retirement guard must explain that unmarked workflows are repository-owned.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $destinationDir 'ci.yml')) `
        -Message 'Retirement guard must leave a repo-owned workflow in place.'

    & pwsh -NoProfile -File $retirementPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -Workflow basecoat-secret-scan.yml `
        -DryRun | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Dry-run retirement of a factory-owned workflow must succeed.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $destinationDir 'basecoat-secret-scan.yml')) `
        -Message 'Dry-run retirement must not remove the factory-owned workflow.'

    & pwsh -NoProfile -File $installerPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -InstallClass reusable | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Installer must complete when its ownership manifest is present.'
    $installedSecretWorkflow = Get-Content -LiteralPath (Join-Path $destinationDir 'basecoat-secret-scan.yml') -Raw
    $installedTopLevelNames = @(
        $installedSecretWorkflow -split "`r?`n" |
            Where-Object { $_ -match '^name:' }
    )
    Assert-True -Condition ($installedTopLevelNames.Count -eq 1) `
        -Message 'Installer must emit exactly one top-level name for a source workflow that already has a name.'
    Assert-True -Condition ($installedTopLevelNames[0] -eq 'name: "BaseCoat Reusable - Secret Scan"') `
        -Message 'Installer must replace the source workflow name with the configured downstream name.'
    Assert-True -Condition ($installedSecretWorkflow -match '(?m)^on:$' -and $installedSecretWorkflow -match '(?m)^jobs:$') `
        -Message 'Installer must preserve the source workflow YAML structure when replacing its name.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $destinationDir 'bc-secret-scan.yml'))) `
        -Message 'Installer must retire a legacy workflow marked factory-owned.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $destinationDir 'basecoat-custom-ci.yml')) `
        -Message 'Installer must preserve an unmarked workflow even with a BaseCoat-like prefix.'

    $targetedSourceDir = Join-Path $scratch 'targeted-source'
    $targetedDestinationDir = Join-Path $scratch 'targeted-destination'
    $targetedGovernanceDir = Join-Path $scratch 'targeted-governance'
    New-Item -ItemType Directory -Force -Path $targetedSourceDir, $targetedDestinationDir, $targetedGovernanceDir | Out-Null
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $targetedSourceDir 'workflow-ownership-manifest.json')
    Copy-Item -LiteralPath (Join-Path $repoRoot '.github\base-coat\workflows\version-check.yml') `
        -Destination (Join-Path $targetedSourceDir 'version-check.yml')
    Copy-Item -LiteralPath (Join-Path $repoRoot '.github\base-coat\workflows\dependency-update-advisor.yml') `
        -Destination (Join-Path $targetedSourceDir 'dependency-update-advisor.yml')
    'legacy factory workflow' | Set-Content -LiteralPath (Join-Path $targetedDestinationDir 'bc-version-check.yml') -Encoding utf8NoBOM
    'consumer-owned prefix collision' | Set-Content -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-custom.yml') -Encoding utf8NoBOM
    '{"consumer":"policy"}' | Set-Content -LiteralPath (Join-Path $targetedGovernanceDir 'policy-packs.json') -Encoding utf8NoBOM

    & pwsh -NoProfile -File $installerPath `
        -SourceDir $targetedSourceDir `
        -DestinationDir $targetedDestinationDir `
        -GovernanceDestinationDir $targetedGovernanceDir `
        -Workflow bc-version-check.yml | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Installer must resolve a selected legacy destination to its registered source mapping.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-version-check.yml')) `
        -Message 'Targeted refresh must install the canonical destination for a captured legacy workflow.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $targetedDestinationDir 'bc-version-check.yml'))) `
        -Message 'Targeted refresh must retire only the mapped legacy factory-owned workflow.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-upstream-version-drift.yml'))) `
        -Message 'Targeted refresh must not enable an unselected workflow from the same class.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-custom.yml') -Raw).Trim() -eq 'consumer-owned prefix collision') `
        -Message 'Targeted refresh must preserve consumer-owned prefix collisions.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $targetedGovernanceDir 'policy-packs.json') -Raw).Trim() -eq '{"consumer":"policy"}') `
        -Message 'Targeted refresh must preserve consumer governance files.'

    $versionWorkflowHash = (Get-FileHash -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-version-check.yml')).Hash
    & pwsh -NoProfile -File $installerPath `
        -SourceDir $targetedSourceDir `
        -DestinationDir $targetedDestinationDir `
        -GovernanceDestinationDir $targetedGovernanceDir `
        -Workflow basecoat-version-check.yml | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message 'Repeated targeted refresh must succeed.'
    Assert-Equal (Get-FileHash -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-version-check.yml')).Hash `
        $versionWorkflowHash 'Repeated targeted refresh must be idempotent.'

    & pwsh -NoProfile -File $installerPath `
        -SourceDir $targetedSourceDir `
        -DestinationDir $targetedDestinationDir `
        -GovernanceDestinationDir $targetedGovernanceDir `
        -Workflow bc-dependency-update-advisor.yml | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Targeted template refresh must resolve legacy names and preserve governance.'
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-dependency-update-advisor.yml')) `
        -Message 'Targeted template refresh must install only its selected destination.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $targetedDestinationDir 'basecoat-sprint-closeout-branch-audit.yml'))) `
        -Message 'Targeted template refresh must not enable other template workflows.'
    Assert-True -Condition ((Get-Content -LiteralPath (Join-Path $targetedGovernanceDir 'policy-packs.json') -Raw).Trim() -eq '{"consumer":"policy"}') `
        -Message 'Targeted template refresh must preserve existing governance files.'

    $assignmentSourceDir = Join-Path $scratch 'assignment-source'
    $assignmentGovernanceDir = Join-Path $scratch 'assignment-governance'
    New-Item -ItemType Directory -Force -Path $assignmentSourceDir, $assignmentGovernanceDir | Out-Null
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $assignmentSourceDir 'workflow-ownership-manifest.json')
    foreach ($assignmentWorkflow in @(
            'agent-assignment-worker.yml',
            'issue-approve.yml',
            'automation-stuck-state-watchdog.yml',
            'approved-spec-handoff.yml'
        )) {
        Copy-Item -LiteralPath (Join-Path $repoRoot ".github\base-coat\workflows\$assignmentWorkflow") `
            -Destination $assignmentSourceDir
    }
    foreach ($caller in @('issue-approve.yml', 'automation-stuck-state-watchdog.yml', 'approved-spec-handoff.yml')) {
        $callerDestinationDir = Join-Path $scratch "assignment-destination-$($caller -replace '\.yml$', '')"
        New-Item -ItemType Directory -Force -Path $callerDestinationDir | Out-Null
        & pwsh -NoProfile -File $installerPath `
            -SourceDir $assignmentSourceDir `
            -DestinationDir $callerDestinationDir `
            -GovernanceDestinationDir $assignmentGovernanceDir `
            -Workflow $caller | Out-Null
        Assert-True -Condition ($LASTEXITCODE -eq 0) `
            -Message "Targeted install of $caller must include the reusable worker dependency."
        $callerDestination = if ($caller -eq 'automation-stuck-state-watchdog.yml') { $caller } else { "basecoat-$caller" }
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $callerDestinationDir $callerDestination)) `
            -Message "Targeted install must install caller $caller."
        Assert-True -Condition (Test-Path -LiteralPath (Join-Path $callerDestinationDir 'agent-assignment-worker.yml')) `
            -Message "Targeted install of $caller must install agent-assignment-worker.yml."
    }

    $targetedManifestPath = Join-Path $targetedSourceDir 'workflow-ownership-manifest.json'
    $heldManifestPath = "$targetedManifestPath.held"
    Move-Item -LiteralPath $targetedManifestPath -Destination $heldManifestPath
    try {
        $ownershipConflictOutput = & pwsh -NoProfile -File $installerPath `
            -SourceDir $targetedSourceDir `
            -DestinationDir $targetedDestinationDir `
            -Workflow basecoat-version-check.yml 2>&1 | Out-String -Width 4096
        Assert-True -Condition ($LASTEXITCODE -ne 0 -and $ownershipConflictOutput -match 'without an ownership manifest') `
            -Message 'Targeted refresh must refuse to overwrite an existing file without ownership evidence.'
    }
    finally {
        Move-Item -LiteralPath $heldManifestPath -Destination $targetedManifestPath
    }

    $partialShipItOutput = & pwsh -NoProfile -File $installerPath `
        -SourceDir $targetedSourceDir `
        -DestinationDir $targetedDestinationDir `
        -Workflow ship-it-intent-dispatch.yml 2>&1 | Out-String
    Assert-True -Condition ($LASTEXITCODE -ne 0 -and $partialShipItOutput -match 'Partial ship-it workflow selection') `
        -Message 'Installer must reject a partial ship-it capability and name its missing members.'
    $unsupportedOutput = & pwsh -NoProfile -File $installerPath `
        -SourceDir $targetedSourceDir `
        -DestinationDir $targetedDestinationDir `
        -Workflow auto-approve-cloud-agent-workflows.yml 2>&1 | Out-String -Width 4096
    Assert-True -Condition ($LASTEXITCODE -ne 0 -and $unsupportedOutput -match 'unsupported') `
        -Message 'Installer must report explicitly selected unsupported workflows as blockers.'
    $missingSourceOutput = & pwsh -NoProfile -File $installerPath `
        -SourceDir $targetedSourceDir `
        -DestinationDir $targetedDestinationDir `
        -Workflow check-version.yml 2>&1 | Out-String -Width 4096
    Assert-True -Condition ($LASTEXITCODE -ne 0 -and $missingSourceOutput -match 'Selected workflow source is missing') `
        -Message 'Installer must fail when a selected workflow source is missing.'
    $unknownSelectorOutput = & pwsh -NoProfile -File $installerPath `
        -SourceDir $targetedSourceDir `
        -DestinationDir $targetedDestinationDir `
        -Workflow unknown-consumer.yml 2>&1 | Out-String -Width 4096
    Assert-True -Condition ($LASTEXITCODE -ne 0 -and $unknownSelectorOutput -match 'Unknown workflow selector') `
        -Message 'Installer must fail closed on an unsupported selected mapping.'

    & pwsh -NoProfile -File $retirementPath `
        -SourceDir $sourceDir `
        -DestinationDir $destinationDir `
        -Workflow basecoat-secret-scan.yml | Out-Null
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Retirement of a factory-owned workflow must succeed.'
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $destinationDir 'basecoat-secret-scan.yml'))) `
        -Message 'Retirement command must remove the approved factory-owned workflow.'

    $sizeTemplatePath = Join-Path $repoRoot '.github\base-coat\workflows\pr-size-labeler.yml'
    $sizeRuntimePath = Join-Path $repoRoot '.github\workflows\pr-size-labeler.yml'
    $sizeTemplate = (Get-Content -LiteralPath $sizeTemplatePath -Raw) -replace "`r`n", "`n"
    $sizeRuntime = (Get-Content -LiteralPath $sizeRuntimePath -Raw) -replace "`r`n", "`n"
    Assert-Equal $sizeTemplate $sizeRuntime 'Size labeler template must preserve the production algorithm exactly.'
    Assert-True -Condition ($sizeTemplate -match 'pull_request_target:' -and
        $sizeTemplate -notmatch '(?m)actions/checkout|^\s*(?:-\s*)?run:' ) `
        -Message 'Privileged size labeling must remain API-only without PR-head execution.'
    Assert-True -Condition ($sizeTemplate -match '(?m)^  actions: write$') `
        -Message 'Size labeling must have permission to dispatch post-label merge reevaluation.'
    Assert-True -Condition (@($manifest.workflows | Where-Object {
        $_.file -eq 'basecoat-pr-size-labeler.yml'
    }).Count -eq 1) -Message 'Distributed size labeler must have factory ownership.'
    foreach ($mode in @('default', 'executor')) {
        $metadataDestination = Join-Path $scratch "metadata-$mode"
        New-Item -ItemType Directory -Path $metadataDestination -Force | Out-Null
        $consumerOwned = Join-Path $metadataDestination 'consumer-ci.yml'
        'consumer-owned metadata fixture' | Set-Content -LiteralPath $consumerOwned
        $installArguments = @{
            SourceDir = (Join-Path $repoRoot '.github\base-coat\workflows')
            DestinationDir = $metadataDestination
            GovernanceDestinationDir = (Join-Path $scratch "metadata-governance-$mode")
        }
        if ($mode -eq 'executor') { $installArguments.Workflow = 'pr-auto-merge-executor.yml' }
        & $installerPath @installArguments | Out-Null
        $installedSizePath = Join-Path $metadataDestination 'basecoat-pr-size-labeler.yml'
        Assert-True -Condition (Test-Path -LiteralPath $installedSizePath -PathType Leaf) `
            -Message "$mode install must include the deterministic size producer."
        $installedSize = (Get-Content -LiteralPath $installedSizePath -Raw) -replace "`r`n", "`n"
        $expectedSize = $sizeTemplate -replace 'BaseCoat - PR Size and Sprint Labeler',
            'BaseCoat Reusable - PR Size and Sprint Labeler'
        Assert-Equal $installedSize $expectedSize "$mode install must preserve the trusted source script."
        Assert-Equal (Get-Content -LiteralPath $consumerOwned -Raw).Trim() `
            'consumer-owned metadata fixture' 'Metadata install must preserve consumer-owned workflows.'
        $upgradeSource = Join-Path $scratch "metadata-upgrade-source-$mode"
        Copy-Item -LiteralPath $installArguments.SourceDir -Destination $upgradeSource -Recurse
        $upgradeSizePath = Join-Path $upgradeSource 'pr-size-labeler.yml'
        Add-Content -LiteralPath $upgradeSizePath -Value '# Future factory release fixture'
        $upgradeArguments = $installArguments.Clone()
        $upgradeArguments.SourceDir = $upgradeSource
        & $installerPath @upgradeArguments -DryRun | Out-Null
        Assert-Equal (Get-Content -LiteralPath $installedSizePath -Raw).TrimEnd() `
            $expectedSize.TrimEnd() 'Recognized predecessor dry run must preserve installed bytes.'
        & $installerPath @upgradeArguments | Out-Null
        Assert-True -Condition ((Get-Content -LiteralPath $installedSizePath -Raw) -match
            '# Future factory release fixture') -Message "$mode install must upgrade a recognized unmodified predecessor."
        'consumer-authored exact-name workflow' | Set-Content -LiteralPath $installedSizePath
        $earlierPath = Join-Path $metadataDestination 'basecoat-secret-scan.yml'
        'earlier workflow must not change on failed preflight' | Set-Content -LiteralPath $earlierPath
        $collisionArguments = @(
            '-NoProfile', '-File', $installerPath,
            '-SourceDir', $installArguments.SourceDir,
            '-DestinationDir', $metadataDestination,
            '-GovernanceDestinationDir', $installArguments.GovernanceDestinationDir
        )
        if ($mode -eq 'executor') { $collisionArguments += @('-Workflow', 'pr-auto-merge-executor.yml') }
        foreach ($dry in @($true, $false)) {
            $arguments = @($collisionArguments)
            if ($dry) { $arguments += '-DryRun' }
            $collisionOutput = & pwsh @arguments 2>&1 | Out-String -Width 4096
            Assert-True -Condition ($LASTEXITCODE -ne 0 -and
                $collisionOutput -match 'Refusing to overwrite unrecognized PR size labeler') `
                -Message "$mode install must explicitly reject exact-name consumer collisions."
            Assert-Equal (Get-Content -LiteralPath $installedSizePath -Raw).Trim() `
                'consumer-authored exact-name workflow' 'Collision must preserve exact consumer file.'
            Assert-Equal (Get-Content -LiteralPath $earlierPath -Raw).Trim() `
                'earlier workflow must not change on failed preflight' 'Collision must precede all workflow writes.'
        }
    }

    @'
const assert = require('node:assert/strict');
const source = require('node:fs').readFileSync(process.argv[2], 'utf8').replace(/\r\n/g, '\n');
const match = source.match(/^          script: \|\n((?: {12}[^\n]*(?:\n|$)|[ \t]*\n)*)/m);
assert.ok(match, 'Extract actual size labeler script.');
const script = match[1].split('\n').map(line => line.replace(/^ {12}/, '')).join('\n');
assert.match(source, /^  cancel-in-progress: false$/m, 'Finish serialized label reconciliation.');
const executor = require('node:fs').readFileSync(process.argv[3], 'utf8').replace(/\r\n/g, '\n');
const sizeContract = executor.match(/\/\/ BEGIN CURRENT PR SIZE CONTRACT\n([\s\S]*?)\/\/ END CURRENT PR SIZE CONTRACT/);
assert.ok(sizeContract, 'Extract actual current-head executor size validation.');
const checkSize = new Function('pr', 'files', 'labelNames',
  `const blockers = []; ${sizeContract[1]} return blockers;`);
const pr = { additions: 2001, deletions: 0, changed_files: 1 };
const files = [{ filename: 'source.cjs', additions: 2001, deletions: 0 }];
assert.deepEqual(checkSize(pr, files, ['size:XXL']), []);
for (const labels of [[], ['size:XS'], ['size:XS', 'size:XXL']]) {
  assert.ok(checkSize(pr, files, labels).length, 'Reject missing, stale or duplicate label evidence.');
}
assert.ok(checkSize(pr, [], ['size:XXL']).length, 'Reject incomplete file enumeration.');
assert.deepEqual(checkSize(
  { additions: 3001, deletions: 0, changed_files: 1 },
  [{ filename: 'package-lock.json', additions: 3001, deletions: 0 }], ['size:XS']), []);
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
async function run(headId, baseId, expectedSprint, additions, files, expectedSize, hasExecutor = true) {
  const added = [];
  const removed = [];
  const dispatched = [];
  const operationOrder = [];
  const github = {
    rest: {
      pulls: { async get() { return { data: {
        additions, deletions: 0, head: { repo: headId === null ? null : { id: headId, fork: true } },
        base: { repo: { id: baseId } }
      } }; }, async listFiles() { return { data: files }; } },
      actions: {
        async listRepoWorkflows() { return { data: [
          { id: 15, name: 'BaseCoat Template - PR Auto Merge Executor', state: 'active', path: '.github/workflows/unrelated.yml' },
          { id: 16, state: 'disabled_manually', path: '.github/workflows/pr-auto-merge-executor.yml' },
          ...(hasExecutor ? [{ id: 17, name: 'Customized display name', state: 'active',
            path: '.github/workflows/basecoat-pr-auto-merge-executor.yml' }] : [])
        ] }; },
        async createWorkflowDispatch(args) { dispatched.push(args); operationOrder.push('dispatch'); }
      },
      issues: {
        async listLabelsOnIssue() { return { data: [{ name: 'size:XXL' }] }; },
        async removeLabel(args) { removed.push(args.name); },
        async getLabel() {}, async createLabel() {},
        async addLabels(args) { added.push(...args.labels); operationOrder.push('labels'); }
      }
    },
    async paginate(method) { return (await method()).data; }
  };
  const core = {
    info() {}, setFailed(message) { throw new Error(message); },
    summary: { addHeading() { return this; }, addTable() { return this; }, async write() {} }
  };
  await new AsyncFunction('github', 'context', 'core', 'process', script)(
    github, { repo: { owner: 'fixture', repo: 'consumer' }, payload: { repository: { default_branch: 'trunk' } } },
    core, { env: { PR_NUMBER_INPUT: '42' } }
  );
  assert.ok(added.includes(expectedSize), 'Preserve actual size/lockfile thresholds.');
  assert.equal(added.some(label => label.startsWith('sprint:')), expectedSprint,
    'Manual dispatch derives cross-repo status from fetched repositories.');
  assert.deepEqual(removed, ['size:XXL']);
  assert.deepEqual(operationOrder, hasExecutor ? ['labels', 'dispatch'] : ['labels'],
    'Dispatch only an active installed executor, after labels are applied.');
  assert.deepEqual(dispatched, hasExecutor ? [{
    owner: 'fixture', repo: 'consumer', workflow_id: 17, ref: 'trunk', inputs: { pr_number: '42' }
  }] : [], 'Match installed path, not display names or disabled executors.');
}
(async () => {
  await run(1, 2, false, 20, [], 'size:XS');
  await run(null, 2, false, 20, [], 'size:XS');
  await run(1, 2, false, 20, [], 'size:XS', false);
  await run(1, 1, true, 21, [], 'size:S');
  await run(1, 1, true, 5000,
    [{ filename: 'nested/package-lock.json', additions: 4990, deletions: 0 }], 'size:XS');
  console.log('Actual size labeler and executor dispatch, fork, threshold and lockfile fixtures passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
'@ | & node - $sizeRuntimePath (Join-Path $repoRoot '.github\workflows\pr-auto-merge-executor.yml')
    Assert-True -Condition ($LASTEXITCODE -eq 0) `
        -Message 'Actual manual size-label dispatch fixtures must pass.'

    Write-Host 'Workflow ownership tests passed.'
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
