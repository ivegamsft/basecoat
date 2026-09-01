$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$validatorPath = Join-Path $repoRoot 'scripts/validate-workflow-action-pins.ps1'
$fixtureRoot = Join-Path $repoRoot 'test-results/workflow-action-pinning-fixture'
$sourceRoot = Join-Path $fixtureRoot 'source'
$installedRoot = Join-Path $fixtureRoot 'installed'
$checkoutSha = '9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0'
$dockerDigest = 'sha256:' + ('a' * 64)

function Invoke-Validator {
    param(
        [string]$RootDir,
        [ValidateSet('Auto', 'Source', 'Installed')]
        [string]$Mode = 'Auto'
    )

    $output = & pwsh -NoProfile -File $validatorPath -RootDir $RootDir -Mode $Mode 2>&1
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = ($output | Out-String)
    }
}

function Assert-ValidatorFails {
    param(
        [string]$RootDir,
        [string]$Expected,
        [ValidateSet('Auto', 'Source', 'Installed')]
        [string]$Mode = 'Auto'
    )

    $result = Invoke-Validator -RootDir $RootDir -Mode $Mode
    if ($result.ExitCode -eq 0) {
        throw "Expected workflow action pin validation to fail with '$Expected'."
    }
    if (-not $result.Output.Contains($Expected)) {
        throw "Expected validation output to contain '$Expected'.`n$($result.Output)"
    }
    return $result
}

