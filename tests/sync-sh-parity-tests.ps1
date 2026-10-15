[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$syncShContent = Get-Content -LiteralPath (Join-Path $repoRoot 'sync.sh') -Raw
Assert-True ($syncShContent -match '\^\(https://\[\^/\]\+\)') `
    'Bash authenticated retry must derive the HTTPS origin for corporate mirrors.'
Assert-True ($syncShContent -match 'http\.\$\{auth_origin\}\.extraheader') `
    'Bash authentication must be scoped to the derived corporate mirror origin.'
Assert-True ($syncShContent -match 'token="\$\{BASECOAT_FETCH_TOKEN:-\}"') `
    'Bash authentication must use only the dedicated source fetch token.'
Assert-True ($syncShContent -match 'trusted_authority="\$\{BASECOAT_FETCH_HOST:-\}"') `
    'Bash authentication must require an explicitly trusted source authority.'
Assert-True ($syncShContent -notmatch '\$\{[^}]+,,\}') `
    'Bash authentication must not use Bash 4-only lowercase expansion on macOS system Bash.'
Assert-True ($syncShContent -match "tr '\[:upper:\]' '\[:lower:\]'") `
    'Bash authentication must compare trusted authorities with portable case normalization.'
Assert-True ($syncShContent -notmatch 'token="\$\{GITHUB_TOKEN:-\$\{GH_TOKEN:-\}\}"') `
    'Bash source fetch must never reuse consumer GitHub tokens.'
Assert-True ($syncShContent -match 'sed "1s/\^\$\{bom\}//" "\$config" \| awk') `
    'Bash known-bad map parsing must strip a leading UTF-8 BOM before matching the section.'
Assert-True ($syncShContent -notmatch 'YOUR-ORG') `
    'Bash sync must never fall back to a placeholder source URL (issue #3417).'
Assert-True ($syncShContent -match "No BaseCoat source configured\. Set 'source:' in \.basecoat\.yml or the BASECOAT_REPO env var\.") `
    'Bash sync must fail fast with an actionable message naming .basecoat.yml and BASECOAT_REPO.'
Assert-True ($syncShContent -match 'guidance_lock_file="\$REPO_ROOT/\.github/base-coat/guidance-lock\.json"') `
    'Bash sync must use the canonical cross-product guidance lock.'
Assert-True ($syncShContent -match 'GUIDANCE_PATH_COLLISION' -and $syncShContent -match 'GUIDANCE_CONTENT_MODIFIED') `
    'Bash sync must enforce foreign-owner collisions and consumer-modification hashes.'
Assert-True ($syncShContent -match 'approved_predecessor_path="\.github/agents/agentic-sdlc-autonomy\.agent\.md"' -and
    $syncShContent -match 'approved_predecessor_sha256="2487c414f197e0e999164c6da9a6254417eeb317c6442000b868184dccee45ea"' -and
    $syncShContent -match '"\$path" != "\$approved_predecessor_path"' -and
    $syncShContent -match '"\$locked_hash" != "\$approved_predecessor_sha256"' -and
    $syncShContent -match '"\$actual_hash" != "\$expected_hash"') `
    'Bash sync must allow only the exact Adhesion v0.7.1 predecessor path/hash pair.'
Assert-True ($syncShContent -match 'guidance_write_lock "\$guidance_lock_file"' -and
    $syncShContent -match 'rm -f "\$legacy_overlay_file"') `
    'Bash sync must publish guidance-lock/v1 and retire the legacy overlay tracker.'
Assert-True ($syncShContent -notmatch 'echo "\.github/agent-references/\$\{asset_path' -and
    $syncShContent -match '"\$normalized" == \.github/agents/references/\* \]\]; then\s+asset_path="agents/references/' -and
    $syncShContent -match 'Preserving modified legacy reference') `
    'Bash pre-lock migration must claim only legacy .github/agents/references paths whose bytes match the previous manifest (#3766).'
Assert-True ($syncShContent -match 'reference_docs_prefix="\.\./\.\./\$\{TARGET_DIR%/\}/docs/"') 'Bash reference projection must point docs links at the docs installed under TARGET_DIR.'
$rollbackShContent = Get-Content -LiteralPath (Join-Path $repoRoot 'rollback.sh') -Raw
Assert-True ($rollbackShContent -match 'BASECOAT_REF="\$TAG" BASECOAT_TARGET_DIR="\$TARGET_DIR" BASECOAT_GUIDANCE_LEASE="\$LEASE" bash "\$SYNC_SCRIPT"' -and
    $rollbackShContent -notmatch 'git clone') 'Bash rollback must replay sync.sh for the explicit tag instead of re-copying the staged payload (#3776).'
if ($IsWindows) {
    Write-Host 'Bash runtime parity skipped on Windows after static corporate-origin checks; Ubuntu CI runs the fixture.'
    exit 0
}
$bash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bash) {
    Write-Host 'Bash sync parity tests skipped: bash is unavailable.'
    exit 0
}
& $bash.Source --version 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Bash sync parity tests skipped: bash is not runnable.'
    exit 0
}

$scratch = Join-Path $repoRoot 'test-results/sync-sh-parity'
$source = Join-Path $scratch 'source'
$mirror = Join-Path $scratch 'mirror.git'
$consumer = Join-Path $scratch 'consumer'

try {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $source,$consumer -Force | Out-Null

    $leaseFixture = Join-Path $scratch 'lease-fixture.sh'
    @'
#!/usr/bin/env bash
set -euo pipefail
source "$1"
root="$2"
lease="$(guidance_enter_lease "$root" 2 60)"
if guidance_enter_lease "$root" 1 60 >/dev/null 2>&1; then
  echo "second Bash writer unexpectedly acquired an active lease" >&2
  exit 1
fi
guidance_exit_lease "$lease"
lease2="$(guidance_enter_lease "$root" 2 60)"
guidance_exit_lease "$lease2"
mkdir -p "$root/.github/base-coat/guidance-lock.lease"
printf 'token=abandoned\npid=0\nacquiredEpoch=1\n' > "$root/.github/base-coat/guidance-lock.lease/owner"
lease3="$(guidance_enter_lease "$root" 2 1)"
guidance_exit_lease "$lease3"
'@ | Set-Content -LiteralPath $leaseFixture -Encoding utf8NoBOM
    & $bash.Source $leaseFixture (Join-Path $repoRoot 'scripts/guidance-lock.sh') $consumer
    Assert-True ($LASTEXITCODE -eq 0) 'Bash lease contention, release, or abandoned-owner recovery failed.'

    git -C $source init | Out-Null
    git -C $source config user.name basecoat-test
    git -C $source config user.email basecoat-test@example.com
    New-Item -ItemType Directory -Path (Join-Path $source '.github/base-coat/scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $source 'agents'),(Join-Path $source 'instructions'),(Join-Path $source 'prompts'),(Join-Path $source 'skills'),(Join-Path $source 'docs/reference'),(Join-Path $source 'docs/guides') -Force | Out-Null
    '{"version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $source 'version.json') -Encoding utf8NoBOM
    '{"schemaVersion":"1","assets":[]}' | Set-Content -LiteralPath (Join-Path $source 'asset-manifest.json') -Encoding utf8NoBOM
    '# source' | Set-Content -LiteralPath (Join-Path $source 'README.md') -Encoding utf8NoBOM
    '# changes' | Set-Content -LiteralPath (Join-Path $source 'CHANGELOG.md') -Encoding utf8NoBOM
    "---`nname: example`ndescription: example`n---" | Set-Content -LiteralPath (Join-Path $source 'agents/example.agent.md') -Encoding utf8NoBOM
    "---`nname: agentic-sdlc-autonomy`ndescription: fixture`n---`n# Canonical BaseCoat payload" |
        Set-Content -LiteralPath (Join-Path $source 'agents/agentic-sdlc-autonomy.agent.md') -Encoding utf8NoBOM
    New-Item -ItemType Directory -Path (Join-Path $source 'agents/references') -Force | Out-Null
    "# example detail reference`n[guide](../../docs/guides/example-guide.md)" | Set-Content -LiteralPath (Join-Path $source 'agents/references/example-detail.md') -Encoding utf8NoBOM
    '# guide' | Set-Content -LiteralPath (Join-Path $source 'docs/guides/example-guide.md') -Encoding utf8NoBOM
    "---`ndescription: example`napplyTo: '**/*'`n---" | Set-Content -LiteralPath (Join-Path $source 'instructions/example.instructions.md') -Encoding utf8NoBOM
    "---`nname: example`ndescription: example`n---" | Set-Content -LiteralPath (Join-Path $source 'prompts/example.prompt.md') -Encoding utf8NoBOM
    'Write-Host updater' | Set-Content -LiteralPath (Join-Path $source '.github/base-coat/scripts/invoke-basecoat-consumer-update.ps1') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m 'seed v1' | Out-Null
    git -C $source tag v1.0.0
    git clone --bare $source $mirror | Out-Null

    git -C $consumer init | Out-Null
    git -C $consumer config user.name basecoat-test
    git -C $consumer config user.email basecoat-test@example.com
    $consumerConfig = @"
source: file://$scratch/missing-canonical.git
mirror: file://$mirror
ref: v0.9.0+corp.1
known_bad_releases:
  v0.9.0+corp.1: v1.0.0__TRAILING__
"@
    $consumerConfig.Replace('__TRAILING__', '  ') |
        Set-Content -LiteralPath (Join-Path $consumer '.basecoat.yml') -Encoding utf8BOM
    '# consumer' | Set-Content -LiteralPath (Join-Path $consumer 'README.md') -Encoding utf8NoBOM
    # Pre-lock upgrade (#3766): legacy references are claimed only when unchanged,
    # and the new .github/agent-references path is never claimed from old evidence.
    $legacyRefs = Join-Path $consumer '.github/agents/references'
    New-Item -ItemType Directory -Path $legacyRefs, (Join-Path $consumer '.github/agent-references') -Force | Out-Null
    '# example detail v0' | Set-Content -LiteralPath (Join-Path $legacyRefs 'example-detail.md') -Encoding utf8NoBOM
    '# modified detail v0' | Set-Content -LiteralPath (Join-Path $legacyRefs 'modified-detail.md') -Encoding utf8NoBOM
    'foreign overlay' | Set-Content -LiteralPath (Join-Path $consumer '.github/agent-references/foreign-detail.md') -Encoding utf8NoBOM
    $legacyAssets = @(foreach ($name in @('example-detail', 'modified-detail', 'foreign-detail')) {
        $file = if ($name -eq 'foreign-detail') { Join-Path $consumer '.github/agent-references/foreign-detail.md' } else { Join-Path $legacyRefs "$name.md" }
        [ordered]@{ path = "agents/references/$name.md"; sha = (git hash-object -- $file).Trim() }
    })
    Add-Content -LiteralPath (Join-Path $legacyRefs 'modified-detail.md') 'consumer edit'
    @{ assets = $legacyAssets } | ConvertTo-Json -Depth 4 |
        Set-Content -LiteralPath (Join-Path $consumer '.github/base-coat/asset-manifest.json') -Encoding utf8NoBOM
    git -C $consumer add -A
    git -C $consumer commit -m initial | Out-Null

    Push-Location $consumer
    try {
        & $bash.Source (Join-Path $repoRoot 'sync.sh')
        if ($LASTEXITCODE -ne 0) { throw 'sync.sh mirror/remap run failed.' }
    }
    finally {
        Pop-Location
    }

    $installed = (Get-Content -LiteralPath (Join-Path $consumer '.github/base-coat/version.json') -Raw | ConvertFrom-Json).version
    Assert-True ($installed -eq '1.0.0') 'sync.sh did not parse a BOM-prefixed config and literally match its SemVer build-metadata known-bad key.'
    Assert-True (Test-Path -LiteralPath (Join-Path $consumer '.github/base-coat/scripts/invoke-basecoat-consumer-update.ps1')) 'sync.sh did not distribute managed updater scripts.'
    Assert-True (Test-Path -LiteralPath (Join-Path $consumer '.github/agent-references/example-detail.md')) 'sync.sh did not distribute the agents/references subtree into .github/agent-references.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $consumer '.github/agent-references/example-detail.md') -Raw).Contains('](../../.github/base-coat/docs/guides/example-guide.md)') -and (Test-Path -LiteralPath (Join-Path $consumer '.github/base-coat/docs/guides/example-guide.md'))) 'sync.sh did not point reference docs links at the installed BaseCoat docs.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $legacyRefs 'example-detail.md'))) 'sync.sh did not remove the unchanged legacy reference.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $legacyRefs 'modified-detail.md') -Raw) -match 'consumer edit') 'sync.sh deleted a consumer-modified legacy reference.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $consumer '.github/agent-references/foreign-detail.md') -Raw).Trim() -eq 'foreign overlay') 'sync.sh claimed a pre-existing .github/agent-references file.'
    $tagSha = (git -C $source rev-list -n 1 v1.0.0).Trim()
    $provenance = Get-Content -LiteralPath (Join-Path $consumer '.github/base-coat/.source-provenance.json') -Raw | ConvertFrom-Json
    Assert-True ($provenance.commit -eq $tagSha) 'sync.sh provenance did not record the fetched commit.'

    Remove-Item -LiteralPath (Join-Path $source '.github/base-coat/scripts') -Recurse -Force
    '{"version":"1.0.1"}' | Set-Content -LiteralPath (Join-Path $source 'version.json') -Encoding utf8NoBOM
    git -C $source add -A
    git -C $source commit -m 'remove managed scripts' | Out-Null
    $sha = (git -C $source rev-parse HEAD).Trim()
    git -C $source push "file://$mirror" HEAD:refs/heads/main | Out-Null

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$source"
        $env:BASECOAT_MIRROR = "file://$mirror"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        & $bash.Source (Join-Path $repoRoot 'sync.sh')
        if ($LASTEXITCODE -ne 0) { throw 'sync.sh immutable SHA run failed.' }
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        Pop-Location
    }

    $provenance = Get-Content -LiteralPath (Join-Path $consumer '.github/base-coat/.source-provenance.json') -Raw | ConvertFrom-Json
    Assert-True ($provenance.commit -eq $sha) 'sync.sh did not enforce immutable SHA provenance.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $consumer '.github/base-coat/scripts/invoke-basecoat-consumer-update.ps1'))) `
        'sync.sh did not remove a stale managed updater script.'

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = 'https://user:password@127.0.0.1:1/basecoat.git?token=secret-value'
        $env:BASECOAT_MIRROR = $env:BASECOAT_REPO
        $env:BASECOAT_REF = 'main'
        Remove-Item Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        $failure = & $bash.Source (Join-Path $repoRoot 'sync.sh') 2>&1 | Out-String
        $failureCode = $LASTEXITCODE
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF -ErrorAction SilentlyContinue
        Pop-Location
    }
    Assert-True ($failureCode -ne 0) 'sync.sh redaction fixture must fail cloning.'
    Assert-True ($failure -notmatch 'user:password|secret-value|token=') 'sync.sh failure output leaked URL credentials.'
    Assert-True ($failure -match 'https://127\.0\.0\.1:1/basecoat\.git') 'sync.sh redaction removed useful source context.'

    # Regression for #3415: sync.sh must never wipe co-located overlay files
    # it does not own (e.g. basecoat-sheen/basecoat-adhesion), and must only
    # ever prune files it previously tracked as its own.
    $foreignPaths = @(
        '.github/skills/foreign-skill/SKILL.md',
        '.github/instructions/foreign.instructions.md',
        '.github/agents/foreign.agent.md',
        '.agents/skills/foreign-skill/SKILL.md'
    )
    foreach ($relPath in $foreignPaths) {
        $fullPath = Join-Path $consumer $relPath
        New-Item -ItemType Directory -Force -Path (Split-Path $fullPath -Parent) | Out-Null
        '# foreign content owned by another product (e.g. Sheen/Adhesion)' | Set-Content -LiteralPath $fullPath -Encoding utf8NoBOM
    }

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$source"
        $env:BASECOAT_MIRROR = "file://$mirror"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        & $bash.Source (Join-Path $repoRoot 'sync.sh')
        if ($LASTEXITCODE -ne 0) { throw 'sync.sh mixed-overlay run failed.' }
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        Pop-Location
    }

    foreach ($relPath in $foreignPaths) {
        Assert-True (Test-Path -LiteralPath (Join-Path $consumer $relPath)) `
            "sync.sh deleted foreign overlay file '$relPath' via a wholesale wipe (#3415)."
    }

    $guidanceLockPath = Join-Path $consumer '.github/base-coat/guidance-lock.json'
    Assert-True (Test-Path -LiteralPath $guidanceLockPath) 'sync.sh did not write guidance-lock.json.'

    $retiredRelPath = '.github/instructions/zzz-retired-basecoat-file.instructions.md'
    $retiredFullPath = Join-Path $consumer $retiredRelPath
    '# retired BaseCoat-managed file' | Set-Content -LiteralPath $retiredFullPath -Encoding utf8NoBOM
    . (Join-Path $repoRoot 'scripts/guidance-lock.ps1')
    $lock = Read-GuidanceLock -RepoRoot $consumer
    $retiredEntry = New-GuidanceLockEntry -RepoRoot $consumer -Path $retiredRelPath -Owner basecoat `
        -GuidanceUnit 'instructions/zzz-retired-basecoat-file.instructions.md' -SourceVersion test `
        -Sha256 (Get-GuidanceContentHash -Path $retiredFullPath)
    Write-GuidanceLock -RepoRoot $consumer -Entries (@($lock.entries) + $retiredEntry)

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$source"
        $env:BASECOAT_MIRROR = "file://$mirror"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        & $bash.Source (Join-Path $repoRoot 'sync.sh')
        if ($LASTEXITCODE -ne 0) { throw 'sync.sh mixed-overlay prune run failed.' }
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        Pop-Location
    }

    Assert-True (-not (Test-Path -LiteralPath $retiredFullPath)) 'sync.sh did not prune a retired BaseCoat-managed overlay file.'
    foreach ($relPath in $foreignPaths) {
        Assert-True (Test-Path -LiteralPath (Join-Path $consumer $relPath)) `
            "sync.sh deleted foreign overlay file '$relPath' while pruning a retired BaseCoat file (#3415)."
    }

    $managedInstruction = Join-Path $consumer '.github/instructions/example.instructions.md'
    '# consumer modification' | Set-Content -LiteralPath $managedInstruction -Encoding utf8NoBOM
    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$source"
        $env:BASECOAT_MIRROR = "file://$mirror"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        $modifiedFailure = & $bash.Source (Join-Path $repoRoot 'sync.sh') 2>&1 | Out-String
        $modifiedExitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        Pop-Location
    }
    Assert-True ($modifiedExitCode -ne 0 -and $modifiedFailure -match 'GUIDANCE_CONTENT_MODIFIED' -and
        $modifiedFailure -match "expected='[a-f0-9]{64}'" -and $modifiedFailure -match "actual='[a-f0-9]{64}'") `
        'sync.sh did not fail closed with expected/actual hashes for consumer-modified managed content.'

    Copy-Item -LiteralPath (Join-Path $source 'instructions/example.instructions.md') -Destination $managedInstruction -Force
    $lock = Read-GuidanceLock -RepoRoot $consumer
    $foreignClaim = New-GuidanceLockEntry -RepoRoot $consumer -Path '.github/instructions/example.instructions.md' `
        -Owner sheen -Sha256 (Get-GuidanceContentHash -Path $managedInstruction)
    $remainingEntries = @($lock.entries | Where-Object path -ne '.github/instructions/example.instructions.md')
    Write-GuidanceLock -RepoRoot $consumer -Entries ($remainingEntries + $foreignClaim)

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$source"
        $env:BASECOAT_MIRROR = "file://$mirror"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        $collisionFailure = & $bash.Source (Join-Path $repoRoot 'sync.sh') 2>&1 | Out-String
        $collisionExitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        Pop-Location
    }
    Assert-True ($collisionExitCode -ne 0 -and $collisionFailure -match 'GUIDANCE_PATH_COLLISION' -and
        $collisionFailure -match "owner='sheen'") `
        'sync.sh did not block a foreign owner before overwrite.'

    $lock = Read-GuidanceLock -RepoRoot $consumer
    $basecoatClaim = New-GuidanceLockEntry -RepoRoot $consumer -Path '.github/instructions/example.instructions.md' `
        -Owner basecoat -GuidanceUnit 'instructions/example.instructions.md' -SourceVersion '1.0.1' `
        -Sha256 (Get-GuidanceContentHash -Path $managedInstruction)
    $remainingEntries = @($lock.entries | Where-Object path -ne '.github/instructions/example.instructions.md')
    Write-GuidanceLock -RepoRoot $consumer -Entries ($remainingEntries + $basecoatClaim)

    $predecessorPath = '.github/agents/agentic-sdlc-autonomy.agent.md'
    $predecessorHash = '2487c414f197e0e999164c6da9a6254417eeb317c6442000b868184dccee45ea'
    $predecessorFile = Join-Path $consumer $predecessorPath
    $lock = Read-GuidanceLock -RepoRoot $consumer
    $predecessorEntry = @($lock.entries | Where-Object path -eq $predecessorPath) | Select-Object -First 1
    $predecessorEntry.sha256 = $predecessorHash
    Write-GuidanceLock -RepoRoot $consumer -Entries @($lock.entries)

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$source"
        $env:BASECOAT_MIRROR = "file://$mirror"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        & $bash.Source (Join-Path $repoRoot 'sync.sh')
        if ($LASTEXITCODE -ne 0) { throw 'sync.sh rejected the exact approved predecessor path/hash.' }
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        Pop-Location
    }

    $migratedEntry = @((Read-GuidanceLock -RepoRoot $consumer).entries |
        Where-Object path -eq $predecessorPath) | Select-Object -First 1
    Assert-True ($migratedEntry.sha256 -eq (Get-GuidanceContentHash -Path $predecessorFile)) `
        'sync.sh did not migrate the exact approved predecessor to the canonical payload hash.'

    $lock = Read-GuidanceLock -RepoRoot $consumer
    $predecessorEntry = @($lock.entries | Where-Object path -eq $predecessorPath) | Select-Object -First 1
    $predecessorEntry.sha256 = $predecessorHash
    Write-GuidanceLock -RepoRoot $consumer -Entries @($lock.entries)
    '# consumer modification' | Set-Content -LiteralPath $predecessorFile -Encoding utf8NoBOM

    Push-Location $consumer
    try {
        $env:BASECOAT_REPO = "file://$source"
        $env:BASECOAT_MIRROR = "file://$mirror"
        $env:BASECOAT_REF = $sha
        $env:BASECOAT_EXPECTED_SHA = $sha
        $predecessorFailure = & $bash.Source (Join-Path $repoRoot 'sync.sh') 2>&1 | Out-String
        $predecessorExitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_MIRROR,Env:\BASECOAT_REF,Env:\BASECOAT_EXPECTED_SHA -ErrorAction SilentlyContinue
        Pop-Location
    }
    Assert-True ($predecessorExitCode -ne 0 -and $predecessorFailure -match 'GUIDANCE_CONTENT_MODIFIED') `
        'sync.sh accepted modified content under the exact approved predecessor path/hash.'
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

# Rollback parity (#3776): rollback.sh to vN equals a fresh sync of vN.
$rbScratch = Join-Path $repoRoot 'test-results/rollback-sh-parity'
try {
    Remove-Item -LiteralPath $rbScratch -Recurse -Force -ErrorAction SilentlyContinue
    $rbSource = Join-Path $rbScratch 'source'
    git init -q $rbSource
    git -C $rbSource config user.name basecoat-test
    git -C $rbSource config user.email basecoat-test@example.com
    foreach ($release in @(
            @{ Version = '1.0.0'; Instruction = 'retired'; Tag = 'v1.0.0' },
            @{ Version = '1.1.0'; Instruction = 'added'; Tag = 'v1.1.0' },
            # Drifted version.json makes sync.sh fail late, after projections and the lock are written.
            @{ Version = '9.9.9'; Instruction = 'drifted'; Tag = 'v1.2.0' })) {
        Get-ChildItem -LiteralPath $rbSource -Force | Where-Object Name -ne '.git' | Remove-Item -Recurse -Force
        New-Item -ItemType Directory -Path (Join-Path $rbSource 'agents'),(Join-Path $rbSource 'instructions'),(Join-Path $rbSource 'docs/reference') -Force | Out-Null
        "{`"version`":`"$($release.Version)`"}" | Set-Content -LiteralPath (Join-Path $rbSource 'version.json') -Encoding utf8NoBOM
        '{"schemaVersion":"1","assets":[]}' | Set-Content -LiteralPath (Join-Path $rbSource 'asset-manifest.json') -Encoding utf8NoBOM
        '# source' | Set-Content -LiteralPath (Join-Path $rbSource 'README.md') -Encoding utf8NoBOM
        '# reference' | Set-Content -LiteralPath (Join-Path $rbSource 'docs/reference/README.md') -Encoding utf8NoBOM
        "---`nname: rollback`ndescription: v$($release.Version)`n---" | Set-Content -LiteralPath (Join-Path $rbSource 'agents/rollback.agent.md') -Encoding utf8NoBOM
        "---`ndescription: $($release.Instruction)`napplyTo: '**/*'`n---" |
            Set-Content -LiteralPath (Join-Path $rbSource "instructions/$($release.Instruction).instructions.md") -Encoding utf8NoBOM
        git -C $rbSource add -A
        git -C $rbSource commit -q -m "release $($release.Version)" | Out-Null
        git -C $rbSource tag $release.Tag
    }

    $rbState = {
        param([string]$Root)
        $files = foreach ($dir in '.github/agents', '.github/instructions') {
            Get-ChildItem -LiteralPath (Join-Path $Root $dir) -Recurse -File | Where-Object Name -notlike 'adhesion-*' |
                ForEach-Object { "$($_.Name)=$(Get-GuidanceContentHash -Path $_.FullName)" }
        }
        $owned = @((Read-GuidanceLock -RepoRoot $Root).entries | Where-Object owner -eq 'basecoat')
        return "$(@($files | Sort-Object) -join ';')|$($owned | ConvertTo-Json -Depth 4 -Compress)"
    }
    $rbRun = {
        param([string]$Root, [string]$Script, [string[]]$Arguments)
        Push-Location $Root
        try {
            $env:BASECOAT_REPO = "file://$rbSource"
            $output = & $bash.Source (Join-Path $repoRoot $Script) @Arguments 2>&1 | Out-String
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
        finally {
            Remove-Item Env:\BASECOAT_REPO,Env:\BASECOAT_REF -ErrorAction SilentlyContinue
            Pop-Location
        }
    }
    $rbConsumer = {
        param([string]$Name, [string]$Ref)
        $root = Join-Path $rbScratch $Name
        git init -q $root
        "source: file://$rbSource`nref: $Ref" | Set-Content -LiteralPath (Join-Path $root '.basecoat.yml') -Encoding utf8NoBOM
        $result = & $rbRun $root 'sync.sh' @()
        if ($result.ExitCode -ne 0) { throw "sync.sh $Ref failed for ${Name}: $($result.Output)" }
        return $root
    }

    $expectedState = & $rbState (& $rbConsumer 'fresh' 'v1.0.0')

    $rolled = & $rbConsumer 'rolled' 'v1.0.0'
    $foreignRel = '.github/instructions/adhesion-owned.instructions.md'
    'adhesion' | Set-Content -LiteralPath (Join-Path $rolled $foreignRel) -Encoding utf8NoBOM
    $foreignEntry = New-GuidanceLockEntry -RepoRoot $rolled -Path $foreignRel -Owner 'adhesion' -Sha256 (Get-GuidanceContentHash -Path (Join-Path $rolled $foreignRel))
    Write-GuidanceLock -RepoRoot $rolled -Entries (@((Read-GuidanceLock -RepoRoot $rolled).entries) + $foreignEntry)
    "source: file://$rbSource`nref: v1.1.0" | Set-Content -LiteralPath (Join-Path $rolled '.basecoat.yml') -Encoding utf8NoBOM
    $upgrade = & $rbRun $rolled 'sync.sh' @()
    Assert-True ($upgrade.ExitCode -eq 0) "sync.sh v1.1.0 upgrade failed: $($upgrade.Output)"
    $rollback = & $rbRun $rolled 'rollback.sh' @('v1.0.0')
    Assert-True ($rollback.ExitCode -eq 0) "rollback.sh v1.0.0 failed: $($rollback.Output)"
    Assert-True ((& $rbState $rolled) -eq $expectedState) 'rollback.sh projections or basecoat lock entries differ from a fresh v1.0.0 sync.'
    $foreignAfter = @((Read-GuidanceLock -RepoRoot $rolled).entries | Where-Object owner -eq 'adhesion')
    Assert-True ($foreignAfter.Count -eq 1 -and $foreignAfter[0].sha256 -eq $foreignEntry.sha256 -and
        (Test-Path -LiteralPath (Join-Path $rolled $foreignRel))) 'rollback.sh changed a foreign-owned lock entry or file.'
    Assert-True ((Get-Content -LiteralPath (Join-Path $rolled '.basecoat.yml') -Raw) -match '(?m)^ref: v1\.0\.0$') 'rollback.sh did not update the .basecoat.yml pin after success.'
    $rbSnapshot = { "$(& $rbState $rolled)|$(Get-Content -LiteralPath (Join-Path $rolled '.github/base-coat/guidance-lock.json') -Raw)|$(Get-Content -LiteralPath (Join-Path $rolled '.github/base-coat/.source-provenance.json') -Raw)|$(Get-Content -LiteralPath (Join-Path $rolled '.basecoat.yml') -Raw)|$(Test-Path -LiteralPath (Join-Path $rolled '.github/base-coat/guidance-lock.lease'))" }
    $beforeLate = & $rbSnapshot
    $late = & $rbRun $rolled 'rollback.sh' @('v1.2.0')
    Assert-True ($late.ExitCode -ne 0 -and $late.Output -match 'provenance check failed') "rollback.sh v1.2.0 did not fail late in sync.sh: $($late.Output)"
    Assert-True ((& $rbSnapshot) -eq $beforeLate) 'A late sync.sh failure left projections, lock, provenance, pin, or lease changed after rollback.sh.'
    Set-ItemProperty -LiteralPath (Join-Path $rolled '.basecoat.yml') -Name IsReadOnly -Value $true
    $pinFailure = & $rbRun $rolled 'rollback.sh' @('v1.1.0')
    Assert-True ($pinFailure.ExitCode -ne 0 -and (& $rbSnapshot) -eq $beforeLate) "A failed .basecoat.yml pin write did not restore the prior install: $($pinFailure.Output)"
    $leaseDir = "$(git -C $rolled rev-parse --show-toplevel)/.github/base-coat/guidance-lock.lease"; New-Item -ItemType Directory -Path $leaseDir | Out-Null
    "token=held`nacquiredEpoch=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 598)" | Set-Content -LiteralPath (Join-Path $leaseDir 'owner') -Encoding ascii
    $env:BASECOAT_GUIDANCE_LEASE = "$leaseDir|other"; $env:BASECOAT_REF = 'v1.1.0'; try { $foreign = & $rbRun $rolled 'sync.sh' @() } finally { Remove-Item Env:\BASECOAT_GUIDANCE_LEASE }
    Assert-True ($foreign.ExitCode -ne 0 -and $foreign.Output -match 'GUIDANCE_LOCK_BUSY' -and (Get-Content -LiteralPath (Join-Path $rolled '.github/base-coat/version.json') -Raw) -match '1\.0\.0') "sync.sh wrote the staged payload before rejecting a foreign inherited lease: $($foreign.Output)"
    $env:BASECOAT_GUIDANCE_LEASE = "$leaseDir|held"; try { $inherited = & $rbRun $rolled 'sync.sh' @() } finally { Remove-Item Env:\BASECOAT_GUIDANCE_LEASE }
    Start-Sleep -Seconds 3; $takeover = try { Enter-GuidanceLockLease -RepoRoot $rolled -TimeoutSeconds 0 } catch { 'busy' }; Remove-Item -LiteralPath $leaseDir -Recurse -Force
    Assert-True ($inherited.ExitCode -eq 0 -and $takeover -eq 'busy') "sync.sh did not renew an aged inherited lease, so another writer could reclaim it mid-sync: $($inherited.Output)"

    $edited = & $rbConsumer 'edited' 'v1.1.0'
    Add-Content -LiteralPath (Join-Path $edited '.github/instructions/added.instructions.md') 'local edit'
    $blocked = & $rbRun $edited 'rollback.sh' @('v1.0.0')
    Assert-True ($blocked.ExitCode -ne 0 -and $blocked.Output -match 'GUIDANCE_CONTENT_MODIFIED') 'rollback.sh did not stop on a locally modified BaseCoat-owned file.'
    $stagedVersion = (Get-Content -LiteralPath (Join-Path $edited '.github/base-coat/version.json') -Raw | ConvertFrom-Json).version
    Assert-True ($stagedVersion -eq '1.1.0' -and (Get-Content -LiteralPath (Join-Path $edited '.basecoat.yml') -Raw) -match 'ref: v1\.1\.0') `
        'A failed rollback.sh changed the staged payload or the .basecoat.yml pin.'
}
finally {
    Remove-Item -LiteralPath $rbScratch -Recurse -Force -ErrorAction SilentlyContinue
}

# Agents allow-list parity (#3747): same scoping, pruning, and opt-out as sync.ps1.
$alScratch = Join-Path $repoRoot 'test-results/sync-sh-agents-allow-list'
try {
    Remove-Item -LiteralPath $alScratch -Recurse -Force -ErrorAction SilentlyContinue
    $alSource = Join-Path $alScratch 'source'
    $alConsumer = Join-Path $alScratch 'consumer'
    git init -q $alSource
    git -C $alSource config user.name basecoat-test
    git -C $alSource config user.email basecoat-test@example.com
    New-Item -ItemType Directory -Path (Join-Path $alSource 'agents/references'),(Join-Path $alSource 'docs/reference') -Force | Out-Null
    '{"version":"1.0.0"}' | Set-Content -LiteralPath (Join-Path $alSource 'version.json') -Encoding utf8NoBOM
    '{"schemaVersion":"1","assets":[]}' | Set-Content -LiteralPath (Join-Path $alSource 'asset-manifest.json') -Encoding utf8NoBOM
    '# source' | Set-Content -LiteralPath (Join-Path $alSource 'README.md') -Encoding utf8NoBOM
    '# reference' | Set-Content -LiteralPath (Join-Path $alSource 'docs/reference/README.md') -Encoding utf8NoBOM
    "---`nname: alpha`ndescription: alpha`n---`n[detail](references/alpha-detail.md)" | Set-Content -LiteralPath (Join-Path $alSource 'agents/alpha.agent.md') -Encoding utf8NoBOM
    "---`nname: `"beta`"`ndescription: beta`n---`n[detail](references/beta-detail.md)" | Set-Content -LiteralPath (Join-Path $alSource 'agents/basecoat-10-core-beta.agent.md') -Encoding utf8NoBOM
    '# alpha detail' | Set-Content -LiteralPath (Join-Path $alSource 'agents/references/alpha-detail.md') -Encoding utf8NoBOM
    '# beta detail' | Set-Content -LiteralPath (Join-Path $alSource 'agents/references/beta-detail.md') -Encoding utf8NoBOM
    git -C $alSource add -A
    git -C $alSource commit -q -m 'seed' | Out-Null
    git -C $alSource tag v1.0.0
    git init -q $alConsumer
    New-Item -ItemType Directory -Path (Join-Path $alConsumer '.github/agents') -Force | Out-Null
    '# consumer-owned agent' | Set-Content -LiteralPath (Join-Path $alConsumer '.github/agents/consumer-owned.agent.md') -Encoding utf8NoBOM

    $alConfig = Join-Path $alConsumer '.basecoat.yml'
    $alProjected = { @(Get-ChildItem -LiteralPath (Join-Path $alConsumer '.github/agents') -Filter '*.agent.md' -File | ForEach-Object Name | Sort-Object) -join ',' }
    $alLock = { @((Read-GuidanceLock -RepoRoot $alConsumer).entries | Where-Object { $_.owner -eq 'basecoat' -and $_.path -like '.github/agent*' } | ForEach-Object path | Sort-Object) -join ',' }
    $alSync = {
        param([string]$Config)
        "source: file://$alSource`nref: v1.0.0`n$Config" | Set-Content -LiteralPath $alConfig -Encoding utf8NoBOM
        Push-Location $alConsumer
        try {
            $output = & $bash.Source (Join-Path $repoRoot 'sync.sh') 2>&1 | Out-String
            return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
        finally { Pop-Location }
    }

    $run = & $alSync ''
    Assert-True ($run.ExitCode -eq 0 -and (& $alProjected) -eq 'alpha.agent.md,basecoat-10-core-beta.agent.md,consumer-owned.agent.md') "sync.sh without agents: must project every agent: $($run.Output)"
    $run = & $alSync "# scoped`nagents:`n  - alpha  # keep`n  - `"missing-agent`"`nskills:`n  - unrelated"
    Assert-True ($run.ExitCode -eq 0 -and (& $alProjected) -eq 'alpha.agent.md,consumer-owned.agent.md' -and
        (& $alLock) -eq '.github/agent-references/alpha-detail.md,.github/agents/alpha.agent.md') "sync.sh block allow-list did not scope projection/lock: $(& $alProjected) | $(& $alLock)"
    Assert-True ($run.Output -match "entry 'missing-agent' does not match") 'sync.sh did not report an unknown allow-list entry.'
    $run = & $alSync 'agents: []'
    Assert-True ($run.ExitCode -eq 0 -and (& $alProjected) -eq 'consumer-owned.agent.md' -and (& $alLock) -eq '' -and
        -not (Test-Path -LiteralPath (Join-Path $alConsumer '.github/agent-references/alpha-detail.md'))) "sync.sh agents: [] did not remove every projected agent and reference: $($run.Output)"
    Assert-True (Test-Path -LiteralPath (Join-Path $alConsumer '.github/base-coat/agents/basecoat-10-core-beta.agent.md')) 'sync.sh agents: [] must keep agents staged under .github/base-coat/agents.'
    $run = & $alSync "agents: [ 'beta' ]"
    Assert-True ($run.ExitCode -eq 0 -and (& $alProjected) -eq 'basecoat-10-core-beta.agent.md,consumer-owned.agent.md' -and
        (& $alLock) -eq '.github/agent-references/beta-detail.md,.github/agents/basecoat-10-core-beta.agent.md' -and
        -not (Test-Path -LiteralPath (Join-Path $alConsumer '.github/agent-references/alpha-detail.md'))) "sync.sh beta-only flow list did not scope projection/lock: $(& $alProjected) | $(& $alLock)"
    $run = & $alSync "agents: [ 'beta', alpha.agent.md, alpha.AGENT.MD ]"
    Assert-True ($run.ExitCode -eq 0 -and (& $alProjected) -eq 'alpha.agent.md,basecoat-10-core-beta.agent.md,consumer-owned.agent.md') "sync.sh flow allow-list was not honored: $($run.Output)"
    Assert-True ($run.Output -match "entry 'alpha\.AGENT\.MD' does not match") 'sync.sh must strip the .agent.md suffix case-sensitively.'
    $run = & $alSync 'agents: all'
    Assert-True ($run.ExitCode -ne 0 -and $run.Output -match "Invalid \.basecoat\.yml 'agents:' value 'all'" -and
        (& $alProjected) -eq 'alpha.agent.md,basecoat-10-core-beta.agent.md,consumer-owned.agent.md') "sync.sh must reject an unsupported agents value before any write: $($run.Output)"
    foreach ($bad in "agents:`n  name: alpha", "agents:`n  - name: alpha", "agents:`n  -", "agents:`n  -alpha", 'agents: [,]') {
        $run = & $alSync $bad
        Assert-True ($run.ExitCode -ne 0 -and $run.Output -match "Invalid \.basecoat\.yml 'agents:' value '(name: alpha|-alpha)?'" -and
            (& $alProjected) -eq 'alpha.agent.md,basecoat-10-core-beta.agent.md,consumer-owned.agent.md') "sync.sh must fail closed on a mapping or empty entry under agents: $($run.Output)"
    }
}
finally {
    Remove-Item -LiteralPath $alScratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Bash sync parity tests passed.'
