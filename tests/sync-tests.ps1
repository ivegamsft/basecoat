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

    foreach ($excluded in @('tests', 'scripts', 'sync.ps1', 'sync.sh', '.github', '.gitignore', '.gitleaks.toml', 'basecoat-metadata.json')) {
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

    foreach ($required in @('reference', 'guides')) {
        $testCount++
        Assert-SyncPathExists -Path (Join-Path $docsTargetDir $required) `
            -Message "Sync test failed: required docs subtree '$required' missing from overlay"
    }

    $testCount++
    Assert-SyncPathExists -Path (Join-Path $docsTargetDir 'agents/AGENTS.md') `
        -Message 'Sync test failed: docs/agents/AGENTS.md missing from overlay'

    foreach ($excludedDocsSubtree in @('archive', 'architecture', 'diagrams', 'examples', 'memory', 'operations', 'research', 'templates')) {
        $testCount++
        Assert-SyncPathNotExists -Path (Join-Path $docsTargetDir $excludedDocsSubtree) `
            -Message "Sync test failed: excluded docs subtree '$excludedDocsSubtree' should not be synced"
    }

    $testCount++
    Assert-SyncPathNotExists -Path (Join-Path $docsTargetDir 'index.md') `
        -Message 'Sync test failed: docs/index.md should not be synced'

    $topLevelDocsEntries = @(Get-ChildItem -Path $docsTargetDir -Force | ForEach-Object { $_.Name })
    $unexpectedDocsEntries = $topLevelDocsEntries | Where-Object { $_ -notin @('reference', 'guides', 'agents') }
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
