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

function Set-LockedGuidanceHash {
    param(
        [string]$Consumer,
        [string]$Path,
        [string]$Sha256
    )

    $lock = Read-GuidanceLock -RepoRoot $Consumer
    $entry = @($lock.entries | Where-Object path -CEQ $Path) | Select-Object -First 1
    if (-not $entry) { throw "Fixture lock entry not found: $Path" }
    $entry.sha256 = $Sha256
    Write-GuidanceLock -RepoRoot $Consumer -Entries @($lock.entries)
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

$canonicalLf = Join-Path $scratch 'canonical-lf.md'
$canonicalCrlf = Join-Path $scratch 'canonical-crlf.md'
[IO.File]::WriteAllText($canonicalLf, "line one`nline two`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($canonicalCrlf, "line one`r`nline two`r`n", [Text.UTF8Encoding]::new($false))
Assert-True ((Get-GuidanceContentHash -Path $canonicalLf) -eq (Get-GuidanceContentHash -Path $canonicalCrlf)) `
    'Guidance hashes must be stable across LF and CRLF checkouts.'

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

Invoke-Scenario 'normal idempotence' {
    $source = Join-Path $scratch 'idempotent-source'
    $consumer = Join-Path $scratch 'idempotent-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    $before = Get-Content -LiteralPath (Get-GuidanceLockPath -RepoRoot $consumer) -Raw
    Invoke-TestSync $source $consumer
    $after = Get-Content -LiteralPath (Get-GuidanceLockPath -RepoRoot $consumer) -Raw
    Assert-True ($after -ceq $before) 'An idempotent sync changed the guidance lock.'
}

Invoke-Scenario 'approved Adhesion v0.7.1 predecessor' {
    $source = Join-Path $scratch 'approved-predecessor-source'
    $consumer = Join-Path $scratch 'approved-predecessor-consumer'
    New-TestSource $source
    "---`nname: agentic-sdlc-autonomy`ndescription: fixture`n---`n# Canonical BaseCoat payload" |
        Set-Content -LiteralPath (Join-Path $source 'agents/agentic-sdlc-autonomy.agent.md') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m add-agent | Out-Null
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    $path = '.github/agents/agentic-sdlc-autonomy.agent.md'
    Set-LockedGuidanceHash -Consumer $consumer -Path $path `
        -Sha256 '2487c414f197e0e999164c6da9a6254417eeb317c6442000b868184dccee45ea'
    Invoke-TestSync $source $consumer
    $entry = @((Read-GuidanceLock -RepoRoot $consumer).entries | Where-Object path -CEQ $path) | Select-Object -First 1
    Assert-True ($entry.sha256 -eq (Get-GuidanceContentHash -Path (Join-Path $consumer $path))) `
        'The exact approved predecessor path/hash was not migrated to the canonical BaseCoat hash.'
}

Invoke-Scenario 'modified approved Adhesion predecessor is rejected' {
    $source = Join-Path $scratch 'modified-approved-predecessor-source'
    $consumer = Join-Path $scratch 'modified-approved-predecessor-consumer'
    New-TestSource $source
    "---`nname: agentic-sdlc-autonomy`ndescription: fixture`n---`n# Canonical BaseCoat payload" |
        Set-Content -LiteralPath (Join-Path $source 'agents/agentic-sdlc-autonomy.agent.md') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m add-agent | Out-Null
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    $path = '.github/agents/agentic-sdlc-autonomy.agent.md'
    Set-LockedGuidanceHash -Consumer $consumer -Path $path `
        -Sha256 '2487c414f197e0e999164c6da9a6254417eeb317c6442000b868184dccee45ea'
    '# consumer modification' | Set-Content -LiteralPath (Join-Path $consumer $path) -Encoding utf8NoBOM
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_CONTENT_MODIFIED') `
        "Modified content was accepted under the approved predecessor path/hash: $($result.Output)"
}

Invoke-Scenario 'approved predecessor hash at another path is rejected' {
    $source = Join-Path $scratch 'wrong-path-predecessor-source'
    $consumer = Join-Path $scratch 'wrong-path-predecessor-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    $path = '.github/instructions/example.instructions.md'
    Set-LockedGuidanceHash -Consumer $consumer -Path $path `
        -Sha256 '2487c414f197e0e999164c6da9a6254417eeb317c6442000b868184dccee45ea'
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_CONTENT_MODIFIED') `
        "The approved predecessor hash was accepted at another path: $($result.Output)"
}

Invoke-Scenario 'case-variant predecessor path is rejected' {
    $source = Join-Path $scratch 'case-variant-predecessor-source'
    $consumer = Join-Path $scratch 'case-variant-predecessor-consumer'
    New-TestSource $source
    "---`nname: agentic-sdlc-autonomy`ndescription: fixture`n---`n# Canonical BaseCoat payload" |
        Set-Content -LiteralPath (Join-Path $source 'agents/agentic-sdlc-autonomy.agent.md') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m add-agent | Out-Null
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    $path = '.github/agents/agentic-sdlc-autonomy.agent.md'
    $lock = Read-GuidanceLock -RepoRoot $consumer
    $entry = @($lock.entries | Where-Object path -CEQ $path) | Select-Object -First 1
    $entry.path = '.github/agents/Agentic-sdlc-autonomy.agent.md'
    $entry.sha256 = '2487c414f197e0e999164c6da9a6254417eeb317c6442000b868184dccee45ea'
    Write-GuidanceLock -RepoRoot $consumer -Entries @($lock.entries)
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_CONTENT_MODIFIED') `
        "A case-variant predecessor lock path was accepted: $($result.Output)"
}

Invoke-Scenario 'unknown predecessor hash at target path is rejected' {
    $source = Join-Path $scratch 'unknown-target-predecessor-source'
    $consumer = Join-Path $scratch 'unknown-target-predecessor-consumer'
    New-TestSource $source
    "---`nname: agentic-sdlc-autonomy`ndescription: fixture`n---`n# Canonical BaseCoat payload" |
        Set-Content -LiteralPath (Join-Path $source 'agents/agentic-sdlc-autonomy.agent.md') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m add-agent | Out-Null
    New-TestConsumer $consumer
    Invoke-TestSync $source $consumer
    $path = '.github/agents/agentic-sdlc-autonomy.agent.md'
    Set-LockedGuidanceHash -Consumer $consumer -Path $path `
        -Sha256 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_CONTENT_MODIFIED') `
        "An unknown predecessor hash was accepted at the target path: $($result.Output)"
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

Invoke-Scenario 'generic unknown modification' {
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

Invoke-Scenario 'non-file lock path' {
    $source = Join-Path $scratch 'lock-directory-source'
    $consumer = Join-Path $scratch 'lock-directory-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    New-Item -ItemType Directory -Path (Get-GuidanceLockPath -RepoRoot $consumer) -Force | Out-Null
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_LOCK_INVALID' -and
        $result.Output -match 'regular file') `
        "Non-file lock path did not fail closed: $($result.Output)"
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

Invoke-Scenario 'concurrent writer lease' {
    $consumer = Join-Path $scratch 'concurrent-consumer'
    New-TestConsumer $consumer
    $helperPath = Join-Path $repoRoot 'scripts/guidance-lock.ps1'
    $readyPath = Join-Path $consumer 'lease-ready'
    $job = Start-Job -ScriptBlock {
        param($HelperPath, $ConsumerPath, $ReadyPath)
        . $HelperPath
        $lease = Enter-GuidanceLockLease -RepoRoot $ConsumerPath -TimeoutSeconds 2
        Set-Content -LiteralPath $ReadyPath -Value ready -Encoding utf8NoBOM
        Start-Sleep -Seconds 3
        Exit-GuidanceLockLease -LeasePath $lease
    } -ArgumentList $helperPath, $consumer, $readyPath
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        while (-not (Test-Path -LiteralPath $readyPath) -and [DateTime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 50
        }
        Assert-True (Test-Path -LiteralPath $readyPath) 'Concurrent writer fixture did not acquire its first lease.'
        $message = $null
        try {
            $unexpectedLease = Enter-GuidanceLockLease -RepoRoot $consumer -TimeoutSeconds 1
            Exit-GuidanceLockLease -LeasePath $unexpectedLease
        }
        catch {
            $message = $_.Exception.Message
        }
        Assert-True ($message -match 'GUIDANCE_LOCK_BUSY') `
            "Second writer was not serialized by the shared lease: $message"
    }
    finally {
        Wait-Job -Job $job -Timeout 10 | Out-Null
        Receive-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

Invoke-Scenario 'abandoned writer lease recovery' {
    $consumer = Join-Path $scratch 'abandoned-consumer'
    New-TestConsumer $consumer
    $leasePath = Join-Path $consumer '.github/base-coat/guidance-lock.lease'
    New-Item -ItemType Directory -Path $leasePath -Force | Out-Null
    "token=abandoned`npid=0`nacquiredEpoch=1`n" |
        Set-Content -LiteralPath (Join-Path $leasePath 'owner') -Encoding utf8NoBOM
    $lease = Enter-GuidanceLockLease -RepoRoot $consumer -TimeoutSeconds 2 -StaleAfterSeconds 1
    try {
        $leaseParts = $lease -split '\|', 2
        Assert-True ($leaseParts[1] -ne 'abandoned' -and (Test-Path -LiteralPath (Join-Path $leaseParts[0] 'owner'))) `
            'A stale lease was not reclaimed with a new ownership token.'
    }
    finally {
        Exit-GuidanceLockLease -LeasePath $lease
    }
    Assert-True (-not (Test-Path -LiteralPath $leasePath)) 'Reclaimed lease was not released by its owner.'
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
    Write-Host "Guidance lock telemetry: checks=$checks scenarios=19 failures=$($failures.Count)" -ForegroundColor Red
    exit 1
}

Write-Host "Guidance lock telemetry: checks=$checks scenarios=19 failures=0" -ForegroundColor Green
