$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scratch = Join-Path $repoRoot 'test-results/guidance-lock'
$checks = 0
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:checks++
    if (-not $Condition) { throw $Message }
}

function New-TestSource {
    param([string]$Path)

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    foreach ($dir in @(
        'agents', 'agents/references', 'instructions', 'prompts', 'skills',
        'templates', 'schemas', 'scripts', 'docs/reference', 'docs/guides',
        '.github/base-coat/scripts'
    )) {
        New-Item -ItemType Directory -Path (Join-Path $Path $dir) -Force | Out-Null
    }
    '{"version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $Path 'version.json') -Encoding utf8NoBOM
    '{"schemaVersion":"1","assets":[]}' | Set-Content -LiteralPath (Join-Path $Path 'asset-manifest.json') -Encoding utf8NoBOM
    '# source' | Set-Content -LiteralPath (Join-Path $Path 'README.md') -Encoding utf8NoBOM
    '# changes' | Set-Content -LiteralPath (Join-Path $Path 'CHANGELOG.md') -Encoding utf8NoBOM
    '# example v1' | Set-Content -LiteralPath (Join-Path $Path 'instructions/example.instructions.md') -Encoding utf8NoBOM
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/guidance-lock.ps1') -Destination (Join-Path $Path 'scripts/guidance-lock.ps1')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'scripts/guidance-lock.sh') -Destination (Join-Path $Path 'scripts/guidance-lock.sh')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'schemas/guidance-lock-v1.schema.json') -Destination (Join-Path $Path 'schemas/guidance-lock-v1.schema.json')
    git -C $Path init | Out-Null
    git -C $Path config user.name basecoat-test
    git -C $Path config user.email basecoat-test@example.com
    git -C $Path add -A
    git -C $Path commit -m seed | Out-Null
}

function New-TestConsumer {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    git -C $Path init | Out-Null
    git -C $Path config user.name basecoat-test
    git -C $Path config user.email basecoat-test@example.com
    '# consumer' | Set-Content -LiteralPath (Join-Path $Path 'README.md') -Encoding utf8NoBOM
    git -C $Path add -A
    git -C $Path commit -m seed | Out-Null
}

