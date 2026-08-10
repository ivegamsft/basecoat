$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$failures = @()
$testCount = 0

function Assert-SyncPathExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (-not (Test-Path $Path)) {
        throw $Message
    }
}

function Assert-SyncPathNotExists {
    param(
        [string]$Path,
        [string]$Message
    )

    if (Test-Path $Path) {
        throw $Message
    }
}

Write-Host 'Starting sync process tests...' -ForegroundColor Cyan

# ============================================================================
# Helper: create a consumer repo and run sync.ps1 against it
# ============================================================================
function New-ConsumerRepo {
    param(
        [switch]$WithGitHubDir
    )

    $tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-sync-test-" + [System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempRepo | Out-Null

    Push-Location $tempRepo
    git init | Out-Null
    git config user.name 'basecoat-test'
    git config user.email 'basecoat-test@example.com'
    Set-Content -Path 'README.md' -Value '# Consumer Repo'
    git add README.md
    git commit -m 'initial commit' | Out-Null

    if ($WithGitHubDir) {
        New-Item -ItemType Directory -Force -Path (Join-Path $tempRepo '.github') | Out-Null
    }

    Pop-Location
    return $tempRepo
}

function Invoke-SyncToConsumer {
    param(
        [string]$ConsumerPath
    )

    # Create a temporary named branch so git clone --branch works even in
    # detached-HEAD CI environments (tag checkouts, PR merge commits).
    $testBranch = "sync-test-" + [System.Guid]::NewGuid().ToString().Substring(0, 8)
    git -C $repoRoot branch $testBranch HEAD 2>&1 | Out-Null

    Push-Location $ConsumerPath
    try {
        $env:BASECOAT_REPO = "file://$repoRoot"
        $env:BASECOAT_REF = $testBranch
        & pwsh -NoProfile -File (Join-Path $repoRoot 'sync.ps1')
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO -ErrorAction SilentlyContinue
        Remove-Item Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        git -C $repoRoot branch -D $testBranch 2>&1 | Out-Null
        Pop-Location
    }
}

function Invoke-SyncToConsumerWithSource {
    param(
        [string]$ConsumerPath,
        [string]$SourceRepo,
        [string]$SourceRef
    )

    Push-Location $ConsumerPath
    try {
        $env:BASECOAT_REPO = $SourceRepo
        $env:BASECOAT_REF = $SourceRef
        & pwsh -NoProfile -File (Join-Path $repoRoot 'sync.ps1')
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO -ErrorAction SilentlyContinue
        Remove-Item Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        Pop-Location
    }
}

