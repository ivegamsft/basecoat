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
        [switch]$ExpectFailure,
        [string]$Shell
    )
    $sha = (git -C $Source rev-parse HEAD).Trim()
    Push-Location $Consumer
    try {
        $env:BASECOAT_REPO = "file://$Source"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        $env:BASECOAT_TEST_SOURCE_PATH = $Source
        if ($Shell) {
            # Detached with file output, so a leaked child holding sync's handles fails the test instead of hanging it.
            $out = Join-Path $Consumer 'sync.out'; $err = Join-Path $Consumer 'sync.err'
            $process = Start-Process -FilePath $Shell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $repoRoot 'sync.ps1')`"" -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
            $null = $process.Handle
            if (-not $process.WaitForExit(180000)) { Stop-Process -Id $process.Id -Force; throw "sync.ps1 under $Shell did not exit within 180s." }
            return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = (Get-Content -LiteralPath $out, $err -Raw) -join "`n" }
        }
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

function Test-ProcessRunning {
    param([int]$ProcessId)
    if ($env:OS -eq 'Windows_NT') { return [bool](Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) }
    $state = & ps -p $ProcessId -o stat= 2>$null
    return $LASTEXITCODE -eq 0 -and $state -and $state.Trim() -notmatch '^Z'
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

Invoke-Scenario 'legacy reference manifest migration preserves modified and foreign files' {
    $source = Join-Path $scratch 'reference-migration-source'
    $consumer = Join-Path $scratch 'reference-migration-consumer'
    New-TestSource $source
    foreach ($name in @('unchanged-detail', 'modified-detail')) {
        "# $name v2" | Set-Content -LiteralPath (Join-Path $source "agents/references/$name.md") -Encoding utf8NoBOM
    }
    git -C $source add -A
    git -C $source commit -m references | Out-Null
    New-TestConsumer $consumer
    $legacyDir = Join-Path $consumer '.github/agents/references'
    $newDir = Join-Path $consumer '.github/agent-references'
    New-Item -ItemType Directory -Path $legacyDir, $newDir, (Join-Path $consumer '.github/base-coat') -Force | Out-Null
    $assets = @(foreach ($name in @('unchanged-detail', 'modified-detail')) {
        $legacy = Join-Path $legacyDir "$name.md"
        "# $name v1" | Set-Content -LiteralPath $legacy -Encoding utf8NoBOM
        @{ path = "agents/references/$name.md"; sha = (git hash-object -- $legacy).Trim() }
    })
    Add-Content -LiteralPath (Join-Path $legacyDir 'modified-detail.md') 'consumer edit'
    $foreign = Join-Path $newDir 'foreign-detail.md'
    'foreign overlay' | Set-Content -LiteralPath $foreign -Encoding utf8NoBOM
    $assets += @{ path = 'agents/references/foreign-detail.md'; sha = (git hash-object -- $foreign).Trim() }
    @{ assets = $assets } | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath (Join-Path $consumer '.github/base-coat/asset-manifest.json') -Encoding utf8NoBOM

    Invoke-TestSync $source $consumer
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $legacyDir 'unchanged-detail.md'))) 'Unchanged legacy reference was not removed.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $legacyDir 'modified-detail.md') -Raw) -match 'consumer edit') 'Consumer-modified legacy reference was deleted.'
    Assert-True ((Get-Content -LiteralPath $foreign -Raw).Trim() -eq 'foreign overlay') 'Pre-existing .github/agent-references file was claimed by the legacy migration.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $newDir 'modified-detail.md') -Raw).Trim() -eq '# modified-detail v2') 'Reference was not projected to .github/agent-references.'
    $lockPath = Get-GuidanceLockPath -RepoRoot $consumer
    $lock = Read-GuidanceLock -RepoRoot $consumer
    Assert-True (-not @($lock.entries | Where-Object { $_.path -in @('.github/agent-references/foreign-detail.md', '.github/agents/references/modified-detail.md') }).Count) 'Unverified reference paths were recorded as BaseCoat-owned.'
    Assert-True (Test-Json -Json (Get-Content -LiteralPath $lockPath -Raw) -SchemaFile (Join-Path $repoRoot 'schemas/guidance-lock-v1.schema.json') -ErrorAction SilentlyContinue) 'Lock with .github/agent-references entries violates guidance-lock-v1 schema.'
}