function Invoke-TestSync {
    param(
        [string]$Source,
        [string]$Consumer,
        [switch]$ExpectFailure
    )
    $sha = (git -C $Source rev-parse HEAD).Trim()
    Push-Location $Consumer
    try {
        $env:BASECOAT_REPO = "file://$Source"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        $env:BASECOAT_TEST_SOURCE_PATH = $Source
        if ($ExpectFailure) {
            $output = & pwsh -NoProfile -File (Join-Path $repoRoot 'sync.ps1') 2>&1 | Out-String
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
        & (Join-Path $repoRoot 'sync.ps1')
        if ($LASTEXITCODE -ne 0) { throw "sync.ps1 exited $LASTEXITCODE" }
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA,Env:\BASECOAT_TEST_SOURCE_PATH -ErrorAction SilentlyContinue
        Pop-Location
    }
}

function Invoke-Scenario {
    param([string]$Name, [scriptblock]$Body)
    Write-Host "  Scenario: $Name"
    try {
        & $Body
    }
    catch {
        $failures.Add("${Name}: $($_.Exception.Message) [$($_.ScriptStackTrace)]")
    }
}

Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
. (Join-Path $repoRoot 'scripts/guidance-lock.ps1')

Invoke-Scenario 'same-owner update' {
    $source = Join-Path $scratch 'same-owner-source'
    $consumer = Join-Path $scratch 'same-owner-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    '# example v2' | Set-Content -LiteralPath (Join-Path $source 'instructions/example.instructions.md') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m update | Out-Null
    Invoke-TestSync $source $consumer
    Assert-True ((Get-Content -LiteralPath (Join-Path $consumer '.github/instructions/example.instructions.md') -Raw) -match 'v2') `
        'Same-owner update did not replace the managed file.'
}

Invoke-Scenario 'foreign-owner collision' {
    $source = Join-Path $scratch 'foreign-source'
    $consumer = Join-Path $scratch 'foreign-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $foreignPath = Join-Path $consumer '.github/instructions/example.instructions.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $foreignPath) -Force | Out-Null
    '# sheen' | Set-Content -LiteralPath $foreignPath -Encoding utf8NoBOM
    $foreignEntry = New-GuidanceLockEntry -RepoRoot $consumer -Path '.github/instructions/example.instructions.md' `
        -Owner sheen -GuidanceUnit 'sheen/example' -SourceVersion '1.0.0' `
        -Sha256 (Get-GuidanceContentHash $foreignPath)
    Write-GuidanceLock -RepoRoot $consumer -Entries @($foreignEntry)
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_PATH_COLLISION' -and $result.Output -match "owner='sheen'") `
        "Foreign-owner collision did not fail with the stable diagnostic: $($result.Output)"
    Assert-True ((Get-Content -LiteralPath $foreignPath -Raw) -match 'sheen') 'Collision changed the foreign-owned file.'
}

Invoke-Scenario 'unmanaged existing path collision' {
    $source = Join-Path $scratch 'unmanaged-source'
    $consumer = Join-Path $scratch 'unmanaged-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $unmanagedPath = Join-Path $consumer '.github/instructions/example.instructions.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $unmanagedPath) -Force | Out-Null
    '# unmanaged' | Set-Content -LiteralPath $unmanagedPath -Encoding utf8NoBOM
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_PATH_COLLISION' -and
        $result.Output -match "owner='unmanaged'") `
        "Unmanaged existing path did not block before overwrite: $($result.Output)"
}

Invoke-Scenario 'directory destination collision' {
    $source = Join-Path $scratch 'directory-source'
    $consumer = Join-Path $scratch 'directory-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $directoryPath = Join-Path $consumer '.github/instructions/example.instructions.md'
    New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_PATH_COLLISION' -and
        $result.Output -match "owner='directory'") `
        "Directory destination did not block before applying the write plan: $($result.Output)"
}

Invoke-Scenario 'consumer modification' {
    $source = Join-Path $scratch 'modified-source'
    $consumer = Join-Path $scratch 'modified-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    $managedPath = Join-Path $consumer '.github/instructions/example.instructions.md'
    '# consumer edit' | Set-Content -LiteralPath $managedPath -Encoding utf8NoBOM
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_CONTENT_MODIFIED' -and
        $result.Output -match "expected='[a-f0-9]{64}'" -and $result.Output -match "actual='[a-f0-9]{64}'") `
        "Consumer modification did not report expected and actual hashes: $($result.Output)"
}

Invoke-Scenario 'stale owned removal and foreign stale preservation' {
    $source = Join-Path $scratch 'stale-source'
    $consumer = Join-Path $scratch 'stale-consumer'
    New-TestSource $source
    '# retired' | Set-Content -LiteralPath (Join-Path $source 'instructions/retired.instructions.md') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m add-retired | Out-Null
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer

    $foreignPath = Join-Path $consumer '.github/instructions/sheen-stale.instructions.md'
    '# preserve' | Set-Content -LiteralPath $foreignPath -Encoding utf8NoBOM
    $lock = Read-GuidanceLock -RepoRoot $consumer
    $foreignEntry = New-GuidanceLockEntry -RepoRoot $consumer -Path '.github/instructions/sheen-stale.instructions.md' `
        -Owner sheen -Sha256 (Get-GuidanceContentHash $foreignPath)
    Write-GuidanceLock -RepoRoot $consumer -Entries (@($lock.entries) + $foreignEntry)

    Remove-Item -LiteralPath (Join-Path $source 'instructions/retired.instructions.md')
    git -C $source add -A
    git -C $source commit -m retire | Out-Null
    Invoke-TestSync $source $consumer
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $consumer '.github/instructions/retired.instructions.md'))) `
        'Stale BaseCoat-owned file was not removed.'
    Assert-True (Test-Path -LiteralPath $foreignPath) 'Foreign stale file was removed.'
    Assert-True ((Read-GuidanceLock -RepoRoot $consumer).entries.owner -contains 'sheen') `
        'Foreign stale lock entry was not preserved.'
}