try {
    $sourceWorkflowDirectories = @(
        '.github/workflows',
        '.github/base-coat/workflows',
        '.github/workflow-templates',
        '.github/template-repos/example/.github/workflows',
        'docs/examples/workflows',
        'skills/example'
    )
    foreach ($directory in $sourceWorkflowDirectories) {
        New-Item -ItemType Directory -Path (Join-Path $sourceRoot $directory) -Force | Out-Null
    }

    Set-Content -Path (Join-Path $sourceRoot '.github/workflows/valid.yml') -Value @"
jobs:
  validate:
    env:
      uses: non-executable-environment-value
    steps:
      - "uses": "actions/checkout@$checkoutSha" # quoted executable key
        with:
          uses: nested-block-input
      - uses: ./.github/actions/local
        with: { uses: nested-flow-input }
      - uses: docker://ghcr.io/example/action:1@$dockerDigest
      - run: |
          echo "uses: actions/checkout@v4"
      - run: >
          echo 'uses: actions/github-script@main'
      - run: "echo start
          uses: actions/checkout@v4"
"@
    Set-Content -Path (Join-Path $sourceRoot '.github/base-coat/workflows/valid.yaml') -Value @"
jobs:
  reusable:
    uses: example/repository/.github/workflows/reusable.yml@$checkoutSha
    with:
      uses: reusable-input
"@
    Set-Content -Path (Join-Path $sourceRoot '.github/workflow-templates/valid.yml') -Value @"
jobs:
  validate:
    steps:
      - uses: actions/checkout@$checkoutSha
"@
    Set-Content -Path (Join-Path $sourceRoot '.github/template-repos/example/.github/workflows/valid.yml') -Value @"
jobs:
  validate:
    steps:
      - uses: actions/checkout@$checkoutSha
"@
    Set-Content -Path (Join-Path $sourceRoot 'docs/examples/workflows/valid.yml') -Value @"
jobs:
  validate:
    steps:
      - uses: './.github/actions/local'
"@
    Set-Content -Path (Join-Path $sourceRoot 'skills/example/sample-workflow.yml') -Value @"
jobs:
  validate:
    steps:
      - uses: actions/checkout@$checkoutSha
"@
    $dependencyWorkflow = Join-Path $sourceRoot 'skills/example/node_modules/dependency/.github/workflows/invalid.yml'
    New-Item -ItemType Directory -Path (Split-Path -Parent $dependencyWorkflow) -Force | Out-Null
    Set-Content -Path $dependencyWorkflow -Value @"
jobs:
  validate:
    steps:
      - uses: actions/checkout@v4
"@
    $templateDependencyWorkflow = Join-Path $sourceRoot '.github/template-repos/example/node_modules/dependency/.github/workflows/invalid.yml'
    New-Item -ItemType Directory -Path (Split-Path -Parent $templateDependencyWorkflow) -Force | Out-Null
    Set-Content -Path $templateDependencyWorkflow -Value @"
jobs:
  validate:
    steps:
      - uses: actions/checkout@v4
"@

    $sourceResult = Invoke-Validator -RootDir $sourceRoot
    if ($sourceResult.ExitCode -ne 0 -or $sourceResult.Output -notmatch "mode 'source'") {
        throw "Expected complete source layout to pass in source mode while ignoring dependency workflows.`n$($sourceResult.Output)"
    }

    $invalidScopeFiles = @(
        @{ Path = '.github/workflows/invalid.yml'; Reference = 'actions/checkout@v4' },
        @{ Path = '.github/base-coat/workflows/invalid.yml'; Reference = 'owner/action@main' },
        @{ Path = '.github/workflow-templates/invalid.yml'; Reference = 'owner/template-action@main' },
        @{ Path = '.github/template-repos/example/.github/workflows/invalid.yml'; Reference = 'docker://ghcr.io/example/action:latest' },
        @{ Path = 'docs/examples/workflows/invalid.yml'; Reference = 'owner/action@0123456' },
        @{ Path = 'skills/example/invalid-workflow.yml'; Reference = 'actions/checkout@v4' }
    )
    foreach ($fixture in $invalidScopeFiles) {
        Set-Content -Path (Join-Path $sourceRoot $fixture.Path) -Value "jobs:`n  validate:`n    steps:`n      - uses: $($fixture.Reference)"
    }

    $scopeFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected 'failed with 6 violation(s)'
    foreach ($fixture in $invalidScopeFiles) {
        $expectedPath = "$($fixture.Path):4"
        if (-not $scopeFailure.Output.Contains($expectedPath)) {
            throw "Expected clear failure path '$expectedPath'.`n$($scopeFailure.Output)"
        }
        Remove-Item (Join-Path $sourceRoot $fixture.Path) -Force
    }
    if ($scopeFailure.Output -notmatch '40-character commit SHA' -or
        $scopeFailure.Output -notmatch 'immutable sha256 digest') {
        throw "Expected actionable SHA and Docker digest remediation messages.`n$($scopeFailure.Output)"
    }

    $bypassPath = Join-Path $sourceRoot '.github/workflows/bypass.yml'

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps:`n      - `"uses`": actions/checkout@v4"
    Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4' | Out-Null

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps:`n    - uses: actions/checkout@v4"
    Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4' | Out-Null

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps: [{ uses: actions/checkout@v4 }]"
    $flowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:3'
    if ($flowFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected flow mapping to fail closed as unsupported.`n$($flowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps: [{ `"\x75ses`": actions/checkout@v4 }]"
    $escapedFlowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:3'
    if ($escapedFlowFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected YAML-only escaped flow key to fail closed as unsupported.`n$($escapedFlowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value @"
jobs:
  validate:
    steps: [
      {
        ? uses
        : actions/checkout@v4
      }
    ]
"@
    $flowExplicitFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:5'
    if ($flowExplicitFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected multiline explicit flow mapping to fail closed as unsupported.`n$($flowExplicitFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value 'jobs: { reusable: { uses: owner/workflow@main } }'
    $jobFlowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:1'
    if ($jobFlowFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected job-level flow mapping to fail closed as unsupported.`n$($jobFlowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps:`n      - name: explicit`n        ? uses`n        : actions/checkout@v4"
    $explicitFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:5'
    if ($explicitFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected explicit mapping to fail closed as unsupported.`n$($explicitFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps:`n      - ? uses`n        : actions/checkout@v4"
    $sequenceExplicitFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4'
    if ($sequenceExplicitFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected sequence explicit mapping to fail closed as unsupported.`n$($sequenceExplicitFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps:`n      - &checkout uses: actions/checkout@v4"
    $anchorFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4'
    if ($anchorFailure.Output -notmatch '40-character commit SHA') {
        throw "Expected anchored executable mapping to enforce immutable pinning.`n$($anchorFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value @"
jobs:
  validate:
    strategy:
      matrix:
        include:
          - &checkout
            uses: actions/checkout@v4
    steps:
      - *checkout
"@
    $aliasFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:9'
    if ($aliasFailure.Output -notmatch 'YAML aliases are unsupported') {
        throw "Expected executable step alias to fail closed as unsupported.`n$($aliasFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value @"
jobs:
  validate:
    strategy:
      matrix:
        include:
          - &checkout.step
            uses: actions/checkout@v4
    steps:
      - *checkout.step
"@
    $dottedAliasFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:9'
    if ($dottedAliasFailure.Output -notmatch 'YAML aliases are unsupported') {
        throw "Expected dotted executable step alias to fail closed as unsupported.`n$($dottedAliasFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps: [*checkout]"
    $flowAliasFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:3'
    if ($flowAliasFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected flow-sequence alias to fail closed as unsupported.`n$($flowAliasFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps: [*1]"
    $numericFlowAliasFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:3'
    if ($numericFlowAliasFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected numeric flow-sequence alias to fail closed as unsupported.`n$($numericFlowAliasFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  validate:`n    steps:`n      - <<: *checkout"
    $mergeAliasFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4'
    if ($mergeAliasFailure.Output -notmatch 'YAML aliases are unsupported') {
        throw "Expected executable merge alias to fail closed as unsupported.`n$($mergeAliasFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs: &all-jobs`n  validate:`n    steps:`n      - uses: actions/checkout@v4"
    Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4' | Out-Null

    Set-Content -Path $bypassPath -Value "jobs: &all.jobs`n  validate:`n    steps:`n      - uses: actions/checkout@v4"
    Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4' | Out-Null

    Set-Content -Path $bypassPath -Value "jobs: &all-jobs { validate: { uses: owner/workflow@main } }"
    $anchoredFlowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:1'
    if ($anchoredFlowFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected anchored flow mapping to fail closed as unsupported.`n$($anchoredFlowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "&root jobs:`n  &validate validate:`n    uses: owner/workflow@main"
    Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:3' | Out-Null

    Set-Content -Path $bypassPath -Value "{jobs: {call: {uses: owner/workflow@main}}}"
    $rootFlowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:1'
    if ($rootFlowFailure.Output -notmatch 'Unsupported root YAML flow mapping') {
        throw "Expected root flow mapping to fail closed as unsupported.`n$($rootFlowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "--- jobs:`n  call:`n    uses: owner/workflow@main"
    Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:3' | Out-Null

    Set-Content -Path $bypassPath -Value "--- {jobs: {call: {uses: owner/workflow@main}}}"
    $markedRootFlowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:1'
    if ($markedRootFlowFailure.Output -notmatch 'Unsupported root YAML flow mapping') {
        throw "Expected document-marked root flow mapping to fail closed.`n$($markedRootFlowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "--- &root {jobs: {call: {uses: owner/workflow@main}}}"
    $anchoredMarkedRootFlowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:1'
    if ($anchoredMarkedRootFlowFailure.Output -notmatch 'Unsupported root YAML flow mapping') {
        throw "Expected anchored document root flow mapping to fail closed.`n$($anchoredMarkedRootFlowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "--- !workflow {jobs: {call: {uses: owner/workflow@main}}}"
    $taggedMarkedRootFlowFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:1'
    if ($taggedMarkedRootFlowFailure.Output -notmatch 'Unsupported root YAML flow mapping') {
        throw "Expected tagged document root flow mapping to fail closed.`n$($taggedMarkedRootFlowFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "? jobs`n:`n  build: { uses: owner/workflow@main }"
    $rootExplicitKeyFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:1'
    if ($rootExplicitKeyFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected root explicit mapping key to fail closed.`n$($rootExplicitKeyFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  ? build`n  :`n    uses: owner/workflow@main"
    $jobExplicitKeyFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:2'
    if ($jobExplicitKeyFailure.Output -notmatch 'Unsupported YAML form') {
        throw "Expected explicit job mapping key to fail closed.`n$($jobExplicitKeyFailure.Output)"
    }

    Set-Content -Path $bypassPath -Value "jobs:`n  `"\x62uild`":`n    steps:`n      - uses: actions/checkout@v4"
    $quotedKeyFailure = Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:2'
    if ($quotedKeyFailure.Output -notmatch 'Unsupported YAML quoted mapping key') {
        throw "Expected unsupported YAML quoted job key to fail closed.`n$($quotedKeyFailure.Output)"
    }

    Set-Content -Path $bypassPath -Encoding utf8BOM -Value "jobs:`n  validate:`n    steps:`n      - uses: actions/checkout@v4"
    Assert-ValidatorFails -RootDir $sourceRoot -Expected '.github/workflows/bypass.yml:4' | Out-Null
    Remove-Item $bypassPath -Force

    New-Item -ItemType Directory -Path (Join-Path $installedRoot 'workflows') -Force | Out-Null
    Set-Content -Path (Join-Path $installedRoot 'workflows/valid.yml') -Value @"
jobs:
  validate:
    steps:
      - uses: actions/checkout@$checkoutSha
        with: { uses: nested-input }
      - uses: ./.github/actions/local
"@
    $installedResult = Invoke-Validator -RootDir $installedRoot
    if ($installedResult.ExitCode -ne 0 -or $installedResult.Output -notmatch "mode 'installed'") {
        throw "Expected installed payload layout to pass in installed mode.`n$($installedResult.Output)"
    }

    Set-Content -Path (Join-Path $installedRoot 'workflows/invalid.yml') -Value "jobs:`n  validate:`n    steps:`n      - uses: owner/action@main"
    Assert-ValidatorFails -RootDir $installedRoot -Expected 'workflows/invalid.yml:4' | Out-Null
    Remove-Item (Join-Path $installedRoot 'workflows/invalid.yml') -Force

    foreach ($directory in @('instructions', 'skills', 'prompts', 'agents', 'scripts')) {
        New-Item -ItemType Directory -Path (Join-Path $installedRoot $directory) -Force | Out-Null
    }
    Set-Content -Path (Join-Path $installedRoot 'README.md') -Value '# Installed fixture'
    Set-Content -Path (Join-Path $installedRoot 'CHANGELOG.md') -Value '# Changes'
    Set-Content -Path (Join-Path $installedRoot 'INVENTORY.md') -Value '# Inventory'
    Set-Content -Path (Join-Path $installedRoot 'version.json') -Value '{"version":"1.0.0"}'
    Set-Content -Path (Join-Path $installedRoot 'asset-manifest.json') -Value '{"schemaVersion":"1","libraryVersion":"1.0.0","assets":[{"path":"workflows/valid.yml"}]}'
    Set-Content -Path (Join-Path $installedRoot 'sync.sh') -Value '#!/usr/bin/env bash'
    Set-Content -Path (Join-Path $installedRoot 'sync.ps1') -Value '$true'
    foreach ($scriptName in @(
            'validate-basecoat.ps1',
            'validate-workflow-action-pins.ps1',
            'validate-workflow-action-pins.py'
        )) {
        Copy-Item -Path (Join-Path $repoRoot "scripts/$scriptName") -Destination (Join-Path $installedRoot "scripts/$scriptName")
    }

    Push-Location $fixtureRoot
    try {
        $relativeInstalledRoot = [System.IO.Path]::GetRelativePath($fixtureRoot, $installedRoot)
        $consumerOutput = & (Join-Path $installedRoot 'scripts/validate-basecoat.ps1') -RootDir $relativeInstalledRoot 2>&1
        if ($LASTEXITCODE -ne 0 -or ($consumerOutput | Out-String) -notmatch "mode 'installed'") {
            throw "Expected relative installed payload validation to pass.`n$($consumerOutput | Out-String)"
        }
    }
    finally {
        Pop-Location
    }

    $missingInstalledRoot = Join-Path $fixtureRoot 'missing-installed'
    New-Item -ItemType Directory -Path $missingInstalledRoot -Force | Out-Null
    Assert-ValidatorFails -RootDir $missingInstalledRoot -Mode Installed -Expected 'Required workflow validation scope is missing: workflows' | Out-Null

    $missingSourceRoot = Join-Path $fixtureRoot 'missing-source'
    foreach ($directory in $sourceWorkflowDirectories | Where-Object { $_ -ne 'docs/examples/workflows' }) {
        New-Item -ItemType Directory -Path (Join-Path $missingSourceRoot $directory) -Force | Out-Null
    }
    Assert-ValidatorFails -RootDir $missingSourceRoot -Mode Source -Expected 'Required workflow validation scope is missing: docs/examples/workflows' | Out-Null

    $missingStarterRoot = Join-Path $fixtureRoot 'missing-starter-workflows'
    foreach ($directory in $sourceWorkflowDirectories | Where-Object { $_ -ne '.github/workflow-templates' }) {
        New-Item -ItemType Directory -Path (Join-Path $missingStarterRoot $directory) -Force | Out-Null
    }
    Assert-ValidatorFails -RootDir $missingStarterRoot -Mode Source -Expected 'Required workflow validation scope is missing: .github/workflow-templates' | Out-Null

    $vendoredTemplateRoot = Join-Path $fixtureRoot 'vendored-template-workflows'
    foreach ($directory in $sourceWorkflowDirectories | Where-Object { $_ -ne '.github/template-repos/example/.github/workflows' }) {
        New-Item -ItemType Directory -Path (Join-Path $vendoredTemplateRoot $directory) -Force | Out-Null
    }
    New-Item -ItemType Directory -Path (Join-Path $vendoredTemplateRoot '.github/template-repos/example/node_modules/dependency/.github/workflows') -Force | Out-Null
    Assert-ValidatorFails -RootDir $vendoredTemplateRoot -Mode Source -Expected 'Required workflow validation scope is missing: .github/template-repos/**/.github/workflows' | Out-Null

    $missingSkillRoot = Join-Path $fixtureRoot 'missing-skills'
    foreach ($directory in $sourceWorkflowDirectories | Where-Object { $_ -ne 'skills/example' }) {
        New-Item -ItemType Directory -Path (Join-Path $missingSkillRoot $directory) -Force | Out-Null
    }
    Assert-ValidatorFails -RootDir $missingSkillRoot -Mode Source -Expected 'Required workflow validation scope is missing: skills' | Out-Null

    Push-Location $repoRoot
    try {
        $relativeSourceRoot = [System.IO.Path]::GetRelativePath($repoRoot, $sourceRoot)
        $relativeResult = Invoke-Validator -RootDir $relativeSourceRoot
        if ($relativeResult.ExitCode -ne 0) {
            throw "Expected relative source root to resolve once and pass.`n$($relativeResult.Output)"
        }
    }
    finally {
        Pop-Location
    }

    $repositoryResult = Invoke-Validator -RootDir $repoRoot -Mode Source
    if ($repositoryResult.ExitCode -ne 0) {
        throw "Repository workflow references must pass validation.`n$($repositoryResult.Output)"
    }

    Write-Host 'Workflow action pinning tests passed'
}
finally {
    if (Test-Path $fixtureRoot) {
        Remove-Item $fixtureRoot -Recurse -Force
    }
}