function Get-FileSha256 {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Invoke-CleanupToConsumer {
    param(
        [string]$ConsumerPath,
        [bool]$ProtectCustomized = $true,
        [bool]$SetArchiveReadOnly = $true
    )

    Push-Location $ConsumerPath
    try {
        & pwsh -NoProfile -File (Join-Path $repoRoot 'scripts/cleanup-basecoat-upgrade.ps1') `
            -TargetDir '.github/base-coat' `
            -ProtectCustomized:$ProtectCustomized `
            -SetArchiveReadOnly:$SetArchiveReadOnly
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# Test 1: Sync populates .github/ Copilot-discoverable directories
# ============================================================================
Write-Host "`nTest 1: Sync populates .github/ Copilot-discoverable directories" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    Invoke-SyncToConsumer -ConsumerPath $consumer

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/agents') `
        -Message 'Sync test failed: .github/agents/ not created'

    $testCount++
    $agentCount = (Get-ChildItem (Join-Path $consumer '.github/agents') -Filter '*.agent.md' -File).Count
    if ($agentCount -eq 0) {
        throw 'Sync test failed: .github/agents/ contains no agent files'
    }

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/instructions') `
        -Message 'Sync test failed: .github/instructions/ not created'

    $testCount++
    $instrCount = (Get-ChildItem (Join-Path $consumer '.github/instructions') -Filter '*.instructions.md' -File).Count
    if ($instrCount -eq 0) {
        throw 'Sync test failed: .github/instructions/ contains no instruction files'
    }

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/prompts') `
        -Message 'Sync test failed: .github/prompts/ not created'

    $testCount++
    $promptCount = (Get-ChildItem (Join-Path $consumer '.github/prompts') -Filter '*.prompt.md' -File).Count
    if ($promptCount -eq 0) {
        throw 'Sync test failed: .github/prompts/ contains no prompt files'
    }

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/PULL_REQUEST_TEMPLATE.md') `
        -Message 'Sync test failed: .github/PULL_REQUEST_TEMPLATE.md not seeded'

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/ISSUE_TEMPLATE/issue.md') `
        -Message 'Sync test failed: .github/ISSUE_TEMPLATE/issue.md not seeded'

    Write-Host "  Passed: agents($agentCount), instructions($instrCount), prompts($promptCount) synced" -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 6: Cleanup removes stale unchanged files but preserves customized/unverified
# ============================================================================
Write-Host "`nTest 6: Cleanup removes stale unchanged files but preserves customized/unverified" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    $targetDir = Join-Path $consumer '.github/base-coat'
    $statePath = Join-Path $targetDir '.sync-state.json'
    $manifestPath = Join-Path $targetDir 'asset-manifest.json'

    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    '{ "schemaVersion": "1", "assets": [] }' | Set-Content -Path $manifestPath -Encoding UTF8
    '{}' | Set-Content -Path (Join-Path $targetDir 'basecoat-metadata.json') -Encoding UTF8
    '{ "version": "0.0.0-test" }' | Set-Content -Path (Join-Path $targetDir 'version.json') -Encoding UTF8
    '# test' | Set-Content -Path (Join-Path $targetDir 'README.md') -Encoding UTF8
    '# changelog' | Set-Content -Path (Join-Path $targetDir 'CHANGELOG.md') -Encoding UTF8

    $staleUnchanged = Join-Path $targetDir 'agents/stale-unchanged.agent.md'
    $staleCustomized = Join-Path $targetDir 'agents/stale-customized.agent.md'
    $staleUnverified = Join-Path $targetDir 'agents/stale-unverified.agent.md'
    New-Item -ItemType Directory -Force -Path (Split-Path $staleUnchanged -Parent) | Out-Null

    'unchanged' | Set-Content -Path $staleUnchanged -Encoding UTF8
    'custom-original' | Set-Content -Path $staleCustomized -Encoding UTF8
    'custom-unverified' | Set-Content -Path $staleUnverified -Encoding UTF8

    $staleUnchangedHash = Get-FileSha256 -Path $staleUnchanged
    $staleCustomizedHash = Get-FileSha256 -Path $staleCustomized
    'custom-modified' | Set-Content -Path $staleCustomized -Encoding UTF8

    $state = [ordered]@{
        schemaVersion = '1'
        generatedAt = (Get-Date).ToString('o')
        targetDir = '.github/base-coat'
        managedFiles = @(
            [ordered]@{ path = 'agents/stale-unchanged.agent.md'; sha256 = $staleUnchangedHash }
            [ordered]@{ path = 'agents/stale-customized.agent.md'; sha256 = $staleCustomizedHash }
            [ordered]@{ path = 'agents/stale-unverified.agent.md' }
        )
    }
    $state | ConvertTo-Json -Depth 6 | Set-Content -Path $statePath -Encoding UTF8

    Invoke-CleanupToConsumer -ConsumerPath $consumer -ProtectCustomized $true -SetArchiveReadOnly $false

    $testCount++
    Assert-SyncPathNotExists -Path $staleUnchanged `
        -Message 'Sync cleanup test failed: unchanged stale managed file should be removed'

    $testCount++
    Assert-SyncPathExists -Path $staleCustomized `
        -Message 'Sync cleanup test failed: customized stale file should be preserved'

    $testCount++
    Assert-SyncPathExists -Path $staleUnverified `
        -Message 'Sync cleanup test failed: unverified stale file should be preserved'

    Write-Host '  Passed: stale cleanup is hash-safe for unchanged/customized/unverified files' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 7: Cleanup marks archive files as read-only by policy
# ============================================================================
Write-Host "`nTest 7: Cleanup marks archive files as read-only by policy" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    $targetDir = Join-Path $consumer '.github/base-coat'
    $manifestPath = Join-Path $targetDir 'asset-manifest.json'
    $archiveFile = Join-Path $targetDir 'docs/archive/policy-check.md'

    New-Item -ItemType Directory -Force -Path (Split-Path $archiveFile -Parent) | Out-Null
    '{ "schemaVersion": "1", "assets": [] }' | Set-Content -Path $manifestPath -Encoding UTF8
    'archive data' | Set-Content -Path $archiveFile -Encoding UTF8

    Invoke-CleanupToConsumer -ConsumerPath $consumer -ProtectCustomized $true -SetArchiveReadOnly $true

    $testCount++
    if (-not (Get-Item -Path $archiveFile).IsReadOnly) {
        throw 'Sync cleanup test failed: archive file should be marked read-only'
    }

    Write-Host '  Passed: archive policy marks docs/archive files as read-only' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 2: Sync populates base-coat target directory with metadata
# ============================================================================
Write-Host "`nTest 2: Sync populates base-coat target directory with metadata" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    Invoke-SyncToConsumer -ConsumerPath $consumer

    $targetDir = Join-Path $consumer '.github/base-coat'

    foreach ($item in @('README.md', 'CHANGELOG.md', 'version.json', 'asset-manifest.json')) {
        $testCount++
        Assert-SyncPathExists -Path (Join-Path $targetDir $item) `
            -Message "Sync test failed: $item not found in target directory"
    }

    foreach ($dir in @('agents', 'instructions', 'prompts', 'skills')) {
        $testCount++
        Assert-SyncPathExists -Path (Join-Path $targetDir $dir) `
            -Message "Sync test failed: $dir/ not found in target directory"
    }

    foreach ($runtimeScript in @(
            'scripts/cleanup-branches.ps1',
            'scripts/publish-orphaned-lane-ledger.ps1',
            'scripts/validate-basecoat.ps1',
            'scripts/validate-basecoat.sh',
            'scripts/validate-workflow-action-pins.ps1',
            'scripts/validate-workflow-action-pins.py'
        )) {
        $testCount++
        Assert-SyncPathExists -Path (Join-Path $targetDir $runtimeScript) `
            -Message "Sync test failed: distributed runtime '$runtimeScript' not found"
    }

    $invalidWorkflow = Join-Path $targetDir 'workflows/sync-test-unpinned.yml'
    Push-Location $repoRoot
    try {
        & (Join-Path $targetDir 'scripts/validate-basecoat.ps1') -RootDir $targetDir -WorkflowValidationMode Installed

        Set-Content -Path $invalidWorkflow -Value "jobs:`n  validate:`n    steps:`n      - uses: actions/checkout@v4"
        $rejected = $false
        try {
            & (Join-Path $targetDir 'scripts/validate-basecoat.ps1') -RootDir $targetDir -WorkflowValidationMode Installed
        }
        catch {
            $rejected = $true
        }
    }
    finally {
        Pop-Location
        Remove-Item $invalidWorkflow -Force -ErrorAction SilentlyContinue
    }
    if (-not $rejected) {
        throw 'Sync test failed: installed validator accepted an unpinned workflow action'
    }

    Write-Host "  Passed: target directory contains expected metadata and asset directories" -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 3: Non-distributed files are NOT copied
# ============================================================================
Write-Host "`nTest 3: Non-distributed files are NOT copied" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    Invoke-SyncToConsumer -ConsumerPath $consumer

    $targetDir = Join-Path $consumer '.github/base-coat'

    foreach ($excluded in @('tests', 'sync.ps1', 'sync.sh', '.github', '.gitignore', '.gitleaks.toml', 'basecoat-metadata.json')) {
        $testCount++
        Assert-SyncPathNotExists -Path (Join-Path $targetDir $excluded) `
            -Message "Sync test failed: non-distributed item '$excluded' was copied to target"
    }

    Write-Host "  Passed: non-distributed files excluded from sync" -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 4: Sync works when .github/ does not pre-exist (issue #249 edge case)
# ============================================================================
Write-Host "`nTest 4: Sync works when .github/ does not pre-exist (issue #249)" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo  # no -WithGitHubDir flag

    $testCount++
    Assert-SyncPathNotExists -Path (Join-Path $consumer '.github') `
        -Message 'Sync test precondition failed: .github/ should not exist before sync'

    Invoke-SyncToConsumer -ConsumerPath $consumer

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/agents') `
        -Message 'Sync test failed: .github/agents/ not created when .github/ was missing'

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/instructions') `
        -Message 'Sync test failed: .github/instructions/ not created when .github/ was missing'

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/prompts') `
        -Message 'Sync test failed: .github/prompts/ not created when .github/ was missing'

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $consumer '.github/base-coat/version.json') `
        -Message 'Sync test failed: target directory not populated when .github/ was missing'

    Write-Host "  Passed: sync succeeds even without pre-existing .github/" -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 5: Sync enforces minimal docs overlay scope
# ============================================================================
Write-Host "`nTest 5: Sync enforces minimal docs overlay scope" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    Invoke-SyncToConsumer -ConsumerPath $consumer

    $docsTargetDir = Join-Path $consumer '.github/base-coat/docs'

    foreach ($required in @('reference', 'guides', 'diagrams')) {
        $testCount++
        Assert-SyncPathExists -Path (Join-Path $docsTargetDir $required) `
            -Message "Sync test failed: required docs subtree '$required' missing from overlay"
    }

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $docsTargetDir 'agents/AGENTS.md') `
        -Message 'Sync test failed: docs/agents/agents.md missing from overlay'

    foreach ($excludedDocsSubtree in @('archive', 'architecture', 'examples', 'memory', 'operations', 'research', 'templates')) {
        $testCount++
        Assert-SyncPathNotExists -Path (Join-Path $docsTargetDir $excludedDocsSubtree) `
            -Message "Sync test failed: excluded docs subtree '$excludedDocsSubtree' should not be synced"
    }

    $testCount++
    Assert-SyncPathNotExists -Path (Join-Path $docsTargetDir 'index.md') `
        -Message 'Sync test failed: docs/index.md should not be synced'

    $topLevelDocsEntries = @(Get-ChildItem -Path $docsTargetDir -Force | ForEach-Object { $_.Name })
    $unexpectedDocsEntries = $topLevelDocsEntries | Where-Object { $_ -notin @('reference', 'guides', 'agents', 'diagrams') }
    $testCount++
    if ($unexpectedDocsEntries.Count -gt 0) {
        $unexpected = ($unexpectedDocsEntries | Sort-Object) -join ', '
        throw "Sync test failed: unexpected docs entries found in overlay: $unexpected"
    }

    $agentDocsEntries = @(Get-ChildItem -Path (Join-Path $docsTargetDir 'agents') -Force | ForEach-Object { $_.Name })
    $unexpectedAgentDocsEntries = $agentDocsEntries | Where-Object { $_ -ne 'AGENTS.md' }
    $testCount++
    if ($unexpectedAgentDocsEntries.Count -gt 0) {
        $unexpected = ($unexpectedAgentDocsEntries | Sort-Object) -join ', '
        throw "Sync test failed: docs/agents should only contain AGENTS.md but found: $unexpected"
    }

    Write-Host '  Passed: docs overlay constrained to minimal scope' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 8: Sync does not overwrite customized intake templates
# ============================================================================
Write-Host "`nTest 8: Sync preserves customized intake templates" -ForegroundColor Yellow

$consumer = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir

    $customPrTemplate = Join-Path $consumer '.github/PULL_REQUEST_TEMPLATE.md'
    $customIssueTemplate = Join-Path $consumer '.github/ISSUE_TEMPLATE/issue.md'
    New-Item -ItemType Directory -Force -Path (Split-Path $customIssueTemplate -Parent) | Out-Null

    $prSentinel = '# custom-pr-template-sentinel'
    $issueSentinel = '# custom-issue-template-sentinel'
    Set-Content -Path $customPrTemplate -Value $prSentinel -Encoding UTF8
    Set-Content -Path $customIssueTemplate -Value $issueSentinel -Encoding UTF8

    Invoke-SyncToConsumer -ConsumerPath $consumer

    $testCount++
    $prAfter = Get-Content -Path $customPrTemplate -Raw
    if ($prAfter -notmatch [regex]::Escape($prSentinel)) {
        throw 'Sync test failed: custom PR template was overwritten'
    }

    $testCount++
    $issueAfter = Get-Content -Path $customIssueTemplate -Raw
    if ($issueAfter -notmatch [regex]::Escape($issueSentinel)) {
        throw 'Sync test failed: custom issue template was overwritten'
    }

    Write-Host '  Passed: custom intake templates are preserved' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
}

# ============================================================================
# Test 9: Sync blocks invalid workflow definitions before propagation (#2040)
# ============================================================================
Write-Host "`nTest 9: Sync blocks invalid workflow definitions before propagation (#2040)" -ForegroundColor Yellow

$consumer = $null
$sourceFixture = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    $sourceFixture = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-sync-source-" + [System.Guid]::NewGuid().ToString())
    $invalidRef = "sync-invalid-workflow-" + [System.Guid]::NewGuid().ToString().Substring(0, 8)

    git clone --no-hardlinks $repoRoot $sourceFixture | Out-Null
    git -C $sourceFixture checkout -B $invalidRef HEAD | Out-Null
    git -C $sourceFixture config user.name 'basecoat-test' | Out-Null
    git -C $sourceFixture config user.email 'basecoat-test@example.com' | Out-Null

    $workflowDir = Join-Path $sourceFixture '.github/base-coat/workflows'
    New-Item -ItemType Directory -Force -Path $workflowDir | Out-Null

    $invalidWorkflow = Join-Path $workflowDir 'invalid-local-uses.yml'
    @'
name: Invalid Local Uses
on:
  workflow_dispatch:
jobs:
  bad:
    uses: ./.github/base-coat/workflows/check-version.yml
'@ | Set-Content -Path $invalidWorkflow -Encoding UTF8

    git -C $sourceFixture add .github/base-coat/workflows/invalid-local-uses.yml | Out-Null
    git -C $sourceFixture commit -m 'test(sync): add invalid workflow fixture' | Out-Null

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$sourceFixture"
        $env:BASECOAT_REF = $invalidRef
        $output = & pwsh -NoProfile -File (Join-Path $repoRoot 'sync.ps1') 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO -ErrorAction SilentlyContinue
        Remove-Item Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        Pop-Location
    }

    $testCount++
    if ($exitCode -eq 0) {
        throw 'Sync test failed: sync.ps1 should fail when source workflows contain invalid reusable workflow paths'
    }

    $testCount++
    if ($output -notmatch 'Workflow validation failed before sync') {
        throw "Sync test failed: expected pre-sync validation failure message, got: $output"
    }

    $testCount++
    if ($output -notmatch 'invalid-local-uses\.yml') {
        throw "Sync test failed: expected invalid workflow file to be reported, got: $output"
    }

    Write-Host '  Passed: invalid workflow definitions are rejected before sync copy' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
    if ($sourceFixture -and (Test-Path $sourceFixture)) {
        Remove-Item -Path $sourceFixture -Recurse -Force
    }
}

# ============================================================================
# Test 10: Sync auto-remaps known bad tags
# ============================================================================
Write-Host "`nTest 10: Sync auto-remaps known bad tags to corrected releases" -ForegroundColor Yellow

$consumer = $null
$sourceRepo = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    $sourceRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-sync-source-remap-test-" + [System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $sourceRepo | Out-Null

    Push-Location $sourceRepo
    try {
        git init | Out-Null
        git config user.name 'basecoat-test'
        git config user.email 'basecoat-test@example.com'

        New-Item -ItemType Directory -Force -Path 'agents', 'instructions', 'skills/example-skill', 'prompts', 'docs/reference', 'docs/guides' | Out-Null
        Set-Content -Path 'README.md' -Value '# Source Repo' -Encoding UTF8
        Set-Content -Path 'CHANGELOG.md' -Value '# Changelog' -Encoding UTF8
        Set-Content -Path 'version.json' -Value '{ "version": "3.30.5", "releaseDate": "2026-06-06" }' -Encoding UTF8
        Set-Content -Path 'asset-manifest.json' -Value '{ "schemaVersion": "1", "assets": [] }' -Encoding UTF8
        Set-Content -Path 'agents/example.agent.md' -Value "---`nname: example`ndescription: example`n---`n" -Encoding UTF8
        Set-Content -Path 'instructions/example.instructions.md' -Value "---`ndescription: example`napplyTo: ""**/*""`n---`n" -Encoding UTF8
        Set-Content -Path 'prompts/example.prompt.md' -Value "---`nname: example`ndescription: example`n---`n" -Encoding UTF8
        Set-Content -Path 'skills/example-skill/SKILL.md' -Value "---`nname: example`ndescription: example`ncompatibility: [github-copilot-cli]`n---`n" -Encoding UTF8
        Set-Content -Path 'docs/reference/README.md' -Value '# Reference' -Encoding UTF8
        Set-Content -Path 'docs/guides/README.md' -Value '# Guides' -Encoding UTF8

        git add .
        git commit -m 'seed source' | Out-Null
        git tag 'v3.30.5'
        git tag 'v3.30.4'
    }
    finally {
        Pop-Location
    }

    Invoke-SyncToConsumerWithSource -ConsumerPath $consumer -SourceRepo "file://$sourceRepo" -SourceRef 'v3.30.4'

    $testCount++
    $installedVersion = (Get-Content -Path (Join-Path $consumer '.github/base-coat/version.json') -Raw | ConvertFrom-Json).version
    if ($installedVersion -ne '3.30.5') {
        throw "Sync remap test failed: expected installed version 3.30.5, got $installedVersion"
    }

    Write-Host '  Passed: known-bad tag was auto-remapped to corrected release' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
    if ($sourceRepo -and (Test-Path $sourceRepo)) {
        Remove-Item -Path $sourceRepo -Recurse -Force
    }
}

# ============================================================================
# Test 11: Sync rejects semver tags whose payload version drifts
# ============================================================================
Write-Host "`nTest 11: Sync rejects semver tags whose payload version drifts" -ForegroundColor Yellow

$consumer = $null
$sourceRepo = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    $sourceRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-sync-source-drift-test-" + [System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $sourceRepo | Out-Null

    Push-Location $sourceRepo
    try {
        git init | Out-Null
        git config user.name 'basecoat-test'
        git config user.email 'basecoat-test@example.com'

        New-Item -ItemType Directory -Force -Path 'agents', 'instructions', 'skills/example-skill', 'prompts', 'docs/reference', 'docs/guides' | Out-Null
        Set-Content -Path 'README.md' -Value '# Source Repo' -Encoding UTF8
        Set-Content -Path 'CHANGELOG.md' -Value '# Changelog' -Encoding UTF8
        Set-Content -Path 'version.json' -Value '{ "version": "9.9.9", "releaseDate": "2026-06-06" }' -Encoding UTF8
        Set-Content -Path 'asset-manifest.json' -Value '{ "schemaVersion": "1", "assets": [] }' -Encoding UTF8
        Set-Content -Path 'agents/example.agent.md' -Value "---`nname: example`ndescription: example`n---`n" -Encoding UTF8
        Set-Content -Path 'instructions/example.instructions.md' -Value "---`ndescription: example`napplyTo: ""**/*""`n---`n" -Encoding UTF8
        Set-Content -Path 'prompts/example.prompt.md' -Value "---`nname: example`ndescription: example`n---`n" -Encoding UTF8
        Set-Content -Path 'skills/example-skill/SKILL.md' -Value "---`nname: example`ndescription: example`ncompatibility: [github-copilot-cli]`n---`n" -Encoding UTF8
        Set-Content -Path 'docs/reference/README.md' -Value '# Reference' -Encoding UTF8
        Set-Content -Path 'docs/guides/README.md' -Value '# Guides' -Encoding UTF8

        git add .
        git commit -m 'seed drift source' | Out-Null
        git tag 'v1.2.3'
    }
    finally {
        Pop-Location
    }

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$sourceRepo"
        $env:BASECOAT_REF = 'v1.2.3'
        $output = & pwsh -NoProfile -File (Join-Path $repoRoot 'sync.ps1') 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO -ErrorAction SilentlyContinue
        Remove-Item Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        Pop-Location
    }

    $testCount++
    if ($exitCode -eq 0) {
        throw 'Sync provenance test failed: sync.ps1 should fail when semver tag payload version drifts'
    }

    $testCount++
    if ($output -notmatch 'BaseCoat ref/version provenance check failed') {
        throw "Sync provenance test failed: expected provenance failure message, got: $output"
    }

    Write-Host '  Passed: semver tag/version drift is rejected by sync provenance checks' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) {
        Remove-Item -Path $consumer -Recurse -Force
    }
    if ($sourceRepo -and (Test-Path $sourceRepo)) {
        Remove-Item -Path $sourceRepo -Recurse -Force
    }
}