Invoke-Scenario 'legacy tracker reference migration preserves modified files' {
    $source = Join-Path $scratch 'reference-tracker-source'
    $consumer = Join-Path $scratch 'reference-tracker-consumer'
    New-TestSource $source
    foreach ($name in @('unchanged-detail', 'modified-detail')) {
        "# $name v2" | Set-Content -LiteralPath (Join-Path $source "agents/references/$name.md") -Encoding utf8NoBOM
    }
    git -C $source add -A
    git -C $source commit -m references | Out-Null
    New-TestConsumer $consumer
    $legacyDir = Join-Path $consumer '.github/agents/references'
    New-Item -ItemType Directory -Path $legacyDir, (Join-Path $consumer '.github/base-coat') -Force | Out-Null
    '# unchanged-detail v2' | Set-Content -LiteralPath (Join-Path $legacyDir 'unchanged-detail.md') -Encoding utf8NoBOM
    "# modified-detail v2`nconsumer edit" | Set-Content -LiteralPath (Join-Path $legacyDir 'modified-detail.md') -Encoding utf8NoBOM
    ".github/agents/references/unchanged-detail.md`n.github/agents/references/modified-detail.md`n" |
        Set-Content -LiteralPath (Join-Path $consumer '.github/base-coat/.overlay-managed-files') -NoNewline -Encoding utf8NoBOM

    Invoke-TestSync $source $consumer
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $legacyDir 'unchanged-detail.md'))) 'Tracker-owned unchanged legacy reference was not removed.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $legacyDir 'modified-detail.md') -Raw) -match 'consumer edit') 'Tracker-owned consumer-modified legacy reference was deleted.'
}

function New-LeaseHookSource {
    param([string]$Path, [string]$Consumer, [string]$OwnerAction)
    New-TestSource $Path
    # The source-supplied distribution filter runs right after the payload is staged, mid-sync.
    @"
. '$((Join-Path $repoRoot 'scripts/distribution-filter.ps1').Replace("'", "''"))'
`$script:LeaseHookFilter = `${function:Remove-BaseCoatDistributionExcluded}
function Remove-BaseCoatDistributionExcluded {
    param([string]`$Root)
    & `$script:LeaseHookFilter -Root `$Root
    `$owner = Join-Path `$repoRoot '.github/base-coat/guidance-lock.lease/owner'
    if (Test-Path -LiteralPath `$owner) { $OwnerAction }
}
"@ | Set-Content -LiteralPath (Join-Path $Path 'scripts/distribution-filter.ps1') -Encoding utf8NoBOM
    git -C $Path add -A
    git -C $Path commit -m 'lease hook' | Out-Null
    New-TestConsumer $Consumer
}

