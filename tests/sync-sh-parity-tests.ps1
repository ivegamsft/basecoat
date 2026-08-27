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
    New-Item -ItemType Directory -Path (Join-Path $source 'agents/references') -Force | Out-Null
    '# example detail reference' | Set-Content -LiteralPath (Join-Path $source 'agents/references/example-detail.md') -Encoding utf8NoBOM
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
    Assert-True (Test-Path -LiteralPath (Join-Path $consumer '.github/agents/references/example-detail.md')) 'sync.sh did not distribute the agents/references subtree into .github/agents/references.'
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
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'Bash sync parity tests passed.'