# ============================================================================
# .basecoat.yml source/ref resolution (issue #2705)
# ============================================================================
Write-Host "`nTesting .basecoat.yml source/ref pinning..." -ForegroundColor Cyan

function New-BasecoatSource {
    param([string]$Marker)

    $sourceRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("basecoat-sync-pin-source-" + [System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $sourceRepo | Out-Null

    Push-Location $sourceRepo
    try {
        git init | Out-Null
        git config user.name 'basecoat-test'
        git config user.email 'basecoat-test@example.com'

        New-Item -ItemType Directory -Force -Path 'agents', 'instructions', 'skills/example-skill', 'prompts', 'docs/reference', 'docs/guides' | Out-Null
        Set-Content -Path 'README.md' -Value '# Source Repo' -Encoding UTF8
        Set-Content -Path 'CHANGELOG.md' -Value '# Changelog' -Encoding UTF8
        Set-Content -Path 'version.json' -Value '{ "version": "9.9.9", "releaseDate": "2026-06-06" }' -Encoding UTF8
        Set-Content -Path 'asset-manifest.json' -Value '{ "schemaVersion": "1", "assets": [] }' -Encoding UTF8
        Set-Content -Path 'agents/base.agent.md' -Value "---`nname: base`ndescription: base`n---`n" -Encoding UTF8
        Set-Content -Path 'instructions/example.instructions.md' -Value "---`ndescription: example`napplyTo: ""**/*""`n---`n" -Encoding UTF8
        Set-Content -Path 'prompts/example.prompt.md' -Value "---`nname: example`ndescription: example`n---`n" -Encoding UTF8
        Set-Content -Path 'skills/example-skill/SKILL.md' -Value "---`nname: example`ndescription: example`ncompatibility: [github-copilot-cli]`n---`n" -Encoding UTF8
        Set-Content -Path 'docs/reference/README.md' -Value '# Reference' -Encoding UTF8
        Set-Content -Path 'docs/guides/README.md' -Value '# Guides' -Encoding UTF8

        git add .
        git commit -m 'seed pin source (default branch, no pin marker)' | Out-Null
        $defaultBranch = (git rev-parse --abbrev-ref HEAD).Trim()

        # Build the pinned release on a throwaway branch so its unique marker is
        # reachable ONLY via the v9.9.9 tag, never from the default branch. The
        # content assertion then fails if a sync clones the default branch instead
        # of the pinned ref. The v9.9.9 tag also exercises the semver-provenance
        # path (version.json already reports 9.9.9).
        git checkout -q -b _pin-build | Out-Null
        Set-Content -Path "agents/$Marker.agent.md" -Value "---`nname: $Marker`ndescription: $Marker`n---`n" -Encoding UTF8
        git add "agents/$Marker.agent.md"
        git commit -m 'pinned release marker' | Out-Null
        git tag 'v9.9.9' | Out-Null
        git checkout -q $defaultBranch | Out-Null
        git branch -D _pin-build | Out-Null
    }
    finally {
        Pop-Location
    }

    return $sourceRepo
}

$consumer = $null
$sourceRepo = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    $sourceRepo = New-BasecoatSource -Marker 'pinmarker'

    # Consumer pins source + ref via .basecoat.yml, with NO env overrides.
    Set-Content -Path (Join-Path $consumer '.basecoat.yml') -Value @(
        "source: file://$sourceRepo"
        'ref: v9.9.9'
    ) -Encoding UTF8

    Push-Location $consumer
    try {
        Remove-Item Env:\BASECOAT_REPO -ErrorAction SilentlyContinue
        Remove-Item Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        $output = & pwsh -NoProfile -File (Join-Path $repoRoot 'sync.ps1') 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    $testCount++
    if ($exitCode -ne 0) {
        throw "Sync .basecoat.yml pin test failed: sync.ps1 exited $exitCode. Output: $output"
    }

    $testCount++
    if ($output -notmatch "ref 'v9.9.9' \(from \.basecoat\.yml\)") {
        throw "Sync .basecoat.yml pin test failed: expected ref resolved from .basecoat.yml, got: $output"
    }

    $testCount++
    Assert-SyncPathExists (Join-Path $consumer '.github/agents/pinmarker.agent.md') 'Sync .basecoat.yml pin test failed: pinned-ref-only agent was not synced (clone did not follow the pinned tag)'

    Write-Host '  Passed: .basecoat.yml source/ref is honored when env vars are unset' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) { Remove-Item -Path $consumer -Recurse -Force }
    if ($sourceRepo -and (Test-Path $sourceRepo)) { Remove-Item -Path $sourceRepo -Recurse -Force }
}

# Env vars must take precedence over .basecoat.yml.
$consumer = $null
$sourceRepo = $null
try {
    $consumer = New-ConsumerRepo -WithGitHubDir
    $sourceRepo = New-BasecoatSource -Marker 'pinmarker'

    # .basecoat.yml points at a non-existent ref; env override must win.
    Set-Content -Path (Join-Path $consumer '.basecoat.yml') -Value @(
        "source: file://$sourceRepo"
        'ref: does-not-exist'
    ) -Encoding UTF8

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$sourceRepo"
        $env:BASECOAT_REF = 'v9.9.9'
        $output = & pwsh -NoProfile -File (Join-Path $repoRoot 'sync.ps1') 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO -ErrorAction SilentlyContinue
        Remove-Item Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        Pop-Location
    }

    $testCount++
    if ($exitCode -ne 0) {
        throw "Sync env-precedence test failed: sync.ps1 exited $exitCode (env override should be used). Output: $output"
    }

    $testCount++
    if ($output -notmatch "ref 'v9.9.9' \(from env\)") {
        throw "Sync env-precedence test failed: expected ref resolved from env, got: $output"
    }

    $testCount++
    Assert-SyncPathExists (Join-Path $consumer '.github/agents/pinmarker.agent.md') 'Sync env-precedence test failed: pinned-ref-only agent was not synced (clone did not follow the env ref)'

    Write-Host '  Passed: BASECOAT_REF env var takes precedence over .basecoat.yml' -ForegroundColor Green
}
catch {
    $failures += $_.Exception.Message
}
finally {
    if ($consumer -and (Test-Path $consumer)) { Remove-Item -Path $consumer -Recurse -Force }
    if ($sourceRepo -and (Test-Path $sourceRepo)) { Remove-Item -Path $sourceRepo -Recurse -Force }
}

# ============================================================================
# Summary
# ============================================================================
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host 'Sync Test Summary' -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

if ($failures.Count -gt 0) {
    Write-Host "`nFAILED: $($failures.Count) issues found" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nTotal checks performed: $testCount" -ForegroundColor Yellow
    exit 1
}

Write-Host "`nAll sync tests passed ($testCount checks)" -ForegroundColor Green
exit 0