Invoke-Scenario 'sync acquires the lease before staging the payload' {
    $source = Join-Path $scratch 'busy-source'
    $consumer = Join-Path $scratch 'busy-consumer'
    New-TestSource $source
    New-TestConsumer $consumer
    $heldLease = Enter-GuidanceLockLease -RepoRoot $consumer
    try {
        $result = Invoke-TestSync $source $consumer -ExpectFailure
    }
    finally {
        Exit-GuidanceLockLease -LeasePath $heldLease
    }
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_LOCK_BUSY' -and
        -not (Test-Path -LiteralPath (Join-Path $consumer '.github/base-coat/version.json'))) `
        "A concurrent sync changed the staged payload before waiting for the held lease: $($result.Output)"
}

Invoke-Scenario 'sync renews its lease through the write window' {
    $source = Join-Path $scratch 'renew-source'
    $consumer = Join-Path $scratch 'renew-consumer'
    New-LeaseHookSource $source $consumer `
        "(Get-Content -LiteralPath `$owner) -replace '^acquiredEpoch=.*', `"acquiredEpoch=`$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 500)`" | Set-Content -LiteralPath `$owner"
    $observed = Join-Path $consumer 'lease-observed.txt'
    New-Item -ItemType Directory -Path (Join-Path $consumer 'scripts') -Force | Out-Null
    "param(`$TargetDir, [switch]`$ProtectCustomized, [switch]`$SetArchiveReadOnly)`n" +
    "`$o = '.github/base-coat/guidance-lock.lease/owner'; if (Test-Path `$o) { Copy-Item `$o '$observed' } else { 'missing' | Set-Content '$observed' }" |
        Set-Content -LiteralPath (Join-Path $consumer 'scripts/cleanup-basecoat-upgrade.ps1') -Encoding utf8NoBOM
    Invoke-TestSync $source $consumer
    $epochLine = @(Get-Content -LiteralPath $observed | Where-Object { $_ -like 'acquiredEpoch=*' }) | Select-Object -First 1
    $epoch = if ($epochLine) { [long]($epochLine -replace '^acquiredEpoch=', '') } else { 0 }
    Assert-True ($epoch -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 300) `
        "Sync did not hold and renew its lease through the late write phases: $(Get-Content -LiteralPath $observed -Raw)"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $consumer '.github/base-coat/guidance-lock.lease'))) 'Sync did not release its lease.'
}

Invoke-Scenario 'sync stops writing after its lease is taken over' {
    $source = Join-Path $scratch 'takeover-source'
    $consumer = Join-Path $scratch 'takeover-consumer'
    New-LeaseHookSource $source $consumer `
        "[IO.File]::WriteAllText(`$owner, `"token=intruder``npid=0``nacquiredEpoch=`$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())``n`")"
    $result = Invoke-TestSync $source $consumer -ExpectFailure
    $owner = Join-Path $consumer '.github/base-coat/guidance-lock.lease/owner'
    Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_LOCK_BUSY' -and $result.Output -match "reason='lease lost during sync'" -and
        -not (Test-Path -LiteralPath (Get-GuidanceLockPath -RepoRoot $consumer)) -and
        -not (Test-Path -LiteralPath (Join-Path $consumer '.github/instructions/example.instructions.md')) -and
        (Get-Content -LiteralPath $owner -Raw) -match 'token=intruder') `
        "Sync kept writing, or released the new owner's lease, after a takeover: $($result.Output)"
}

Invoke-Scenario 'lease loss stops the cleanup callback process tree and nothing else' {
    $source = Join-Path $scratch 'tree-source'
    New-TestSource $source
    $shells = @('pwsh') + @(if ($env:OS -eq 'Windows_NT' -and (Get-Command powershell.exe -ErrorAction SilentlyContinue)) { 'powershell.exe' })
    foreach ($shell in $shells) {
        $consumer = Join-Path $scratch "tree-consumer-$($shell -replace '\W', '')"
        New-TestConsumer $consumer
        New-Item -ItemType Directory -Path (Join-Path $consumer 'scripts') -Force | Out-Null
        $log = Join-Path $consumer 'writer.log'; $writerPid = Join-Path $consumer 'writer.pid'; $late = Join-Path $consumer 'late.txt'
        "while (`$true) { Add-Content -LiteralPath '$log' -Value x; Start-Sleep -Milliseconds 100 }" | Set-Content -LiteralPath (Join-Path $consumer 'writer.ps1') -Encoding utf8
        # The callback spawns a child writer, loses its lease to a successor, then keeps running.
        @"