Invoke-Scenario 'malformed lock' {
    $source = Join-Path $scratch 'malformed-source'
    $consumer = Join-Path $scratch 'malformed-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $lockPath = Get-GuidanceLockPath -RepoRoot $consumer
    New-Item -ItemType Directory -Path (Split-Path -Parent $lockPath) -Force | Out-Null
    '{bad json' | Set-Content -LiteralPath $lockPath -Encoding utf8NoBOM
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_LOCK_INVALID') `
        "Malformed lock did not fail closed: $($result.Output)"
}

Invoke-Scenario 'unknown lock property' {
    $source = Join-Path $scratch 'unknown-property-source'
    $consumer = Join-Path $scratch 'unknown-property-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $lockPath = Get-GuidanceLockPath -RepoRoot $consumer
    New-Item -ItemType Directory -Path (Split-Path -Parent $lockPath) -Force | Out-Null
    @'
{"schema":"guidance-lock/v1","entries":[{"path":".github/skills/example/SKILL.md","owner":"sheen","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","futureField":"must-not-drop"}]}
'@ | Set-Content -LiteralPath $lockPath -Encoding utf8NoBOM
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_LOCK_INVALID' -and
        $result.Output -match 'futureField') `
        "Unknown lock property was not rejected before foreign data could be discarded: $($result.Output)"
}

Invoke-Scenario 'path traversal' {
    $source = Join-Path $scratch 'traversal-source'
    $consumer = Join-Path $scratch 'traversal-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $lockPath = Get-GuidanceLockPath -RepoRoot $consumer
    New-Item -ItemType Directory -Path (Split-Path -Parent $lockPath) -Force | Out-Null
    @'
{"schema":"guidance-lock/v1","entries":[{"path":".github/skills/../../victim","owner":"basecoat","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}]}
'@ | Set-Content -LiteralPath $lockPath -Encoding utf8NoBOM
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_LOCK_INVALID' -and $result.Output -match 'victim') `
        "Traversal lock entry did not fail closed: $($result.Output)"
}

Invoke-Scenario 'legacy tracker migration' {
    $source = Join-Path $scratch 'migration-source'
    $consumer = Join-Path $scratch 'migration-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $managedPath = Join-Path $consumer '.github/instructions/example.instructions.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $managedPath) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $source 'instructions/example.instructions.md') -Destination $managedPath
    $legacyPath = Join-Path $consumer '.github/base-coat/.overlay-managed-files'
    New-Item -ItemType Directory -Path (Split-Path -Parent $legacyPath) -Force | Out-Null
    ".github/instructions/example.instructions.md`n" | Set-Content -LiteralPath $legacyPath -NoNewline -Encoding utf8NoBOM
    Invoke-TestSync $source $consumer
    $lock = Read-GuidanceLock -RepoRoot $consumer
    Assert-True (-not (Test-Path -LiteralPath $legacyPath)) 'Legacy overlay tracker was not removed after migration.'
    Assert-True ($lock.schema -eq 'guidance-lock/v1' -and
        ($lock.entries | Where-Object path -eq '.github/instructions/example.instructions.md').owner -eq 'basecoat') `
        'Legacy overlay ownership was not migrated to guidance-lock/v1.'
    Assert-True (@(Get-ChildItem -LiteralPath (Split-Path -Parent (Get-GuidanceLockPath -RepoRoot $consumer)) `
        -Filter 'guidance-lock.json.*.tmp' -File -ErrorAction SilentlyContinue).Count -eq 0) `
        'Atomic lock publication left a temporary file behind.'
}

Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAILED: $_" -ForegroundColor Red }
    Write-Host "Guidance lock telemetry: checks=$checks scenarios=10 failures=$($failures.Count)" -ForegroundColor Red
    exit 1
}

Write-Host "Guidance lock telemetry: checks=$checks scenarios=10 failures=0" -ForegroundColor Green