param(`$TargetDir, [switch]`$ProtectCustomized, [switch]`$SetArchiveReadOnly)
`$writer = Start-Process -FilePath (Get-Process -Id `$PID).Path -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '"$(Join-Path $consumer 'writer.ps1')"' -NoNewWindow -PassThru -RedirectStandardOutput '$(Join-Path $consumer 'writer.out')' -RedirectStandardError '$(Join-Path $consumer 'writer.err')'
Set-Content -LiteralPath '$writerPid' -Value `$writer.Id
while (-not (Test-Path -LiteralPath '$log')) { Start-Sleep -Milliseconds 50 }
[IO.File]::WriteAllText('$(Join-Path $consumer '.github/base-coat/guidance-lock.lease/owner')', "token=intruder``npid=0``nacquiredEpoch=`$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())``n")
Start-Sleep -Seconds 30
Set-Content -LiteralPath '$late' -Value late
"@ | Set-Content -LiteralPath (Join-Path $consumer 'scripts/cleanup-basecoat-upgrade.ps1') -Encoding utf8
        $bystander = Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 120' -NoNewWindow -PassThru
        $env:BASECOAT_LEASE_HEARTBEAT_SECONDS = '1'
        try { $result = Invoke-TestSync $source $consumer -Shell $shell }
        finally { Remove-Item Env:\BASECOAT_LEASE_HEARTBEAT_SECONDS }
        $childId = [int](Get-Content -LiteralPath $writerPid -Raw -ErrorAction SilentlyContinue)
        $childAlive = $childId -and (Test-ProcessRunning $childId)
        $logLength = (Get-Item -LiteralPath $log).Length; Start-Sleep -Milliseconds 800
        $bystanderAlive = -not $bystander.HasExited
        if ($bystanderAlive) { Stop-Process -Id $bystander.Id -Force }
        if ($childAlive) { Stop-Process -Id $childId -Force }
        Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'GUIDANCE_LOCK_BUSY' -and $result.Output -match "reason='lease lost during sync'") "$shell sync did not fail closed when the cleanup callback lost its lease: $($result.Output)"
        Assert-True ($childId -and -not $childAlive -and (Get-Item -LiteralPath $log).Length -eq $logLength -and -not (Test-Path -LiteralPath $late)) `
            "$shell sync returned while the cleanup callback or its child writer could still write after the lease was taken over (#3822)."
        Assert-True $bystanderAlive "$shell sync terminated a process outside the cleanup callback's process tree."
        Assert-True ((Get-Content -LiteralPath (Join-Path $consumer '.github/base-coat/guidance-lock.lease/owner') -Raw) -match 'token=intruder') "$shell sync released the successor's lease."
    }
}

Invoke-Scenario 'forced termination during renewal preserves a reclaimable owner' {
    $consumer = Join-Path $scratch 'interrupted-renewal'
    New-TestConsumer $consumer
    $lease = Enter-GuidanceLockLease -RepoRoot $consumer
    $owner = Join-Path ($lease -split '\|', 2)[0] 'owner'
    $original = Get-Content -LiteralPath $owner -Raw
    $marker = Join-Path $consumer 'write-paused'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'sync.ps1'), [ref]$null, [ref]$null)
    $definition = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Update-SyncGuidanceLease' }, $true).Extent.Text
    $definition = $definition.Replace('[System.IO.File]::WriteAllText(', 'Invoke-InterruptedWrite(')
    $scriptPath = Join-Path $consumer 'renew.ps1'
    @"
function Invoke-InterruptedWrite {
    param([object[]]`$WriteArguments)
    [IO.File]::WriteAllText([string]`$WriteArguments[0], '')
    Set-Content -LiteralPath '$marker' -Value paused
    Start-Sleep -Seconds 120
}
$definition
Update-SyncGuidanceLease -Lease '$lease'
"@ | Set-Content -LiteralPath $scriptPath -Encoding utf8
    $process = Start-Process -FilePath pwsh -ArgumentList '-NoProfile', '-File', "`"$scriptPath`"" -NoNewWindow -PassThru
    try {
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        while (-not (Test-Path -LiteralPath $marker) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        Assert-True (Test-Path -LiteralPath $marker) 'Renewal fixture did not pause after opening its write destination.'
        Stop-Process -Id $process.Id -Force; $process.WaitForExit()
        Assert-True ((Get-Content -LiteralPath $owner -Raw) -ceq $original) 'Interrupted renewal truncated or changed the published owner.'
        $original -replace '(?m)^acquiredEpoch=\d+', "acquiredEpoch=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 601)" |
            Set-Content -LiteralPath $owner -Encoding ascii
        $successor = Enter-GuidanceLockLease -RepoRoot $consumer -TimeoutSeconds 0
        Exit-GuidanceLockLease -LeasePath $successor
    }
    finally {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
        $process.Dispose()
        Exit-GuidanceLockLease -LeasePath $lease
    }
}

Invoke-Scenario 'forced sync termination stops the cleanup callback and its children' {
    $source = Join-Path $scratch 'parent-kill-source'
    New-TestSource $source
    $shells = @('pwsh') + @(if ($env:OS -eq 'Windows_NT' -and (Get-Command powershell.exe -ErrorAction SilentlyContinue)) { 'powershell.exe' })
    foreach ($shell in $shells) {
        $consumer = Join-Path $scratch "parent-kill-$($shell -replace '\W', '')"
        New-TestConsumer $consumer
        New-Item -ItemType Directory -Path (Join-Path $consumer 'scripts') -Force | Out-Null
        $log = Join-Path $consumer 'writer.log'; $writerPid = Join-Path $consumer 'writer.pid'; $callbackPid = Join-Path $consumer 'callback.pid'
        "while (`$true) { Add-Content -LiteralPath '$log' -Value x; Start-Sleep -Milliseconds 100 }" |
            Set-Content -LiteralPath (Join-Path $consumer 'writer.ps1') -Encoding utf8
        @"
param(`$TargetDir, [switch]`$ProtectCustomized, [switch]`$SetArchiveReadOnly)
Set-Content -LiteralPath '$callbackPid' -Value `$PID
`$writer = Start-Process -FilePath (Get-Process -Id `$PID).Path -ArgumentList '-NoProfile', '-File', '"$(Join-Path $consumer 'writer.ps1')"' -NoNewWindow -PassThru -RedirectStandardOutput '$(Join-Path $consumer 'writer.out')' -RedirectStandardError '$(Join-Path $consumer 'writer.err')'
Set-Content -LiteralPath '$writerPid' -Value `$writer.Id
while (-not (Test-Path -LiteralPath '$log')) { Start-Sleep -Milliseconds 50 }
`$owner = Get-Content -LiteralPath '.github/base-coat/guidance-lock.lease/owner' -Raw
Stop-Process -Id ([int]([regex]::Match(`$owner, '(?m)^pid=(\d+)').Groups[1].Value)) -Force
Start-Sleep -Seconds 120
"@ | Set-Content -LiteralPath (Join-Path $consumer 'scripts/cleanup-basecoat-upgrade.ps1') -Encoding utf8
        $bystander = Start-Process -FilePath pwsh -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 120' -NoNewWindow -PassThru
        $childId = 0; $callbackId = 0
        try {
            $result = Invoke-TestSync $source $consumer -Shell $shell
            $childId = [int](Get-Content -LiteralPath $writerPid -Raw)
            $callbackId = [int](Get-Content -LiteralPath $callbackPid -Raw)
            $deadline = [DateTime]::UtcNow.AddSeconds(30)
            while (((Test-ProcessRunning $childId) -or (Test-ProcessRunning $callbackId)) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
            Assert-True ($result.ExitCode -ne 0 -and -not (Test-ProcessRunning $childId) -and -not (Test-ProcessRunning $callbackId)) "$shell parent death left the callback tree running."
            $length = (Get-Item -LiteralPath $log).Length; Start-Sleep -Milliseconds 800
            Assert-True ((Get-Item -LiteralPath $log).Length -eq $length -and -not $bystander.HasExited) "$shell parent-death cleanup allowed writes or stopped an unrelated process."
            $owner = Join-Path $consumer '.github/base-coat/guidance-lock.lease/owner'
            (Get-Content -LiteralPath $owner -Raw) -replace '(?m)^acquiredEpoch=\d+', "acquiredEpoch=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 601)" |
                Set-Content -LiteralPath $owner -Encoding ascii
            $successor = Enter-GuidanceLockLease -RepoRoot $consumer -TimeoutSeconds 0
            Exit-GuidanceLockLease -LeasePath $successor
        }
        finally {
            foreach ($processId in @($childId, $callbackId, $bystander.Id)) {
                if ($processId -and (Test-ProcessRunning $processId)) { Stop-Process -Id $processId -Force }
            }
            $bystander.Dispose()
        }
    }
}

Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Host "FAILED: $_" -ForegroundColor Red }
    Write-Host "Guidance lock telemetry: checks=$checks scenarios=27 failures=$($failures.Count)" -ForegroundColor Red
    exit 1
}

Write-Host "Guidance lock telemetry: checks=$checks scenarios=27 failures=0" -ForegroundColor Green
